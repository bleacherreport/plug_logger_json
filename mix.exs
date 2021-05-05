defmodule PlugLoggerJson.Mixfile do
  use Mix.Project

  @source_url "https://github.com/bleacherreport/plug_logger_json"
  @version "0.7.0"

  def project do
    [
      app: :plug_logger_json,
      name: "Plug Logger JSON",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixir: "~> 1.3",
      version: @version,
      deps: deps(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_deps: true],
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
      applications: [:logger, :plug]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0.2", only: [:dev]},
      {:dialyxir, "~> 0.5.1", only: [:dev]},
      {:earmark, "~> 1.3.1", only: [:dev]},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10.5", only: [:test]},
      {:plug, "~> 1.0"},
      {:poison, "~> 1.5 or ~> 2.0 or ~> 3.0 or ~> 4.0"}
    ]
  end

  defp package do
    [
      description: "Elixir Plug that formats HTTP request logs as JSON.",
      files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
      licenses: ["Apache-2.0"],
      maintainers: ["John Kelly, Ben Marx"],
      links: %{
        "Changelog" => "https://hexdocs.pm/plug_logger_json/changelog.html",
        "GitHub" => @source_url
      },
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: @version,
      api_reference: false,
      formatters: ["html"]
    ]
  end
end
