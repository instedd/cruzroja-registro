defmodule Coherence.RegistrationView do
  use Registro.Coherence.Web, :view

  def raw_radio_button(name, value, prefill) do
    attrs = [ {:type, "radio"},
              {:value, value},
              {:name, name},
              {:id, value},
              {:class, "with-gap"} ]

    attrs = if value == prefill[name] do
              [{:checked, "checked"} | attrs]
            else
              attrs
            end

    tag(:input, attrs)
  end

  def raw_select(name, opts, prefill) do
    selected_value = prefill[name]

    content_tag(:select, name: name, class: "form-control") do
      Enum.map(opts, fn {label, value} ->
        if value == selected_value do
          content_tag(:option, label, value: value, selected: "selected")
        else
          content_tag(:option, label, value: value)
        end
      end)
    end
  end
end
