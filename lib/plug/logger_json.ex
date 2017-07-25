defmodule Plug.LoggerJSON do
  @moduledoc ~S(
  A plug for logging basic request information in the format:
  ```json
  {
    "api_version":     "N/A"
    "client_ip":       "23.235.46.37"
    "client_version":  "ios/1.6.7",
    "date_time":       "2016-05-31T18:00:13Z",
    "duration":        4.670,
    "handler":         "fronts#index"
    "log_type":        "http",
    "method":          "POST",
    "params":          {
                         "user":"jkelly",
                         "password":"[FILTERED]"
                       },
    "path":            "/",
    "request_id":      "d90jcl66vp09r8tke3utjsd1pjrg4ln8",
    "status":          "200"
  }
  ```

  To use it, just plug it into the desired module.
  plug Plug.LoggerJSON, log: :debug
  ## Options
  * `:log` - The log level at which this plug should log its request info.
  Default is `:info`.
  * `:extra_paths` - Extra paths that should be logged to the request.
  Default is `[]`. Please see "Extra Paths" section for more information.

  ## Extra Paths

  Additional data can be logged alongside the request by specifying them in
  the following format to the `:extra_paths` key:

        extra_paths: [
          {"user_id", [:assigns, :user, :user_id]},
          {"other_id", [:private, :private_resource, :id]},
          {"should_not_appear", [:private, :does_not_exist]}
        ]

  In this example, the `:user_id` is retrieved from `conn.assigns.user.user_id`
  and added to the log if it exists. If the path is not found then the
  additional field is not logged. The first argument in the pair is the key
  that will be logged, the second argument is the path relative to conn that
  the value will be found. The first entry in the list must be `:assigns` or
  `:private`. It is also a requirement that the value is serialiazable as JSON
  by the Poison library, otherwise an error will be raised.
  )

  alias Plug.Conn

  @behaviour Plug

  require Logger

  @typedoc """
  Type for a plug option
  """
  @type opts :: binary | tuple | atom | integer | float | [opts] | %{opts => opts}

  @typedoc """
  Type for time
  """
  @type time :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @spec init(opts) :: opts
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), opts) :: Plug.Conn.t()
  def call(conn, level_or_opts) when is_atom(level_or_opts) do
    call(conn, level: level_or_opts)
  end
  def call(conn, opts) do
    level = Keyword.get(opts, :log, :info)
    start = :os.timestamp()

    Conn.register_before_send(conn, fn conn ->
      :ok = log(conn, level, start, opts)
      conn
    end)
  end

  @spec log(Plug.Conn.t(), atom(), time(), opts) :: atom() | no_return()
  def log(conn, level, start, opts \\ [])
  def log(conn, :error, start, opts), do: log(conn, :info, start, opts)
  def log(conn, :info, start, opts) do
    _ = Logger.log :info, fn ->
      conn
      |> basic_logging(start)
      |> Map.merge(phoenix_attributes(conn))
      |> Map.merge(extra_attributes(conn, opts))
      |> Poison.encode!
    end
  end
  def log(conn, :warn, start, opts), do: log(conn, :debug, start, opts)
  def log(conn, :debug, start, opts) do
    _ = Logger.log :info, fn ->
      conn
      |> basic_logging(start)
      |> Map.merge(debug_logging(conn))
      |> Map.merge(phoenix_attributes(conn))
      |> Map.merge(extra_attributes(conn, opts))
      |> Poison.encode!
    end
  end

  @spec log_error(atom(), map(), list()) :: atom()
  def log_error(kind, reason, stacktrace) do
    _ = Logger.log :error, fn ->
      %{
        "log_type"    => "error",
        "message"     => Exception.format(kind, reason, stacktrace),
        "request_id"  => Logger.metadata[:request_id],
      }
      |> Poison.encode!
    end
  end

  defp basic_logging(conn, start) do
    stop        = :os.timestamp()
    duration    = :timer.now_diff(stop, start)
    req_id      = Logger.metadata[:request_id]
    req_headers = format_map_list(conn.req_headers)

    %{
      "api_version"     => Map.get(req_headers, "accept", "N/A"),
      "date_time"       => iso8601(:calendar.now_to_datetime(:os.timestamp)),
      "duration"        => Float.round(duration / 1000, 3),
      "log_type"        => "http",
      "method"          => conn.method,
      "path"            => conn.request_path,
      "request_id"      => req_id,
      "status"          => conn.status
    }
  end

  defp extra_attributes(conn, opts) do
    paths = Keyword.get(opts, :extra_paths, [])
    Enum.reduce(paths, %{}, fn {key, path}, acc ->
      {map, path} =
        case path do
          [:assigns | tail] -> {conn.assigns, tail}
          [:private | tail] -> {conn.private, tail}
          _ -> {%{}, []}
        end
      case get_in(map, path) do
        nil -> acc
        val -> Map.put(acc, key, val)
      end
    end)
  end

  @spec client_version(%{String.t() => String.t()}) :: String.t()
  defp client_version(headers) do
    headers
    |> Map.get("x-client-version", "N/A")
    |> case do
      "N/A" ->
        Map.get(headers, "user-agent", "N/A")
      accept_value ->
        accept_value
    end
  end

  defp debug_logging(conn) do
    req_headers = format_map_list(conn.req_headers)
    req_params  = format_map_list(conn.params)

    %{
      "client_ip"       => format_ip(Map.get(req_headers, "x-forwarded-for", "N/A")),
      "client_version"  => client_version(req_headers),
      "params"          => req_params,
    }
  end

  @spec filter_values({String.t(), String.t()}) :: map()
  defp filter_values({k,v}) do
    filtered_keys = Application.get_env(:plug_logger_json, :filtered_keys, [])
    if Enum.member?(filtered_keys, k) do
      %{k => "[FILTERED]"}
    else
      %{k => format_value(v)}
    end
  end

  @spec format_ip(String.t()) :: String.t()
  defp format_ip("N/A") do
    "N/A"
  end
  defp format_ip(x_forwarded_for) do
    hd(String.split(x_forwarded_for, ", "))
  end

  @spec format_map_list([%{String.t() => String.t()}]) :: map()
  defp format_map_list(list) do
    list
    |> Enum.take(20)
    |> Enum.map(&filter_values/1)
    |> Enum.reduce(%{}, &(Map.merge(&2, &1)))
  end

  defp format_value(value) when is_binary(value) do
    String.slice(value, 0..500)
  end

  defp format_value(value) do
    value
  end

  defp iso8601({{year, month, day}, {hour, minute, second}}) do
    zero_pad(year, 4) <> "-" <> zero_pad(month, 2) <> "-" <> zero_pad(day, 2) <> "T" <>
    zero_pad(hour, 2) <> ":" <> zero_pad(minute, 2) <> ":" <> zero_pad(second, 2) <> "Z"
  end

  @spec phoenix_attributes(map()) :: map()
  defp phoenix_attributes(%{private: %{phoenix_controller: controller, phoenix_action: action}}) do
    %{"handler" => "#{controller}##{action}"}
  end
  defp phoenix_attributes(_) do
    %{"handler" => "N/A"}
  end

  @spec zero_pad(1..3_000, non_neg_integer()) :: String.t()
  defp zero_pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end
end
