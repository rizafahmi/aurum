# Multi-User Vaults — Product Requirements Document (PRD)

## 1. Overview

This document describes the architecture and requirements for transforming Aurum Vault from a single-user local application to a **multi-user web service** while preserving the local-first, privacy-focused philosophy.

Core principle: **Each user gets their own isolated SQLite database. No traditional auth. No passwords. Just works.**

---

## 2. Problem Statement

The current implementation:
- Single SQLite database for all data
- Works only for one user on one server
- Cannot be deployed as a public web service

To serve multiple users on the internet, we need:
- User isolation (each user's data is separate)
- User identification (know which database to load)
- Zero-friction onboarding (no signup forms)

---

## 3. Design Principles

1. **No passwords** — Users should not need to create accounts or remember credentials
2. **Instant start** — First visit creates a vault immediately, no forms
3. **Cookie-based identity** — Long-lived secure cookie identifies returning users
4. **True data ownership** — Users can download their entire database file
5. **Graceful recovery** — Optional email for vault recovery, never required

---

## 4. Architecture

### 4.1 Database Strategy

**Central Database (Accounts Repo)**
- Stores vault metadata only: `id`, `slug`, `token_hash`, `recovery_email`, `created_at`
- No business data, no portfolio information
- Single SQLite or Postgres database

**Per-User Databases (User Repos)**
- Each vault has its own SQLite file: `priv/user_databases/vault_{id}.db`
- Contains all portfolio data (items, cached prices, etc.)
- Same schema as current `Aurum.Repo`
- Portable: user can download and use locally

### 4.2 File Structure

```
priv/
  ├── accounts_repo/           # Central DB migrations
  │   └── migrations/
  ├── repo/                    # User DB migrations (template)
  │   └── migrations/
  └── user_databases/          # Runtime vault databases
      ├── vault_abc123.db
      ├── vault_def456.db
      └── ...
```

### 4.3 Identification Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      FIRST VISIT                            │
├─────────────────────────────────────────────────────────────┤
│  1. No vault cookie detected                                │
│  2. Generate: vault_id (UUID) + vault_token (secure random) │
│  3. Create vault record in central DB (store token hash)    │
│  4. Create vault_{id}.db with migrations                    │
│  5. Set secure cookie: vault_id + vault_token (1 year TTL)  │
│  6. Store vault_id in localStorage (backup)                 │
│  7. Redirect to dashboard                                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     RETURN VISIT                            │
├─────────────────────────────────────────────────────────────┤
│  1. Read vault_id + vault_token from cookie                 │
│  2. Verify token against hash in central DB                 │
│  3. Start/get dynamic repo for vault_{id}.db                │
│  4. Load dashboard with user's data                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   RECOVERY (OPTIONAL)                       │
├─────────────────────────────────────────────────────────────┤
│  If cookie lost but localStorage has vault_id:              │
│    → Prompt: "We found a vault. Enter recovery email?"      │
│                                                             │
│  If user added recovery email:                              │
│    → Send magic link to regain access                       │
│                                                             │
│  If no recovery method:                                     │
│    → Create new vault (old data inaccessible)               │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Functional Requirements

### 5.1 Vault Creation

**FR-001: Automatic Vault Provisioning**
- On first visit (no valid cookie), automatically create a new vault
- No user interaction required
- Vault is immediately usable

**FR-002: Vault Database Initialization**
- Create SQLite file at `priv/user_databases/vault_{id}.db`
- Run all migrations from `priv/repo/migrations/`
- Verify database is accessible before proceeding

**FR-003: Secure Token Generation**
- Generate 32-byte cryptographically secure random token
- Store only bcrypt/argon2 hash in central database
- Never log or expose raw token

### 5.2 Vault Identification

**FR-004: Cookie-Based Identification**
- Set `vault_id` and `vault_token` in signed, HTTP-only, secure cookie
- Cookie TTL: 1 year, refreshed on each visit
- Cookie attributes: `SameSite=Lax`, `Secure` (in production)

**FR-005: Token Verification**
- On each request, verify token against stored hash
- Invalid token → treat as new user (create vault)
- Do not reveal whether vault_id exists

**FR-006: LocalStorage Backup**
- Store `vault_id` in browser localStorage
- Used only for recovery hints, not authentication
- JavaScript-accessible for recovery flow

### 5.3 Dynamic Database Routing

**FR-007: Per-Request Repo Binding**
- Each LiveView session binds to user's specific repo
- Use Ecto dynamic repos with `put_dynamic_repo/1`
- Repo process started on-demand, cached for session

**FR-008: Idle Repo Cleanup**
- Stop repo processes after 30 minutes of inactivity
- Graceful shutdown, no data loss
- Restart on next request

**FR-009: Concurrent User Support**
- Multiple users can access simultaneously
- Each user's queries isolated to their database
- No cross-vault data leakage

### 5.4 Recovery (Optional Feature)

**FR-010: Optional Recovery Email**
- Soft prompt after first item created: "Add email to protect your vault?"
- Email stored in central DB, associated with vault
- Never required, dismissible permanently

**FR-011: Magic Link Recovery**
- If user loses cookie but has recovery email configured
- Send one-time link to email
- Link sets new cookie and grants access

**FR-012: Recovery Without Email**
- If localStorage has vault_id but no recovery email
- Show: "A vault was found but cannot be verified. Start fresh?"
- User can choose to create new vault

### 5.5 Data Portability

**FR-013: Database Export**
- User can download their entire `vault_{id}.db` file
- Standard SQLite format, usable with any SQLite client
- Accessible from settings/profile area

**FR-014: Database Import (Future)**
- User can upload a `.db` file to restore/migrate vault
- Validate schema compatibility before import
- Out of scope for initial implementation

---

## 6. Technical Requirements

### 6.1 New Modules

```
lib/aurum/
  ├── accounts/
  │   ├── accounts.ex          # Context for vault management
  │   ├── vault.ex             # Vault schema (central DB)
  │   └── repo.ex              # Aurum.Accounts.Repo
  │
  └── vault_database/
      ├── manager.ex           # Create/delete vault databases
      ├── migrator.ex          # Run migrations on vault DBs
      ├── dynamic_repo.ex      # Start/stop per-vault repos
      └── supervisor.ex        # DynamicSupervisor for repos
```

### 6.2 Central Database Schema

```elixir
# vaults table
:id          - UUID, primary key
:slug        - String, unique, URL-friendly (optional, for sharing)
:token_hash  - String, bcrypt hash of vault token
:recovery_email - String, nullable
:inserted_at - DateTime
:updated_at  - DateTime
```

### 6.3 Modified Repo Configuration

```elixir
# Aurum.Repo becomes dynamic
defmodule Aurum.Repo do
  use Ecto.Repo,
    otp_app: :aurum,
    adapter: Ecto.Adapters.SQLite3,
    dynamic: true  # NEW: enables dynamic repo switching
end
```

### 6.4 LiveView Integration

```elixir
# on_mount hook for all LiveViews
defmodule AurumWeb.VaultLoader do
  def on_mount(:default, _params, session, socket) do
    vault_id = session["vault_id"]
    {:ok, repo} = Aurum.VaultDatabase.ensure_started(vault_id)
    {:cont, assign(socket, :vault_repo, repo)}
  end
end
```

### 6.5 Supervision Tree

```
Aurum.Supervisor
  ├── Aurum.Accounts.Repo              # Central DB (always running)
  ├── Aurum.VaultDatabase.Supervisor   # DynamicSupervisor
  │   ├── {Aurum.Repo, vault_1}        # Started on-demand
  │   ├── {Aurum.Repo, vault_2}
  │   └── ...
  └── AurumWeb.Endpoint
```

---

## 7. Migration Strategy

### Phase 1: Infrastructure
1. Create `Aurum.Accounts.Repo` and central database
2. Create `Aurum.VaultDatabase` module suite
3. Modify `Aurum.Repo` to support dynamic mode
4. Add vault loader plug/hook

### Phase 2: Identity
1. Implement cookie-based vault identification
2. Auto-create vault on first visit
3. Wire up LiveViews to use dynamic repo

### Phase 3: Existing Data Migration
1. Create "default" vault for existing data
2. Copy current `aurum_dev.db` contents to vault database
3. Test with single vault before enabling multi-user

### Phase 4: Recovery (Optional)
1. Add recovery email prompt
2. Implement magic link flow
3. Add database export feature

---

## 8. Security Considerations

| Concern | Mitigation |
|---------|------------|
| Token theft | HTTP-only, Secure, SameSite cookies |
| Token guessing | 256-bit random tokens, rate limiting |
| Cross-vault access | Repo isolation, no shared queries |
| Database enumeration | UUIDs, no sequential IDs |
| Token storage | Only hashes stored, never plaintext |

---

## 9. User Experience

### First Visit
1. User lands on homepage
2. "Creating your vault..." (< 1 second)
3. Redirect to empty dashboard
4. Subtle toast: "Your vault is ready. Bookmark this page!"

### Return Visit
1. User returns to site
2. Dashboard loads with their data
3. No login, no prompts

### Lost Access
1. User clears cookies, returns
2. If localStorage backup exists: "We found a previous vault. Add email to recover it?"
3. If no backup: New vault created, old data inaccessible

---

## 10. User Stories

### US-101: Automatic Vault Creation
**Description:** As a new visitor, I want a vault created automatically so that I can start tracking gold immediately.

**Acceptance Criteria:**
- [ ] First visit creates vault without user input
- [ ] Vault database file created at expected path
- [ ] User redirected to dashboard within 2 seconds
- [ ] Cookie set with vault credentials
- [ ] mix test passes

---

### US-102: Return Visit Recognition
**Description:** As a returning user, I want to be recognized automatically so that I see my existing portfolio.

**Acceptance Criteria:**
- [ ] Valid cookie loads correct vault data
- [ ] No login prompt shown
- [ ] Dashboard displays previously created items
- [ ] Cookie TTL refreshed on visit
- [ ] mix test passes

---

### US-103: Multi-User Isolation
**Description:** As a user, I want my data isolated from other users so that my portfolio is private.

**Acceptance Criteria:**
- [ ] Two users in different browsers see different data
- [ ] Creating item in one vault does not affect another
- [ ] Invalid vault_id cannot access other vaults
- [ ] mix test passes

---

### US-104: Vault Database Export
**Description:** As a user, I want to download my vault database so that I own my data completely.

**Acceptance Criteria:**
- [ ] Export button available in settings
- [ ] Downloads `.db` file with all user data
- [ ] File is valid SQLite, openable with standard tools
- [ ] Filename includes vault identifier
- [ ] mix test passes

---

### US-105: Optional Recovery Email
**Description:** As a user, I want to optionally add a recovery email so that I can regain access if I lose my browser data.

**Acceptance Criteria:**
- [ ] Prompt appears after adding first item (dismissible)
- [ ] Email saved to central database on submission
- [ ] "Email added" confirmation shown
- [ ] Prompt does not reappear after dismissal
- [ ] mix test passes

---

### US-106: Idle Vault Cleanup
**Description:** As the system, I want to stop idle vault repo processes so that server resources are conserved.

**Acceptance Criteria:**
- [ ] Repo process stops after 30 minutes of inactivity
- [ ] Next request restarts repo transparently
- [ ] No data loss on repo restart
- [ ] mix test passes

---

## 11. Out of Scope

- User-to-user sharing
- Collaborative vaults
- Password-based authentication
- OAuth/social login
- Database import
- Vault deletion by user
- Admin dashboard

---

## 12. Success Criteria

1. Multiple users can use the app simultaneously with isolated data
2. Zero-friction onboarding (no forms before first use)
3. Users can export their complete database
4. Existing single-user functionality preserved
5. No measurable performance degradation for single user

---

## 13. Guiding Constraint

If a feature adds friction to the first-use experience, it does not ship.

Invisible infrastructure is the goal.

---

## 14. Amendments (Post-Review)

The following amendments address architectural risks, security gaps, and operational concerns identified during PRD review.

### 14.1 Scale Target & Constraints

**Amendment A-001: Explicit Scale Envelope**
- Target: **≤5,000 total vaults, ≤500 concurrent active sessions**
- Single-node deployment only (horizontal scaling out of scope)
- If scale exceeds this, migrate to multi-tenant Postgres architecture

**Amendment A-002: Vault Creation Rate Limiting**
- Max 10 new vaults per IP per hour
- Max 100 new vaults per hour globally
- Implement via `Hammer` or similar rate-limiting library

**Amendment A-003: Abandoned Vault Cleanup Policy**
- Vaults with no activity for 90 days and no recovery email: eligible for deletion
- Send warning email 7 days before deletion (if email configured)
- Retain central DB record with `deleted_at` timestamp for 30 days

### 14.2 Token & Cookie Security

**Amendment A-004: Use SHA-256 for Token Verification (Not bcrypt)**

Replace FR-003 and FR-005:
```elixir
# Token generation
token = :crypto.strong_rand_bytes(32)
token_hash = :crypto.hash(:sha256, token <> Application.get_env(:aurum, :token_pepper))
             |> Base.encode64()

# Token verification (constant-time comparison)
expected_hash = :crypto.hash(:sha256, token <> pepper) |> Base.encode64()
Plug.Crypto.secure_compare(stored_hash, expected_hash)
```

Rationale: bcrypt on every request is a self-DoS; 256-bit random tokens don't need slow hashing.

**Amendment A-005: Use Encrypted Cookies (Not Just Signed)**
- Cookie must be **signed AND encrypted** to prevent token exposure
- Use Phoenix's built-in encrypted cookie support
- Token is a bearer credential; treat it like a password

**Amendment A-006: Token Rotation on Recovery**
- When magic link is used, generate new `vault_token` and invalidate old `token_hash`
- Prevents continued access from stolen tokens after recovery

### 14.3 Recovery Flow Hardening

**Amendment A-007: Email Verification Required Before Binding**

Replace FR-010:
- User submits email → send verification link
- Only after clicking link is email associated with vault
- Prevents session hijacking → recovery takeover attack

**Amendment A-008: Magic Link Specification**

Expand FR-011:
- TTL: 15 minutes
- Single-use: token invalidated after first use
- Store as hashed token in `recovery_tokens` table
- Rate limit: max 3 recovery requests per email per hour
- Anti-enumeration: always show "If this email is registered, you'll receive a link"

**Amendment A-009: Recovery Initiation Without localStorage**
- Add flow: user can enter email on login page to request recovery
- If email matches a vault with verified recovery email, send magic link
- Enables recovery on new device/browser

### 14.4 Vault Database Path & Storage

**Amendment A-010: Configurable Vault Storage Directory**

Replace `priv/user_databases/` with configurable path:
```elixir
# config/runtime.exs
config :aurum, :vault_databases_path,
  System.get_env("VAULT_DATABASES_PATH") || Path.join(File.cwd!(), "data/vaults")
```

Rationale: `priv/` is read-only in releases; user data must be on persistent volume.

**Amendment A-011: SQLite Configuration for Concurrency**
```elixir
# All vault repos must use:
config :aurum, Aurum.Repo,
  pool_size: 1,                    # SQLite is single-writer
  journal_mode: :wal,              # Better concurrency
  busy_timeout: 5000,              # Wait up to 5s for lock
  cache_size: -64000               # 64MB cache
```

### 14.5 Dynamic Repo Safety

**Amendment A-012: Mandatory Repo Wrapper**

Replace the pattern in 6.4 with a safe wrapper:
```elixir
defmodule Aurum.VaultRepo do
  @doc "Execute function with correct dynamic repo. Safe for Tasks/async."
  def with_vault(vault_id, fun) when is_function(fun, 0) do
    {:ok, repo} = Aurum.VaultDatabase.ensure_started(vault_id)
    Aurum.Repo.put_dynamic_repo(repo)
    fun.()
  end
end

# Usage in LiveView
def handle_event("save", params, socket) do
  VaultRepo.with_vault(socket.assigns.vault_id, fn ->
    Items.create_item(params)
  end)
end
```

**Amendment A-013: Cross-Vault Isolation Tests**
- Add integration tests that run concurrent requests across 2+ vaults
- Verify no data leakage between vaults
- Test async operations (Tasks, PubSub handlers) maintain correct repo binding

### 14.6 Database Export Safety

**Amendment A-014: Safe Export Using SQLite Backup API**
```elixir
def export_vault(vault_id) do
  source_path = vault_path(vault_id)
  export_path = Path.join(System.tmp_dir!(), "export_#{vault_id}_#{timestamp()}.db")
  
  # Use SQLite backup API for consistency during concurrent writes
  {:ok, conn} = Exqlite.Sqlite3.open(source_path)
  :ok = Exqlite.Sqlite3.execute(conn, "VACUUM INTO '#{export_path}'")
  Exqlite.Sqlite3.close(conn)
  
  {:ok, export_path}
end
```

### 14.7 Schema Cleanup

**Amendment A-015: Remove `slug` Field**
- Remove `:slug` from vaults table
- Sharing is out of scope; slug serves no purpose
- Reduces attack surface (no public vault identifiers)

### 14.8 Updated Central Database Schema

```elixir
# vaults table (amended)
:id               - UUID, primary key
:token_hash       - String, SHA-256 hash of vault token
:recovery_email   - String, nullable (only set after verification)
:email_verified_at - DateTime, nullable
:last_accessed_at - DateTime
:deleted_at       - DateTime, nullable (soft delete)
:inserted_at      - DateTime
:updated_at       - DateTime

# recovery_tokens table (new)
:id          - UUID, primary key
:vault_id    - UUID, foreign key
:token_hash  - String, SHA-256 hash
:expires_at  - DateTime
:used_at     - DateTime, nullable
:inserted_at - DateTime
```

### 14.9 Updated Security Considerations

| Concern | Mitigation |
|---------|------------|
| Token theft | HTTP-only, Secure, SameSite, **encrypted** cookies |
| Token guessing | 256-bit random tokens, rate limiting |
| Cross-vault access | Repo wrapper with process-dictionary binding, isolation tests |
| Database enumeration | UUIDs, no sequential IDs, no slug |
| Token storage | SHA-256 hash with server pepper |
| Recovery hijack | Email verification before binding, token rotation on recovery |
| Storage DoS | Rate limiting vault creation, cleanup policy |
| Request DoS | SHA-256 verification (fast), not bcrypt |
| Export consistency | SQLite VACUUM INTO for atomic export |

### 14.10 UX Copy Fix

**Amendment A-016: Remove "Bookmark this page" Toast**
- Cookie-based auth is not URL-dependent; bookmarking doesn't help recovery
- Replace with: "Your vault is ready. Add a recovery email in Settings to protect your data."
