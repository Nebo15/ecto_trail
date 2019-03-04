use Mix.Config

config :ecto_trail,
  table_name: "audit_log"

import_config "#{Mix.env()}.exs"
