defmodule EctoTrail.TestRepo.Migrations.CreateAuditLogTable do
  @moduledoc false
  use Ecto.Migration

  @table_name String.to_atom(Application.fetch_env!(:ecto_trail, :table_name))

  def change(table_name \\ @table_name) do
    IO.inspect(table_name, label: :table_name)

    create table(table_name, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:actor_id, :string, null: false)
      add(:resource, :string, null: false)
      add(:resource_id, :string, null: false)
      add(:changeset, :map, null: false)

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
