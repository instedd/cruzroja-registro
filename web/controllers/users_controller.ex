defmodule Registro.UsersController do
  use Registro.Web, :controller
  use Timex

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
    VolunteerActivity,
    AssociatePayment
  }

  import Ecto.Query

  plug Authorization, [ check: &UsersController.authorize_detail/2 ] when action in [:show, :update]
  plug Authorization, [ check: &UsersController.authorize_profile_update/2 ] when action in [:update_profile]
  plug Authorization, [ check: &UsersController.authorize_associate_request/2 ] when action in [:associate_request]

  def index(conn, params) do
    current_user = Coherence.current_user(conn)
    render_raw = params["raw"] != nil
    authorized = Datasheet.is_staff?(current_user.datasheet)

    if authorized do
      page = Pagination.requested_page(params)

      sorting = sorting(params)

      filtered_query =
        conn
        |> listing_query
        |> apply_filters(params)
        |> apply_sorting(sorting)

      datasheets =
        filtered_query
        |> Pagination.query(page_number: page)
        |> Repo.all

      total_count = Repo.count(filtered_query)

      render_params = [
        datasheets: datasheets,
        sorting: sorting,
        page: page,
        page_count: Pagination.page_count(total_count),
        page_size: Pagination.default_page_size,
        total_count: total_count
      ]

      if render_raw do
        conn
        |> put_layout(false)
        |> render("listing.html", render_params)
      else
        branches = Branch.accessible_by(current_user.datasheet)
        render_params = Keyword.put(render_params, :branches, branches)

        render(conn, "index.html", render_params)
      end
    else
      Authorization.handle_unauthorized(conn, redirect: !render_raw)
    end
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
    current_user = Coherence.current_user(conn)
    datasheet = Repo.get(Datasheet, params["id"])
                |> Datasheet.preload_user
                |> Registro.Repo.preload([:volunteer_activities])
                |> Registro.Repo.preload([:associate_payments])

    datasheet_params =
      params["datasheet"]
      |> set_colaboration_settings(params["branch_name"], params["selected_role"], params["flow_action"], datasheet)

    if !authorize_update(conn, datasheet, datasheet_params) do
      Authorization.handle_unauthorized(conn)
    else
      email = if params["flow_action"] == "reinstate" do
                datasheet.user.email
              else
                params["email"]
              end

      changeset = Datasheet.changeset(datasheet, datasheet_params)
      changeset = if email && email != "" do
                    user = User.changeset(datasheet.user, :update, %{email: email})
                    Ecto.Changeset.put_assoc(changeset, :user, user)
                  else
                    changeset
                  end
      activities = setup_activities(params["activity"], datasheet)
      changeset = if activities do
                    Ecto.Changeset.put_assoc(changeset, :volunteer_activities, activities)
                  else
                    changeset
                  end
      {new_payments,existing} = setup_payments(params["payment"], datasheet)
      changeset = if new_payments || existing do
              Ecto.Changeset.put_assoc(changeset, :associate_payments, new_payments ++ existing)
            else
              changeset
            end

      case Repo.update(changeset) do
        {:ok, ds} ->
          id = if action_for(changeset) == :reject, do: [format_identifier(ds)], else: nil
          UserAuditLogEntry.add(datasheet.id, current_user, action_for(changeset), id)
          send_email_on_status_change(conn, changeset, email, ds)
          conn
          |> put_flash(:info, "Los cambios en la cuenta fueron efectuados.")
          |> redirect(to: users_path(conn, :show, datasheet))
        {:error, changeset} ->
          branch_name = if datasheet.branch, do: datasheet.branch.name
          conn
          |> assign(:history, UserAuditLogEntry.for(datasheet))
          |> assign(:quarters, quarters_for(datasheet))
          |> assign(:months, months_for(datasheet))
          |> load_datasheet_form_data
          |> render("show.html", changeset: changeset, branches: Branch.all, roles: Role.all, datasheet: datasheet, branch_name: branch_name)
      end
    end
  end

  def associate_request(conn, _params) do
    current_user = Coherence.current_user(conn)
    datasheet = current_user.datasheet

    changeset = Datasheet.associate_request_changeset(datasheet)

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
    datasheet = Repo.one(from d in Datasheet.full_query, where: d.id == ^params["id"], preload: [:volunteer_activities])
    changeset = Ecto.Changeset.change(datasheet)
    branch = datasheet.branch
    branch_name = if branch, do: branch.name

    conn
    |> assign(:branches, Branch.all)
    |> assign(:roles, Role.all)
    |> assign(:history, UserAuditLogEntry.for(datasheet))
    |> assign(:quarters, quarters_for(datasheet))
    |> assign(:months, months_for(datasheet))
    |> load_datasheet_form_data
    |> render("show.html", changeset: changeset, datasheet: datasheet, branch_name: branch_name)
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
              "Calle",
              "Número",
              "Bloque",
              "Piso",
              "Departamento",
              "Localidad",
              "Provincia",
              "Filial",
              "Rol",
              "Estado",
              "Asociado Pago"
             ]

    format = fn(d) ->
      [
        d.last_name,
        d.first_name,
        (if d.user, do: d.user.email, else: d.invitation.email),
        Datasheet.legal_id_kind(d).label,
        d.legal_id,
        d.country.name,
        Elixir.Date.to_iso8601(d.birth_date),
        d.occupation,
        d.address_street,
        d.address_number,
        d.address_block,
        d.address_floor,
        d.address_apartement,
        d.address_city,
        d.address_province,
        if(d.branch == nil, do: "", else: d.branch.name),
        Role.label(d.role),
        Datasheet.status_label(d.status),
        (case d.is_paying_associate do
           nil -> ""
           true -> "Sí"
           false -> "No"
         end)
      ]
    end

    datasheets = listing_query(conn)
               |> order_by([d], [d.last_name, d.first_name, d.id])
               |> preload(:country)
               |> preload(:invitation)
               |> apply_filters(params)
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

  defp role_filter(query, nil), do: query
  defp role_filter(query, param), do: from d in query, where: d.role == ^param

  defp branch_filter(query, nil), do: query
  defp branch_filter(query, param), do: from d in query, where: d.branch_id == ^param

  defp status_filter(query, nil), do: query
  defp status_filter(query, param), do: from d in query, where: d.status == ^param

  defp name_filter(query, nil), do: query
  defp name_filter(query, param) do
    name = "%" <> param <> "%"
    from d in query,
      left_join: u in User, on: u.datasheet_id == d.id,
      where: ilike(d.first_name, ^name) or ilike(d.last_name, ^name) or ilike(u.email, ^name)
  end

  def sorting(params) do
    field = params["sorting"] || "name"

    direction = case params["sorting_direction"] do
                  "desc" -> :desc
                  _ -> :asc
                end

    {field, direction}
  end

  def apply_sorting(query, {field, direction}) do
    case field do
      "name" ->
        order_by(query, [d], [{^direction, d.first_name}, {^direction, d.last_name}])
      "email" ->
        from d in query, left_join: u in User, on: u.datasheet_id == d.id, order_by: [{^direction, u.email}]
      "role" ->
        order_by(query, [d], [{^direction, d.role}])
      "status" ->
        order_by(query, [d], [{^direction, d.status}])
      "branch" ->
        from d in query, left_join: b in Branch, on: d.branch_id == b.id, order_by: [{^direction, b.name}]
    end
  end

  defp quarters_for(datasheet) do
    case datasheet.registration_date do
      nil -> []
      date ->
        quarter_start = Timex.beginning_of_quarter(Date.from(Elixir.Date.to_erl(date)))
        Interval.new(from: quarter_start, until: Date.now("America/Buenos_Aires"), right_open: false)
        |> Interval.with_step([months: 3])
        |> Enum.map(fn(dt) -> [Timex.format(dt, "%m/%Y", :strftime), VolunteerActivity.desc_for(datasheet.volunteer_activities, dt)] end)
        |> Enum.map(fn([{:ok, date}, desc]) -> [date, desc] end)
    end
  end

  defp months_for(datasheet) do
    case datasheet.volunteer_to_associate_date do
      nil -> []
      date ->
        month_start = Timex.beginning_of_month(Date.from(Elixir.Date.to_erl(date)))
        Interval.new(from: month_start, until: Date.now("America/Buenos_Aires"), right_open: false)
        |> Interval.with_step([months: 1])
        |> Enum.map(fn(dt) -> [Timex.format(dt, "%m/%Y", :strftime), AssociatePayment.for(datasheet.associate_payments, dt)] end)
        |> Enum.map(fn([{:ok, date}, payed]) -> [date, payed] end)
    end
  end

  defp setup_activities(updated, datasheet) do
    if updated == nil do
      nil
    else
      updated
      |> Enum.map(fn {date, description} ->
          formatted_date = string_to_db_date(date)
          case Enum.find(datasheet.volunteer_activities, fn(act) -> act.date == formatted_date end) do
            nil ->
              if description == "" do
                nil
              else
                build_assoc(datasheet, :volunteer_activities, %{date: formatted_date, description: description})
              end
            found ->
              if found.description == description do
                found
              else
                Ecto.Changeset.change(found, description: description)
              end
          end
        end)
      |> Enum.filter(fn res -> res != nil end)
    end
  end

  defp string_to_db_date(date) do
    dates = Regex.named_captures(~r/(?<month>[0-9]+)\/(?<year>[0-9]+)/, date)
    {_res,formatted_date} = Elixir.Date.new(String.to_integer(dates["year"]),String.to_integer(dates["month"]),1)
    formatted_date
  end

  defp setup_payments(updated, datasheet) do
    if updated == nil do
      {nil, nil}
    else
      new = updated
          |> Enum.map(fn {date, _x} ->
              formatted_date = string_to_db_date(date)
              case Enum.find(datasheet.associate_payments, fn(pay) -> pay.date == formatted_date end) do
                nil -> build_assoc(datasheet, :associate_payments, %{date: formatted_date})
                found -> nil
              end
            end)
          |> Enum.filter(fn e -> e != nil end)
      existing = datasheet.associate_payments
                  |> Enum.map(fn p ->
                      if !Enum.any?(updated, fn {date, _x} ->
                        formatted_date = string_to_db_date(date)
                        p.date == formatted_date end) do
                          %{Ecto.Changeset.change(p) | action: :delete}
                      else
                        p
                      end end)
      {new, existing}
    end
  end

  defp restrict_to_visible_users(query, conn) do
    user = conn.assigns[:current_user]
    datasheet = user.datasheet

    cond do
      Datasheet.has_global_access?(datasheet) ->
        query

      Datasheet.has_branch_access?(datasheet) ->
        branch_ids = Branch.accessible_by(datasheet) |> Enum.map(&(&1.id))

        from d in query, where: d.branch_id in ^branch_ids

      true ->
        from d in query, where: false
    end
  end

  def nil_to_string(val) do
    if val == nil do
      ""
    else
      val
    end
  end

  def authorize_listing(current_user) do
    datasheet = current_user.datasheet
    Datasheet.is_staff?(datasheet)
  end

  def authorize_detail(conn, %User{datasheet: datasheet}) do
    target_datasheet_id = String.to_integer(conn.params["id"])

    target_datasheet = (from d in Datasheet, where: d.id == ^target_datasheet_id)
                     |> restrict_to_visible_users(conn)
                     |> Repo.one

    cond do
      is_nil(target_datasheet) ->
        false

      Datasheet.is_global_admin?(datasheet) ->
        {true, [:view, :update]}

      Datasheet.is_admin_of?(datasheet, target_datasheet.branch_id) ->
        {true, [:view, :update]}

      Datasheet.is_global_reader?(datasheet) ->
        {true, [:view]}

      Datasheet.is_clerk_of?(datasheet, target_datasheet.branch_id) ->
        {true, [:view]}

      true ->
        false
    end
  end

  def authorize_update(conn, target_datasheet, datasheet_params) do
    # Assumes authorize_detail was run first to set abilities
    current_user = Coherence.current_user(conn)
    abilities = conn.assigns[:abilities]

    is_super_admin = Datasheet.is_super_admin?(current_user.datasheet)
    is_global_admin = Datasheet.is_global_admin?(current_user.datasheet)
    global_grant_changed = global_grant_changed(datasheet_params, target_datasheet)

    super_admin_revoking_own_access =
      is_super_admin &&
      target_datasheet.user &&
      target_datasheet.user.id == current_user.id &&
      global_grant_changed

    non_super_admin_changing_global_grant =
      !is_super_admin && global_grant_changed

    non_global_admin_updating_branch =
      !is_global_admin && branch_updated(datasheet_params, target_datasheet)

    forbidden_update = super_admin_revoking_own_access || non_super_admin_changing_global_grant || non_global_admin_updating_branch

    Enum.member?(abilities, :update) && !forbidden_update
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

  defp listing_query(conn) do
    q = from d in Datasheet.full_query,
        left_join: u in User, on: u.datasheet_id == d.id,
        where: d.filled == true

    restrict_to_visible_users(q, conn)
  end

  defp action_for(changeset) do
    case changeset.changes[:status] do
      "approved" -> :approve
      "rejected" -> :reject
      "at_start" -> :reopen
      "suspended" -> :suspend
      _ -> :update
    end
  end

  defp set_colaboration_settings(datasheet_params, branch_name, selected_role, flow_action, datasheet) do
    datasheet_params = set_branch_id_from_branch_name(datasheet_params, branch_name)

    case flow_action do
      "reject" ->
        # rejected a volunteer requesting to become an associate turns him back
        # into an approved volunteer
        case {datasheet.role, datasheet.status} do
          { "volunteer", "associate_requested" } ->
            Map.merge(datasheet_params, %{ "role" => "volunteer",
                                           "status" => "approved",
                                           "is_paying_associate" => nil })
          _ ->
            Map.merge(datasheet_params, %{ "status" => "rejected" })
        end

      "approve" ->
        datasheet_params
        |> Map.put("status", "approved")
        |> ensure_registration_date(datasheet)
        |> apply_role_changes(selected_role)
        |> add_associate_date(datasheet)

      "reopen" ->
        datasheet_params
        |> Map.put("status", "at_start")

      "suspend" ->
        datasheet_params
        |> Map.put("status", "suspended")

      "reinstate" ->
        %{}
        |> Map.put("id", datasheet.id)
        |> Map.put("status", "approved")

      _ ->
        datasheet_params
        |> apply_role_changes(selected_role)
        |> set_status_if_creating_colaboration(datasheet)
    end
  end

  def ensure_registration_date(datasheet_params, datasheet) do
    fallback_date = datasheet.registration_date || Timex.Date.today

    registration_date = case datasheet_params["registration_date"] do
                          nil -> fallback_date
                          ""  -> fallback_date
                          val -> val
                        end

    Map.put(datasheet_params, "registration_date", registration_date)
  end

  defp add_associate_date(datasheet_params, datasheet) do
    case datasheet.volunteer_to_associate_date do
      nil ->
        case datasheet_params["role"] do
          "associate" ->
            Map.put(datasheet_params, "volunteer_to_associate_date", Timex.Date.today)
          _ ->
            datasheet_params
        end
      value -> datasheet_params
    end
  end

  defp apply_role_changes(datasheet_params, selected_role) do
    # The UI encodes valid combinatios of {role, is_paying_associate} in a single input.
    # Here we decode the input and apply the changes
    case selected_role do
      "volunteer" ->
        Map.merge(datasheet_params, %{ "role" => "volunteer",
                                       "is_paying_associate" => nil })
      "paying_associate" ->
        Map.merge(datasheet_params, %{ "role" => "associate",
                                       "is_paying_associate" => true })
      "non_paying_associate" ->
        Map.merge(datasheet_params, %{ "role" => "associate",
                                       "is_paying_associate" => false })
      nil ->
        datasheet_params
    end
  end

  defp set_status_if_creating_colaboration(datasheet_params, datasheet) do
    # if the user doesn't have a current colaboration in a branch
    # and both brach_id and role are set, this means that a superadmin
    # is assigning a user to a branch as a colaborator. the change is
    # assumed to be approved.
    if !Datasheet.is_colaborator?(datasheet) do
      branch_id = datasheet_params["branch_id"]
      role = datasheet_params["role"]

      if !is_nil(branch_id) && !is_nil(role) do
        datasheet_params
        |> Map.put("status", "approved")
        |> ensure_registration_date(datasheet)
      else
        datasheet_params
      end
    else
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

  def branch_updated(datasheet_params, target_datasheet) do
    case Map.fetch(datasheet_params, "branch_id") do
      {:ok, new_branch_id} ->
        new_branch_id != target_datasheet.branch_id
      _ ->
        false
    end
  end

  def global_grant_changed(datasheet_params, target_datasheet) do
    case Map.fetch(datasheet_params, "global_grant") do
      {:ok, new_value} ->
        new_value != target_datasheet.global_grant
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
    |> assign(:provinces, Registro.Province.all)
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

  defp format_identifier(datasheet) do
    branch_part = datasheet.branch.identifier
                  |> Integer.to_string
                  |> String.rjust(3, ?0)

    datasheet_part = datasheet.branch_identifier
                    |> Integer.to_string
                    |> String.rjust(6, ?0)

    "#{branch_part}-#{datasheet_part}"
  end
end
