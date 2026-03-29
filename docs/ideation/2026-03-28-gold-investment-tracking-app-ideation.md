---
date: 2026-03-28
topic: gold-investment-tracking-app
focus: gold investment tracking app
---

# Ideation: Gold Investment Tracking App

## Codebase Context

**Project Shape:**
- **Language/Framework:** Elixir/Phoenix v1.8 web application
- **Database:** SQLite (ecto_sqlite3)
- **Frontend:** Phoenix LiveView with Tailwind CSS v4, esbuild
- **Architecture:** Standard Phoenix OTP application structure

**Top-level Directory Layout:**
- `lib/aurum/` - Core domain logic (minimal boilerplate only)
- `lib/aurum_web_web/` - Web layer (controllers, components, router, endpoint)
- `config/` - Environment configs (dev, prod, runtime, test)
- `assets/` - Frontend assets (JS, CSS, vendor)
- `priv/repo/migrations/` - Empty (only .formatter.exs, no migrations)
- `test/` - Test files
- `deps/`, `_build/` - Dependencies and build artifacts

**Notable Patterns/Conventions:**
- Phoenix v1.8 conventions with LiveView, HEEx templates
- `mix precommit` alias with quality checks (credo, dialyzer, format, test)
- Req library for HTTP requests (per AGENTS.md)
- Tailwind CSS v4 with new `@import "tailwindcss"` syntax
- LiveView streams for collections
- Bandit web server, telemetry, LiveDashboard in dev
- Ecto with SQLite, Swoosh for email

**Pain Points/Gaps:**
- **No domain models** - Despite gold investment focus, no schemas/migrations exist
- **Empty migrations directory** - No database schema defined
- **Minimal business logic** - Only Phoenix boilerplate files present
- **No test coverage** - Minimal test structure
- **Blank slate** - Project appears freshly scaffolded with no implementation

**Leverage Points:**
- Modern Phoenix v1.8 foundation with best practices pre-configured
- Robust precommit workflow (static analysis, type checking, formatting, tests)
- LiveView ready for real-time gold price tracking
- Telemetry infrastructure for monitoring
- Clear modular structure (aurum domain vs aurum_web_web presentation)

## Ranked Ideas

### 1. Real-time Portfolio Dashboard
**Description:** Live dashboard showing total portfolio value, individual holdings, and performance metrics with automatic value calculations
**Rationale:** Eliminates manual spreadsheet calculations; provides instant visibility into gold holdings; foundational for all other features
**Downsides:** Requires reliable spot price data source; LiveView complexity for real-time updates
**Confidence:** 90%
**Complexity:** Medium
**Status:** Unexplored

### 2. Multi-Storage Location Tracker
**Description:** Track physical gold across multiple storage locations (home vault, bank safe deposit box, third-party storage) with location details and security notes
**Rationale:** Solves the real-world complexity of physical gold custody; many investors hold gold in multiple places; essential for asset security
**Downsides:** Requires manual data entry; security implications for storing location data
**Confidence:** 85%
**Complexity:** Low
**Status:** Unexplored

### 3. Premium vs Spot Price Analyzer
**Description:** Track and analyze premiums paid above spot price for different gold products (coins, bars, rounds) to identify best value purchases
**Rationale:** Gold premiums vary significantly; helps investors avoid overpaying; enables informed purchasing decisions
**Downsides:** Requires historical spot price data; product catalog management complexity
**Confidence:** 80%
**Complexity:** Medium
**Status:** Unexplored

### 4. Currency-Agnostic Valuation
**Description:** Track gold holdings in multiple currencies with automatic conversion and consolidated portfolio views
**Rationale:** Gold is a global asset; investors often hold across currencies; eliminates manual conversion friction
**Downsides:** Requires reliable exchange rate API; currency volatility adds complexity
**Confidence:** 75%
**Complexity:** Medium
**Status:** Unexplored

### 5. Weight and Purity Normalizer
**Description:** Standardize different gold products (1oz coins, 10g bars, grams) into consistent weight units for accurate portfolio comparison
**Rationale:** Gold products come in confusing variety; normalization enables accurate valuation and comparison
**Downsides:** Conversion complexity; purity calculations (24k vs 22k vs 18k)
**Confidence:** 85%
**Complexity:** Low
**Status:** Unexplored

### 6. Historical Performance Timeline
**Description:** Visual timeline showing portfolio value changes, purchase history, and performance over time with interactive charts
**Rationale:** Enables strategy evaluation; reveals patterns; essential for long-term investment decisions
**Downsides:** Requires historical price data; charting library integration
**Confidence:** 80%
**Complexity:** Medium
**Status:** Unexplored

### 7. Real-time Spot Price Threshold Alerts
**Description:** Set custom price thresholds and receive instant notifications when gold spot prices hit targets
**Rationale:** Gold is volatile; timely alerts prevent missed opportunities; automated monitoring saves time
**Downsides:** Requires reliable real-time data feed; notification infrastructure complexity
**Confidence:** 75%
**Complexity:** Medium
**Status:** Unexplored

