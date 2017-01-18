defmodule Registro.Router do
  use Registro.Web, :router
  use Coherence.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug Registro.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Set current user if present for unprotected pages
  pipeline :set_user do
    plug Coherence.Authentication.Session
    plug Registro.PreloadDatasheet
  end

  # Require authentication
  pipeline :check_authentication do
    plug Coherence.Authentication.Session, protected: true
    plug Registro.PreloadDatasheet
  end

  scope "/", Registro do
    pipe_through [:browser, :set_user]

    get "/", HomeController, :index

    get "/registracion",  Coherence.RegistrationController, :new
    post "/registracion", Coherence.RegistrationController, :create
    get  "/registracion/invitado/:id",         Coherence.InvitationController, :edit
    post "/registracion/invitado/confirmar",   Coherence.InvitationController, :create_user
    coherence_routes :public
  end

  scope "/", Registro do
    pipe_through [:browser, :check_authentication]

    get  "/usuarios/alta",              Coherence.InvitationController, :new
    post "/usuarios/alta",                Coherence.InvitationController, :create
    get  "/usuarios/alta/:id/reenviar", Coherence.InvitationController, :resend
    coherence_routes :protected

    resources "/filiales/", BranchesController
    get "/usuarios/filter", UsersController, :filter
    get "/usuarios/descargar", UsersController, :download_csv
    resources "/usuarios", UsersController, only: [:index, :show, :update]
    get "/perfil", UsersController, :profile
  end

  # navigate to /dev/mailbox to see sent emails
  if Mix.env == :dev do
    scope "/dev" do
      pipe_through [:browser]

      forward "/mailbox", Plug.Swoosh.MailboxPreview, [base_path: "/dev/mailbox"]
    end
  end
end
