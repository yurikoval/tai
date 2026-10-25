defmodule ExDeribit.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_deribit,
      version: "0.0.9",
      elixir: "~> 1.10",
      package: package(),
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.1"},
      {:mapail, "~> 1.0.2"},
      {:timex, "~> 3.5"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:exvcr, "~> 0.10", only: [:dev, :test]},
      {:ex_unit_notifier, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp description do
    "Deribit API Client for Elixir"
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: ["Alex Kwiatkowski"],
      links: %{"GitHub" => "https://github.com/fremantle-capital/ex_deribit"}
    }
  end
end
