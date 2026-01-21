defmodule Aurum.Accounts.Repo do
  use Ecto.Repo,
    otp_app: :aurum,
    adapter: Ecto.Adapters.SQLite3
end
