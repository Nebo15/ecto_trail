use Mix.Releases.Config,
  default_release: :default,
  default_environment: :default

cookie = :sha256
|> :crypto.hash(System.get_env("ERLANG_COOKIE") || "iOm04jzQmc/RWe8YdPxe0cO1rYK6uMhDiEisVSb+nl9FFvaXAJ8WKlQ0Bc7TiJVp")
|> Base.encode64

environment :default do
  set pre_start_hook: "bin/hooks/pre-start.sh"
  set dev_mode: false
  set include_erts: false
  set include_src: false
  set cookie: cookie
end

release :change_logger do
  set version: current_version(:change_logger)
  set applications: [
    change_logger: :permanent
  ]
end
