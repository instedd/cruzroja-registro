defmodule Registro.PageController do
  use Registro.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
