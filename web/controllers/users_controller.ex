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
    if params["role"] do
      query = from u in query,
                where: u.role == ^params["role"]
    end
    if branch_id do
      query = from u in query,
                where: u.branch_id == ^branch_id
    end
    if params["status"] do
      query = from u in query,
                where: u.status == ^params["status"]
    end
    if params["name"] do
      name = "%" <> params["name"] <> "%"
      query = from u in query,
                where: ilike(u.name, ^name) or ilike(u.email, ^name)
    end
    query
  end
end
