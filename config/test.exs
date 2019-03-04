use Mix.Config
config :ex_unit, capture_log: true
config :ecto_trail, sql_sandbox: true

config :ecto_trail, TestRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "ecto_trail_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  types: EctoTrail.PostgresTypes

config :ecto_trail, TestRepoWithCustomSchema,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "ecto_trail_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  types: EctoTrail.PostgresTypes
