defmodule Registro.BranchesView do
  use Registro.Web, :view

  use Phoenix.HTML

  import Registro.ListingsHelpers
  import Registro.ViewHelpers

  def chip_selector(title, id, field_name) do
    content_tag(:div, class: "section") do
      [
        content_tag(:h3, title),

        content_tag(:div, id: id) do
          [
            tag(:input, name: field_name, type: "hidden", value: ""),

            content_tag(:div, class: "input-field") do
              content_tag(:div, [], class: "selector-chips")
            end,
          ]
        end,

        content_tag(:div, class: "input-instructions") do
          "Agregar emails y presionar Enter. Se enviará una invitación a las direcciones que no tengan una cuenta asociada."
        end,
      ]
    end
  end
end
