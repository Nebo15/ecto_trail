defmodule ChangeLogger.Repo.Migrations.CreateLogChangesTable do
  use Ecto.Migration

  def change do
    create table(:log_changes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :string, null: false
      add :resource, :string, null: false
      add :resource_id, :string, null: false
      add :changeset, :map, null: false

      timestamps([type: :utc_datetime, updated_at: false])
    end
  end
end
