---
title: feat: Add real-time portfolio dashboard
type: feat
status: active
date: 2026-03-28
origin: docs/brainstorms/2026-03-28-real-time-portfolio-dashboard-requirements.md
---

# feat: Add real-time portfolio dashboard

## Overview

Add a single-page LiveView dashboard for tracking physical gold investments with real-time price updates. The dashboard displays portfolio metrics (total value, weight breakdown, cost basis, ROI), lists individual holdings, and provides inline forms for adding/editing holdings. Gold prices are fetched every 30 minutes from external APIs and broadcast via Phoenix PubSub for automatic dashboard updates.

## Problem Frame

Gold investors need to monitor their portfolio performance but currently lack a centralized, real-time view. Manual spreadsheet tracking is error-prone and doesn't provide automatic updates with current gold prices. The user wants a dashboard that shows portfolio metrics in real-time with automatic updates in Indonesian Rupiah (IDR).

**Note:** Historical performance tracking (charts, timelines) is explicitly out of scope for this implementation. The focus is on current portfolio metrics with real-time price updates.

(see origin: docs/brainstorms/2026-03-28-real-time-portfolio-dashboard-requirements.md)

## Requirements Trace

- R1. Display total portfolio value in Indonesian Rupiah (IDR)
- R2. Show weight breakdown by gold product type (coins, bars, rounds)
- R3. Display cost basis for the entire portfolio
- R4. Calculate and display ROI (Return on Investment)
- R5. List individual holdings with their current values
- R6. Automatically update dashboard without page refresh when gold prices change (every 30 minutes)
- R7. Provide inline forms to add new gold holdings (type, weight, purity, purchase price, date)
- R8. Provide inline forms to edit existing holdings
- R9. Support different gold product types: coins, bars, rounds
- R10. Support different weight units: ounces, grams
- R11. Support different purity levels: 24k, 22k, 18k, etc.

## Scope Boundaries

- Physical gold only (coins, bars, rounds) - no ETFs, mining stocks, or derivatives
- Manual entry only for adding holdings - import from CSV/JSON is out of scope
- Current performance metrics only - no historical charts or timelines
- Single currency support (IDR) - multi-currency is out of scope
- No price alerts or notifications - dashboard viewing only
- No storage location tracking - holdings only
- No premium vs spot price analysis - basic valuation only

## Context & Research

### Relevant Code and Patterns

- `lib/aurum_web/components/core_components.ex` - Core UI components (button, input, table, header) to use for forms and displays
- `lib/aurum_web/components/layouts.ex` - App layout with `<Layouts.app flash={@flash} ...>` wrapper required for LiveView templates
- `lib/aurum/application.ex` - Application supervisor with `Aurum.PubSub` already configured for broadcasting
- `lib/aurum/repo.ex` - Ecto repo configuration with SQLite adapter
- `assets/css/app.css` - Tailwind v4 with `@import "tailwindcss" source(none);` syntax
- `test/test_helper.exs` - Test setup with Ecto SQL Sandbox for transactional tests

### Institutional Learnings

None - this is a fresh project with no documented learnings yet. This implementation will establish foundational patterns.

### External References

