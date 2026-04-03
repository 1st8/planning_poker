# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=trixie-20260223-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.19.5-erlang-26.2.5.16-debian-trixie-20260223-slim
#
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=26.2.5.16
ARG DEBIAN_VERSION=trixie-20260223-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN --mount=type=cache,target=/var/lib/apt/lists,id=apt-lists-builder \
    --mount=type=cache,target=/var/cache/apt,id=apt-cache-builder \
    apt-get update \
  && apt-get install -y --no-install-recommends build-essential git curl \
  && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get install -y nodejs

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN --mount=type=cache,target=/app/deps,id=mix-deps \
    mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN --mount=type=cache,target=/app/deps,id=mix-deps \
    --mount=type=cache,target=/app/_build,id=mix-build \
    mix deps.compile

RUN --mount=type=cache,target=/app/deps,id=mix-deps \
    --mount=type=cache,target=/app/_build,id=mix-build \
    mix assets.setup

COPY priv priv

COPY lib lib

COPY assets assets

# install npm dependencies
WORKDIR /app/assets
RUN npm ci
WORKDIR /app

# Compile the release
RUN --mount=type=cache,target=/app/deps,id=mix-deps \
    --mount=type=cache,target=/app/_build,id=mix-build \
    mix compile

# compile assets
RUN --mount=type=cache,target=/app/deps,id=mix-deps \
    --mount=type=cache,target=/app/_build,id=mix-build \
    mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN --mount=type=cache,target=/app/deps,id=mix-deps \
    --mount=type=cache,target=/app/_build,id=mix-build \
    mix release \
  && cp -r /app/_build/${MIX_ENV}/rel/planning_poker /app/_release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

RUN --mount=type=cache,target=/var/lib/apt/lists,id=apt-lists-runner \
    --mount=type=cache,target=/var/cache/apt,id=apt-cache-runner \
    apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_release ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
