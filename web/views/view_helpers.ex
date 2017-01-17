defmodule Registro.ViewHelpers do

  use Phoenix.HTML

  def set_generic_error_toast do
    set_toast("Hubo un problema. Por favor revisar los errores.")
  end

  def set_toast(message) do
    content_tag(:script) do
      {:safe, encoded_msg} = raw(Poison.encode!(message))
      raw("var toastMsg = #{encoded_msg}")
    end
  end

end
