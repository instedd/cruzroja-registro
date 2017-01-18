defmodule Registro.LayoutView do
  use Registro.Web, :view

  def global_toast do
    content_tag(:script) do
      raw("""
      if(window.toastMsg) {
      Materialize.toast(window.toastMsg, 8000)
      }
      """)
    end
  end

  def toast_message(message) do
    content_tag(:script) do
      {:safe, encoded_msg} = raw(Poison.encode!(message))
      raw("Materialize.toast(#{encoded_msg}, 8000)")
    end
  end

  def toast_flash_message(conn, flash_section) do
    if get_flash(conn, flash_section) do
      content_tag(:script) do
        {:safe, encoded_msg} = raw(Poison.encode!(get_flash(conn, flash_section)))
        raw("Materialize.toast(#{encoded_msg}, 8000)")
      end
    end
  end

  def menu_item(conn, href, text) do
    class = if String.starts_with?(conn.request_path, href) do
              "active"
            else
              ""
            end

    content_tag(:li, class: class) do
      content_tag(:a, text, href: href)
    end
  end
end
