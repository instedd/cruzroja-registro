defmodule Registro.HomeController do
  use Registro.Web, :controller

  def index(conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        Registro.Coherence.SessionController.new(conn, params)
      _ ->
        user = conn.assigns[:current_user]

        if Registro.Datasheet.is_admin?(user.datasheet) do
          redirect(conn, to: users_path(conn, :index))
        else
          redirect(conn, to: users_path(conn, :profile))
        end
    end
  end
end
