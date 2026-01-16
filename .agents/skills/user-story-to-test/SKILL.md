---
name: user-story-to-test
description: Converts user stories from PRD into PhoenixTest feature tests. Use when asked to create acceptance tests, feature tests, or convert user stories to tests.
---

# User Story to PhoenixTest Feature Test

Converts user stories from `tasks/prd.md` into acceptance/feature tests using PhoenixTest library.

## Workflow

1. **Read the PRD** at `tasks/prd.md` to find user stories
2. **Prioritize stories** using this order:
   - Foundation/blocking stories first (data creation, price fetching)
   - Core flows (CRUD operations, dashboard)
   - Edge cases and validation last
3. **Check existing tests** in `test/aurum_web/features/` to avoid duplicates
4. **Generate test file** following conventions below

## Priority Order for User Stories

Pick the first uncovered story from this priority list:

1. **US-001: Create Gold Item** — Foundation for all other features
2. **US-006: Fetch Live Gold Price** — Required for valuation
3. **US-002: View Portfolio Dashboard** — Core value prop
4. **US-003: List All Gold Items** — Navigation/listing
5. **US-004: Edit Gold Item** — CRUD completion
6. **US-005: Delete Gold Item** — CRUD completion
7. **US-011: View Item Details** — Detail view
8. **US-012: Validate Item Form Inputs** — Form validation
9. **US-008: Calculate Item Valuation** — Business logic
10. **US-009: Convert Weight Units** — Unit handling
11. **US-010: Refresh Gold Price Manually** — User interaction
12. **US-007: Display Stale Price Indicator** — Edge case

## Test File Conventions

### Location
`test/aurum_web/features/<feature>_test.exs`

Examples:
- `create_gold_item_test.exs`
- `portfolio_dashboard_test.exs`
- `gold_price_test.exs`

### Structure

```elixir
defmodule AurumWeb.<FeatureName>Test do
  use AurumWeb.ConnCase, async: true

  # Optional: import factories or fixtures
  # import Aurum.Factory

  describe "US-XXX: <Story Title>" do
    test "acceptance criteria 1", %{conn: conn} do
      conn
      |> visit("/path")
      |> assert_has("selector", text: "expected")
    end

    test "acceptance criteria 2", %{conn: conn} do
      # ...
    end
  end
end
```

## PhoenixTest API Reference

### Navigation
```elixir
visit(conn, "/path")           # Start a session at path
click_link(session, "Text")    # Click link by text
click_button(session, "Text")  # Click button by text
```

### Forms
```elixir
fill_in(session, "Label", with: "value")
select(session, "Label", option: "Option Text")
choose(session, "Radio Label")     # Radio button
check(session, "Checkbox Label")   # Checkbox
submit(session)                    # Submit form (Enter key)
```

### Assertions
```elixir
assert_has(session, "selector")                    # Element exists
assert_has(session, "selector", text: "content")   # Element with text
refute_has(session, "selector")                    # Element doesn't exist
assert_path(session, "/expected/path")             # Current path
```

### Scoping
```elixir
within(session, "#form-id", fn scoped ->
  scoped
  |> fill_in("Name", with: "value")
  |> click_button("Submit")
end)
```

## Example Test (Reference)

From `test/aurum_web/features/homepage_test.exs`:

```elixir
defmodule AurumWeb.HomepageTest do
  use AurumWeb.ConnCase, async: true

  test "GET / has branding", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Aurum")
  end
end
```

## Test Data Setup

For tests requiring existing data, create records in setup:

```elixir
setup do
  # Create test data
  {:ok, item} = Aurum.Portfolio.create_item(%{
    name: "Test Gold Bar",
    category: :bar,
    weight: 100.0,
    weight_unit: :grams,
    purity: 99.9,
    quantity: 1,
    purchase_price: Decimal.new("5000.00")
  })
  
  %{item: item}
end
```

## Verification Checklist

After creating a test:

1. Run `mix test test/aurum_web/features/<file>_test.exs`
2. Ensure all tests pass or document expected failures for unimplemented features
3. Run `mix precommit` to verify no regressions

## Notes

- Tests should be written from user's perspective
- Use meaningful DOM selectors (IDs preferred)
- One test per acceptance criterion when possible
- Mark tests as `@tag :skip` if feature not yet implemented
