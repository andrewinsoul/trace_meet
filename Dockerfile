ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.0.6
ARG DEBIAN_VERSION=bookworm-20261005-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
    && mix local.rebar --force

ENV MIX_ENV="prod"

COPY . .

RUN mix deps.get --only "$MIX_ENV" \
    && mix deps.compile \
    && mix compile \
    && mkdir -p deps/tiktokenex/priv/ranks \
    && cp priv/tiktokenex/ranks/*.tiktoken deps/tiktokenex/priv/ranks/ \
    && mix tokenizer.install \
    && mix assets.deploy \
    && mix release trace_meet \
    && mkdir -p _build/prod/rel/trace_meet/lib/tiktokenex-0.1.0/priv/ranks \
    && cp priv/tiktokenex/ranks/*.tiktoken \
        _build/prod/rel/trace_meet/lib/tiktokenex-0.1.0/priv/ranks/ \
    && test -s _build/prod/rel/trace_meet/lib/tiktokenex-0.1.0/priv/ranks/cl100k_base.tiktoken \
    && test -s _build/prod/rel/trace_meet/lib/tiktokenex-0.1.0/priv/ranks/o200k_base.tiktoken

FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        libstdc++6 \
        openssl \
        libncurses6 \
        locales \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV MIX_ENV="prod"
ENV PHX_SERVER="true"
ENV PORT="8080"

WORKDIR /app

RUN chown nobody /app

COPY --from=builder --chown=nobody:root \
    /app/_build/prod/rel/trace_meet ./

USER nobody

CMD ["/app/bin/trace_meet", "start"]
