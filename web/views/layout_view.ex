defmodule Registro.LayoutView do
  use Registro.Web, :view

  def toast_flash_message(conn, flash_section) do
    if get_flash(conn, flash_section) do
      content_tag(:script) do
        {:safe, encoded_msg} = raw(Poison.encode!(get_flash(conn, flash_section)))
        raw("Materialize.toast(#{encoded_msg}, 8000)")
      end
    end
  end
end
