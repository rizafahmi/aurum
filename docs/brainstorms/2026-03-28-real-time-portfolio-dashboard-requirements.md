---
date: 2026-03-28
topic: real-time-portfolio-dashboard
---

# Real-time Portfolio Dashboard

## Problem Frame
Gold investors need to monitor their portfolio performance over time but currently lack a centralized, real-time view. Manual spreadsheet tracking is error-prone and doesn't provide automatic updates with current gold prices. The user wants a dashboard that shows portfolio metrics in real-time with automatic updates.

## Requirements
- R1. Display total portfolio value in user's preferred currency
- R2. Show weight breakdown by gold product type (coins, bars, rounds)
- R3. Display cost basis for the entire portfolio
- R4. Calculate and display ROI (Return on Investment)
- R5. List individual holdings with their current values
- R6. Automatically update dashboard without page refresh when gold prices change
- R7. Provide inline forms to add new gold holdings (type, weight, purity, purchase price, date)
- R8. Provide inline forms to edit existing holdings
- R9. Support different gold product types: coins, bars, rounds
- R10. Support different weight units: ounces, grams
- R11. Support different purity levels: 24k, 22k, 18k, etc.

## Success Criteria
- User can see total portfolio value update automatically without refreshing the page
- User can add a gold holding and see it reflected in all metrics immediately
- User can edit a holding and see updated metrics instantly
- ROI calculation is accurate based on cost basis and current value
- Dashboard loads quickly and updates smoothly without jank

## Scope Boundaries
- Physical gold only (coins, bars, rounds) - no ETFs, mining stocks, or derivatives
- Manual entry only for adding holdings - import from CSV/JSON is out of scope
- Current performance metrics only - no historical charts or timelines
- Single currency support initially - multi-currency is out of scope
- No price alerts or notifications - dashboard viewing only
- No storage location tracking - holdings only
- No premium vs spot price analysis - basic valuation only

## Key Decisions
- **Single-page approach with inline forms**: All functionality on one page for simplicity and ease of use
- **LiveView for real-time updates**: Leverage Phoenix LiveView's automatic re-renders and WebSocket support
- **Manual entry only**: Start with manual forms, add import capability later as a separate feature
- **Physical gold focus**: Concentrate on coins, bars, and rounds rather than paper gold
- **Current metrics only**: Focus on today's performance metrics without historical charts
- **Currency: IDR**: Portfolio valuation in Indonesian Rupiah
- **Update frequency: 30 minutes**: Gold prices fetched every 30 minutes
- **Generic product types initially**: Start with coins/bars/rounds, add specific catalog later

## Dependencies / Assumptions
- Gold spot price data source is available (needs to be determined during planning)
- Exchange rate API is available if multi-currency support is added later
- User has basic understanding of gold weights and purity
- Dashboard will be accessed via web browser

## Outstanding Questions

### Deferred to Planning
- [Affects R6][Needs research] What gold price API should be used for spot price data?
- [Affects R1][Technical] How should we handle API failures or rate (IDR) limiting?
- [Affects R4][Technical] What precision should be used for financial calculations?

## Next Steps
→ /ce:plan for structured implementation planning
