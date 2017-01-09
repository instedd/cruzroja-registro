defmodule Registro.Authorization do
  @moduledoc """
  This module provides a unified way to handle authorizaton errors,
  as well as a conveniente plug for hooking authorization tests into
  controller actions.

  The plug can be check functions that return one of the following:
    - true, which means the request is authorized
    - {true, abilities}, which means the request is authorized and
      the user is allowed the specified abilities on the accessed resource
    - any other result means the request is not authorized

  In the simplest case, a check function receives only the role of the current
  user. Example:
  ```
  plug Registro.Authorization, check_role: &Role.is_super_admin?/1
  ```

  If more information is needed, use `check` instead of `check_role` to supply a
  function that received the current user and the request params. Example:
  ```
  plug Registro.Authorization, check: &complex_check/2
  ```

  To handle authorization errors without using the plug, use the
  handle_unauthorized/1 function.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias Registro.User
  alias Registro.Router.Helpers, as: Routes

  def init(default), do: default

  def call(conn, opts) do
    current_user = conn.assigns[:current_user]

    result = case opts[:check_role] do
               nil ->
                 opts[:check].(current_user, conn.params)
               check_fn ->
                 check_fn.(current_user.datasheet.role)
             end


    case result do
      true ->
        conn
      {true, abilities} ->
        assign(conn, :abilities, abilities)
      _ ->
        handle_unauthorized(conn)
    end
  end

  def handle_unauthorized(conn) do
    conn
    |> put_flash(:info, "Página no accesible")
    |> redirect(to: Routes.home_path(conn, :index))
    |> halt
  end

end
