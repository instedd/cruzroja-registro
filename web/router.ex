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
    coherence_routes

    get "/", HomeController, :index
  end

  scope "/", Registro do
    pipe_through [:browser, :check_authentication]
    coherence_routes :protected

    get "/profile", UsersController, :profile
    get "/users/", UsersController, :index
    put "/users/:id", UsersController, :update
    get "/users/filter", UsersController, :filter

    get "/branches/", BranchesController, :index
  end
end
