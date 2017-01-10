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
  alias Registro.User

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
    user_schema = Config.user_schema
    cs = Helpers.changeset(:registration, user_schema, user_schema.__struct__)

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

    cs = User.changeset(%User{}, registration_params)

    case Config.repo.insert(cs) do
      {:ok, user} ->
        UserAuditLogEntry.add(cs, cs.data, :create)
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

  defp translate_flash(conn) do
    # Hack! Coherence currently provides no way to customize flash messages defined in it's internal helpers.
    translations = %{
      "Registration created successfully." => "Registración exitosa."
    }

    info_flash = get_flash(conn, :info)

    case translations[info_flash] do
      nil ->
        conn

      translation ->
        conn
        |> put_flash(:info, translation)
    end
  end

  defp load_registration_form_data(conn) do
    conn
    |> assign(:branches, Registro.Branch.all |> Enum.map(&{&1.name, &1.id }))
  end
end
