defmodule EctoTrail.TestRepo.Migrations.AddLocationToResourceTable do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"
    alter table(:resources) do
      add :location, :geometry
    end
  end
end
