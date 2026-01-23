defmodule Aurum.Accounts.Repo.Migrations.AddRecoveryEmailPromptDismissed do
  use Ecto.Migration

  def change do
    alter table(:vaults) do
      add :recovery_email_prompt_dismissed, :boolean, default: false
    end
  end
end
