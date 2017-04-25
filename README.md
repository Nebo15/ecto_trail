# EctoTrail
[![Hex.pm Downloads](https://img.shields.io/hexpm/dw/ecto_trail.svg?maxAge=3600)](https://hex.pm/packages/ecto_trail) [![Latest Version](https://img.shields.io/hexpm/v/ecto_trail.svg?maxAge=3600)](https://hex.pm/packages/ecto_trail) [![License](https://img.shields.io/hexpm/l/ecto_trail.svg?maxAge=3600)](https://hex.pm/packages/ecto_trail) [![Build Status](https://travis-ci.org/Nebo15/ecto_trail.svg?branch=master)](https://travis-ci.org/Nebo15/ecto_trail) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/ecto_trail/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/ecto_trail?branch=master) [![Ebert](https://ebertapp.io/github/Nebo15/ecto_trail.svg)](https://ebertapp.io/github/Nebo15/ecto_trail)

EctoTrail allows to store changeset changes into a separate `audit_log` table.

## Installation and usage

1. Add `ecto_trail` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:ecto_trail, "~> 0.1.0"}]
  end
  ```

2. Ensure `ecto_trail` is started before your application:

  ```elixir
  def application do
    [extra_applications: [:ecto_trail]]
  end
  ```

3. Add a migration that creates `audit_log` table to `priv/repo/migrations` folder:

  ```elixir
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
  ```

4. Use `EctoTrail` in your repo:

  ```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo, otp_app: :my_app
    use EctoTrail
  end
  ```

5. Use logging functions instead of defaults. See `EctoTrail` module docs.

## Docs

The docs can be found at [https://hexdocs.pm/ecto_trail](https://hexdocs.pm/ecto_trail).

