defmodule Registro.Authorization do
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias Registro.User
  alias Registro.Router.Helpers, as: Routes
  require Logger

  def init(default), do: default

  defmacro check_path(conn, pattern, do: exp) do
    quote do
      if(Regex.match?(unquote(pattern), unquote(conn).request_path), do: unquote(exp))
    end
  end

  def call(conn, opts) do
    case opts[:check].(conn.assigns[:current_user].role) do
      true ->
        conn
      _ ->
        conn
        |> put_flash(:info, "Página no accesible")
        |> redirect(to: Routes.home_path(conn, :index))
        |> halt
    end
  end

end
