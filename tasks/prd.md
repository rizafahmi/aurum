# Aurum Vault — MVP Product Requirements Document (PRD)

## 1. Product Overview
Aurum Vault is a **personal, local-first gold portfolio tracker** designed for individuals who own **physical gold** (bars, coins, jewelry). The app provides real-time valuation, cost-basis tracking, and portfolio insights **without storing any user data in the cloud**.

Core principle: **Your gold data never leaves your device.**

This product deliberately avoids accounts, syncing, social features, recommendations, or analytics. Trust is the product.

---

## 2. Problem Statement
Physical gold owners lack simple, private tools to track:
- What they own
- What it cost
- What it’s worth today

Existing solutions:
- Assume ETFs or brokerage accounts
- Require cloud accounts
- Mix gold with other assets
- Collect or monetize user data

Gold owners value **privacy, sovereignty, and simplicity**. Spreadsheets are common but fragile and error-prone.

---

## 3. Target User
Primary user:
- Owns physical gold (bars, coins, jewelry)
- Buys occasionally or regularly
- Cares about privacy and self-custody
- Wants clear valuation, not trading

Non-goals:
- Traders
- ETF-only investors
- Institutional users

---

## 4. Core Value Proposition
- Local-only encrypted storage
- Accurate valuation of physical gold
- Simple, honest math
- Zero data extraction

---

## 5. MVP Scope (Strict)
The MVP focuses on **tracking and valuation only**.

Explicit exclusions:
- No user accounts
- No cloud sync
- No social or sharing features
- No price prediction
- No news feed

---

## 6. Functional Requirements

### 6.1 Gold Holdings Management
Users can create and manage gold items with the following fields:
- Item name (free text)
- Category: Bar / Coin / Jewelry / Other
- Weight (grams or troy ounces)
- Purity (e.g., 24K, 22K, 18K, custom %)
- Quantity
- Purchase price (total)
- Purchase date (optional)
- Notes (optional)

All data is stored locally.

---

### 6.2 Portfolio Dashboard
Dashboard displays:
- Total gold weight (pure gold equivalent)
- Total invested amount
- Current total value (based on live spot price)
- Unrealized gain / loss (absolute and %)

Calculations must be transparent and deterministic.

---

### 6.3 Real-Time Gold Price
- Fetch live gold spot price (XAU) from a public API
- Read-only usage (no authentication tied to user identity)
- Cache latest price locally
- Display last updated timestamp

If offline:
- Use last cached price
- Clearly indicate price is stale

---

### 6.4 Valuation Logic
For each item:
- Convert weight × purity → pure gold weight
- Multiply by spot price
- Aggregate across items

All calculations performed locally.

---

### 6.5 Local Storage & Security
- Use local database (e.g., SQLite)
- Encrypt data at rest
- Optional app-level passcode
- No telemetry, analytics, or logging sent externally

---

### 6.6 Data Export
- Export holdings and valuations to CSV
- Export summary report to PDF
- Export is user-initiated only

---

## 7. Non-Functional Requirements

### 7.1 Privacy
- No cloud storage
- No background network calls except price fetch
- No third-party SDKs that collect data

### 7.2 Performance
- App must function fully offline (except price updates)
- Instant load for portfolio dashboard

### 7.3 Reliability
- Local data persistence must survive app restarts
- Graceful handling of API failure

---

## 8. UX Principles
- Minimalist UI
- No gamification
- No notifications by default
- Clear labels and explicit numbers

Tone: calm, serious, utilitarian.

---

## 9. Technical Assumptions (Flexible)
- Single-platform MVP (desktop or mobile)
- One external dependency: gold price API
- No authentication system

---

## 10. Success Criteria (MVP)
- User can accurately track physical gold holdings
- User trusts the app with sensitive financial data
- App functions fully without internet

---

## 11. Future (Out of Scope for MVP)
- Multi-currency support
- Historical price charts
- Alerts
- Secure user-controlled backups
- Optional manual sync (file-based)

---

## 12. User Stories

### US-001: Create Gold Item
**Description:** As a gold owner, I want to add a new gold item to my portfolio so that I can track its value.

**Acceptance Criteria:**
- [ ] Form displays fields: name, category (Bar/Coin/Jewelry/Other), weight, weight unit (grams/troy oz), purity, quantity, purchase price, purchase date (optional), notes (optional)
- [ ] Category is a dropdown with exactly 4 options
- [ ] Purity accepts preset values (24K, 22K, 18K, 14K) or custom percentage
- [ ] Weight and quantity must be positive numbers
- [ ] Purchase price must be non-negative
- [ ] Item is persisted to local SQLite database after submission
- [ ] User is redirected to portfolio view after successful creation
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-002: View Portfolio Dashboard
**Description:** As a gold owner, I want to see a summary of my entire gold portfolio so that I understand my total holdings at a glance.

