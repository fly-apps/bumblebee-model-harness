# Harness

See the accompanying blog post [Easy at-home AI with Bumblebee and Fly GPUs](https://fly.io/phoenix-files/clustering-elixir-from-laptop-to-cloud/)

This is a minimal Elixir Phoenix web application that only exists to host a pre-trained Machine Learning model on a Fly.io machine with an attached GPU. The purpose is to make the model and GPU accessible to a separate Elixir application that is clustered with this app. In this way, this app is just a harness for the following:

- Fetching the ML model (from HuggingFace)
- Caching the downloaded model on a volume attached to the machine
- Hosting the model through [Bumblebee](https://github.com/elixir-nx/bumblebee) in an [Nx.Serving](https://hexdocs.pm/nx/Nx.Serving.html), making it easy for Elixir to communicate with.

## What's the advantage?

For a more detailed look at the advantages of doing this, please refer to [this article](https://fly.io/phoenix-files/clustering-elixir-from-laptop-to-cloud/).

In short, it's for the following reasons:

- keep the benefits of rapid, local development
- get access to large models, machines and GPUs
- shut down machines when not in use
- enables developing customized ML/AI code without compromising on the dev tooling or speed of development
- bragging rights

## Deploy this for yourself

- Follow the [Fly.io GPUs Quickstart](https://fly.io/docs/gpus/gpu-quickstart/) and refer to [Getting Started with Fly GPUs](https://fly.io/docs/gpus/getting-started-gpus/)
- Clone this project
- Change the app name in `fly.toml` to one you like
- `fly launch` and say "yes" to copy the config.

This builds the Dockerfile image, deploys it, and starts the selected serving. For me, the process of starting the serving for a new Llama 2 model took about 4 minutes to download and start.

Track the logs if you like:

```
fly logs
```

**Optional updates:**

The `fly.toml` file has the `auto_stop_machines = false` setting. This is helpful when getting started so the machine doesn't get shutdown while the model is being downloaded. Once the machine is setup, feel free to change this value if that works best for your needs.

The VM size is set setting is `size = "a100-40gb"`. This ensures the machine we get has the NVidia A100 GPU.

## Selecting a ready-to-go model

Three LLMs are built-in and ready to go. Select the model to serve and enable it. Depending on the available hardware and the size of the model, hosting multiple models on the same GPU may not be practical or possible.

Select a single model to enable, deploy the harness application, and develop against it.

**Models:**

- [Llama2 7B](https://llama.meta.com/llama2/) - `Harness.Llama2Chat`
- [Zephyr 7B](https://zephyr-7b.net/) - `Harness.Zephyr`
- [Mistral 7B](https://docs.mistral.ai/) - `Harness.MistralInstruct`

To select a model, uncomment it in `lib/harness/application.ex` and comment out the unused ones. This selects which serving to create and start. The following is an example of serving the Llama 2 model.

```elixir
{Harness.DelayedServing,
  serving_name: Llama2ChatModel,
  serving_fn: fn -> Harness.Llama2Chat.serving() end},
```

In this example, the `serving_name` of `Llama2ChatModel` is the name of the serving to address in the client application. Name it whatever you like! It is the name used in the client when calling using the serving. In the client, it looks like this:

```elixir
Nx.Serving.batched_run(Llama2ChatModel, "Say hello.")
```

The harness application uses a `DelayedServing` helper to start the model. Downloading and loading a large model takes time. It happens in the application startup process, which if done synchronously, makes the application unresponsive to health check. Fly will kill the app thinking it's unresponsive... which it is.

The `DelayedServing` makes the loading asynchronous so the application starts quickly and is responsive while the larger loading task continues.

## Troubleshooting and diagnosis tips

To test and verify that you've successfully deployed the application to a
machine with GPU access and that your application has all the necessary support
for taking advantage of the GPU, do the following:

```
$ fly ssh console
nvidia-smi
```

If the required NVidia libraries and hardware are in place, then the `nvidia-smi` tool should output a table with the information like this:

```
+---------------------------------------------------------------------------------------+
| NVIDIA-SMI 545.23.08              Driver Version: 545.23.08    CUDA Version: 12.3     |
|-----------------------------------------+----------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |         Memory-Usage | GPU-Util  Compute M. |
|                                         |                      |               MIG M. |
|=========================================+======================+======================|
|   0  NVIDIA A100-PCIE-40GB          Off | 00000000:00:06.0 Off |                   On |
| N/A   38C    P0              39W / 250W |      0MiB / 40960MiB |     N/A      Default |
|                                         |                      |              Enabled |
+-----------------------------------------+----------------------+----------------------+

+---------------------------------------------------------------------------------------+
| MIG devices:                                                                          |
+------------------+--------------------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |                   Memory-Usage |        Vol|      Shared           |
|      ID  ID  Dev |                     BAR1-Usage | SM     Unc| CE ENC DEC OFA JPG    |
|                  |                                |        ECC|                       |
|==================+================================+===========+=======================|
|  No MIG devices found                                                                 |
+---------------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------------+
| Processes:                                                                            |
|  GPU   GI   CI        PID   Type   Process name                            GPU Memory |
|        ID   ID                                                             Usage      |
|=======================================================================================|
|  No running processes found                                                           |
+---------------------------------------------------------------------------------------+
```

The next layer to test is that Elixir has access to the GPU. For that, run the following:

```
$ fly ssh console
# bin/harness remote
iex> Harness.DelayedServing.has_gpu_access?()
true
```

If you get a `true` response, then the machine, and your Elixir application both
have access to the GPU.

Additionally, the harness app's logs report on successful GPU access or not for
the Elixir application.

Logged messages:
- **info** - "Elixir has CUDA GPU access! Starting serving #{serving_name}."
- **warning** - "Elixir does not have GPU access. Serving will NOT be started."

## Waiting for first-time model downloads

Depending on the model being used, it may be many GB in size and take
several minutes to download.

If the Fly.io volume is setup correctly and available to the machine, the files
are downloaded to `/data/cache/bumblebee/huggingface/`.

Before the Nx serving can be activated, the model must be fully downloaded, loaded into RAM, then moved to the GPU. Once complete, the serving is available for making calls against.

The attached volume caches the download so the local files are used the next time the harness application is started, skipping the lengthy download step.

## Clustering your local app to the harness app on Fly.io

This documentation walks through the process: [Easy Clustering from Home to Fly.io](https://fly.io/docs/elixir/advanced-guides/clustering-from-home-to-your-app-in-fly/)
