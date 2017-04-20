defmodule ChangeLogger do
  @moduledoc """
  This is an entry point of change_loggers application.
  """
  import Ecto.Changeset
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    opts = [strategy: :one_for_one, name: ChangeLogger.Supervisor]
    Supervisor.start_link([], opts)
  end

  @doc false
  def load_from_system_env(config) do
    {:ok, Confex.process_env(config)}
  end

  def save_changes({:ok, result}, %Ecto.Changeset{valid?: true} = changeset, resource, user_id) do
    %{
      user_id: user_id,
      resource: resource,
      resource_id: result.id,
      what_changed: changeset.changes
    }
    |> log_changes_changeset()
    |> get_project_repo().insert()

    {:ok, result}
  end
  def save_changes(result, _changeset, _resource, _user_id), do: result

  def log_changes_changeset(attrs) do
    fields = ~W(
      user_id
      resource
      resource_id
      what_changed
    )

    required_fields = [
      :user_id,
      :resource,
      :resource_id,
      :what_changed,
    ]

    %ChangeLogger.Model{}
    |> cast(attrs, fields)
    |> validate_required(required_fields)
  end

  defp get_project_repo() do
    Confex.get(:change_logger, :repo)
  end

  def extract_object_name(module) do
    module
    |> to_string
    |> String.split(".")
    |> List.last
    |> Macro.underscore
  end

end