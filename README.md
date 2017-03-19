# PlugLoggerJson
[![Hex pm](http://img.shields.io/hexpm/v/plug_logger_json.svg?style=flat)](https://hex.pm/packages/plug_logger_json)
[![Build Status](https://travis-ci.org/bleacherreport/plug_logger_json.svg?branch=master)](https://travis-ci.org/bleacherreport/plug_logger_json)
[![License](https://img.shields.io/badge/license-Apache%202-blue.svg)](https://github.com/bleacherreport/plug_logger_json/blob/master/LICENSE)

A comprehenisve JSON logger Plug.

## Dependencies
  * Plug
  * Poison

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add plug_logger_json to your list of dependencies in `mix.exs`:

        def deps do
          [{:plug_logger_json, "~> 0.4.0"}]
        end

  2. Ensure plug_logger_json is started before your application:

        def application do
          [applications: [:plug_logger_json]]
        end
  3. Replace `Plug.Logger` with `Plug.LoggerJSON, log: Logger.level` in your plug pipeline (endpoint.ex for phoenix apps)

## Recommended Setup
  * Configure this application
    * Add to your `config/config.exs` or `config/env_name.exs` ONLY if you want to filter params or headers:

            config :plug_logger_json,
              filtered_keys: ["password", "authorization"],

  * Configure the logger (console)
    * Add to your `config/config.exs` or `config/env_name.exs`:

            config :logger, :console,
              format: "$message\n",
              level: :info, #You may want to make this an env variable to change verbosity of the logs
              metadata: [:request_id]

  * Configure the logger (file)
    * Add `{:logger_file_backend, "~> 0.0.7"}` to your mix.exs
    * Run `mix deps.get`
    * Add to your `config/config.exs` or `config/env_name.exs`:

            config :logger, format: "$message\n", backends: [{LoggerFileBackend, :log_file}, :console]

            config :logger, :log_file,
              format: "$message\n",
              level: :info,
              metadata: [:request_id],
              path: "log/my_pipeline.log"

  * Ensure you are using Plug.Parsers (Phoenix adds this to endpoint.ex by default) to parse params & req bodies

            plug Plug.Parsers,
              parsers: [:urlencoded, :multipart, :json],
              pass: ["*/*"],
              json_decoder: Poison

## Error Logging
  * In router.ex of your phoenix project or your plug pipeline
    * Add `require Logger`
    * Add `use Plug.ErrorHandler`
    * Add the following two private functions:
            
            defp handle_errors(%Plug.Conn{status: 500} = conn, %{kind: kind, reason: reason, stack: stacktrace}) do
              Plug.LoggerJSON.log_error(kind, reason, stacktrace)
              send_resp(conn, 500, Poison.encode!(%{errors: %{detail: "Internal server error"}}))
            end

            defp handle_errors(_, _), do: nil 

## Log Verbosity
  * Plug Logger JSON supports two levels of logging. 
  * Info / Error will log api_version, date_time, duration, log_type, method, path, request_id, & status.
  * Warn / Debug log levels will include everything from info plus client_id, client_version, and params / request bodies.

## Contributing
Before submitting your pull request, please run:
  * `mix credo --strict`
  * `mix coveralls`
  * `mix dialyzer`

Please squash your pull request's commits into a single commit with a message and
detailed description explaining the commit.