### 8. Auto-Calculated Portfolio Metrics
**Description:** Automatically compute ROI, average cost basis, total weight, and portfolio composition without manual calculations
**Rationale:** Eliminates spreadsheet errors; instant metrics; foundational for analysis
**Downsides:** Calculation complexity; edge cases in cost basis accounting
**Confidence:** 90%
**Complexity:** Low
**Status:** Unexplored

### 9. Auto-Currency Conversion
**Description:** Automatically convert portfolio values between currencies using live exchange rates
**Rationale:** Gold is global; eliminates manual conversion; real-time accuracy
**Downsides:** Exchange rate API dependency; rate volatility
**Confidence:** 80%
**Complexity:** Low
**Status:** Unexplored

### 10. Flexible Transaction Import System
**Description:** Import transactions from CSV/JSON files to quickly build portfolio from existing records
**Rationale:** Investors have existing records; reduces onboarding friction; essential for adoption
**Downsides:** Parsing complexity; format validation; error handling
**Confidence:** 85%
**Complexity:** Medium
**Status:** Unexplored

### 11. Automated Cost Basis Tracking
**Description:** Automatically calculate and update cost basis across purchase methods (spot, ETFs, mining stocks)
**Rationale:** Critical for tax reporting; prevents errors; enables accurate ROI
**Downsides:** Complex accounting logic; edge cases in different purchase types
**Confidence:** 80%
**Complexity:** Medium
**Status:** Unexplored

### 12. Multi-Currency Portfolio Tracking
**Description:** Unified portfolio view across multiple currencies with automatic conversion and consolidated reporting
**Rationale:** Global gold holdings need unified view; eliminates currency silos; essential for international investors
**Downsides:** Exchange rate API dependency; currency volatility complexity
**Confidence:** 75%
**Complexity:** Medium
**Status:** Unexplored

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | Buy/Sell Signal Alerts | Requires complex algorithmic analysis and reliable real-time data infrastructure beyond MVP scope |
| 2 | Physical Gold Premium Cost Tracking | Duplicate of Premium vs Spot Price Analyzer |
| 3 | Multi-Form Gold Exposure Dashboard | Too vague; unclear what "forms" means or how to implement |
| 4 | Tax Lot Optimization Engine | Complex tax logic varies by jurisdiction; months of implementation without clear MVP value |
| 5 | Inflation-Adjusted Performance Tracking | Requires reliable historical inflation data API and complex calculations |
| 6 | Currency Impact Analyzer | Duplicate of Currency-Agnostic Valuation |
| 7 | Liquidity Planning Simulator | Complex simulation logic with unclear requirements; too advanced for MVP |
| 8 | Real-time Price Streaming Dashboard | Requires WebSocket infrastructure and reliable streaming data sources; high implementation burden |
| 9 | One-Click Transaction Import | Too vague; what formats? CSV? PDF? Bank APIs? Unclear scope |
| 10 | Smart Rebalancing Suggestions | Complex algorithmic logic requiring sophisticated portfolio optimization algorithms |
| 11 | Automated Tax Reporting | Tax rules vary wildly by jurisdiction; complex compliance logic beyond MVP |
| 12 | Live Price Alert System | Duplicate of Real-time Spot Price Threshold |
alerts |
| 13 | Historical Price Auto-Fetching | Requires reliable historical data API; many have costs or rate limits |
| 14 | Crowd-Sourced Sentiment Engine | Requires social media APIs, NLP, and complex sentiment analysis; completely out of scope |
| 15 | Physical Gold Vault Manager | Duplicate of Multi-Storage Location Tracker |
| 16 | Scenario Simulation Lab | Too vague; what scenarios? Requires complex modeling engine |
| 17 | Gold-as-Currency Exchange | Requires integration with crypto exchanges or payment systems; out of scope |
| 18 | Micro-Investment Rhythm Tracker | Too vague; unclear what "rhythm" means or how to track it |
| 19 | Hedge Effectiveness Analyzer | Complex financial analysis requiring sophisticated correlation and benchmarking logic |
| 20 | Goal-Anchor Gold Tracker | Too vague; unclear what "goal-anchoring" means in this context |
| 21 | Global Arbitrage Opportunity Scanner | Requires real-time global price data across multiple markets; complex infrastructure |
| 22 | Historical Price Database with Live Updates | Requires building/maintaining historical database infrastructure; high burden for MVP |
| 23 | Real-Time Alert System with Complex Rules | Complex rule engine and notification infrastructure; months of work |
| 24 | Modular Analytics Dashboard | Too vague; what analytics? Architecture overengineering for MVP |
| 25 | Performance Benchmarking System | Complex benchmarking logic requiring multiple comparison datasets |
| 26 | Tax Lot Management with FIFO/LIFO Optimization | Duplicate of Tax Lot Optimization Engine; complex tax logic |

## Session Log
- 2026-03-28: Initial ideation — 32 ideas generated, 12 survived
