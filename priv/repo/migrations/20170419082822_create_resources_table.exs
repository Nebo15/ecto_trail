defmodule EctoTrail.TestRepo.Migrations.CreateResourcesTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:resources) do
      add :name, :string
      add :data, :map

      timestamps()
    end
  end
end
