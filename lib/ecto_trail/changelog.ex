defmodule EctoTrail.Changelog do
  @moduledoc """
  This is schema that used to store changes in DB.
  """
  use Ecto.Schema

  schema Application.fetch_env!(:ecto_trail, :table_name) do
    field :actor_id, :string
    field :resource, :string
    field :resource_id, :string
    field :changeset, :map

    timestamps([type: :utc_datetime, updated_at: false])
  end
end
