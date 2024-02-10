# Harness

This is a minimal Elixir Phoenix web application that only exists to host a Machine Learning model on a Fly.io Machine with an attached GPU. The purpose is to make the model and GPU accessible to a separate Elixir application that is clustered with this app. In this way, this app is just a harness for the following:

- Fetching the ML model (from HuggingFace)
- Caching the downloaded model on a volume attached to the machine
- Hosting the model through [Bumblebee](https://github.com/elixir-nx/bumblebee) in an [Nx.Serving](https://hexdocs.pm/nx/Nx.Serving.html), making it easy for Elixir to communicate with.

## What's the advantage?

For a more detailed look at the advantages of doing this, please refer to [this article](!!!!).

In short, it's for the following reasons:

- keep the benefits of rapid, local development
- get access to large models, machines and GPUs
- shut down large, expensive machines when not in use
- enables developing customized ML/AI code without compromising on the dev tooling or speed of development
- bragging rights

## Deploy this for yourself

- Download the project
- Follow the [Fly.io GPUs Quickstart](https://fly.io/docs/gpus/gpu-quickstart/) and refer to [Getting Started with Fly GPUs](https://fly.io/docs/gpus/getting-started-gpus/)
  - Your Fly.io organization needs to be GPU enabled
- `fly apps create --generate-name --org your-org-with-gpus` or provide the name you want with `--name my-desired-name`
- Copy the new name to the `fly.toml` file in `app` and `PHX_HOST`
- Change the `RELEASE_COOKIE` value as desired. The value must match for the client application.
- Deploy to the desired region: `fly deploy --region desired-region`. Ensure the region has the desired GPUs.
- Set the `SECRET_KEY_BASE`
```
$ mix phx.gen.secret
randomlyGeneratedText

$ fly secrets set SECRET_KEY_BASE=randomlyGeneratedText
```
- `fly apps open` or `fly logs`

Optional updates:

The `fly.toml` file has the `auto_stop_machines = false` setting. This is helpful when getting started so the machine doesn't get shutdown while the model is being downloaded. Once the machine is setup, feel free to playing with this value to determine what works best for your needs.

The VM size is set setting is `size = "a100-40gb"`. This ensures the machine we get has the NVidia A100 GPU.


## Troubleshooting and diagnosis tips

To test and verify that you've successfully deployed the application to a
machine with GPU access and that your application has all the necessary support
for taking advantage of the GPU, do the following:

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

Before the Nx serving can be activated, the model must be downloaded fully, loaded
into RAM, then moved to the GPU. Once complete, the serving is available for
making calls against.

The attached volume caches the download so the local files are used the next
time the harness application is started, skipping the lengthy download step.

## Getting the server node name

There are several ways to get the server node name. See [the article](with-link-to-part) for details.
