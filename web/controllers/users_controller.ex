defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias Registro.User

  plug :authorize_user when action in [:index, :filter]

  def index(conn, _params) do
    users = Repo.all from u in User,
                     preload: [:branch]

    render(conn, "index.html", users: users)
  end

  def profile(conn, _params) do
    changeset = User.changeset(conn.assigns[:current_user])
    render(conn, "profile.html", changeset: changeset)
  end

  def update(conn, _params) do
    # TODO: check authorization
    # TODO: check which fields can be updated
  end

  def filter(conn, params) do
    query = from u in User,
            select: u,
            preload: [:branch]

    if params["role"] do
      query = from u in query,
                where: u.role == ^params["role"]
    end
    if params["branch"] do
      query = from u in query,
                where: u.branch == ^params["branch"]
    end
    if params["status"] do
      query = from u in query,
                where: u.status == ^params["status"]
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
