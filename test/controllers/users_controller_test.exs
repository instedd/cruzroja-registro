defmodule Registro.UsersControllerTest do
  use Registro.ConnCase

  test "verifies that user is logged in", %{conn: conn} do
    conn = get conn, "/users"
    assert html_response(conn, 302)
  end
end
