defmodule Messi.Poll do
  use Task
  alias Messi.ScoreData

  def start_link(_arg \\ []) do
    Task.start_link(&poll/0)
  end

  def poll() do
    receive do
    after
      30_000 ->
        #ScoreData.fetchData()
        printData()
        poll()
    end
  end

  def printData() do
    IO.inspect "Hello..."
  end
end
