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

  You can configure audit_log table name (default `audit_log`) in config:

    config :ecto_trail,
      table_name: "custom_audit_log_name"

   If you use multiple Repo and `audit_log` should be stored in tables with different names,
   you can configure Schema module for each Repo:

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use EctoTrail, schema: My.Custom.ChangeLogSchema
      end
  """
  alias Ecto.{Changeset, Multi}
  alias EctoTrail.Changelog
  require Logger

  defmacro __using__(opts) do
    schema = Keyword.get(opts, :schema, Changelog)

    quote do
      @doc """
      Call `c:Ecto.Repo.insert/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.insert/2` has.
      """
      @spec insert_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      def insert_and_log(struct_or_changeset, actor_id, opts \\ []),
        do: EctoTrail.insert_and_log(__MODULE__, struct_or_changeset, actor_id, opts)

      @doc """
      Call `c:Ecto.Repo.update/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.update/2` has.
      """
      @spec update_and_log(
              changeset :: Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()}
              | {:error, Ecto.Changeset.t()}
      def update_and_log(changeset, actor_id, opts \\ []),
        do: EctoTrail.update_and_log(__MODULE__, changeset, actor_id, opts)

      @doc """
      Call `c:Ecto.Repo.audit_schema/0` operation and get Ecto Schema struct for change_log table.

      Return Ecto Schema struct for change_log table.
      """
      @spec audit_log_schema :: atom()
      def audit_log_schema, do: struct(unquote(schema))
    end
  end

  @doc """
  Call `c:Ecto.Repo.insert/2` operation and store changes in a `change_log` table.

  Insert arguments, return and options same as `c:Ecto.Repo.insert/2` has.
  """
  @spec insert_and_log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.insert(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id)
  end

  @doc """
  Call `c:Ecto.Repo.update/2` operation and store changes in a `change_log` table.

  Insert arguments, return and options same as `c:Ecto.Repo.update/2` has.
  """
  @spec update_and_log(
          repo :: Ecto.Repo.t(),
          changeset :: Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def update_and_log(repo, changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.update(:operation, changeset, opts)
    |> run_logging_transaction(repo, changeset, actor_id)
  end

  defp run_logging_transaction(multi, repo, struct_or_changeset, actor_id) do
    multi
    |> Multi.run(:changelog, fn repo, acc ->
      log_changes(repo, acc, struct_or_changeset, actor_id)
    end)
    |> repo.transaction()
    |> build_result()
  end

  defp build_result({:ok, %{operation: operation}}),
    do: {:ok, operation}

  defp build_result({:error, :operation, reason, _changes_so_far}),
    do: {:error, reason}

  defp log_changes(repo, multi_acc, struct_or_changeset, actor_id) do
    %{operation: operation} = multi_acc
    associations = operation.__struct__.__schema__(:associations)
    resource = operation.__struct__.__schema__(:source)
    embeds = operation.__struct__.__schema__(:embeds)

    changes =
      struct_or_changeset
      |> get_changes()
      |> get_embed_changes(embeds)
      |> get_assoc_changes(associations)

    result =
      %{
        actor_id: to_string(actor_id),
        resource: resource,
        resource_id: to_string(operation.id),
        changeset: changes
      }
      |> changelog_changeset(repo)
      |> repo.insert()

    case result do
      {:ok, changelog} ->
        {:ok, changelog}

      {:error, reason} ->
        Logger.error(
          "Failed to store changes in audit log: #{inspect(struct_or_changeset)} " <>
            "by actor #{inspect(actor_id)}. Reason: #{inspect(reason)}"
        )

        {:ok, reason}
    end
  end

  defp get_changes(%Changeset{changes: changes}),
    do: map_custom_ecto_types(changes)

  defp get_changes(changes) when is_map(changes),
    do: changes |> Changeset.change(%{}) |> get_changes()

  defp get_changes(changes) when is_list(changes),
    do:
      changes
      |> Enum.map_reduce([], fn ch, acc -> {nil, List.insert_at(acc, -1, get_changes(ch))} end)
      |> elem(1)

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

  defp get_assoc_changes(changeset, associations) do
    Enum.reduce(associations, changeset, fn assoc, changeset ->
      case Map.get(changeset, assoc) do
        nil ->
          changeset

        assoc_changes ->
          Map.put(changeset, assoc, get_changes(assoc_changes))
      end
    end)
  end

  defp map_custom_ecto_types(changes) do
    Enum.into(changes, %{}, &map_custom_ecto_type/1)
  end

  defp map_custom_ecto_type({_field, %Changeset{}} = input), do: input

  defp map_custom_ecto_type({field, value}) when is_map(value) do
    case Map.has_key?(value, :__struct__) do
      true -> {field, inspect(value)}
      false -> {field, value}
    end
  end

  defp map_custom_ecto_type(value), do: value

  defp changelog_changeset(attrs, repo) do
    Changeset.cast(repo.audit_log_schema(), attrs, ~w(actor_id resource resource_id changeset)a)
  end
end
