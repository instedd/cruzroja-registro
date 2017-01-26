defmodule Registro.LayoutHelpers do
  use Phoenix.HTML

  def single_column(do: content) do
    content_tag(:div, class: "row") do
      content_tag(:div, class: "col s12 m8 offset-m2 l8 offset-l2") do
        content_tag(:div, class: "content-main") do
          content
        end
      end
    end
  end
end
