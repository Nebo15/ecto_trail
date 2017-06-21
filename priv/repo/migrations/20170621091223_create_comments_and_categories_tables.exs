defmodule EctoTrail.TestRepo.Migrations.CreateCommentsAndCategoriesTables do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :title, :string, null: false
      add :resource_id, references(:resources, on_delete: :nothing)
    end

    create table(:categories) do
      add :title, :string, null: false
      add :resource_id, references(:resources, on_delete: :nothing)
    end
  end
end
