defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.Pagination
  alias Registro.User
  alias Registro.Role
  alias Registro.Branch
  alias Registro.Datasheet
  alias Registro.UserAuditLogEntry

  import Ecto.Query

  plug Registro.Authorization, [ check: &UsersController.authorize_listing/2 ] when action in [:index, :filter]
  plug Registro.Authorization, [ check: &UsersController.authorize_detail/2 ] when action in [:show, :update]

  def index(conn, _params) do
    query = listing_page_query(conn, 1)
    users = Repo.all(query)
    total_count = Repo.aggregate(query, :count, :id)

    conn
    |> assign(:branches, Branch.all)
    |> render("index.html",
      users: users,
      page: 1,
      page_count: Pagination.page_count(total_count),
      page_size: Pagination.default_page_size,
      total_count: total_count
    )
  end

  def profile(conn, _params) do
    user = Coherence.current_user(conn)
    changeset = Ecto.Changeset.change(user)

    conn
    |> render("profile.html", changeset: changeset)
  end

  def update(conn, params) do
    user = Repo.get(User, params["id"]) |> User.preload_datasheet

    %{"user" => user_params} = params
                             |> set_branch_id_from_branch_name
                             |> set_status_if_creating_colaboration(user)

    current_user = Coherence.current_user(conn)

    forbidden = !current_user.datasheet.is_super_admin &&
                  (branch_updated(user_params, user) || colaboration_updated(user_params, user))

    if forbidden do
      Registro.Authorization.handle_unauthorized(conn)
    else
      changeset = User.changeset(user, :update, user_params)

      case Repo.update(changeset) do
        {:ok, _user} ->
          UserAuditLogEntry.add(user.datasheet_id, Coherence.current_user(conn), action_for(changeset))
          conn
          |> put_flash(:info, "Los cambios en la cuenta fueron efectuados.")
          |> redirect(to: users_path(conn, :index))
        {:error, changeset} ->
          branch_name = if user.datasheet.branch, do: user.datasheet.branch.name
          conn
          |> assign(:history, UserAuditLogEntry.for(user))
          |> render("show.html", changeset: changeset, branches: Branch.all, roles: Role.all, user: user, branch_name: branch_name)
      end
    end
  end

  def show(conn, params) do
    user = Repo.one(from u in User.query_with_datasheet, where: u.id == ^params["id"])
    changeset = Ecto.Changeset.change(user)
    branch = user.datasheet.branch
    branch_name = if branch, do: branch.name

    conn
    |> assign(:branches, Branch.all)
    |> assign(:roles, Role.all)
    |> assign(:history, UserAuditLogEntry.for(user))
    |> render("show.html", changeset: changeset, user: user, branch_name: branch_name)
  end

  def filter(conn, params) do
    page = Pagination.requested_page(params)

    query = listing_page_query(conn, page)
          |> apply_filters(params)

    total_count = Repo.aggregate(query, :count, :id)
    users = Repo.all(query |> Pagination.restrict(page_number: page))

    conn
    |> put_layout(false)
    |> render("listing.html",
      users: users,
      page: page,
      page_count: Pagination.page_count(total_count),
      page_size: Pagination.default_page_size,
      total_count: total_count
    )
  end

  def download_csv(conn, params) do
    header = ["Nombre", "Email", "Filial", "Rol", "Estado"]

    format = fn(%User{ email: email, datasheet: d }) ->
      [
        d.name,
        email,
        if(d.branch == nil, do: "", else: d.branch.name),
        if(d.role == nil, do: "", else: Datasheet.role_label(d)),
        Datasheet.status_label(d.status)
      ]
    end

    query = from u in User.query_with_datasheet,
      join: d in assoc(u, :datasheet),
      order_by: d.name

    users = query
          |> apply_filters(params)
          |> restrict_to_visible_users(conn)
          |> Repo.all
          |> Enum.map(format)

    csv_content = [ header | users]
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
  def role_filter(query, param), do: from u in query, join: d in Datasheet, on: u.datasheet_id == d.id, where: d.role == ^param

  def branch_filter(query, param) when is_nil(param), do: query
  def branch_filter(query, param), do: from u in query, join: d in Datasheet, on: u.datasheet_id == d.id, where: d.branch_id == ^param

  def status_filter(query, param) when is_nil(param), do: query
  def status_filter(query, param), do: from u in query, join: d in Datasheet, on: u.datasheet_id == d.id, where: d.status == ^param

  def name_filter(query, param) when is_nil(param), do: query
  def name_filter(query, param) do
    name = "%" <> param <> "%"
    from u in query,
      join: d in Datasheet, on: u.datasheet_id == d.id,
      where: ilike(d.name, ^name) or ilike(u.email, ^name)
  end

  defp restrict_to_visible_users(query, conn) do
    user = conn.assigns[:current_user]
    datasheet = user.datasheet

    cond do
      datasheet.is_super_admin ->
        query
      Datasheet.is_branch_admin?(datasheet) ->
        administrated_branch_ids = Enum.map(datasheet.admin_branches, &(&1.id))

        from u in query,
        join: d in Datasheet, on: u.datasheet_id == d.id,
        left_join: b in assoc(d, :admin_branches),
        where: ((d.branch_id in ^administrated_branch_ids) or (b.id in ^administrated_branch_ids)),
        distinct: u.id # distinct here is used to avoid yielding a copy of a user for every branch administrated
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
    cond do
      datasheet.is_super_admin ->
        true

      Datasheet.is_branch_admin?(datasheet) ->
        user_id = String.to_integer(conn.params["id"])

        id_or_nil = (from u in User, where: u.id == ^user_id, select: 1)
                  |> restrict_to_visible_users(conn)
                  |> Repo.one

        id_or_nil != nil

      Datasheet.is_colaborator?(datasheet) ->
        false
    end
  end

  defp listing_page_query(conn, page_number) do
    (from u in User,
      join: d in Datasheet, on: d.id == u.datasheet_id,
      order_by: d.name)
      |> User.query_with_datasheet
      |> Pagination.query(page_number: page_number)
      |> restrict_to_visible_users(conn)
  end

  defp action_for(changeset) do
    ds = changeset.changes[:datasheet]
    if ds do
      case ds.changes[:status] do
        "approved" -> :approve
        "rejected" -> :reject
        _ -> :update
      end
    else
      :update
    end
  end

  defp set_branch_id_from_branch_name(params) do
    case params["branch_name"] do
      nil ->
        params
      "" ->
        params
      branch_name ->
        [branch_id] = Repo.one!(from b in Branch, where: b.name == ^branch_name, select: [b.id])

        update_in(params, ["user", "datasheet"], fn(dp) ->
          Map.put(dp, "branch_id", branch_id)
        end)
    end
  end

  defp set_status_if_creating_colaboration(params, user) do
    # if the user doesn't have a current colaboration in a branch
    # and both brach_id and role are set, this means that a superadmin
    # is assigning a user to a branch as a colaborator. the change is
    # assumed to be approved.

    %{"datasheet" => datasheet_params} = params["user"]

    if !Datasheet.is_colaborator?(user.datasheet) do
      case {datasheet_params["branch_id"], datasheet_params["role"]} do
        {nil, _} ->
          params
        {_, nil} ->
          params
        _ ->
          update_in(params, ["user", "datasheet"], fn(dp) ->
            Map.put(dp, "status", "approved")
          end)
      end
    else
      params
    end
  end

  def branch_updated(%{"datasheet" => datasheet_params}, target_user) do
    case Map.fetch(datasheet_params, "branch_id") do
      {:ok, new_branch_id} ->
        new_branch_id != target_user.datasheet.branch_id
      _ ->
        false
    end
  end

  def colaboration_updated(%{"datasheet" => datasheet_params}, target_user) do
    case Map.fetch(datasheet_params, "role") do
      {:ok, new_role} ->
        new_role != target_user.datasheet.role
      _ ->
        false
    end
  end
end
