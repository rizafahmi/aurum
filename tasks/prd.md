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

## 12. Guiding Constraint
If a feature weakens privacy or increases complexity without clear value, it does not ship.

Simplicity is a feature.
