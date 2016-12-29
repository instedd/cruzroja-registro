defmodule Registro.UsersController do
  use Registro.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
