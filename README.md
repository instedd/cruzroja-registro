# Registro

## Development environment

### Stack

  * Phoenix web app
  * PostgreSQL database server

### How to run

See [this guide](http://www.phoenixframework.org/docs/installation) for instructions on how to install Elixir, Hex and Phoenix.

A `docker-compose.yml` is provided to run a PostgreSQL with the `registro_dev` database needed during development. It can be started with `docker-compose up -d`.

To start the Phoenix app:

  * Install dependencies with `mix deps.get`
  * Migrate your database with `mix ecto.migrate`
  * Install Node.js dependencies with `npm install`
  * Load PL/pgSQL functions with `mix run priv/repo/functions_init.exs`
  * Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
Alternatively, run with `iex -S mix phoenix.sever` to use iex's interactive shell.

For development, run `mix run priv/repo/seeds.exs` to create an administrator user.

*Note:* a recent version of npm is required. Otherwise the required Babel dependencies might not be fetched. The app is tested with node `v6.9.2` and npm `v3.10.9`. See [this issue](https://github.com/phoenixframework/phoenix/issues/1410) for more information.
