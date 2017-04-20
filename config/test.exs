use Mix.Config

# Configuration for test environment
config :ex_unit, capture_log: true


# Configure your database
config :change_logger, ChangeLogger.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: {:system, "DB_NAME", "change_logger_test"}
