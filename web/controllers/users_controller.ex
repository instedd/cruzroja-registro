defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias Registro.User

  def index(conn, _params) do
    users = Repo.all(User)
    render(conn, "index.html", users: users)
  end

  def filter(conn, params) do
    role = params["role"]
    users = Repo.all(User)
    # users = Repo.all from u in User,
    #           where: u.role = role,
    #           select: u
    conn
    |> put_layout(false)
    |> render "filter.html", users: users
  end
end
