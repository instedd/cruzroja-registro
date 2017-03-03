defmodule Registro.FormHelpers do
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
    attrs = if opts[:disabled], do: [ {:disabled, ""} | attrs ], else: attrs

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

  def date_picker(f, name \\ nil, opts \\ []) do
    import Phoenix.HTML.Form, only: [input_id: 2, input_name: 2, input_value: 2]

    value = case input_value(f, name) do
              %Date{} = d ->
                Date.to_iso8601(d)
              _ ->
                nil
            end

    attrs = [{:type, "date"}, {:class, "datepicker"}]

    attrs = if name do
              [ {:id, input_id(f, name)}, {:name, input_name(f, name)} | attrs ]
            else
                attrs
            end

    attrs = if opts[:input_name] do
              [ {:name, opts[:input_name]} | attrs ]
            else
              attrs
            end

    attrs = if opts[:disabled] do
              [{:disabled, ""}, {:value, value} | attrs]
            else
              [{:'data-value', value} | attrs]
            end

    tag(:input, attrs)
  end

  def form_rows(rows) do
    Enum.map(rows, fn(row_content) ->
      form_row do
        row_content
      end
    end)
  end

  def form_row(do: content) do
    content_tag(:div, class: "row") do
      content_tag(:div, class: "input-field col s12") do
        content
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

  def attributes(opts, attrs) do
    attrs = if opts[:disabled], do: [{:disabled, ""} | attrs], else: attrs
    attrs = if opts[:required], do: [{:required, ""} | attrs], else: attrs

    attrs
  end
end
