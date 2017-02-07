defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.{
    Authorization,
    Country,
    Pagination,
    User,
    Role,
    Branch,
    Datasheet,
    UserAuditLogEntry,
  }

  import Ecto.Query

  plug Authorization, [ check: &UsersController.authorize_listing/2 ] when action in [:index]
  plug Authorization, [ check: &UsersController.authorize_listing/2, redirect: false] when action in [:filter]
  plug Authorization, [ check: &UsersController.authorize_detail/2 ] when action in [:show, :update]
  plug Authorization, [ check: &UsersController.authorize_profile_update/2 ] when action in [:update_profile]
  plug Authorization, [ check: &UsersController.authorize_associate_request/2 ] when action in [:associate_request]

  def index(conn, _params) do
    query = listing_page_query(conn, 1)
    datasheets = Repo.all(query)
    total_count = Repo.aggregate(query, :count, :id)

    conn
    |> assign(:branches, Branch.all)
    |> render("index.html",
      datasheets: datasheets,
      page: 1,
      page_count: Pagination.page_count(total_count),
      page_size: Pagination.default_page_size,
      total_count: total_count
    )
  end

  def profile(conn, _params) do
    datasheet = load_datasheet_for_update(conn)

    changeset = if datasheet.filled do
                  Datasheet.profile_update_changeset(datasheet)
                else
                  Datasheet.profile_filled_changeset(datasheet, %{ country_id: Registro.Country.default.id })
                end

    render_profile(conn, changeset)
  end

  def update_profile(conn, %{"datasheet" => datasheet_params}) do
    datasheet = load_datasheet_for_update(conn)

    changeset = if datasheet.filled do
                    Datasheet.profile_update_changeset(datasheet, datasheet_params)
                  else
                    Datasheet.profile_filled_changeset(datasheet, datasheet_params)
                end

    case Repo.update(changeset) do
      {:ok, _datasheet} ->
        conn
        |> put_flash(:info, "Tus datos fueron actualizados.")
        |> redirect(to: users_path(conn, :profile))
      {:error, changeset} ->
        render_profile(conn, changeset)
    end
  end

  def update(conn, params) do
    datasheet = Repo.get(Datasheet, params["id"]) |> Datasheet.preload_user

    datasheet_params = params["datasheet"]
                     |> set_state_changes(params["flow_action"], datasheet)
                     |> set_branch_id_from_branch_name(params["branch_name"])
                     |> set_status_if_creating_colaboration(datasheet)

    email = params["email"]
    current_user = Coherence.current_user(conn)

    forbidden = if current_user.datasheet.is_super_admin && datasheet.user do
                  #don't allow a super user to revoke his own permissions
                  (datasheet.user.id == current_user.id) && super_admin_changed(datasheet_params, datasheet)
                else
                  branch_updated(datasheet_params, datasheet) || super_admin_changed(datasheet_params, datasheet)
                end

    if forbidden do
      Authorization.handle_unauthorized(conn)
    else
      changeset = Datasheet.changeset(datasheet, datasheet_params)
      changeset = if email && email != "" do
                    user = User.changeset(datasheet.user, :update, %{email: email})
                    Ecto.Changeset.put_assoc(changeset, :user, user)
                  else
                    changeset
                  end

      case Repo.update(changeset) do
        {:ok, ds} ->
          UserAuditLogEntry.add(datasheet.id, Coherence.current_user(conn), action_for(changeset))
          send_email_on_status_change(conn, changeset, email, ds)
          conn
          |> put_flash(:info, "Los cambios en la cuenta fueron efectuados.")
          |> redirect(to: users_path(conn, :show, datasheet))
        {:error, changeset} ->
          branch_name = if datasheet.branch, do: datasheet.branch.name
          conn
          |> assign(:history, UserAuditLogEntry.for(datasheet))
          |> load_datasheet_form_data
          |> render("show.html", changeset: changeset, branches: Branch.all, roles: Role.all, datasheet: datasheet, branch_name: branch_name)
      end
    end
  end

  def associate_request(conn, _params) do
    current_user = Coherence.current_user(conn)
    datasheet = current_user.datasheet
    changeset = Datasheet.changeset(datasheet, %{ status: "associate_requested" })

    case Repo.update(changeset) do
      {:ok, _} ->
        UserAuditLogEntry.add(datasheet.id, current_user, :associate_requested)

        conn
        |> put_flash(:info, "Se registró tu solicitud.")
        |> redirect(to: users_path(conn, :profile))
      {:error, changeset} ->
        render_profile(conn, changeset)
    end
  end

  def show(conn, params) do
    datasheet = Repo.one(from d in Datasheet.full_query, where: d.id == ^params["id"])
    changeset = Ecto.Changeset.change(datasheet)
    branch = datasheet.branch
    branch_name = if branch, do: branch.name

    conn
    |> assign(:branches, Branch.all)
    |> assign(:roles, Role.all)
    |> assign(:history, UserAuditLogEntry.for(datasheet))
    |> load_datasheet_form_data
    |> render("show.html", changeset: changeset, datasheet: datasheet, branch_name: branch_name)
  end

  def filter(conn, params) do
    page = Pagination.requested_page(params)

    query = listing_page_query(conn, page)
          |> apply_filters(params)

    total_count = Repo.aggregate(query, :count, :id)
    datasheets = Repo.all(query |> Pagination.restrict(page_number: page))

    conn
    |> put_layout(false)
    |> render("listing.html",
      datasheets: datasheets,
      page: page,
      page_count: Pagination.page_count(total_count),
      page_size: Pagination.default_page_size,
      total_count: total_count
    )
  end

  def download_csv(conn, params) do
    header = ["Apellido",
              "Nombre",
              "Email",
              "Tipo de documento",
              "Número de documento",
              "Nacionalidad",
              "Fecha de nacimiento",
              "Ocupación",
              "Dirección",
              "Filial",
              "Rol",
              "Estado"]

    format = fn(d) ->
      [
        d.last_name,
        d.first_name,
        d.user.email,
        Datasheet.legal_id_kind(d).label,
        d.legal_id_number,
        d.country.name,
        Date.to_iso8601(d.birth_date),
        d.occupation,
        d.address,
        if(d.branch == nil, do: "", else: d.branch.name),
        Datasheet.role_label(d),
        Datasheet.status_label(d.status)
      ]
    end

    query = from d in Datasheet.full_query(Registro.Datasheet),
      join: u in assoc(d, :user),
      order_by: [d.last_name, d.first_name, d.id],
      preload: [:country]

    datasheets = query
          |> apply_filters(params)
          |> restrict_to_visible_users(conn)
          |> Repo.all
          |> Enum.map(format)

    csv_content = [ header | datasheets]
                |> CSV.encode
                |> Enum.to_list
                |> to_string

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"usuarios.csv\"")
    |> send_resp(200, csv_content)
  end

  def apply_filters(query, params) do
    branch_id = if params["branch"] do
                  Repo.one from b in Branch,
                    where: b.name == ^params["branch"],
                    select: b.id
                else
                  nil
                end

    query = query
      |> role_filter(params["role"])
      |> branch_filter(branch_id)
      |> status_filter(params["status"])
      |> name_filter(params["name"])
    query
  end

  def role_filter(query, param) when is_nil(param), do: query
  def role_filter(query, param), do: from d in query, where: d.role == ^param

  def branch_filter(query, param) when is_nil(param), do: query
  def branch_filter(query, param), do: from d in query, where: d.branch_id == ^param

  def status_filter(query, param) when is_nil(param), do: query
  def status_filter(query, param), do: from d in query, where: d.status == ^param

  def name_filter(query, param) when is_nil(param), do: query
  def name_filter(query, param) do
    name = "%" <> param <> "%"
    from d in query,
      left_join: u in User, on: u.datasheet_id == d.id,
      where: ilike(d.first_name, ^name) or ilike(d.last_name, ^name) or ilike(u.email, ^name)
  end

  defp restrict_to_visible_users(query, conn, from_user \\ false) do
    user = conn.assigns[:current_user]
    datasheet = user.datasheet

    cond do
      datasheet.is_super_admin ->
        query
      Datasheet.is_branch_admin?(datasheet) ->
        administrated_branch_ids = Enum.map(datasheet.admin_branches, &(&1.id))

        if from_user do
          from u in query,
          join: d in Datasheet, on: u.datasheet_id == d.id,
          where: d.branch_id in ^administrated_branch_ids
        else
          from d in query,
          where: d.branch_id in ^administrated_branch_ids
        end
    end
  end

  def nil_to_string(val) do
    if val == nil do
      ""
    else
      val
    end
  end

  def authorize_listing(_conn, current_user) do
    datasheet = current_user.datasheet

    datasheet.is_super_admin || Datasheet.is_branch_admin?(datasheet)
  end

  def authorize_detail(conn, %User{datasheet: datasheet}) do
    if Datasheet.is_admin?(datasheet) do
      user_id = String.to_integer(conn.params["id"])

      (from d in Datasheet, where: d.id == ^user_id)
      |> restrict_to_visible_users(conn)
      |> Repo.exists?
    else
      false
    end
  end

  def authorize_profile_update(conn, current_user) do
    case conn.params["datasheet"]["user"] do
      nil ->
        true
      %{ "id" => id } ->
        String.to_integer(id) == current_user.id
    end
  end

  def authorize_associate_request(_conn, %User{ datasheet: datasheet }) do
    Datasheet.can_ask_to_become_associate?(datasheet)
  end

  defp listing_page_query(conn, page_number) do
    (from d in Datasheet,
      left_join: u in User, on: u.datasheet_id == d.id,
      order_by: d.last_name,
      where: d.filled == true)
      |> Datasheet.full_query
      |> Pagination.query(page_number: page_number)
      |> restrict_to_visible_users(conn)
  end

  defp action_for(changeset) do
    case changeset.changes[:status] do
      "approved" -> :approve
      "rejected" -> :reject
      _ -> :update
    end
  end

  defp set_state_changes(datasheet_params, flow_action, datasheet) do
    case {datasheet.status, flow_action} do
      { "at_start", "approve" } ->
        Map.put(datasheet_params, "status", "approved")

      { "at_start", "reject" } ->
        Map.put(datasheet_params, "status", "rejected")

      { "associate_requested", "approve" } ->
        datasheet_params
        |> Map.put("role", "associate")
        |> Map.put("status", "approved")

      { "associate_requested", "reject" } ->
        datasheet_params
        |> Map.put("role", "volunteer")
        |> Map.put("status", "approved")
      _ ->
        datasheet_params
    end
  end

  defp set_branch_id_from_branch_name(datasheet_params, branch_name) do
    case branch_name do
      nil ->
        datasheet_params
      "" ->
        datasheet_params
      branch_name ->
        [branch_id] = Repo.one!(from b in Branch, where: b.name == ^branch_name, select: [b.id])

        Map.put(datasheet_params, "branch_id", branch_id)
    end
  end

  defp set_status_if_creating_colaboration(datasheet_params, datasheet) do
    # if the user doesn't have a current colaboration in a branch
    # and both brach_id and role are set, this means that a superadmin
    # is assigning a user to a branch as a colaborator. the change is
    # assumed to be approved.

    if !Datasheet.is_colaborator?(datasheet) do
      case {datasheet_params["branch_id"], datasheet_params["role"]} do
        {nil, _} ->
          datasheet_params
        {_, nil} ->
          datasheet_params
        _ ->
          Map.put(datasheet_params, "status", "approved")
      end
    else
      datasheet_params
    end
  end

  def branch_updated(datasheet_params, target_datasheet) do
    case Map.fetch(datasheet_params, "branch_id") do
      {:ok, new_branch_id} ->
        new_branch_id != target_datasheet.branch_id
      _ ->
        false
    end
  end

  def super_admin_changed(datasheet_params, target_datasheet) do
    case Map.fetch(datasheet_params, "is_super_admin") do
      {:ok, new_value} ->
        new_value = case new_value do
                      "true" -> true
                      "false" -> false
                      _ -> new_value
                    end

        new_value != target_datasheet.is_super_admin
      _ ->
        false
    end
  end

  defp render_profile(conn, changeset) do
    conn
    |> load_datasheet_form_data
    |> render("profile.html", changeset: changeset, filled: changeset.data.filled)
  end

  defp load_datasheet_form_data(conn) do
    conn
    |> assign(:countries, Country.all |> Enum.map(&{&1.name, &1.id }))
    |> assign(:legal_id_kinds, LegalIdKind.all |> Enum.map(&{&1.label, &1.id }))
  end

  # Since we allow updating the user from the datasheet,
  # we need to preload the association from the datasheet's side
  defp load_datasheet_for_update(conn) do
    user = Coherence.current_user(conn)
    Repo.preload(user.datasheet, :user)
  end

  defp send_email_on_status_change(conn, changeset, email, ds) do
    ds = Repo.preload(ds, :branch)
    if action_for(changeset) == :approve do
      Registro.Coherence.UserEmail.approve(ds, users_url(conn, :profile), email)
    end
    if action_for(changeset) == :reject do
      Registro.Coherence.UserEmail.reject(ds, users_url(conn, :profile), email)
    end
  end
end
