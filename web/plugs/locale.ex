defmodule Registro.Locale do
  import Plug.Conn

  def init(_opts), do: nil

  def call(conn, _opts) do
    Gettext.put_locale(Registro.Gettext, "es")
    conn |> put_session(:locale, "es")
  end
end
