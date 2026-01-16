# Technical Risks

Top 5 technical risks that could kill this project, ranked by likelihood of failure and how much they block everything else.

---

## RISK 1: Free gold price API is unreliable or disappears

**Assumption:** A free, public XAU/USD API exists that we can use without user authentication.

**Failure Mode:** Public XAU APIs have rate limits, require API keys, shut down, or return inconsistent data formats. Most "free" APIs are actually freemium with tight limits.

**Test:** Build a `Aurum.Gold.PriceClient` module that fetches from 2-3 candidate APIs, logs response times/failures over 24 hours, and validates response schema matches expectations.

---

## ~~RISK 2: SQLite encryption adds unacceptable complexity~~ (SKIPPED)

**Decision:** Skip encryption for MVP.

**Rationale:**
- Core value prop is "data never leaves your device" (network privacy), not disk encryption
- If attacker has filesystem access, they likely have full device access anyway
- SQLCipher adds significant complexity (custom compilation, potential Elixir binding issues)
- No clear user benefit for MVP scope
- Can add post-MVP if users request it

---

## RISK 3: Offline-first cache invalidation causes stale/wrong valuations ✅ VALIDATED

**Assumption:** We can cache the gold price locally and clearly indicate when it's stale.

**Failure Mode:** Cached price gets stuck, timestamps drift, or users see outdated valuations without realizing. Trust is destroyed if numbers are silently wrong.

**Test:** Build `Aurum.Gold.PriceCache` GenServer with TTL logic, write tests simulating API failures, and verify stale indicators trigger correctly after 15+ minutes.

**Result:** ✅ Validated with 17 passing tests
- Staleness detection works reliably with configurable TTL
- Cached prices persist through API failures
- All responses include `stale: true/false` indicator
- Age tracking in milliseconds enables precise staleness UI

---

## RISK 4: Floating-point precision errors in valuation math ✅ VALIDATED

**Assumption:** We can perform accurate financial calculations for portfolio valuation.

**Failure Mode:** Weight × purity × price accumulates rounding errors. Users see $0.01 discrepancies that erode trust in "honest math" promise.

**Test:** Create `Aurum.Portfolio.Valuation` module using `Decimal` for all calculations, write property-based tests with edge cases (tiny weights, high quantities), verify round-trip consistency.

**Result:** ✅ Validated with 22 unit tests + 10 property-based tests
- All calculations use Decimal library (no floats in core logic)
- Weight precision: 4 decimal places
- Currency precision: 2 decimal places
- Property tests verify: linear scaling, round-trip stability, edge cases
- Tested: tiny weights (0.000001g), large quantities (1M), high precision floats

---

## RISK 5: Troy oz ↔ gram conversion causes data corruption

**Assumption:** Users can enter weight in either grams or troy ounces and we store/display correctly.

**Failure Mode:** Unit stored ambiguously, conversion applied twice, or precision lost. User enters 1 troy oz, sees 31.1g, edits, saves as 31.1 troy oz.

**Test:** Build `Aurum.Units` module with explicit conversion functions, store canonical unit (grams) in DB with original input unit, write tests for round-trip edit scenarios.
