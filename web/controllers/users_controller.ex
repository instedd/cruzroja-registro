defmodule Registro.UsersController do
  use Registro.Web, :controller

  alias Registro.User

  def index(conn, _params) do
    users = Repo.all(User)
    render(conn, "index.html", users: users)
  end
end
