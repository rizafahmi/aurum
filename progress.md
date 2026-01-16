# Progress Log

## 2026-01-16 22:00

### US-002 Test 1: shows empty state when no items exist

**Implementation:**
- Created `AurumWeb.DashboardLive` LiveView at `/`
- Replaced `PageController` home route with LiveView
- Added `#empty-portfolio` div with link to add first item
- Added `h1` with "Aurum" branding

**Files created:**
- `lib/aurum_web/live/dashboard_live.ex`

**Files modified:**
- `lib/aurum_web/router.ex` - replaced `get "/" with `live "/", DashboardLive`
- `test/aurum_web/controllers/page_controller_test.exs` - updated to expect dashboard
- `test/aurum_web/features/portfolio_dashboard_test.exs` - unskipped Test 1, added `@tag :skip` to remaining tests

**Test status:** ✅ PASSED (140 tests, 0 failures)

---

## 2026-01-16 22:10

### US-002 Test 2: displays total pure gold weight in grams

**Implementation:**
- Added `calculate_summary/1` function using `Valuation.aggregate_portfolio/2`
- Uses hardcoded spot price (`85.00 USD/g`) for now (will be replaced by price API)
- Displays `#total-gold-weight` with pure gold weight calculation

**Learnings:**
- `weight_unit` enum uses `:grams` (plural), not `:gram`
- Valuation module already has `karat_to_purity/1` for purity conversion
- `valuate_item/6` requires spot price per gram

**Files modified:**
- `lib/aurum_web/live/dashboard_live.ex` - Added summary calculation and display
- `test/aurum_web/features/portfolio_dashboard_test.exs` - Fixed test setup, unskipped Test 2

**Test status:** ✅ PASSED (140 tests, 0 failures, 43 skipped)

---

## 2026-01-16 22:15

### US-002 Test 3: displays total invested amount

**Implementation:**
- Added `#total-invested` element showing `@summary.total_invested`

**Files modified:**
- `lib/aurum_web/live/dashboard_live.ex` - Added total invested display
- `test/aurum_web/features/portfolio_dashboard_test.exs` - Unskipped Test 3

**Test status:** ✅ PASSED (140 tests, 0 failures, 42 skipped)

---

## 2026-01-16 22:18

### US-002 Test 4: displays current total value

**Implementation:**
- Added `#total-current-value` element showing `@summary.total_current_value`

**Files modified:**
- `lib/aurum_web/live/dashboard_live.ex` - Added current value display

**Test status:** ✅ PASSED (140 tests, 0 failures, 41 skipped)

---

## 2026-01-16 22:20

### US-002 Test 5: displays unrealized gain/loss in absolute value

**Implementation:**
- Added `#gain-loss-amount` element showing `@summary.total_gain_loss`

**Files modified:**
- `lib/aurum_web/live/dashboard_live.ex` - Added gain/loss display

**Test status:** ✅ PASSED (140 tests, 0 failures, 40 skipped)

---

## 2026-01-16 22:22

### US-002 Test 6: displays unrealized gain/loss as percentage

**Implementation:**
- Added `#gain-loss-percent` element showing `@summary.total_gain_loss_percent`

**Files modified:**
- `lib/aurum_web/live/dashboard_live.ex` - Added percentage display

**Test status:** ✅ PASSED (140 tests, 0 failures, 39 skipped)

---

## 2026-01-16 22:25

### US-002: View Portfolio Dashboard — COMPLETE ✅

**All 6 acceptance tests passing:**
1. ✅ shows empty state when no items exist
2. ✅ displays total pure gold weight in grams
3. ✅ displays total invested amount
4. ✅ displays current total value
5. ✅ displays unrealized gain/loss in absolute value
6. ✅ displays unrealized gain/loss as percentage

**Implementation summary:**
- LiveView: `AurumWeb.DashboardLive` at `/`
- Uses `Valuation.aggregate_portfolio/2` for calculations
- Currently uses hardcoded spot price (85 USD/g) - to be replaced by PriceCache

**Dashboard displays:**
- `#empty-portfolio` - Empty state with link to add first item
- `#total-gold-weight` - Total pure gold in grams
- `#total-invested` - Sum of purchase prices
- `#total-current-value` - Current value based on spot price
- `#gain-loss-amount` - Unrealized gain/loss in USD
- `#gain-loss-percent` - Gain/loss as percentage

---

## 2026-01-16 22:30

### US-002 Refactor: Code Quality Improvements

**Changes based on Oracle review:**

1. **Avoid double DB hits** - Added `connected?(socket)` guard in `mount/3`
   - Only loads data after WebSocket connection established
   - Prevents duplicate DB queries on initial render + connect

2. **Pattern-matched render clauses** - Split `render/1` into two function heads
   - `render(%{items: []} = assigns)` for empty state
   - `render(assigns)` for populated state
   - More idiomatic than `if @items == []`

3. **Extracted `stat_card` component** - Reduced template duplication
   - Private component with `id`, `label`, `value`, `subtitle` attrs
   - Eliminates 4 near-identical div blocks

