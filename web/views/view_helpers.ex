defmodule Registro.ViewHelpers do
  def has_ability?(conn, ability) do
    Enum.member?(conn.assigns[:abilities], ability)
  end

  def format_branch_identifier(branch) do
    branch.identifier
    |> Integer.to_string
    |> String.rjust(3, ?0)
  end

  def format_datasheet_identifier(branch, datasheet) do
    branch_part = format_branch_identifier(branch)

    datasheet_part =
      datasheet.branch_identifier
      |> Integer.to_string
      |> String.rjust(6, ?0)

    "#{branch_part}-#{datasheet_part}"
  end

  def info_card(id, icon, text) do
    import Phoenix.HTML.Tag

    content_tag(:div, class: "info-card row", id: id) do
      [content_tag(:i, icon, class: "material-icons"), content_tag(:span, text)]
    end
  end
end
