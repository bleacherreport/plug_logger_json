defmodule PlugLoggerJson.Mixfile do
  use Mix.Project

  def project do
    [
      app: :plug_logger_json,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: true
      ],
      description: "Elixir Plug that formats http request logs as json",
      docs: [extras: ["README.md"]],
      elixir: "~> 1.3",
      homepage_url: "https://github.com/bleacherreport/plug_logger_json",
      name: "Plug Logger JSON",
      package: package(),
      preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      source_url: "https://github.com/bleacherreport/plug_logger_json",
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.4.0",
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:credo,       "~> 0.7",  only: [:dev]},
      {:dialyxir,    "~> 0.5",  only: [:dev]},
      {:earmark,     "~> 1.2",  only: [:dev]},
      {:ex_doc,      "~> 0.15", only: [:dev]},
      {:excoveralls, "~> 0.6",  only: [:test]},
      {:plug,        "~> 1.0"},
      {:poison,      "~> 1.5 or ~> 2.0 or ~> 3.0"}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/bleacherreport/plug_logger_json"},
      maintainers: ["John Kelly"]
    ]
  end
end
