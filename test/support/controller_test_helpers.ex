defmodule Registro.ControllerTestHelpers do

  alias Registro.Repo
  alias Registro.User

  def log_in(conn, %User{} = user) do
    Plug.Conn.assign(conn, :current_user, user)
  end

  def log_in(conn, email) do
    user = Repo.get_by!(User, email: email)
    log_in(conn, user)
  end

  defmacro assert_unauthorized(conn) do
    quote do
      assert redirected_to(unquote(conn)) == "/"
      assert get_flash(unquote(conn), :info) == "Página no accesible"
    end
  end
end
