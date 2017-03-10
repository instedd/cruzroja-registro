defmodule Registro.ListingsHelpers do

  use Phoenix.HTML

  def listing_header(fields, {sorting_field, sorting_dir} \\ {nil, :asc}) do
    header_class = if is_nil(sorting_field), do: "", else: "sortable"

    content_tag(:thead) do
      content_tag(:tr) do
        Enum.map(fields, fn {field_name, label} ->
          header_class = if sorting_field == to_string(field_name) do
                          "sort sort-#{sorting_dir} #{header_class}"
                        else
                          header_class
                        end

          content_tag(:th, label, [{:'data-field', field_name}, {:class, header_class}])
        end)
      end
    end
  end

  @doc """
  Builds a pagination control.
  - current_page: current page number (starting at 1)
  - page_size: size of a full page
  - item_count: size of the current page (may not be full if it's the last)
  - page_count: amount of pages
  - total_count: total number of items
  """
  def pager(current_page, page_size, item_count, page_count, total_count) do
    first_item = 1 + (current_page - 1) * page_size
    last_item = first_item + item_count - 1

    left_link = case current_page do
                  1 -> nil
                  _ -> current_page - 1
                end

    right_link = case current_page do
                   ^page_count -> nil
                   _ -> current_page + 1
                 end

    class = if total_count > 0, do: "pager", else: "pager hide"

    content_tag(:div,
      class: class,
      'data-current-page': current_page,
      'data-previous-page': left_link,
      'data-next-page': right_link
    ) do
      [
        content_tag(:span, "#{first_item}-#{last_item} of #{total_count}", class: "pager-position"),
        content_tag(:ul, class: "pager-controls pagination") do
          Enum.concat [
            [ pager_arrow("left", left_link) ],
            [ pager_arrow("right", right_link) ]
          ]
        end
      ]
    end
  end

  defp pager_arrow(direction, page) do
    class = if page, do: "waves_effect pager-#{direction}", else: "disabled"

    content_tag(:li, class: class) do
      content_tag(:a, href: "#") do
        content_tag(:i, "chevron_#{direction}", class: "material-icons")
      end
    end
  end
end
