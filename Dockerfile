# Based on:
#
# - https://hub.docker.com/r/hexpm/elixir/tags
# - https://hub.docker.com/r/nvidia/cuda/tags
# - https://github.com/livebook-dev/livebook/blob/main/docker/base/elixir-cuda.dockerfile
# - https://wiki.ubuntu.com/Releases

ARG UBUNTU_VERSION=22.04
ARG UBUNTU_NAMED_VERSION=jammy-20240227
ARG CUDA_VERSION=12.4.1
ARG ELIXIR_VERSION=1.16.2
ARG ERLANG_VERSION=26.2.4

# Target the CUDA build image
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
# NOTE: TRYING TO GET IT WORKING. DON'T KEEP "devel" VERSION FOR RUNTIME?
ARG BASE_CUDA_RUNTIME_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-ubuntu-${UBUNTU_NAMED_VERSION} AS elixir

FROM ${BASE_CUDA_DEV_CONTAINER} as builder

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get install -y build-essential git git curl wget cmake openssl libncurses5 locales && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Elixir: We copy the top-level directory first to preserve symlinks in /usr/local/bin
COPY --from=elixir /usr/local /usr/ELIXIR_LOCAL

RUN cp -r /usr/ELIXIR_LOCAL/lib/* /usr/local/lib && \
  cp -r /usr/ELIXIR_LOCAL/bin/* /usr/local/bin && \
  rm -rf /usr/ELIXIR_LOCAL

# prepare build dir
WORKDIR /app

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"
# bumblebee - XLA_TARGET must exist before deps pulled
ENV XLA_TARGET="cuda120"
ENV BUMBLEBEE_CACHE_DIR="/data/cache/bumblebee"
ENV XLA_CACHE_DIR="/data/cache/xla"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${BASE_CUDA_RUNTIME_CONTAINER}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

# set runner ENV
ENV MIX_ENV="prod"

# Bumblebee
ENV XLA_TARGET="cuda120"
ENV BUMBLEBEE_CACHE_DIR="/data/cache/bumblebee"
ENV XLA_CACHE_DIR="/data/cache/xla"

ENV ECTO_IPV6 true
ENV ERL_AFLAGS "-proto_dist inet6_tcp"

# Only copy the final release from the build stage
COPY --from=builder /app/_build/${MIX_ENV}/rel/harness ./

CMD ["/app/bin/server"]
