defmodule Harness.DelayedServing do
  @moduledoc """
  Start the Nx serving, but it happens async so the application can boot up and
  be "healthy".

  The purpose of this GenServer is to start the `Nx.Serving` for the desired
  module. Large models can take several minutes to download and process before
  they are available to the application. This GenServer can be added to the
  Application supervision tree. It detects and logs if Elixir has CUDA access to
  the GPU. If support is available, it starts the serving and makes it available
  to the application.

  That is the sole purpose for this module. Without this delayed approach, the
  extended start-up times can result in an application being found "unhealthy",
  and killed before ever becoming active.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %{
      serving: nil,
      serving_fn: Keyword.fetch!(opts, :serving_fn),
      serving_name: Keyword.fetch!(opts, :serving_name)
    }

    # tried to use :continue and handle_continue, but loading the serving still
    # takes too long for the GenServer. Here we'll load it up in a separate
    # process.
    server = self()

    spawn(fn ->
      if has_gpu_access?() do
        Logger.info(
          "Elixir has cuda GPU access! Starting serving #{inspect(state.serving_name)}."
        )

        serving = state.serving_fn.()
        Logger.info("Serving #{inspect(state.serving_name)} started")
        send(server, {:serving_loaded, serving})
      else
        Logger.warning("Elixir does not have GPU access. Serving will NOT be started.")
      end

      :ok
    end)

    # trigger the async callback after GenServer start
    {:ok, state}
  end

  def handle_info({:serving_loaded, serving}, state) do
    # start the serving as a linked process so it if crashes, this GenServer
    # crashes then it will all get started up again.
    link = Nx.Serving.start_link(name: state.serving_name, serving: serving)
    Logger.warning("Nx.Serving.start_link  - #{inspect(link)}")
    {:noreply, Map.put(state, :serving, serving)}
  end

  @doc """
  Return if Elixir has access to the GPU or not.
  """
  @spec has_gpu_access? :: boolean()
  def has_gpu_access?() do
    try do
      case Nx.tensor(0) do
        # :host == CPU
        %Nx.Tensor{data: %EXLA.Backend{buffer: %EXLA.DeviceBuffer{client_name: :host}}} ->
          false

        # :cuda == GPU
        %Nx.Tensor{data: %EXLA.Backend{buffer: %EXLA.DeviceBuffer{client_name: :cuda}}} ->
          true

        _other ->
          false
      end
    rescue
      _exception ->
        Logger.error("Error trying to determine GPU access!")
        false
    end
  end
end
