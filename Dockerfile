# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20230227-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.14.3-erlang-25.3-debian-bullseye-20230227-slim
#
ARG ELIXIR_VERSION=1.15.7
ARG OTP_VERSION=26.1.2
ARG DEBIAN_VERSION=bullseye-20230612-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl wget \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Add the repository for the Nvidia CUDA
# Import the Nvidia repository GPG key
RUN apt update -q && apt install -y ca-certificates wget && \
    wget -qO /cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i /cuda-keyring.deb && apt update -q


# Install nvidia GPU support
RUN apt-get install -y cuda-nvcc-12-2 libcublas-12-2 libcudnn8

# prepare build dir
WORKDIR /app

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
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Nvidia stuff
RUN apt update -q && apt install -y ca-certificates wget && \
    wget -qO /cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i /cuda-keyring.deb && apt update -q


# Nvidia support in runtime layer
RUN apt-get install -y --no-install-recommends cuda-nvcc-12-2 libcublas-12-2 libcudnn8
# Copy over needed nvidia support
# COPY --from=builder /usr/local/bin/deviceQuery /usr/local/bin/deviceQuery

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
# RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Bumblebee
ENV XLA_TARGET="cuda120"
ENV BUMBLEBEE_CACHE_DIR="/data/cache/bumblebee"
ENV XLA_CACHE_DIR="/data/cache/xla"
# NOTE: This seems to be causing a crash loop on boot.
# ENV ELIXIR_ERL_OPTIONS = "-proto_dist inet6_tcp +sssdio 128"

# Only copy the final release from the build stage
COPY --from=builder /app/_build/${MIX_ENV}/rel/harness ./

# USER nobody

CMD ["/app/bin/server"]
