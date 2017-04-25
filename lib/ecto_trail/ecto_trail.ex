defmodule EctoTrail do
  @moduledoc """
  EctoTrail allows to store changeset changes into a separate `audit_log` table.

  ## Usage

  1. Add `ecto_trail` to your list of dependencies in `mix.exs`:

      def deps do
        [{:ecto_trail, "~> 0.1.0"}]
      end

  2. Ensure `ecto_trail` is started before your application:

    def application do
      [extra_applications: [:ecto_trail]]
    end

  3. Add a migration that creates `audit_log` table to `priv/repo/migrations` folder:

      defmodule EctoTrail.TestRepo.Migrations.CreateAuditLogTable do
        @moduledoc false
        use Ecto.Migration

        def change do
          create table(:audit_log, primary_key: false) do
            add :id, :uuid, primary_key: true
            add :actor_id, :string, null: false
            add :resource, :string, null: false
            add :resource_id, :string, null: false
            add :changeset, :map, null: false

            timestamps([type: :utc_datetime, updated_at: false])
          end
        end
      end

  4. Use `EctoTrail` in your repo:

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use EctoTrail
      end

  5. Use logging functions instead of defaults. See `EctoTrail` module docs.
  """
  import Ecto.Changeset
  alias EctoTrail.Changelog
  alias Ecto.Multi
  require Logger

  defmacro __using__(_) do
    quote do
      @doc """
      Call `c:Ecto.Repo.insert/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.insert/2` has.
      """
      @spec insert_and_log(struct_or_changeset :: Ecto.Schema.t | Ecto.Changeset.t,
                           actor_id :: String.T,
                           opts :: Keyword.t) ::
            {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
      def insert_and_log(struct_or_changeset, actor_id, opts \\ []) do
        Multi.new
        |> Multi.insert(:operation, struct_or_changeset, opts)
        |> Multi.run(:changelog, &EctoTrail.log_changes(__MODULE__, &1, struct_or_changeset, actor_id))
        |> __MODULE__.transaction()
        |> EctoTrail.build_result()
      end

      @doc """
      Call `c:Ecto.Repo.update/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.update/2` has.
      """
      @spec update_and_log(changeset :: Ecto.Changeset.t,
                           actor_id :: String.T,
                           opts :: Keyword.t) ::
            {:ok, Ecto.Schema.t} |
            {:error, Ecto.Changeset.t}
      def update_and_log(%Ecto.Changeset{} = changeset, actor_id, opts \\ []) do
        Multi.new
        |> Multi.update(:operation, changeset, opts)
        |> Multi.run(:changelog, &EctoTrail.log_changes(__MODULE__, &1, changeset, actor_id))
        |> __MODULE__.transaction()
        |> EctoTrail.build_result()
      end
    end
  end

  @doc false
  @spec build_result({:ok, changes :: Map.t} | {:error, :operation, changeset :: Ecto.Changeset.t}) ::
        {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def build_result({:ok, %{operation: operation}}),
    do: {:ok, operation}
  def build_result({:error, :operation, reason, _changes_so_far}),
    do: {:error, reason}

  @doc false
  @spec log_changes(repo :: Atom.t,
                    multi_acc :: List.t,
                    struct_or_changeset :: Ecto.Schema.t | Ecto.Changeset.t,
                    actor_id :: String.t) ::
        {:ok, Ecto.Schema.t} | {:ok, Ecto.Changeset.t}
  def log_changes(repo, multi_acc, struct_or_changeset, actor_id) do
    %{operation: operation} = multi_acc
    resource = operation.__struct__.__schema__(:source)
    embeds = operation.__struct__.__schema__(:embeds)
    changes = struct_or_changeset |> get_changes() |> get_embed_changes(embeds)

    result =
      %{
        actor_id: to_string(actor_id),
        resource: resource,
        resource_id: to_string(operation.id),
        changeset: changes
      }
      |> changelog_changeset()
      |> repo.insert()

    case result do
      {:ok, changelog} ->
        {:ok, changelog}
      {:error, reason} ->
        Logger.error("Failed to store changes in audit log: #{inspect struct_or_changeset} " <>
                     "by actor #{inspect actor_id}. Reason: #{inspect reason}")
        {:ok, reason}
    end
  end

  defp get_changes(%Changeset{changes: changes}),
    do: changes
  defp get_changes(changes) when is_map(changes),
    do: changes |> Changeset.change(%{}) |> get_changes()
  defp get_changes(nil),
    do: %{}

  defp get_embed_changes(changeset, embeds) do
    Enum.reduce(embeds, changeset, fn embed, changeset ->
      case Map.get(changeset, embed) do
        nil ->
          changeset
        embed_changes ->
          Map.put(changeset, embed, get_changes(embed_changes))
      end
    end)
  end

  defp changelog_changeset(attrs) do
    %Changelog{}
    |> cast(attrs, [
      :actor_id,
      :resource,
      :resource_id,
      :changeset,
    ])
  end
end