- **Metals-API** (https://metals-api.com/api/latest) - Gold spot price API (USD), 100 requests/month free tier
- **CurrencyLayer.com** (https://apilayer.net/api/live) - Exchange rate API for USD to IDR conversion, 1,000 requests/month free tier
- **Elixir Decimal library** (v2.3.0) - Arbitrary-precision decimal arithmetic for financial calculations
- **Phoenix LiveView documentation** - Real-time updates with streams and PubSub

## Key Technical Decisions

- **Use Metals-API + CurrencyLayer**: Fetch gold prices in USD, convert to IDR using exchange rates. Both APIs have generous free tiers suitable for 30-minute updates.
- **Decimal for all financial calculations**: Use Elixir's Decimal library to avoid floating-point precision errors in ROI, cost basis, and portfolio value calculations.
- **Single-page LiveView with inline forms**: All functionality on one page for simplicity, using `<.form>` and `<.input>` components.
- **PubSub for real-time updates**: Subscribe to `price_updates` topic in LiveView, broadcast from background price fetcher every 30 minutes.
- **Background GenServer for price fetching**: Create a GenServer that periodically fetches prices and broadcasts updates via PubSub.
- **Streams for holdings display**: Use LiveView streams with `phx-update="stream"` for efficient collection rendering.
- **Weight normalization**: Convert all weights to troy ounces internally for consistent calculations, display in original units.
- **Purity as decimal**: Store purity as decimal (0.75 for 18K) for precise calculations.

## Open Questions

### Resolved During Planning

- **What gold price API should be used?** Metals-API for gold spot prices (USD) + CurrencyLayer for USD to IDR conversion. Both have free tiers suitable for 30-minute updates.
- **How should we handle API failures?** Gracefully fallback to cached prices with last known good data. Display error notification in dashboard but keep functionality available.
- **What precision should be used for financial calculations?** Use Decimal with 28 decimal places for intermediate calculations, round only for display to nearest thousand for IDR.

### Deferred to Implementation

- **Exact API key configuration**: Will determine secure storage method during implementation (environment variables, config files).
- **Price caching strategy**: Will determine database schema for price history vs in-memory caching based on performance needs.
- **Error notification UI pattern**: Will determine specific error display approach during implementation (flash messages, inline alerts, toast notifications).

## Implementation Units

- [ ] **Unit 1: Create database schemas and migrations**

**Goal:** Define database schema for gold holdings and price history with proper decimal fields.

**Requirements:** R1, R2, R3, R4, R5, R9, R10, R11

**Dependencies:** None

**Files:**
- Create: `priv/repo/migrations/YYYYMMDDHHMMSS_create_holdings.exs`
- Create: `priv/repo/migrations/YYYYMMDDHHMMSS_create_prices.exs`
- Create: `lib/aurum/gold/holding.ex`
- Create: `lib/aurum/gold/price.ex`

**Approach:**
- Use Ecto.Schema with `:decimal` type for all monetary and weight fields
- Store purity as decimal (e.g., 0.75 for 18K) for precise calculations
- Store weight_unit as string enum ("grams", "troy_ounces")
- Store category as string enum ("coin", "bar", "round")
- Add timestamps and proper indexes
- Price schema tracks historical spot prices with currency and timestamp

**Patterns to follow:**
- Phoenix v1.8 Ecto schema conventions from AGENTS.md
- Use `:string` type for all text fields (even long text)
- Set programmatic fields explicitly, not in cast/3

**Test** scenarios:**
- Valid holding with all required fields saves successfully
- Purity values are stored as decimals (0.75 for 18K)
- Weight values are stored as decimals
- Price records with timestamp and currency save successfully
- Invalid purity values (negative, > 1.0) are rejected
- Invalid weight values (negative, zero) are rejected

**Verification:**
- Migrations run successfully with `mix ecto.migrate`
- Schemas compile without errors
- Database tables are created with correct field types and constraints

- [ ] **Unit 2: Create financial calculation module**

**Goal:** Implement precise financial calculations using Decimal for ROI, cost basis, portfolio value, weight normalization, and purity adjustments.

**Requirements:** R1, R2, R3, R4, R10, R11

**Dependencies:** Unit 1

**Files:**
- Create: `lib/aurum/financial.ex`
- Test: `test/aurum/financial_test.exs`

**Approach:**
- Create dedicated `Aurum.Financial` module for all calculation logic
- Use Decimal for all arithmetic operations (no floats)
- Implement pure gold weight calculation: `weight × purity_percentage`
- Implement ROI calculation with zero-division protection
- Implement weight conversion between grams and troy ounces
- Implement karat to percentage conversion (24K → 1.0, 22K → 0.9167, 18K → 0.75)
- Add comprehensive tests for edge cases (zero values, negative values, division by zero)

**Technical design:**
```elixir
# Pseudo-code illustrating approach (directional guidance, not implementation specification)
defmodule Aurum.Financial do
  import Decimal

  @troy_ounce_to_grams Decimal.new("31.1034768")

  def pure_gold_weight(weight, purity_decimal) do
    Decimal.mult(weight, purity_decimal)
  end

  def calculate_roi(current_value, cost_basis) do
    if Decimal.eq?(cost_basis, Decimal.new(0)) do
      Decimal.new(0)
    else
      gain = Decimal.sub(current_value, cost_basis)
      Decimal.mult(Decimal.div(gain, cost_basis), Decimal.new(100))
    end
  end

  def convert_weight(weight, :grams, :troy_ounces) do
    Decimal.div(weight, @troy_ounce_to_grams)
  end
end
```

**Patterns to follow:**
- Use Decimal library already in mix.exs dependencies
- Follow Elixir functional programming patterns
- Use guard clauses for edge cases

**Test scenarios:**
- ROI calculation returns correct percentage for positive gains
- ROI calculation returns correct percentage for losses
- ROI calculation handles zero cost basis (returns 0)
- Pure gold weight calculation adjusts for purity correctly
- Weight conversion between grams and troy ounces is accurate
- Karat to percentage conversion returns correct decimals

**Verification:**
- All calculations pass comprehensive test suite
- No floating-point precision errors in calculations
- Edge cases (zero values, division by zero) are handled gracefully

- [ ] **Unit 3: Create portfolio valuation module**

**Goal:** Implement portfolio aggregation logic for total value, cost basis, weight breakdown, and ROI using financial calculations.

**Requirements:** R1, R2, R3, R4, R5

**Dependencies:** Unit 1, Unit 2

**Files:**
- Create: `lib/aurum/portfolio.ex`
- Test: `test/aurum/portfolio_test.exs`

**Approach:**
- Create `Aurum.Portfolio` module for portfolio aggregation
- Calculate total portfolio value by summing individual holding values
- Calculate total cost basis by summing holding cost basis
- Calculate portfolio ROI using Financial.calculate_roi/2
- Calculate weight breakdown by category (coins, bars, rounds)
- Use pure gold weight for accurate valuation
- Handle empty portfolios gracefully

**Patterns to follow:**
- Use Enum.reduce for aggregation
- Leverage Aurum.Financial module for calculations
- Follow Elixir functional programming patterns

**Test scenarios:**
- Total value calculation sums all holdings correctly
- Total cost basis calculation sums all holdings correctly
- Portfolio ROI calculation uses total value and total cost basis
- Weight breakdown groups by product type correctly
- Empty portfolio returns zero values without errors

**Verification:**
- Portfolio calculations match manual calculations
- Empty portfolio edge case is handled
- Weight breakdown returns correct counts per category

- [ ] **Unit 4: Create currency conversion module**

**Goal:** Implement USD to IDR currency conversion with exchange rate fetching and caching.

**Requirements:** R1

**Dependencies:** Unit 1

**Files:**
- Create: `lib/aurum/currency.ex`
- Test: `test/aurum/currency_test.exs`

**Approach:**
- Create `Aurum.Currency` module for currency conversion
- Implement USD to IDR conversion using exchange rates
- Cache exchange rates with timestamps to avoid repeated API calls
- Fetch exchange rates from CurrencyLayer API using Req library
- Round IDR values to nearest thousand for display
- Handle API failures gracefully with fallback rates
- Implement proper IDR formatting with thousand separators

**Patterns to follow:**
- Use Req library for HTTP requests (per AGENTS.md)
- Use Decimal for currency calculations
- Implement caching strategy for exchange rates

**Test scenarios:**
- USD to IDR conversion returns correct values
- Exchange rate caching reduces API calls
- API failures fall back to cached rates
- IDR rounding to nearest thousand works correctly
- IDR formatting includes proper thousand separators

**Verification:**
- Currency conversions are accurate
- Exchange rate caching works as expected
- API failure handling keeps functionality available

- [ ] **Unit 5: Create gold price fetcher GenServer**

**Goal:** Implement background process that fetches gold prices every 30 minutes and broadcasts updates via PubSub.

**Requirements:** R6

**Dependencies:** Unit 1, Unit 4

**Files:**
- Create: `lib/aurum/gold/price_fetcher.ex`
- Test: `test/aurum/gold/price_fetcher_test.exs`

**Approach:**
- Create GenServer that starts in application supervisor
- Implement periodic price fetching every 30 minutes using Process.send_after/3
- Fetch gold prices from Metals-API using Req library
- Fetch exchange rates from CurrencyLayer API
- Convert USD gold price to IDR using Currency module
- Broadcast price updates via Aurum.PubSub on "price_updates" topic
- Store price history in database
- Handle API failures gracefully with retry logic
- Use exponential backoff for failed requests

**Technical design:**
```elixir
# Pseudo-code illustrating approach (directional guidance, not implementation specification)
defmodule Aurum.Gold.PriceFetcher do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    schedule_next_fetch()
    {:ok, %{last_price: nil, last_updated: nil}}
  end

  def handle_info(:fetch_prices, state) do
    gold_price_usd = fetch_gold_price()
    exchange_rate = fetch_exchange_rate()
    gold_price_idr = convert_to_idr(gold_price_usd, exchange_rate)

    Phoenix.PubSub.broadcast(Aurum.PubSub, "price_updates", {:gold_price_idr, gold_price_usd})
    store_price_in_db(gold_price_idr, gold_price_usd)

    schedule_next_fetch()
    {:noreply, %{last_price: gold_price_idr, last_updated: DateTime.utc_now()}}
  end

  defp schedule_next_fetch() do
    Process.send_after(self(), :fetch_prices, 30 * 60 * 1000)  # 30 minutes
  end
end
```

**Patterns to follow:**
- Use GenServer OTP pattern for background processes
- Use Phoenix.PubSub for broadcasting (already configured in Aurum.Application)
- Use Req library for HTTP requests
- Implement proper error handling and retry logic

**Test scenarios:**
- Price fetcher starts successfully in application supervisor
- Prices are fetched every 30 minutes
- Price updates are broadcast via PubSub
- API failures trigger retry logic with exponential backoff
- Price history is stored in database

**Verification:**
- Price fetcher runs continuously without crashes
- PubSub broadcasts are received by subscribers
- Price history is recorded in database

- [ ] **Unit 6: Create Gold context and queries**

**Goal:** Implement Ecto context for database operations on holdings and prices.

**Dependencies:** Unit 1

**Files:**
- Create: `lib/aurum/gold.ex`
- Create: `lib/aurum/gold/holding_query.ex`
- Create: `lib/aurum/gold/price_query.ex`
- Test: `test/aurum/gold_test.exs`
- Test: `test/aurum/gold/holding_query_test.exs`

**Approach:**
- Create Aurum.Gold context with Repo and schemas
- Implement HoldingQuery for CRUD operations on holdings
- Implement PriceQuery for fetching price history
- Use Ecto queries with proper preloading
- Implement changeset validation for holdings
- Add functions for listing holdings, creating, updating, deleting

**Patterns to follow:**
- Phoenix v1.8 context conventions
- Use Ecto.Query for database queries
- Preload associations when accessed in templates
- Use Ecto.Changeset for validation

**Test scenarios:**
- List holdings returns all holdings
- Create holding with valid data succeeds
- Create holding with invalid data fails with errors
- Update holding modifies existing record
- Delete holding removes record from database
- Price queries return historical price data

**Verification:**
- Context operations work correctly
- Changeset validation catches invalid data
- Queries return expected results

- [ ] **Unit 7: Create Portfolio Dashboard LiveView**

**Goal:** Implement single-page LiveView dashboard with portfolio metrics, holdings list, and inline forms for adding/editing holdings.

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11

**Dependencies:** Unit 2, Unit 3, Unit 4, Unit 6

**Files:**
- Create: `lib/aurum_web/live/portfolio_dashboard_live.ex`
- Create: `lib/aurum_web/live/components/holding_form_component.ex` (optional, if needed)
- Test: `test/aurum_web/live/portfolio_dashboard_live_test.exs`

**Approach:**
- Create AurumWeb.PortfolioDashboardLive following Phoenix v1.8 conventions
- Wrap template with `<Layouts.app flash={@flash} ...>`
- Subscribe to "price_updates" PubSub topic in mount/3
- Handle PubSub messages with handle_info/2 to update current price
- Use streams for holdings display with `phx-update="stream"`
- Calculate portfolio metrics using Portfolio and Financial modules
- Implement inline add form using `<.form>` and `<.input>` components
- Implement inline edit form for each holding
- Handle form submissions for creating and updating holdings
- Display total value, weight breakdown, cost basis, ROI
- Display individual holdings with current values
- Use unique DOM IDs for forms and elements (e.g., `id="add-holding-form"`)
- Implement smooth micro-interactions with Tailwind CSS

**Technical design:**
```elixir
# Pseudo-code illustrating approach (directional guidance, not implementation specification)
defmodule AurumWeb.PortfolioDashboardLive do
  use AurumWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Aurum.PubSub, "price_updates", self())
    end

    holdings = Aurum.Gold.list_holdings()
    current_price = get_cached_price()

    socket =
      socket
      |> assign(:holdings, holdings)
      |> assign(:current_price, current_price)
      |> stream(:holdings, holdings)

    {:ok, socket}
  end

  def handle_info({:gold_price_idr, :gold_price_usd}, socket) do
    {:noreply, assign(socket, :current_price, %{idr: gold_price_idr, usd: gold_price_usd})}
  end

  def handle_event("save", %{"holding" => holding_params}, socket) do
    changeset = Aurum.Gold.create_holding_changeset(holding_params)

    case Aurum.Gold.create_holding(changeset) do
      {:ok, holding} ->
        {:noreply, stream_insert(socket, :holdings, holding)}
      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
```

**Patterns to follow:**
- Phoenix v1.8 LiveView conventions from AGENTS
- Use streams for collections with `phx-update="stream"`
- Use `<.form>` and `<.input>` components from core_components.ex
- Never use deprecated live_redirect/live_patch
- Use push_navigate and push_patch for navigation
- Wrap template with `<Layouts.app flash={@flash} ...>`
- Use Tailwind CSS v4 classes for styling
- Implement micro-interactions and smooth transitions

**Test scenarios:**
- Dashboard renders with all portfolio metrics
- Holdings list displays all holdings with correct values
- Add holding form creates new holding and updates metrics
- Edit holding form updates existing holding and metrics
- PubSub price updates trigger dashboard re-render
- Form validation errors are displayed correctly
- Empty portfolio shows zero values without errors

**Verification:**
- Dashboard loads and displays correctly
- Real-time price updates work without page refresh
- Forms for adding/editing holdings function properly
- All metrics are calculated accurately

- [ ] **Unit 8: Add router route and update navigation**

**Goal:** Add route for portfolio dashboard and update navigation to access it.

**Dependencies:** Unit 7

**Files:**
- Modify: `lib/aurum_web/router.ex`

**Approach:**
- Add live route for portfolio dashboard in router
- Use scope aliasing for clean route definition
- Add navigation link in layout or header to access dashboard
- Ensure proper pipeline configuration

**Patterns to follow:**
- Phoenix v1.8 router conventions
- Use scope aliasing to avoid duplicate module prefixes
- Follow existing route patterns in router.ex

**Test scenarios:**
- Dashboard route is accessible
- Navigation link directs to dashboard
- Route uses correct LiveView module

**Verification:**
- Dashboard is accessible via configured route
- Navigation works correctly

## System-Wide Impact

- **Interaction graph:** Aurum.Gold.PriceFetcher broadcasts via Aurum.PubSub, PortfolioDashboardLive subscribes to updates
- **Error propagation:** API failures in PriceFetcher are handled gracefully with fallback to cached prices, errors are displayed in dashboard but don't break functionality
- **State lifecycle risks:** PriceFetcher state (last_price, last_updated) is in-memory, persists across fetches; database stores price history for persistence
- **API surface parity:** No external API surface changes required - uses standard HTTP APIs
- **Integration coverage:** Unit tests cover individual modules; integration tests cover LiveView interactions; real-time updates tested with PubSub broadcasts

## Risks & Dependencies

- **External API dependency:** Metals-API and CurrencyLayer.com must remain available and stable. Mitigation: implement graceful fallback to cached prices, exponential backoff for retries, display error notifications when prices are stale.
- **API rate limits:** Free tiers have monthly request limits (100/month for Metals-API, 1,000/month for CurrencyLayer). Mitigation: 45-minute update cycle stays within Metals-API free tier (32 requests/day = 960/month), monitor usage and alert if approaching limits.
- **Financial calculation precision:** Decimal operations must be correct to avoid monetary errors. Mitigation: comprehensive test suite, use Decimal exclusively (no floats), round only for display.
- **Real-time update reliability:** PubSub broadcasts must reach LiveView subscribers. Mitigation: Phoenix PubSub is reliable and already configured in application.
- **Database schema changes:** Migrations must be run carefully in production. Mitigation: use Ecto migrations with proper rollback support, test migrations in development first.
- **Price history growth:** Unbounded price history storage will grow over time. Mitigation: implement 90-day retention policy with automated cleanup, add indexes for efficient querying.

## Documentation / Operational Notes

- **Configuration:** Add API keys for CurrencyLayer to environment variables or config files
- **Monitoring:** Consider adding telemetry for API failures, price fetch success rates, and dashboard update latency
- **Deployment:** Ensure PriceFetcher GenServer is started in application supervisor for production
- **Performance:** Monitor database query performance for portfolio calculations, consider adding indexes if needed

## Sources & References

- **Origin document:** [docs/brainstorms/2026-03-28-real-time-portfolio-dashboard-requirements.md](docs/brainstorms/2026-03-28-real-time-portfolio-dashboard-requirements.md)
- **Related code:** `lib/aurum/application.ex` (PubSub configuration), `lib/aurum_web/components/core_components.ex` (UI components)
- **External docs:** [Metals-API](https://metals-api.com), [CurrencyLayer.com](https://apilayer.net), [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view), [Elixir Decimal](https://hexdocs.pm/decimal)
