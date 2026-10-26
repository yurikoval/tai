defmodule Tai.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tai,
      version: "0.0.75",
      elixir: "~> 1.20.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      package: package(),
      start_permanent: Mix.env() == :prod,
      description: description(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {Tai.Application, []},
      start_phases: [venues: []],
      extra_applications: [
        :phoenix_pubsub,
        :logger,
        :iex,
        :jason,
        :tai_events,
        :ecto_term,
        :postgrex
      ]
    ]
  end

  defp deps do
    [
      {:confex, "~> 3.4"},
      {:ecto, "~> 3.6"},
      {:ecto_sql, "~> 3.6"},
      {:ecto_sqlite3, "~> 0.26.0", optional: true},
      # {:ecto_term, github: "fremantle-industries/ecto_term"},
      {:ecto_term, "~> 0.0.1"},
      {:enumerati, "~> 0.0.8"},
      {:ex2ms, "~> 1.0"},
      {:ex_binance, path: "../../packages/ex_binance"},
      {:ex_bybit, path: "../../packages/ex_bybit"},
      {:ex_delta_exchange, path: "../../packages/ex_delta_exchange"},
      {:ex_deribit, path: "../../packages/ex_deribit"},
      {:ex_okex, path: "../../packages/ex_okex"},
      {:ex_gdax, path: "../../packages/ex_gdax"},
      {:ex_huobi, path: "../../packages/ex_huobi"},
      {:decimal, "~> 3.2", override: true},
      {:httpoison, "~> 3.0", override: true},
      {:jason, "~> 1.1"},
      {:juice, "~> 0.0.3"},
      {:murmur, "~> 2.0"},
      {:paged_query, "~> 0.0.2"},
      {:phoenix_pubsub, "~> 2.0"},
      {:polymorphic_embed, "~> 5.0"},
      {:poolboy, "~> 1.5.1"},
      {:postgrex, "~> 0.15", optional: true},
      {:table_rex, "~> 4.1"},
      {:tai_events, path: "../../packages/tai_events"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:timex, "~> 3.6"},
      {:stored, path: "../../packages/stored"},
      {:vex, "~> 0.7"},
      {:websockex, "~> 0.5.1", override: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:exvcr, "~> 0.16.0", only: [:dev, :test]},
      {:logger_file_backend_with_formatters, "~> 0.0.1", only: [:dev, :test]},
      {:logger_file_backend_with_formatters_stackdriver, "~> 0.0.4", only: [:dev, :test]},
      {:echo_boy, "~> 0.6", runtime: false, optional: true},
      {:mock, "~> 0.3", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev},
      # TODO: remove after dialyzer umbrella support is added
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "A composable, real time, market data and trade execution toolkit"
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: ["Alex Kwiatkowski"],
      links: %{"GitHub" => "https://github.com/fremantle-industries/tai"}
    }
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
