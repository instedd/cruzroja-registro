defmodule Registro.Authorization do
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias Registro.User
  alias Registro.Router.Helpers, as: Routes

  def init(default), do: default

  def call(conn, opts) do
    case opts[:check].(conn.assigns[:current_user].role) do
      true ->
        conn
      {true, abilities} ->
        conn
        |> assign(:abilities, abilities)
      _ ->
        conn
        |> put_flash(:info, "Página no accesible")
        |> redirect(to: Routes.home_path(conn, :index))
        |> halt
    end
  end

end
