# EctoTrail

EctoTrail allows to store changeset changes into a separate `audit_log` table.

## Installation and usage

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

## Docs

The docs can be found at [https://hexdocs.pm/ecto_trail](https://hexdocs.pm/ecto_trail).

