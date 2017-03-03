defmodule Coherence.RegistrationView do
  use Registro.Coherence.Web, :view

  def raw_select(name, opts) do
    content_tag(:select, name: name, class: "form-control") do
      Enum.map(opts, fn {label, id} ->
        content_tag(:option, label, value: id)
      end)
    end
  end
end
