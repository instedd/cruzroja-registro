defmodule Registro.BranchesView do
  use Registro.Web, :view

  alias Registro.Router.Helpers, as: Routes

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

    content_tag(:div, class: "pager") do
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
    { href, class } = if page do
                        { pager_link(page), "waves_effect" }
                      else
                        { "#", "disabled" }
                      end

    content_tag(:li, class: class) do
      content_tag(:a, href: href) do
        content_tag(:i, "chevron_#{direction}", class: "material-icons")
      end
    end
  end

  defp pager_link(page) do
    Routes.branches_path(Registro.Endpoint, :index, page: page)
  end
end