**Acceptance Criteria:**
- [ ] Dashboard displays total pure gold weight (in grams)
- [ ] Dashboard displays total invested amount (sum of purchase prices)
- [ ] Dashboard displays current total value based on spot price
- [ ] Dashboard displays unrealized gain/loss in absolute value and percentage
- [ ] Empty state shown when no items exist with prompt to add first item
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-003: List All Gold Items
**Description:** As a gold owner, I want to see all my gold items in a list so that I can review individual holdings.

**Acceptance Criteria:**
- [ ] Each item displays: name, category, weight, purity, quantity, purchase price, current value
- [ ] Items are sorted by creation date (newest first)
- [ ] Each item row links to its detail/edit view
- [ ] List displays "No items yet" message when portfolio is empty
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-004: Edit Gold Item
**Description:** As a gold owner, I want to edit an existing gold item so that I can correct mistakes or update details.

**Acceptance Criteria:**
- [ ] Edit form pre-populates with existing item data
- [ ] All fields from creation are editable
- [ ] Validation rules match creation form
- [ ] Changes are persisted to database on save
- [ ] Cancel button returns to previous view without saving
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-005: Delete Gold Item
**Description:** As a gold owner, I want to delete a gold item so that I can remove items I no longer own.

**Acceptance Criteria:**
- [ ] Delete button shows confirmation dialog before deleting
- [ ] Confirmation dialog clearly states item name being deleted
- [ ] Item is permanently removed from database upon confirmation
- [ ] User is redirected to portfolio list after deletion
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-006: Fetch Live Gold Price
**Description:** As a gold owner, I want the app to fetch current gold spot price so that my portfolio valuation is accurate.

**Acceptance Criteria:**
- [ ] App fetches XAU/USD spot price from a public API on dashboard load
- [ ] Fetched price is cached locally in database
- [ ] "Last updated" timestamp is displayed next to price
- [ ] Price fetch does not require user authentication
- [ ] API errors are handled gracefully without crashing
- [ ] mix test passes

---

### US-007: Display Stale Price Indicator
**Description:** As a gold owner, I want to know when the displayed gold price is outdated so that I understand my valuation may be stale.

**Acceptance Criteria:**
- [ ] When offline or API fails, app uses last cached price
- [ ] Visual indicator (badge/icon) shows when price is stale (>15 minutes old)
- [ ] Tooltip or text explains "Price last updated X minutes/hours ago"
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-008: Calculate Item Valuation
**Description:** As a gold owner, I want each item's current value calculated automatically so that I know what my gold is worth.

**Acceptance Criteria:**
- [ ] Pure gold weight = weight × (purity% / 100) × quantity
- [ ] Current value = pure gold weight × spot price
- [ ] Gain/loss = current value - purchase price
- [ ] Calculations use consistent precision (2 decimal places for currency, 4 for weight)
- [ ] mix test passes

---

### US-009: Convert Weight Units
**Description:** As a gold owner, I want to enter weight in grams or troy ounces so that I can use my preferred unit.

**Acceptance Criteria:**
- [ ] Weight unit selector offers "grams" and "troy oz" options
- [ ] Internal storage normalizes to grams
- [ ] Display converts back to user's preferred unit
- [ ] Conversion uses 1 troy oz = 31.1035 grams
- [ ] mix test passes

---

### US-010: Refresh Gold Price Manually
**Description:** As a gold owner, I want to manually refresh the gold price so that I can get the latest value on demand.

**Acceptance Criteria:**
- [ ] Refresh button is visible on dashboard near price display
- [ ] Clicking refresh fetches new price from API
- [ ] Loading state shown during fetch
- [ ] Success updates displayed price and timestamp
- [ ] Error shows user-friendly message without losing cached price
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-011: View Item Details
**Description:** As a gold owner, I want to view full details of a single gold item so that I can see all information including notes.

**Acceptance Criteria:**
- [ ] Detail page shows all item fields including notes
- [ ] Shows calculated pure gold weight
- [ ] Shows current value and gain/loss for this item
- [ ] Edit and Delete buttons are accessible from this view
- [ ] Back navigation returns to portfolio list
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-012: Validate Item Form Inputs
**Description:** As a gold owner, I want clear validation errors when I enter invalid data so that I can correct my input.

**Acceptance Criteria:**
- [ ] Empty required fields show "is required" error
- [ ] Negative weight shows "must be greater than 0" error
- [ ] Invalid purity (>100% or <0%) shows appropriate error
- [ ] Errors display inline next to the relevant field
- [ ] Form does not submit until all validations pass
- [ ] mix test passes
- [ ] Verify in browser using dev-browser skill

---

### US-013: Persist Data Across Restarts
**Description:** As a gold owner, I want my data to persist after closing the app so that I don't lose my portfolio.

**Acceptance Criteria:**
- [ ] Items created are visible after stopping and restarting the Phoenix server
- [ ] Cached gold price survives app restart
- [ ] SQLite database file exists in priv/repo directory
- [ ] mix test passes

---

## 13. Guiding Constraint
If a feature weakens privacy or increases complexity without clear value, it does not ship.

Simplicity is a feature.
