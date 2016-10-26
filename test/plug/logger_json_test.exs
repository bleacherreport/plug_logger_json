defmodule Plug.LoggerJSONTest do
  use ExUnit.Case
  use Plug.Test

  import ExUnit.CaptureIO
  require Logger

  defmodule MyPlug do
    use Plug.Builder

    plug Plug.LoggerJSON
    plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defp call(conn) do
    get_log fn -> MyPlug.call(conn, []) end
  end

  defp get_log(func) do
    data = capture_io(:user, fn ->
      Process.put(:get_log, func.())
      Logger.flush()
    end)

  {Process.get(:get_log), data}
  end


  test "correct output - no params or headers" do
    {_conn, message} = conn(:get, "/")
                        |> call
    message = String.replace(message, "\e[22m", "")
    message = String.replace(message, "\n\e[0m", "")
    map     = Poison.decode! message

    assert map["api_version"] == "N/A"
    assert map["client_ip"] == "N/A"
    assert map["client_version"] == "N/A"
    assert map["date_time"]
    assert map["duration"]
    assert map["fastly_duration"] == -1
    assert map["handler"] == "N/A"
    assert map["log_type"] == "http"
    assert map["method"] == "GET"
    assert map["params"] == %{}
    assert map["path"] == "/"
    assert map["request_id"] == nil
    assert map["status"] == "200"
  end

  test "correct output - params and headers" do
    {_conn, message} = conn(:get, "/", fake_param: "1")
                        |> put_req_header("authorization", "f3443890-6683-4a25-8094-f23cf10b72d0")
                        |> put_req_header("content-type", "application/json")
                        |> call
    message = String.replace(message, "\e[22m", "")
    message = String.replace(message, "\n\e[0m", "")
    map     = Poison.decode! message

    assert map["api_version"] == "N/A"
    assert map["client_ip"] == "N/A"
    assert map["client_version"] == "N/A"
    assert map["date_time"]
    assert map["duration"]
    assert map["fastly_duration"] == -1
    assert map["handler"] == "N/A"
    assert map["log_type"] == "http"
    assert map["method"] == "GET"
    assert map["params"] == %{"fake_param" => "1"}
    assert map["path"] == "/"
    assert map["request_id"] == nil
    assert map["status"] == "200"
  end

  test "correct output - Phoenix" do
    {_conn, message} = conn(:get, "/")
                        |> put_private(:phoenix_controller, Plug.LoggerJSONTest)
                        |> put_private(:phoenix_action, :show)
                        |> put_private(:phoenix_format, "json")
                        |> call
    message = String.replace(message, "\e[22m", "")
    message = String.replace(message, "\n\e[0m", "")
    map     = Poison.decode! message

    assert map["api_version"] == "N/A"
    assert map["client_ip"] == "N/A"
    assert map["client_version"] == "N/A"
    assert map["date_time"]
    assert map["duration"]
    assert map["fastly_duration"] == -1
    assert map["handler"] == "Elixir.Plug.LoggerJSONTest#show"
    assert map["log_type"] == "http"
    assert map["method"] == "GET"
    assert map["params"] == %{}
    assert map["path"] == "/"
    assert map["request_id"] == nil
    assert map["status"] == "200"
  end

  test "correct output - Post request JSON" do
    json = %{"reaction" => %{
      "reaction" => "other",
      "track_id" => "7550",
      "type"     => "emoji",
      "user_id"  => "a2e684ee-2e5f-4e4d-879a-bb253908eef3"
    }}
    |> Poison.encode!

    {_conn, message} = conn(:post, "/", json)
  |> put_req_header("content-type", "application/json")
  |> call
    message = String.replace(message, "\e[22m", "")
    message = String.replace(message, "\n\e[0m", "")
    map     = Poison.decode! message

    assert map["api_version"] == "N/A"
    assert map["client_ip"] == "N/A"
    assert map["client_version"] == "N/A"
    assert map["date_time"]
    assert map["duration"]
    assert map["fastly_duration"] == -1
    assert map["handler"] == "N/A"
    assert map["log_type"] == "http"
    assert map["method"] == "POST"
    assert map["params"] == %{"reaction" => %{
      "reaction" => "other",
      "track_id" => "7550",
      "type"     => "emoji",
      "user_id"  => "a2e684ee-2e5f-4e4d-879a-bb253908eef3"
    }}
    assert map["path"] == "/"
    assert map["request_id"] == nil
    assert map["status"] == "200"
  end

  test "correct output - X-forwarded-for header" do
    {_conn, message} = conn(:get, "/")
                        |> put_req_header("x-forwarded-for", "209.49.75.165")
                        |> put_private(:phoenix_controller, Plug.LoggerJSONTest)
                        |> put_private(:phoenix_action, :show)
                        |> put_private(:phoenix_format, "json")
                        |> call
    message = String.replace(message, "\e[22m", "")
    message = String.replace(message, "\n\e[0m", "")
    map     = Poison.decode! message

    assert map["api_version"] == "N/A"
    assert map["client_ip"] == "209.49.75.165"
    assert map["client_version"] == "N/A"
    assert map["date_time"]
    assert map["duration"]
    assert map["fastly_duration"] == -1
    assert map["handler"] == "Elixir.Plug.LoggerJSONTest#show"
    assert map["log_type"] == "http"
    assert map["method"] == "GET"
    assert map["params"] == %{}
    assert map["path"] == "/"
    assert map["request_id"] == nil
    assert map["status"] == "200"
  end

  test "correct output - client version header" do
    {_conn, message} = conn(:get, "/")
                        |> put_req_header("x-client-version", "ios/1.5.4")
                        |> call
    message = String.replace(message, "\e[22m", "")
    message = String.replace(message, "\n\e[0m", "")
    map     = Poison.decode! message

    assert map["client_version"] == "ios/1.5.4"
  end

  describe "fastly x-timer header" do
    test "cached, outputs fastly duration correctly" do
      {_conn, message} = conn(:get, "/")
                          |> put_req_header("x-timer", "S1470085542.060224,VS0,VE10")
                          |> call
      message  = String.replace(message, "\e[22m", "")
      message  = String.replace(message, "\n\e[0m", "")
      map      = Poison.decode! message

      assert map["fastly_duration"] == 10
    end

    test "cache miss, outputs fastly duration correctly" do
      {_conn, message} = conn(:get, "/")
                          |> put_req_header("x-timer", "S1470085542.060224,VS0,VS0")
                          |> call

      message = String.replace(message, "\e[22m", "")
      message = String.replace(message, "\n\e[0m", "")
      map     = Poison.decode! message

      assert map["fastly_duration"] == 0
    end
  end

  describe "500 error" do
    test "logs the error" do
      stacktrace = [{MyPlug, :index, 2,
        [file: 'web/controllers/reaction_controller.ex', line: 53]},
       {MyPlug, :action, 2,
        [file: 'web/controllers/reaction_controller.ex', line: 1]},
       {MyPlug, :phoenix_controller_pipeline, 2,
        [file: 'web/controllers/reaction_controller.ex', line: 1]},
       {MyPlug, :instrument, 4,
        [file: 'lib/reactions/endpoint.ex', line: 1]},
       {MyPlug, :dispatch, 2, [file: 'lib/phoenix/router.ex', line: 261]},
       {MyPlug, :do_call, 2, [file: 'web/router.ex', line: 1]},
       {MyPlug, :call, 2, [file: 'lib/plug/error_handler.ex', line: 64]},
       {MyPlug, :phoenix_pipeline, 1,
        [file: 'lib/reactions/endpoint.ex', line: 1]},
       {MyPlug, :call, 2, [file: 'lib/reactions/endpoint.ex', line: 1]},
       {Plug.Adapters.Cowboy.Handler, :upgrade, 4,
        [file: 'lib/plug/adapters/cowboy/handler.ex', line: 15]},
       {:cowboy_protocol, :execute, 4, [file: 'src/cowboy_protocol.erl', line: 442]}]

      {_conn, _} = conn(:get, "/")
                  |> call

      {_, message} = get_log(fn -> Plug.LoggerJSON.log_error(:error, %RuntimeError{message: "ERROR"}, stacktrace) end)

      message = String.replace(message, "\e[31m", "")
      message = String.replace(message, "\e[22m", "")
      message = String.replace(message, "\n\e[0m", "")
      message = String.replace(message, "{\"requ", "{\"requ")
      error_log = Poison.decode! message

      assert error_log["log_type"] == "error"
      assert error_log["message"] == "** (RuntimeError) ERROR\n    web/controllers/reaction_controller.ex:53: Plug.LoggerJSONTest.MyPlug.index/2\n    web/controllers/reaction_controller.ex:1: Plug.LoggerJSONTest.MyPlug.action/2\n    web/controllers/reaction_controller.ex:1: Plug.LoggerJSONTest.MyPlug.phoenix_controller_pipeline/2\n    lib/reactions/endpoint.ex:1: Plug.LoggerJSONTest.MyPlug.instrument/4\n    lib/phoenix/router.ex:261: Plug.LoggerJSONTest.MyPlug.dispatch/2\n    web/router.ex:1: Plug.LoggerJSONTest.MyPlug.do_call/2\n    lib/plug/error_handler.ex:64: Plug.LoggerJSONTest.MyPlug.call/2\n    lib/reactions/endpoint.ex:1: Plug.LoggerJSONTest.MyPlug.phoenix_pipeline/1\n    lib/reactions/endpoint.ex:1: Plug.LoggerJSONTest.MyPlug.call/2\n    lib/plug/adapters/cowboy/handler.ex:15: Plug.Adapters.Cowboy.Handler.upgrade/4\n    src/cowboy_protocol.erl:442: :cowboy_protocol.execute/4\n"
      assert error_log["request_id"] ==  nil
    end
  end
end
