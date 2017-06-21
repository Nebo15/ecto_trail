defmodule EctoTrail.TestRepo.Migrations.AddListAndMapIntoResourcesTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:resources) do
      add :array, {:array, :string}
      add :map, :map
    end
  end
end
