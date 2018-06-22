defmodule Messi.ScoreData do
  require Logger
  @expected_fields ~w(home_team away_team home_team_events away_team_events)
  @timeout 10000

  defstruct old_events: [], new_events: [], home_team: "", away_team: ""

  def fetchData() do
    case HTTPoison.get("http://worldcup.sfg.io/matches/today") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        IO.puts "Not found :("
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end

  def process_response_body(body) do
    body
      |> Poison.decode!
      |> List.first
      |> Map.take(@expected_fields)
  end

  def handle_call(:getData, _from,  %__MODULE__{
    old_events: old_events, new_events: new_events,
    home_team: home_team, away_team: away_team
   } = state) do
    data = fetchData() |> process_response_body
    home_team = data["home_team"]["country"]
    away_team = data["away_team"]["country"]
    all_new_events = data["away_team_events"] ++ data["home_team_events"]
    state = state
    |> Map.put(:new_events, all_new_events)
    |> Map.put(:home_team, home_team)
    |> Map.put(:away_team, away_team)
    IO.inspect state
    {:reply, all_new_events, state}
  end

  def getData() do
    GenServer.call(ScoreData, :getData)
  end

  def updateEvents() do
    GenServer.call(ScoreData, :updateEvents, @timeout)
  end

  def handle_call(:updateEvents, _from,
    %__MODULE__{ old_events: old_events, new_events: new_events,
    home_team: home_team, away_team: away_team
    } = state) do
    old_events = old_events ++ new_events
    state = state
    |> Map.put(:old_events, old_events)
    {:noreply, state}
  end

  def updateState() do
    getData()
    # |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
    # |> Enum.into(%{})
    updateEvents()
  end

  def postData(message) do
    uri = Application.get_env(:messi, :webhook_url)
    body = %{text: message}
    headers =  [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
    ]
    case HTTPoison.post(uri, Poison.encode!(body), headers) do
      {:ok, _response} -> ""
      {:error, response} -> IO.inspect response
    end
  end

  def start_link(__args \\ []) do
    Logger.info("Starting ScoreData ...")
    GenServer.start_link(__MODULE__, [], name: ScoreData)
  end

  def init(_args) do
    state = %__MODULE__{
     old_events: ["old"],
     new_events: ["new"],
     home_team: "",
     away_team: ""
    }
    {:ok, state}
  end
end
