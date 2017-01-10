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

# %% Coherence Configuration %%   Don't remove this line
config :coherence,
  user_schema: Registro.User,
  repo: Registro.Repo,
  module: Registro,
  logged_out_url: "/",
  email_from_name: "Cruz Roja Argentina",
  email_from_email: "noreply@instedd.org",
  allow_unconfirmed_access_for: true,
  changeset: {Registro.User, :coherence_changeset},
  opts: [:authenticatable, :recoverable, :trackable, :rememberable, invitable: [], registerable: []]

config :coherence, Registro.Coherence.Mailer,
  adapter: Swoosh.Adapters.Local
# %% End Coherence Configuration %%

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
