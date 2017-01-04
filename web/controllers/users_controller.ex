defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias Registro.User
  alias Registro.Role
  alias Registro.Branch

  plug Registro.Authorization, [ check: &Role.is_admin?/1 ] when action in [:index, :filter]

  def index(conn, _params) do
    users = Repo.all from u in User,
                     order_by: u.name,
                     preload: [:branch]
    conn
    |> assign(:branches, Branch.all)
    |> render("index.html", users: users)
  end

  def profile(conn, _params) do
    user = Coherence.current_user(conn)
    changeset = User.changeset(user)

    conn
    |> assign(:current_user, Repo.preload(user, :branch))
    |> render("profile.html", changeset: changeset)
  end

  def update(conn, _params) do
    # TODO: check authorization
    # TODO: check which fields can be updated
  end

  def filter(conn, params) do
    query = from u in User,
            preload: [:branch]
    query = apply_filters(query, params)
    users = Repo.all(query)
    conn
    |> put_layout(false)
    |> render("filter.html", users: users)
  end

  def download_csv(conn, params) do
    query = from u in User,
              left_join: b in assoc(u, :branch),
              select: [u.name, u.email, u.role, u.status, b.name]
    query = apply_filters(query, params)
    users = Repo.all(query)

    users = set_labels(users)
    csv_content = [["Nombre", "Email", "Rol", "Estado", "Filial"]] ++ users
    |> CSV.encode
    |> Enum.to_list
    |> to_string
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"usuarios.csv\"")
    |> send_resp(200, csv_content)
  end

  def apply_filters(query, params) do
    if params["branch"] do
      branch_id = Repo.one from b in Branch,
                    where: b.name == ^params["branch"],
                    select: b.id,
                    limit: 1
    end
    query = query
      |> role_filter(params["role"])
      |> branch_filter(branch_id)
      |> status_filter(params["status"])
      |> name_filter(params["name"])
    query
  end

  def role_filter(query, param) when is_nil(param), do: query
  def role_filter(query, param), do: from u in query, where: u.role == ^param

  def branch_filter(query, param) when is_nil(param), do: query
  def branch_filter(query, param), do: from u in query, where: u.branch_id == ^param

  def status_filter(query, param) when is_nil(param), do: query
  def status_filter(query, param), do: from u in query, where: u.status == ^param

  def name_filter(query, param) when is_nil(param), do: query
  def name_filter(query, param) do
    name = "%" <> param <> "%"
    from u in query, where: ilike(u.name, ^name) or ilike(u.email, ^name)
  end


  def nil_to_string(val) do
    if val == nil do
      ""
    else
      val
    end
  end

  def set_labels(list) do
    res = Enum.map(list, fn(u) -> [Enum.at(u,0), Enum.at(u,1), User.role_label(Enum.at(u,2)), nil_to_string(User.status_label(Enum.at(u,3))), nil_to_string(Enum.at(u,4))] end)
    res
  end
end
