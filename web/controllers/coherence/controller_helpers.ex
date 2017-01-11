defmodule Registro.Coherence.ControllerHelpers do

  import Phoenix.Controller, only: [get_flash: 2, put_flash: 3]

  @doc """
  Hack!
  Coherence currently provides no way to customize flash messages defined in it's internal helpers.
  """
  def translate_flash(conn) do
    translations = %{
      "Registration created successfully." => "Registración exitosa."
    }

    info_flash = get_flash(conn, :info)

    case translations[info_flash] do
      nil ->
        conn

      translation ->
        conn
        |> put_flash(:info, translation)
    end
  end

end
