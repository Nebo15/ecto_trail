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
  alias Ecto.Changeset
  alias EctoTrail.Changelog
  alias Ecto.Multi
  require Logger

  defmacro __using__(_) do
    quote do
      @doc """
      Store changes in a `change_log` table.
      """
      @spec log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              changes :: Map.t(),
              actor_id :: String.T
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      def log(struct_or_changeset, changes, actor_id),
        do: EctoTrail.log(__MODULE__, struct_or_changeset, changes, actor_id)

      @doc """
      Store bulk changes in a `change_log` table.
      """
      @spec log_bulk(
              structs :: list(Ecto.Schema.t()),
              changes :: list(Map.t()),
              actor_id :: String.T
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      def log_bulk(structs, changes, actor_id),
        do: EctoTrail.log_bulk(__MODULE__, structs, changes, actor_id)

      @doc """
      Call `c:Ecto.Repo.insert/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.insert/2` has.
      """
      @spec insert_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
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
      Call `c:Ecto.Repo.upsert/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.upsert/2` has.
      """
      @spec upsert_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()}
              | {:error, Ecto.Changeset.t()}
      def upsert_and_log(struct_or_changeset, actor_id, opts \\ []),
        do: EctoTrail.upsert_and_log(__MODULE__, struct_or_changeset, actor_id, opts)

      @doc """
      Call `c:Ecto.Repo.delete/2` operation and store deleted objext in a `change_log` table.
      """
      @spec delete_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()}
              | {:error, Ecto.Changeset.t()}
      def delete_and_log(struct_or_changeset, actor_id, opts \\ []),
        do: EctoTrail.delete_and_log(__MODULE__, struct_or_changeset, actor_id, opts)
    end
  end

  @doc """
  Store changes in a `change_log` table.
  """
  @spec log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          changes :: Map.t(),
          actor_id :: String.T
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def log(repo, struct_or_changeset, changes, actor_id) do
    Multi.new()
    |> Ecto.Multi.run(:operation, fn _, _ -> {:ok, struct_or_changeset} end)
    |> run_logging_transaction_alone(repo, struct_or_changeset, changes, actor_id, :insert)
  end

  @doc """
  Store bulk changes in a `change_log` table.
  """
  @spec log_bulk(
          repo :: Ecto.Repo.t(),
          structs :: list(Ecto.Schema.t()),
          changes :: list(Map.t()),
          actor_id :: String.T
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def log_bulk(repo, structs, changes, actor_id) do
    Enum.zip(structs, changes)
    |> Enum.each(fn {struct, change} ->
      Multi.new()
      |> Ecto.Multi.run(:operation, fn _, _ -> {:ok, struct} end)
      |> run_logging_transaction_alone(repo, struct, change, actor_id, :insert)
    end)
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
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.insert(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id, :insert)
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
    |> run_logging_transaction(repo, changeset, actor_id, :update)
  end

  @doc """
  Call `c:Ecto.Repo.upsert/2` operation and store changes in a `change_log` table.

  Insert arguments, return and options same as `c:Ecto.Repo.upsert/2` has.
  """
  @spec upsert_and_log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def upsert_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.insert_or_update(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id, :upsert)
  end

  @doc """
   Call `c:Ecto.Repo.delete/2` operation and store deleted objext in a `change_log` table.
  """
  @spec delete_and_log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def delete_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.delete(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id, :delete)
  end

  defp run_logging_transaction(multi, repo, struct_or_changeset, actor_id, operation_type) do
    multi
    |> Multi.run(:changelog, &log_changes(&1, &2, struct_or_changeset, actor_id, operation_type))
    |> repo.transaction()
    |> build_result()
  end

  defp run_logging_transaction_alone(multi, repo, struct, changes, actor_id, operation_type) do
    multi
    |> Multi.run(
      :changelog,
      &log_changes_alone(&1, &2, struct, changes, actor_id, operation_type)
    )
    |> repo.transaction()
    |> build_result()
  end

  defp build_result({:ok, %{operation: operation}}), do: {:ok, operation}

  defp build_result({:error, :operation, reason, _changes_so_far}), do: {:error, reason}

  defp log_changes_alone(repo, multi_acc, struct_or_changeset, changes, actor_id, operation_type) do
    %{operation: operation} = multi_acc
    resource = operation.__struct__.__schema__(:source)

    result =
      %{
        actor_id: to_string(actor_id),
        resource: resource,
        resource_id: to_string(operation.id),
        changeset: changes,
        change_type: operation_type
      }
      |> changelog_changeset()
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

  defp log_changes(repo, multi_acc, struct_or_changeset, actor_id, operation_type) do
    %{operation: operation} = multi_acc
    associations = operation.__struct__.__schema__(:associations)
    resource = operation.__struct__.__schema__(:source)
    embeds = operation.__struct__.__schema__(:embeds)

    struct_or_changeset =
      if operation_type == :delete and struct_or_changeset.__struct__ == Ecto.Changeset do
        struct_or_changeset.data
      else
        struct_or_changeset
      end

    changes =
      struct_or_changeset
      |> get_changes()
      |> get_embed_changes(embeds)
      |> get_assoc_changes(associations)
      |> redact_custom_fields()
      |> validate_changes(struct_or_changeset, operation_type)

    result =
      %{
        actor_id: to_string(actor_id),
        resource: resource,
        resource_id: to_string(operation.id),
        changeset: changes,
        change_type: operation_type
      }
      |> changelog_changeset()
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

  defp validate_changes(changes, schema, operation_type) do
    case operation_type do
      :insert ->
        # This case is true when the operation type is an insert operation.
        changes

      :update ->
        # This case is true when the operation type is an update operation.
        changes

      :delete ->
        # This case is true when the operation type is an delete operation.
        {_, return} =
          Map.from_struct(schema)
          |> Map.pop(:__meta__)

        remove_empty_assosiations(return)

      :upsert ->
        # This case is true when the operation type is an upsert operation.
        changes
    end
  end

  defp redact_custom_fields(changeset) do
    redacted_fields = Application.fetch_env(:ecto_trail, :redacted_fields)

    if redacted_fields == :error do
      changeset
    else
      {:ok, redacted_fields} = redacted_fields

      Enum.map(changeset, fn {key, value} ->
        {key,
         if Enum.member?(redacted_fields, key) do
           "[REDACTED]"
         else
           value
         end}
      end)
      |> Map.new()
    end
  end

  defp remove_empty_assosiations(struct) do
    Enum.map(struct, fn {key, value} ->
      {key,
       if String.contains?(Kernel.inspect(value), "Ecto.Association.NotLoaded") do
         nil
       else
         value
       end}
    end)
    |> Map.new()
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

  defp get_assoc_changes(changeset, assocciations) do
    Enum.reduce(assocciations, changeset, fn assoc, changeset ->
      case Map.get(changeset, assoc) do
        nil ->
          changeset

        assoc_changes ->
          Map.put(changeset, assoc, get_changes(assoc_changes))
      end
    end)
  end

  defp map_custom_ecto_types(changes) do
    changes |> Enum.map(&map_custom_ecto_type/1) |> Enum.into(%{})
  end

  defp map_custom_ecto_type({_field, %Ecto.Changeset{}} = input), do: input

  defp map_custom_ecto_type({field, value}) when is_map(value) do
    case Map.has_key?(value, :__struct__) do
      true -> {field, inspect(value)}
      false -> {field, value}
    end
  end

  defp map_custom_ecto_type(value), do: value

  defp changelog_changeset(attrs) do
    Changeset.cast(%Changelog{}, attrs, [
      :actor_id,
      :resource,
      :resource_id,
      :changeset,
      :change_type
    ])
  end
end
