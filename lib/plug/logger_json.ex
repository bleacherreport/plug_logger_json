defmodule Plug.LoggerJSON do
  @moduledoc """
  A plug for logging basic request information in the format:
  ```json
  {
    "status":"200",
    "state":"Sent",
    "server":"localhost",
    "request_id":"d90jcl66vp09r8tke3utjsd1pjrg4ln8",
    "req_headers":{
      "x-client-version":"android/1.0.0",
      "x-api-version":"1",
      "user-agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_3)",
      "postman-token":"71d00d96-f9c4-edf4-3b8e-ac7bcf3ca33b",
      "origin":"file://","host":"localhost:4000",
      "content-type":"application/json",
      "content-length":"50",
      "connection":"keep-alive",
      "cache-control":"no-cache",
      "authorization":"[FILTERED]",
      "accept-language":"en-US",
      "accept-encoding":"gzip,
      deflate","accept":"*/*"
    },
    "remote_ip":"127.0.0.1",
    "path":"/",
    "params":{
      "user":"jkelly",
      "password":"[FILTERED]"
    },
    "method":"POST",
    "level":"info",
    "format":"N/A",
    "environment":"development",
    "duration":"0.670",
    "date_time":"2016-05-31T18:00:13Z",
    "controller":"N/A",
    "client_version":"N/A",
    "app":"reaction",
    "api_version":"N/A",
    "action":"N/A"
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

  def call(conn, level) do
    start = :os.timestamp()

    Conn.register_before_send(conn, fn conn ->
      :ok = log(conn, level, start)
      conn
    end)
  end

  def log(conn, level, start) do
    Logger.log level, fn ->
      stop        = :os.timestamp()
      duration    = diff_times(start, stop)
      req_id      = Logger.metadata[:request_id]
      req_headers = format_map_list(conn.req_headers)
      req_params  = format_map_list(conn.params)

      %{
        state: connection_type(conn),
        status:         Integer.to_string(conn.status),
        request_id:     req_id,
        path:           conn.request_path,
        params:         req_params,
        req_headers:    req_headers,
        server:         Application.get_env(:plug_logger_json, :server, "N/A"),
        remote_ip:      format_ip(conn.remote_ip),
        method:         conn.method,
        level:          level,
        environment:    Application.get_env(:plug_logger_json, :environment, "N/A"),
        duration:       format_duration(duration),
        date_time:      iso8601(:calendar.now_to_datetime(:os.timestamp)),
        client_version: Map.get(req_headers, "client_version", "N/A"),
        app:            Application.get_env(:plug_logger_json, :app, "N/A"),
        api_version:    Map.get(req_headers, "api_version", "N/A")
      }
      |> Map.merge(phoenix_attributes(conn))
      |> Poison.encode!
    end
  end

  defp connection_type(%{state: :chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"

  defp diff_times(start, stop), do: :timer.now_diff(stop, start)

  defp filter_values({k,v}) do
    filtered_keys = Application.get_env(:plug_logger_json, :filtered_keys, [])
    if Enum.member?(filtered_keys, k) do
      %{k => "[FILTERED]"}
    else
      %{k => v}
    end
  end

  defp format_duration(duration) do
    Float.to_string(duration / 1000, decimals: 3)
  end

  defp format_ip({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end

  defp format_map_list(list) do
    list
    |> Enum.map(&filter_values/1)
    |> Enum.reduce(%{}, &(Map.merge(&2, &1)))
  end

  defp iso8601({{year, month, day}, {hour, minute, second}}) do
    zero_pad(year, 4) <> "-" <> zero_pad(month, 2) <> "-" <> zero_pad(day, 2) <> "T" <>
    zero_pad(hour, 2) <> ":" <> zero_pad(minute, 2) <> ":" <> zero_pad(second, 2) <> "Z"
  end

  @spec phoenix_attributes(Plug.Conn.t) :: map
  defp phoenix_attributes(%{private: %{phoenix_format: format, phoenix_controller: controller, phoenix_action: action}}) do
    %{format: format, controller: controller, action: action}
  end
  defp phoenix_attributes(_) do
    %{format: "N/A", controller: "N/A", action: "N/A"}
  end

  defp zero_pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end
end
