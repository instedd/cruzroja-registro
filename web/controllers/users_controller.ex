defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias Registro.User

  def index(conn, _params) do
    users = Repo.all(User)
    render(conn, "index.html", users: users)
  end

  def filter(conn, params) do
    query = from u in User,
              select: u
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
end
