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

  alias Registro.{Branch,Country, User,ImportedUser}

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

  def imported_user_search(conn, params) do
    ds_params = params["user"]["datasheet"]
    search = Registro.Repo.one from u in Registro.ImportedUser, where: u.legal_id == ^ds_params["legal_id"], limit: 1
    {cs, col_details} = case search do
      nil -> {User.changeset(:registration, %{ datasheet: %{country_id: Country.default.id,
                                                  legal_id: ds_params["legal_id"],
                                                  legal_id_kind: ds_params["legal_id_kind"] } }),
              %{}
              }
      found -> {User.changeset(:registration, %{ datasheet: Dict.merge(ImportedUser.as_params(found),
                                                      %{country_id: Country.default.id}),
                                                email: found.email }),
                %{"colaboration_kind" => "current_associate", "current_associate_registration_date" => found.registration_date}
                }
    end

    conn
    |> load_registration_form_data(col_details)
    |> render(:full_new, email: "", changeset: cs)
  end


  @doc """
  Create the new user account.

  Creates the new user account. Create and send a confirmation if
  this option is enabled.
  """
  def create(conn, params) do
    user_schema = Config.user_schema
    registration_params = prepare_registration_params(params)
    search = Registro.Repo.one from u in Registro.ImportedUser, where: u.legal_id == ^registration_params["datasheet"]["legal_id"], limit: 1
    if search do
      branch = case search.branch_name do
        nil -> nil
        name -> Registro.Repo.one from b in Branch, where: like(b.name, ^("%#{name}%"))
      end
      registration_params = registration_params
                            |> put_in(["datasheet","sigrid_profile_id"], search.sigrid_profile_id)
                            |> put_in(["datasheet","extranet_profile_id"], search.extranet_profile_id)
                            |> put_in(["datasheet","volunteer_to_associate_date"], registration_params["datasheet"]["registration_date"])
      if branch do
        registration_params = registration_params
                            |> put_in(["datasheet","branch_id"], branch.id)
      end
    end

    cs = User.changeset(:registration, registration_params)

    case Recaptcha.verify(params["g-recaptcha-response"]) do
      :ok ->
        case Config.repo.insert(cs) do
          {:ok, user} ->
            Registro.UserAuditLogEntry.add(user.datasheet_id, user, :create)
            if search, do: save_changes_in_history(search, user)
            conn
            |> send_confirmation(user, user_schema)
            |> translate_flash
            |> redirect_or_login(user, params, Config.allow_unconfirmed_access_for)
          {:error, changeset} ->
            conn
            |> load_registration_form_data(params)
            |> render("full_new.html", changeset: changeset)
        end
      :error ->
        conn
        |> load_registration_form_data(params)
        |> put_flash(:error, "Hubo un problema. Por favor reintentar.")
        |> render("full_new.html", changeset: cs)
    end
  end

  defp prepare_registration_params(params) do
    registration_params = params["registration"]
    colaboration_kind = params["colaboration_kind"]

    case colaboration_kind do
      "new_colaboration" ->
        is_paying_associate = case params["new_colaboration_role"] do
                                "volunteer" -> nil
                                "associate" -> true
                              end

        registration_params
        |> put_in(["datasheet", "role"], params["new_colaboration_role"])
        |> put_in(["datasheet", "status"], "at_start")
        |> put_in(["datasheet", "is_paying_associate"], is_paying_associate)

      "current_volunteer" ->
        registration_date = params["current_volunteer_registration_date"]
        {status, is_paying_associate} = case params["current_volunteer_desired_role"] do
                                          "volunteer" ->
                                            {"at_start", nil}
                                          "associate" ->
                                            {"associate_requested", Registro.DateTime.less_than_a_year_ago?(registration_date)}
                                        end

        registration_params
        |> put_in(["datasheet", "role"], "volunteer")
        |> put_in(["datasheet", "status"], status)
        |> put_in(["datasheet", "registration_date"], registration_date)
        |> put_in(["datasheet", "is_paying_associate"], is_paying_associate)

      "current_associate" ->
        registration_date = params["current_associate_registration_date"]
        registration_params
        |> put_in(["datasheet", "role"], "associate")
        |> put_in(["datasheet", "status"], "at_start")
        |> put_in(["datasheet", "is_paying_associate"], false)
        |> put_in(["datasheet", "registration_date"], registration_date)
    end
  end

  defp redirect_or_login(conn, _user, params, 0) do
    redirect_to(conn, :registration_create, params)
  end
  defp redirect_or_login(conn, user, params, _) do
    Helpers.login_user(conn, user, params)
  end

  defp load_registration_form_data(conn, submitted_params \\ %{}) do
    conn
    |> assign(:branches, Branch.all_by_province)
    |> assign(:countries, Country.all |> Enum.map(&{&1.name, &1.id }))
    |> assign(:provinces, Registro.Province.all)
    |> assign(:legal_id_kinds, LegalIdKind.all |> Enum.map(&{&1.label, &1.id }))
    # additional params not included in the changeset to prefil form fields
    |> assign(:prefill, Map.take(submitted_params, ["colaboration_kind",
                                                    "new_colaboration_role",
                                                    "current_volunteer_registration_date",
                                                    "current_volunteer_desired_role",
                                                    "current_associate_registration_date"
                                                   ]))
  end

  defp save_changes_in_history(imported, new_user) do
    ds = new_user.datasheet
    changes = []
              |> add_change_if(imported.first_name != ds.first_name, "Nombre")
              |> add_change_if(imported.last_name != ds.last_name, "Apellido")
              |> add_change_if(imported.legal_id_kind != ds.legal_id_kind, "Tipo de documento")
              |> add_change_if(imported.legal_id != ds.legal_id, "Número de documento")
              |> add_change_if(imported.birth_date != ds.birth_date, "Fecha de nacimiento")
              |> add_change_if(imported.occupation != ds.occupation, "Ocupación")
              |> add_change_if(imported.phone_number != ds.phone_number, "Teléfono")
              |> add_change_if(imported.registration_date != ds.registration_date, "Fecha de registro")
              |> add_change_if(imported.email != new_user.email, "Email")
              |> add_change_if(imported.address_street != ds.address_street ||
                               imported.address_number != ds.address_number ||
                               imported.address_block != ds.address_block ||
                               imported.address_floor != ds.address_floor ||
                               imported.address_apartement != ds.address_apartement ||
                               imported.address_city != ds.address_city ||
                               imported.address_province != ds.address_province, "Dirección")

    Registro.UserAuditLogEntry.add(new_user.datasheet_id, new_user, :changed_imported_data, changes)
  end

  defp add_change_if(changes_list, true, label), do: [label | changes_list]
  defp add_change_if(changes_list, false, _label), do: changes_list
end
