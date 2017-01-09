defmodule Registro.PreloadDatasheet do
  import Plug.Conn

  alias Registro.User

  def init(default), do: default

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    case current_user do
      nil ->
        conn
      _ ->
        case current_user.datasheet_id do
          nil ->
            conn
          _ ->
            user_with_datasheet = User.preload_datasheet(current_user)
            assign(conn, :current_user, user_with_datasheet)
        end
    end
  end
end
