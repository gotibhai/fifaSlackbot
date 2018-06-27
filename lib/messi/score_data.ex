defmodule Messi.ScoreData do
  require Logger
  @expected_fields ~w(home_team away_team home_team_events away_team_events)
  @timeout 10000

  defstruct last_event: 0, new_events: [], home_team: "", away_team: ""

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
    body = body
      |> Poison.decode!
      |> List.first
    case body do
      nil -> nil
      _   ->  Map.take(body, @expected_fields)
    end
  end

  def handle_call(:getData, _from,  %__MODULE__{
    last_event: last_event, new_events: new_events,
    home_team: home_team, away_team: away_team
   } = state) do
    case data = fetchData() |> process_response_body do
      nil -> {:reply, [], state}
      _ -> IO.inspect "Match is going on :D"
          home_team = data["home_team"]["country"]
          away_team = data["away_team"]["country"]
          all_new_events = data["away_team_events"] ++ data["home_team_events"]
          state = state
          |> Map.put(:new_events, all_new_events)
          |> Map.put(:home_team, home_team)
          |> Map.put(:away_team, away_team)
          {:reply, all_new_events, state}
    end

  end

  def getData() do
    GenServer.call(ScoreData, :getData)
  end

  def updateEvents() do
    GenServer.call(ScoreData, :updateEvents, @timeout)
  end

  def handle_call(:updateEvents, _from,
    %__MODULE__{ last_event: last_event, new_events: new_events,
    home_team: home_team, away_team: away_team
    } = state) do
    new_filtered_events = get_new_events(last_event, new_events)
    send_notifications(new_filtered_events)
    last_event = get_last_event(last_event, new_filtered_events)
    state = state
    |> Map.put(:new_events, new_filtered_events)
    |> Map.put(:last_event, last_event)
    {:reply, last_event, state}
  end

  def send_notifications(events) do
    Enum.each(events, fn(x) -> process_event(x) end)
  end

  def process_event(event) do
    case event["type_of_event"] do
      "substitution-in" -> postData("#{event["player"]} substituted in")
      "substitution-out" -> postData("#{event["player"]} substituted out")
      "yellow-card" -> postData("#{event["player"]} got a yellow card")
      "red-card" -> postData("#{event["player"]} got a red card")
      "goal-penalty" -> postData("#{event["player"]} scored a penalty!")
      "goal" -> postData("#{event["player"]} SCORED #{event["time"]} minute")
      _ -> IO.inspect "Haven't handled #{event["type_of_event"]} yet!"
    end
  end

  def get_new_events(last_event, new_events) do
    new_filtered_events = new_events
      |> Enum.filter(fn(x) -> is_map(x) and x["id"] > last_event end)
  end

  def get_last_event(last_event, new_filtered_events) do
    max_new_event = new_filtered_events
      |> Enum.map(fn(x) -> x["id"] end)
      |> IO.inspect
      |> Enum.max(fn -> 0 end)
    Enum.max([last_event, max_new_event])
  end

  def updateState() do
    getData()
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
     last_event: 0,
     new_events: [],
     home_team: "",
     away_team: ""
    }
    {:ok, state}
  end
end
