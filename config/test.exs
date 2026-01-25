import Config

# Mark this as test environment for runtime checks
config :aurum, :env, :test

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :aurum, Aurum.Repo,
  database: Path.expand("../aurum_test.db", __DIR__),
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  journal_mode: :wal,
  busy_timeout: 15_000,
  queue_target: 5000,
  queue_interval: 10_000

config :aurum, Aurum.Accounts.Repo,
  database: Path.expand("../aurum_accounts_test.db", __DIR__),
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  journal_mode: :wal,
  busy_timeout: 15_000,
  queue_target: 5000,
  queue_interval: 10_000

config :aurum, :vault_databases_path, Path.expand("../tmp/test_vaults", __DIR__)

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :aurum, AurumWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BkQBv41lDxt3BWjXJPOFktDFETJGbS/QGqNOFSfIG7u66tC/hVWq9iLuulYdcaC2",
  server: false

# In test we don't send emails
config :aurum, Aurum.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, AurumWeb.Endpoint
