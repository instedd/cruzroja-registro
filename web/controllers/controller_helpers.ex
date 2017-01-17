defmodule Registro.ControllerHelpers do

  require Logger
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


  def send_coherence_email(fun, model, url, opts \\ []) do
    send_fn = fn ->
      # TODO: use a mailing queue and provide a mechanism to resend failed invitations
      case Coherence.ControllerHelpers.send_user_email(fun, model, url) do
        {:ok, _receipt} ->
          :ok

        {:error, reason} ->
          Logger.error "An error occurred when sending an email notification. Reason: #{inspect reason}."

        result ->
          Logger.error "Unexpected result when sending email notification: #{inspect result}."
      end
    end

    case opts[:sync] do
      true ->
        apply send_fn, []
      _ ->
        spawn send_fn
    end
  end

end
