defmodule Registro.Router do
  use Registro.Web, :router
  use Coherence.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Set current user if present for unprotected pages
  pipeline :set_user do
    plug Coherence.Authentication.Session
  end

  # Require authentication
  pipeline :check_authentication do
    plug Coherence.Authentication.Session, protected: true
  end

  scope "/", Registro do
    pipe_through [:browser, :set_user]

    get "/", HomeController, :index

    # our overrides go first
    get "/registracion", Coherence.RegistrationController, :new
    post "/registracion", Coherence.RegistrationController, :create
    coherence_routes
  end

  scope "/", Registro do
    pipe_through [:browser, :check_authentication]
    coherence_routes :protected

    get "/filiales/", BranchesController, :index
    get "/usuarios/filter", UsersController, :filter
    resources "/usuarios", UsersController, only: [:index, :show, :update]
    get "/usuarios/descargar", UsersController, :download_csv
    get "/perfil", UsersController, :profile
  end
end
