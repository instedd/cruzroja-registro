defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias Registro.User
  alias Registro.Branch

  plug :authorize_user when action in [:index, :filter]

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
    if params["branch"] do
      branch_id = Repo.one from b in Branch,
                    where: b.name == ^params["branch"],
                    select: b.id,
                    limit: 1
    end

    query = from u in User,
            select: u,
            preload: [:branch]

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
    users = Repo.all(query)
    conn
    |> put_layout(false)
    |> render("filter.html", users: users)
  end

  defp authorize_user(conn, _) do
    if User.can_read(conn.assigns[:current_user]) do
      conn
    else
      conn |> put_flash(:info, "You can't access that page") |> redirect(to: "/") |> halt
    end
  end
end
