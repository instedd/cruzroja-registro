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

  def validated_input(f, name, attrs) do
    attrs = add_class_if_field_error(f, name, attrs, "invalid")

    text_input f, name, attrs
  end

  def validated_password_input(f, name, attrs) do
    attrs = add_class_if_field_error(f, name, attrs, "invalid")

    password_input f, name, attrs
  end

  def validated_label(f, name, opts, attrs \\ []) do
    text = opts[:text] || humanize(name)
    attrs = add_msg_if_field_error(f, name, attrs)

    label f, name, attrs do
      case opts[:required] do
        true ->
          ["#{text}\n", content_tag(:abbr, "*", class: "required", title: "required")]
        _ ->
          text
      end
    end
  end

  defp add_msg_if_field_error(f, name, attrs) do
    case f.errors[name] do
      nil ->
        attrs
      error ->
        [{:'data-error', Registro.ErrorHelpers.translate_error(error)} | attrs]
    end
  end

  defp add_class_if_field_error(f, name, attrs, class) do
    case f.errors[name] do
      nil ->
        attrs
      _error ->
        Keyword.put(attrs, :class, "#{attrs[:class]} #{class}")
    end
  end
end
