# Enable PostGIS for Ecto
Postgrex.Types.define(
  EctoTrail.PostgresTypes,
  [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
  json: Jason
)

defmodule TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_trail,
    adapter: Ecto.Adapters.Postgres

  use EctoTrail
end

defmodule TestRepoWithCustomSchema do
  use Ecto.Repo,
    otp_app: :ecto_trail,
    adapter: Ecto.Adapters.Postgres

  use EctoTrail, schema: TestCustomChangelog
end

defmodule TestCustomChangelog do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "custom_audit_log" do
    field(:actor_id, :string)
    field(:resource, :string)
    field(:resource_id, :string)
    field(:changeset, :map)

    timestamps(type: :utc_datetime, updated_at: false)
  end
end

defmodule Comment do
  use Ecto.Schema

  schema "comments" do
    field(:title, :string)
    belongs_to(:resource, Resource)
  end

  def changeset(%Comment{} = schema, attrs) do
    Ecto.Changeset.cast(schema, attrs, [:title])
  end
end

defmodule Category do
  use Ecto.Schema

  schema "categories" do
    field(:title, :string)
    belongs_to(:resource, Resource)
  end

  def changeset(%Category{} = schema, attrs) do
    Ecto.Changeset.cast(schema, attrs, [:title])
  end
end

defmodule Resource do
  @moduledoc false
  use Ecto.Schema

  schema "resources" do
    field(:name, :string)
    field(:array, {:array, :string})
    field(:map, :map)
    field(:location, Geo.PostGIS.Geometry)

    embeds_one :data, Data, primary_key: false do
      field(:key1, :string)
      field(:key2, :string)
    end

    embeds_many :items, Item, primary_key: false do
      field(:name, :string)
    end

    has_many(:comments, Comment)
    has_one(:category, {"categories", Category}, on_replace: :delete)

    timestamps()
  end

  def embed_changeset(schema, attrs) do
    Ecto.Changeset.cast(schema, attrs, [:key1, :key2])
  end

  def embeds_many_changeset(schema, attrs) do
    Ecto.Changeset.cast(schema, attrs, [:name])
  end
end

# Start Postgrex
{:ok, _pids} = Application.ensure_all_started(:postgrex)

# Create DB
_ = TestRepo.__adapter__().storage_up(TestRepo.config())

# Start Repo
{:ok, _pid} = TestRepo.start_link()
{:ok, _pid} = TestRepoWithCustomSchema.start_link()

# Migrate DB
migrations_path = Path.join([:code.priv_dir(:ecto_trail), "repo", "migrations"])
Ecto.Migrator.run(TestRepo, migrations_path, :up, all: true)

# Start ExUnit
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(TestRepoWithCustomSchema, :manual)
