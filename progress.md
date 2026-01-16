# Progress Log

## 2026-01-16 20:00

### Risk #5 Validation: Unit Conversion Safety

Built `Aurum.Units` module to prevent unit conversion data corruption.

**Design decisions:**
- Store canonical value in grams (DB always stores grams)
- Preserve original input unit for display
- `weight_input` struct tracks: value, unit, canonical_grams
- Explicit function names prevent accidental double-conversion

**Key functions:**
- `create_weight_input/2` - Creates struct from user input
- `restore_weight_input/2` - Recreates from DB for editing
- `update_weight_value/2` - User edits value (recalculates canonical)
- `update_weight_unit/2` - User switches unit (preserves physical amount)

**Test coverage (34 tests):**
- 28 unit tests including 5 round-trip edit scenarios
- 6 property-based tests for stability

**Round-trip scenarios tested:**
1. Enter 1 troy oz → save → load → edit → save
2. Switch unit mid-edit (troy oz → grams)
3. Enter grams → switch to troy oz → edit → save
4. Multiple load/save cycles (no drift)
5. Multiple edits preserve precision

**Files created:**
- `lib/aurum/units.ex` - Unit conversion with canonical storage
- `test/aurum/units_test.exs` - Unit + property tests

---

## 2026-01-16 19:45

### Risk #4 Validation: Decimal Precision for Valuations

Built `Aurum.Portfolio.Valuation` module with Decimal-based calculations.

**Features implemented:**
- Pure gold weight calculation (weight × purity × quantity)
- Current value calculation (pure grams × spot price)
- Gain/loss and percentage calculations
- Unit conversions (troy oz ↔ grams)
- Karat to purity conversion
- Portfolio aggregation

**Precision rules:**
- Weight: 4 decimal places
- Currency: 2 decimal places
- All intermediate calculations use full Decimal precision

**Test coverage (32 tests):**
- 22 unit tests for core calculations
- 10 property-based tests for invariants

**Property tests validate:**
- Precision limits respected
- Linear scaling with quantity
- Gain/loss consistency
- Round-trip unit conversion stability
- Edge cases: tiny weights, large quantities, high precision floats

**Files created:**
- `lib/aurum/portfolio/valuation.ex` - Decimal-based valuation logic
- `test/aurum/portfolio/valuation_test.exs` - Unit + property tests

**Dependencies added:**
- `stream_data` for property-based testing

---

## 2026-01-16 19:30

### Risk #3 Validation: Price Cache with Staleness Detection

Built `Aurum.Gold.PriceCache` GenServer to validate offline-first caching.

**Features implemented:**
- TTL-based staleness detection (configurable, default 15 minutes)
- Cached price returned when API fails
- Staleness indicator in all price responses
- Age tracking in milliseconds and human-readable format
- Error counting for reliability monitoring
- Auto-refresh capability (optional)

**Test coverage (17 tests):**
- Staleness triggers correctly after threshold
- Cached price persists through API failures
- Refresh failures don't lose cached data
- Age/staleness tracking accuracy

**Findings:**
- GenServer approach works well for single-node caching
- Mock function injection enables thorough testing without network calls
- Staleness detection is reliable with millisecond precision

**Files created:**
- `lib/aurum/gold/price_cache.ex` - GenServer with TTL logic
- `test/aurum/gold/price_cache_test.exs` - 17 tests for cache behavior

---

## 2026-01-16 19:15

### Risk #1 Validation: Gold Price API

Built `Aurum.Gold.PriceClient` module to validate API reliability.

**Candidate APIs tested:**
1. **NBP (Polish National Bank)** - ✅ Working, free, no auth required
   - Returns gold price in PLN per gram
   - ~500-1000ms response time
   - Daily updates only
   
2. **GoldAPI.io** - Requires API key (100 req/month free)
   - Returns XAU/USD spot price
   - Real-time updates
   
3. **MetalpriceAPI** - Requires API key (free tier available)
   - Returns XAU/USD spot price
   - Real-time updates

**Findings:**
- NBP is the only truly free API (no auth), but returns PLN not USD
- For USD prices, we need GoldAPI.io or MetalpriceAPI (both require registration)
- Fallback strategy implemented: GoldAPI → MetalpriceAPI → NBP

**Files created:**
- `lib/aurum/gold/price_client.ex` - Multi-provider price fetcher with schema validation
- `lib/aurum/gold/api_monitor.ex` - 24-hour reliability monitoring tool
- `test/aurum/gold/price_client_test.exs` - Schema validation tests

**Next steps:**
- Register for GoldAPI.io free tier to get USD prices
- Run 24-hour monitoring with `Aurum.Gold.ApiMonitor.start_monitoring()`

---

## 2026-01-16 17:09

Initialize project



