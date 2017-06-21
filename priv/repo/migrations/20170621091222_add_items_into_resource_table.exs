defmodule EctoTrail.TestRepo.Migrations.AddItemsIntoResourcesTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:resources) do
      add :items, {:array, :map}
    end
  end
end
