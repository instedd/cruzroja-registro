defmodule Registro.HomeController do
  use Registro.Web, :controller

  def index(conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        Registro.Coherence.SessionController.new(conn, params)
      _ ->
        redirect(conn, to: users_path(conn, :index))
    end
  end
end
