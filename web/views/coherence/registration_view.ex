defmodule Coherence.RegistrationView do
  use Registro.Coherence.Web, :view

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
end
