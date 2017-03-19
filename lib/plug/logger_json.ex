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
  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  @spec call(Plug.Conn.t(), opts) :: Plug.Conn.t()
  def call(conn, level) do
    start = :os.timestamp()

    Conn.register_before_send(conn, fn conn ->
      :ok = log(conn, level, start)
      conn
    end)
  end

  @spec log(Plug.Conn.t(), atom(), time()) :: atom() | no_return()
  def log(conn, :error, start), do: log(conn, :info, start)
  def log(conn, :info, start) do
    _ = Logger.log :info, fn ->
      conn
      |> basic_logging(start)
      |> Map.merge(phoenix_attributes(conn))
      |> Poison.encode!
    end
  end
  def log(conn, :warn, start), do: log(conn, :debug, start)
  def log(conn, :debug, start) do
    _ = Logger.log :info, fn ->
      conn
      |> basic_logging(start)
      |> Map.merge(debug_logging(conn))
      |> Map.merge(phoenix_attributes(conn))
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
