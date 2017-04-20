defmodule ChangeLogger.Model do

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "log_changes" do
    field :declaration_signed_id, Ecto.UUID
    field :user_id, :string
    field :resource, :string
    field :resource_id, :string
    field :what_changed, :map

    timestamps([type: :utc_datetime, updated_at: false])
  end
end