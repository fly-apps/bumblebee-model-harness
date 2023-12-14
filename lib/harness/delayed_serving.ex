defmodule Harness.DelayedServing do
  @moduledoc """
  Start the Nx serving, but it happens async so the application can boot up and
  be "healthy".
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = %{
      serving: nil,
      serving_fn: Keyword.fetch!(opts, :serving_fn),
      serving_name: Keyword.fetch!(opts, :serving_name)
    }

    # trigger the async callback after GenServer start
    {:ok, state, {:continue, :load_serving}}
  end

  # callback to load the serving
  def handle_continue(:load_serving, state) do
    if has_gpu_access?() do
      Logger.info("Elixir has cuda GPU access! Starting serving.")
      serving = state.serving_fn.()
      # start the serving as a linked process so it if crashes, this GenServer
      # crashes then it will all get started up again.
      Nx.Serving.start_link(name: state.serving_name, serving: serving)
      {:noreply, Map.put(state, :serving, serving)}
    else
      Logger.warning("Elixir does not have GPU access. Serving will NOT be started.")
      {:noreply, state}
    end
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
