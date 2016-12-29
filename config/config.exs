# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :registro,
  ecto_repos: [Registro.Repo]

# Configures the endpoint
config :registro, Registro.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "QHEzg93GuDS3rJiO0wD7S0HaZ4sy3McYV5tlkf9xu/o+NDlwhp1TvdJEj4gCy3I3",
  render_errors: [view: Registro.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Registro.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
