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

  def info_card(id, icon, text, attrs \\ []) do
    import Phoenix.HTML.Tag

    class = Keyword.get(attrs, :class, "")

    attrs =
      attrs
      |> Keyword.put(:id, id)
      |> Keyword.put(:class, "info-card row " <> class)

    content_tag(:div, attrs) do
      [content_tag(:i, icon, class: "material-icons"), content_tag(:span, text)]
    end
  end
end
