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

  alias Registro.{Branch,Country, User}

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
    cs = User.changeset(:registration, %{ datasheet: %{country_id: Country.default.id} })

    conn
    |> load_registration_form_data
    |> render(:new, email: "", changeset: cs)
  end


  @doc """
  Create the new user account.

  Creates the new user account. Create and send a confirmation if
  this option is enabled.
  """
  def create(conn, params) do
    user_schema = Config.user_schema
    registration_params = prepare_regitration_params(params)

    cs = User.changeset(:registration, registration_params)

    case Recaptcha.verify(params["g-recaptcha-response"]) do
      :ok ->
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
      :error ->
        conn
        |> load_registration_form_data
        |> put_flash(:error, "Hubo un problema. Por favor reintentar.")
        |> render("new.html", changeset: cs)
    end
  end

  defp prepare_regitration_params(params) do
    registration_params = params["registration"]
    colaboration_kind = params["colaboration_kind"]

    case colaboration_kind do
      "new_colaboration" ->
        is_paying_associate = case params["new_colaboration"]["role"] do
                                "volunteer" -> nil
                                "associate" -> true
                              end

        registration_params
        |> put_in(["datasheet", "role"], params["new_colaboration"]["role"])
        |> put_in(["datasheet", "status"], "at_start")
        |> put_in(["datasheet", "is_paying_associate"], is_paying_associate)

      "current_volunteer" ->
        registration_date = params["current_volunteer"]["registration_date"]
        {status, is_paying_associate} = case params["current_volunteer"]["desired_role"] do
                                          "volunteer" ->
                                            {"at_start", nil}
                                          "associate" ->
                                            {"associate_requested", less_than_a_year_ago(registration_date)}
                                        end

        registration_params
        |> put_in(["datasheet", "role"], "volunteer")
        |> put_in(["datasheet", "status"], status)
        |> put_in(["datasheet", "registration_date"], registration_date)
        |> put_in(["datasheet", "is_paying_associate"], is_paying_associate)

      "current_associate" ->
        registration_params
        |> put_in(["datasheet", "role"], "associate")
        |> put_in(["datasheet", "status"], "at_start")
        |> put_in(["datasheet", "is_paying_associate"], false)
    end
  end

  defp less_than_a_year_ago(d) do
    a_year_ago = Timex.Date.today |> Timex.shift(years: -1)
    {:ok, erl_date} = d |> Ecto.Date.cast! |> Ecto.Date.dump
    before_a_year_ago = Timex.to_date(erl_date) |> Timex.before?(a_year_ago)

    !before_a_year_ago
  end

  defp redirect_or_login(conn, _user, params, 0) do
    redirect_to(conn, :registration_create, params)
  end
  defp redirect_or_login(conn, user, params, _) do
    Helpers.login_user(conn, user, params)
  end

  defp load_registration_form_data(conn) do
    conn
    |> assign(:branches, Branch.eligible |> Enum.map(&{&1.name, &1.id }))
    |> assign(:countries, Country.all |> Enum.map(&{&1.name, &1.id }))
    |> assign(:legal_id_kinds, LegalIdKind.all |> Enum.map(&{&1.label, &1.id }))
  end
end
