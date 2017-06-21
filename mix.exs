defmodule EctoTrail.Mixfile do
  use Mix.Project

  @version "0.2.1"

  def project do
    [app: :ecto_trail,
     description: description(),
     package: package(),
     version: @version,
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test],
     docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["README.md"]]]
  end

  def description do
    "This package allows to add audit log that is based on Ecto changesets and stored in a separate table."
  end

  def application do
    [extra_applications: [:logger, :ecto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:ecto, "~> 2.1"},
     {:postgrex, "~> 0.13.2", optional: true},
     {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
     {:ex_doc, ">= 0.15.0", only: [:dev, :test]},
     {:excoveralls, ">= 0.5.0", only: [:dev, :test]},
     {:dogma, ">= 0.1.12", only: [:dev, :test]},
     {:credo, ">= 0.5.1", only: [:dev, :test]}]
  end

  defp package do
    [contributors: ["Nebo #15"],
     maintainers: ["Nebo #15"],
     licenses: ["LISENSE.md"],
     links: %{github: "https://github.com/Nebo15/ecto_trail"},
     files: ~w(lib LICENSE.md mix.exs README.md)]
  end
end
