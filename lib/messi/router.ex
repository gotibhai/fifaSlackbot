defmodule Messi.Router do
  use Plug.Router
  use Plug.Debugger, otp_app: :messi

  plug Plug.Logger
  plug Plug.Parsers,
    parsers: [:json, :urlencoded],
    json_decoder: Jason

  plug :match
  plug :dispatch

  post "/webhook" do
    IO.inspect conn.body_params
    send_resp(conn, 200, ~s({"text":"ok"}))
  end

  get "/score" do
    send_resp(conn,200, "Russia 5 : 0 Saudi Arabia")
  end

  match _ do
    send_resp(conn, 404, "not_found")
  end
end
