defmodule Registro.UsersView do
  use Registro.Web, :view

  import Registro.ListingsHelpers

  def branch_label(user) do
    case user.datasheet.branch do
      nil -> ""
      b -> b.name
    end
  end

  def role_option(role) do
    content_tag(:option, value: role) do
      Registro.Role.label(role)
    end
  end

  def role_selector(field_name, current_role) do
    content_tag(:select, name: field_name, class: "form-control") do
      prompt_option = content_tag(:option, "Seleccionar", option_attributes(is_nil(current_role), value: "", disabled: ""))

      role_options = Registro.Role.all
                   |> Enum.map(fn(role) ->
                                 content_tag(:option, Registro.Role.label(role), option_attributes(current_role == role, value: role))
                               end)

      [prompt_option | role_options]
    end
  end

  defp option_attributes(true, attrs), do: [{:selected, ""} | attrs]
  defp option_attributes(false, attrs), do: attrs
end
