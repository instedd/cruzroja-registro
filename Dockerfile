FROM elixir:1.3.4

RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-client && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mix local.hex --force
ENV MIX_ENV=prod

ADD mix.exs mix.lock /app/
WORKDIR /app

RUN mix deps.get --only prod
RUN mix deps.compile

ADD . /app
RUN mix compile
RUN mix phoenix.digest

ENV PORT=80
EXPOSE 80

CMD mix phoenix.server
