use Mix.Config

config :ecto_trail,
  table_name: "audit_log"

config :geo_postgis,
  # If you want to set your JSON module
  json_library: Poison

import_config "#{Mix.env()}.exs"
