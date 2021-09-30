use Mix.Config

config :ecto_trail, table_name: "audit_log", redacted_fields: [:password]
