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

  def validated_field(f, name, opts) do
    [ validated_input(f, name, opts, class: "form-control"),
      validated_label(f, name, opts) ]
  end

  def validated_input(f, name, attrs) do
    validated_input(f, name, [], attrs)
  end

  def validated_input(f, name, opts, attrs) do
    attrs = add_class_if_field_error(f, name, attrs, "invalid")

    attrs = if opts[:autofocus], do: [ {:autofocus, ""} | attrs ], else: attrs
    attrs = if opts[:required], do: [ {:required, ""} | attrs ], else: attrs

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
      text
    end
  end

  def date_picker(f, name, attrs \\ []) do
    import Phoenix.HTML.Form, only: [input_id: 2, input_name: 2, input_value: 2]

    attrs = [ {:type, "date"},
              {:class, "datepicker"},
              {:id, input_id(f, name)},
              {:name, input_name(f, name)}
              | attrs ]

    attrs = case input_value(f, name) do
              %Date{} = d ->
                [{:'data-value', Date.to_iso8601(d)} | attrs]
              _ ->
                attrs
            end

    tag(:input, attrs)
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
