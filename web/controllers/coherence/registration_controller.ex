defmodule Registro.Coherence.RegistrationController do
  @moduledoc """
  Handle account registration actions.

  Actions:

  * new - render the register form
  * create - create a new user account
  * edit - edit the user account
  * update - update the user account
  * delete - delete the user account
  """
  use Coherence.Web, :controller
  require Logger
  alias Coherence.ControllerHelpers, as: Helpers
  import Registro.ControllerHelpers

  alias Registro.{Branch,Country, User, Repo}

  plug Coherence.RequireLogin when action in ~w(show edit update delete)a
  plug Coherence.ValidateOption, :registerable
  plug :scrub_params, "registration" when action in [:create, :update]

  plug :layout_view
  plug :redirect_logged_in when action in [:new, :create]

  @doc false
  def layout_view(conn, _) do
    conn
    |> put_layout({Registro.LayoutView, "app.html"})
    |> put_view(Coherence.RegistrationView)
  end

  @doc """
  Render the new user form.
  """
  def new(conn, _params) do
    default_country = Repo.get_by(Country, name: "Argentina")

    cs = User.changeset(:create_with_datasheet, %{ datasheet: %{country_id: default_country.id} })

    conn
    |> load_registration_form_data
    |> render(:new, email: "", changeset: cs)
  end


  @doc """
  Create the new user account.

  Creates the new user account. Create and send a confirmation if
  this option is enabled.
  """
  def create(conn, %{"registration" => registration_params} = params) do
    user_schema = Config.user_schema

    registration_params = update_in(registration_params, ["datasheet"], fn(dp) ->
      Dict.merge(dp, %{"status" => "at_start"})
    end)

    cs = User.changeset(:create_with_datasheet, registration_params)

    case Config.repo.insert(cs) do
      {:ok, user} ->
        Registro.UserAuditLogEntry.add(user.datasheet_id, user, :create)
        conn
        |> send_confirmation(user, user_schema)
        |> translate_flash
        |> redirect_or_login(user, params, Config.allow_unconfirmed_access_for)
      {:error, changeset} ->
        conn
        |> load_registration_form_data
        |> render("new.html", changeset: changeset)
    end
  end

  defp redirect_or_login(conn, _user, params, 0) do
    redirect_to(conn, :registration_create, params)
  end
  defp redirect_or_login(conn, user, params, _) do
    Helpers.login_user(conn, user, params)
  end

  defp load_registration_form_data(conn) do
    conn
    |> assign(:branches, Branch.all |> Enum.map(&{&1.name, &1.id }))
    |> assign(:countries, Country.all |> Enum.map(&{&1.name, &1.id }))
    |> assign(:legal_id_kinds, LegalIdKind.all |> Enum.map(&{&1.label, &1.id }))
  end
end
