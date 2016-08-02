defmodule Plug.LoggerJSON do
  @moduledoc """
  A plug for logging basic request information in the format:
  ```json
  {
    "api_version":     "N/A"
    "client_ip":       "23.235.46.37"
    "client_version":  "ios/1.6.7",
    "date_time":       "2016-05-31T18:00:13Z",
    "duration":        4.670,
    "fastly_duration": 2.670,
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
  """

  require Logger
  alias Plug.Conn
  @behaviour Plug

  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  @spec call(Plug.Conn.t, atom) :: Plug.Conn.t
  def call(conn, level) do
    start = :os.timestamp()

    Conn.register_before_send(conn, fn conn ->
      :ok = log(conn, level, start)
      conn
    end)
  end

  @spec log(Plug.Conn.t, atom, {non_neg_integer, non_neg_integer, non_neg_integer}) :: atom
  def log(conn, level, start) do
    Logger.log level, fn ->
      stop        = :os.timestamp()
      duration    = :timer.now_diff(stop, start)
      req_id      = Logger.metadata[:request_id]
      req_headers = format_map_list(conn.req_headers)
      req_params  = format_map_list(conn.params)

      %{
        "api_version"     => Map.get(req_headers, "accept", "N/A"),
        "client_ip"       => format_ip(Map.get(req_headers, "x-forwarded-for", "N/A")),
        "client_version"  => client_version(req_headers),
        "date_time"       => iso8601(:calendar.now_to_datetime(:os.timestamp)),
        "duration"        => Float.round(duration / 1000, 3),
        "fastly_duration" => fastly_duration(req_headers),
        "log_type"        => "http",
        "method"          => conn.method,
        "params"          => req_params,
        "path"            => conn.request_path,
        "request_id"      => req_id,
        "status"          => Integer.to_string(conn.status)
      }
      |> Map.merge(phoenix_attributes(conn))
      |> Poison.encode!
    end
  end

  @spec client_version(%{String.t => String.t}) :: String.t
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

  @spec fastly_duration(%{String.t => String.t}) :: integer
  defp fastly_duration(headers) do
    x_timer = Map.get(headers, "x-timer", "")
    case String.split(x_timer, ",") do
      [_, "VS" <> start, "VE" <> stop] ->
        String.to_integer(stop) - String.to_integer(start)
      [_, "VS" <> _, "VS" <> _] ->
        0
      _ ->
        -1
    end
  end

  @spec filter_values({String.t, String.t}) :: map
  defp filter_values({k,v}) do
    filtered_keys = Application.get_env(:plug_logger_json, :filtered_keys, [])
    if Enum.member?(filtered_keys, k) do
      %{k => "[FILTERED]"}
    else
      %{k => format_value(v)}
    end
  end

  @spec format_ip(String.t) :: String.t
  defp format_ip("N/A") do
    "N/A"
  end
  defp format_ip(x_forwarded_for) do
    hd(String.split(x_forwarded_for, ", "))
  end

  @spec format_map_list([%{String.t => String.t}]) :: map
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

  @spec phoenix_attributes(Plug.Conn.t) :: map
  defp phoenix_attributes(%{private: %{phoenix_controller: controller, phoenix_action: action}}) do
    %{"handler" => "#{controller}##{action}"}
  end
  defp phoenix_attributes(_) do
    %{"handler" => "N/A"}
  end

  @spec zero_pad(1..3_000, non_neg_integer) :: String.t
  defp zero_pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end
end
