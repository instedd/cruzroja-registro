defmodule Registro.CheckDatasheet do
  import Plug.Conn

  def init(default), do: default

  def call(conn, [redirect_to: redirect_to]) do
    %Registro.User{datasheet: datasheet} = conn.assigns[:current_user]

    if datasheet.filled || conn.request_path == redirect_to || is_logout(conn) do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: redirect_to)
      |> halt
    end
  end

  defp is_logout(conn) do
    conn.request_path == "/sessions" && conn.method == "DELETE"
  end
end