4. **Moved domain logic to context** - Created `Portfolio.dashboard_summary/1`
   - LiveView no longer imports Valuation module
   - Single `Enum.reduce/3` instead of two `Enum.map/2` passes
   - Spot price extracted to module attribute `@default_spot_price`

5. **Improved readability** - Summary calculation uses reduce pattern
   - Builds valuations and purchase_prices in single pass
   - Reverses at end to maintain order

**Files modified:**
- `lib/aurum_web/live/dashboard_live.ex` - Refactored with improvements
- `lib/aurum/portfolio.ex` - Added `dashboard_summary/1` and `calculate_summary/2`

**Test status:** ✅ PASSED (140 tests, 0 failures, 39 skipped)

---

## 2026-01-16 21:00

### US-001 Test 1: displays form with all required fields

**Implementation:**
- Added route `live "/items/new", ItemLive.New` to router
- Created `AurumWeb.ItemLive.New` LiveView with form

**Form fields implemented:**
- `input#item-name` (text)
- `select#item-category` (dropdown)
- `input#item-weight` (number)
- `select#item-weight-unit` (dropdown)
- `select#item-purity` (dropdown)
- `input#item-quantity` (number)
- `input#item-purchase-price` (number)
- `input#item-purchase-date` (date)
- `textarea#item-notes` (textarea)

**Files created:**
- `lib/aurum_web/live/item_live/new.ex`

**Files modified:**
- `lib/aurum_web/router.ex` - added `/items/new` route

**Test status:** ✅ PASSED

---

## 2026-01-16 21:15

### US-001 Tests 2-5: Category, Purity, Weight Unit, Create Item

**Tests 2-4:** Already passing from Test 1 implementation (dropdowns had correct options).

**Test 5: "successfully creates gold item with valid data"**

**Implementation:**
- Created `Aurum.Portfolio.Item` schema with Ecto validations
- Created `Aurum.Portfolio` context with `create_item/1`, `list_items/0`
- Created migration for `items` table
- Updated `ItemLive.New` to use changeset and handle save event
- Created `ItemLive.Index` to list items
- Added `/items` route

**Schema fields:**
- name (string), category (enum), weight (decimal), weight_unit (enum)
- purity (integer), quantity (integer), purchase_price (decimal)
- purchase_date (date, optional), notes (string, optional)

**Files created:**
- `lib/aurum/portfolio/item.ex` - Ecto schema
- `lib/aurum/portfolio.ex` - Context module
- `lib/aurum_web/live/item_live/index.ex` - List view
- `priv/repo/migrations/20260116210000_create_items.exs`

**Test status:** ✅ Tests 2-5 PASSED

---

## 2026-01-16 21:30

### Refactor: Code Quality Improvements

**Changes based on Oracle review:**

1. **Purity validation added** - `validate_inclusion(:purity, [24, 22, 18, 14])`

2. **Live validation (phx-change)** - Added `phx-change="validate"` and handler for real-time validation feedback

3. **Flash message on success** - `put_flash(:info, "Gold item created successfully")`

4. **Centralized options** - Moved category/purity/weight_unit options to `Item` module:
   - `Item.category_options/0`
   - `Item.purity_options/0`
   - `Item.weight_unit_options/0`

5. **Centralized formatting** - Label functions in schema:
   - `Item.category_label/1`
   - `Item.purity_label/1`
   - `Item.weight_unit_label/1`, `Item.weight_unit_short/1`

6. **Input trimming** - `update_change(:name, &String.trim/1)` and notes

7. **Name length validation** - `validate_length(:name, min: 1, max: 100)`

**Files modified:**
- `lib/aurum/portfolio/item.ex` - Added validations, options, and label helpers
- `lib/aurum_web/live/item_live/new.ex` - phx-change, flash, use Item options
- `lib/aurum_web/live/item_live/index.ex` - Use Item label helpers

**Test status:** ✅ All 9 US-001 tests still pass, full suite passes (140 tests)

---

## 2026-01-16 21:45

### US-001: Create Gold Item — COMPLETE ✅

**All 9 acceptance tests passing:**
1. ✅ displays form with all required fields
2. ✅ category dropdown has exactly 4 options
3. ✅ purity accepts preset karat values
4. ✅ weight unit selector offers grams and troy oz
5. ✅ successfully creates gold item with valid data
6. ✅ creates item with optional fields
7. ✅ validates weight must be positive
8. ✅ validates quantity must be positive
9. ✅ validates purchase price must be non-negative

**Implementation summary:**
- Schema: `Aurum.Portfolio.Item` with Ecto validations
- Context: `Aurum.Portfolio` with create/list/change functions
- LiveViews: `ItemLive.New` (form), `ItemLive.Index` (list)
- Routes: `/items/new`, `/items`
- Migration: `create_items` table

**Quality improvements applied:**
- Live validation (phx-change)
- Flash messages
- Centralized options/labels in schema
- Input trimming
- Purity validation

---

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



