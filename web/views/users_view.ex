defmodule Registro.UsersView do
  use Registro.Web, :view

  import Registro.ListingsHelpers

  def branch_label(datasheet) do
    case datasheet.branch do
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

  def readonly_colaboration_controls(form, datasheet) do
    [
      # display the role selected when registering, without allowing changes.
      # this field can be modified later by an administrator, once the user is approved.
      content_tag(:div, class: "input-field col s3") do
        [ label(form, :role, "Rol", class: "control-label"),
          tag(:input, class: "form-control", name: "", type: "text", disabled: "", value: Registro.Role.label(datasheet.role)),
          hidden_input(form, :role, class: "form-control", disabled: "")
        ]
      end,

      # if pending approval, the status will be set depending on which
      # button is pressed. (see form actions below).
      content_tag(:div, class: "input-field col s3") do
        [ label(form, :status, "Estado", class: "control-label"),
          tag(:input, class: "form-control", name: "", type: "text", disabled: "", value: Registro.Datasheet.status_label(datasheet.status)),
        ]
      end,
    ]
  end

  def editable_colaboration_controls(form, datasheet) do
    role_field = content_tag(:div, class: "input-field col s3") do
                  [
                    label(form, :role, "Rol", class: "control-label active"),
                    role_selector("datasheet[role]", datasheet.role),

                  ]
                end

    status_field = if datasheet.status do
                     # display the user status without allowing changes.
                     # if a user doesn't have status then any change to {branch_id, role}
                     # will automatically mark the status as "approved", so the user is not
                     # required to select the status when marking a user as a colaborator of a branch.
                     content_tag(:div, class: "input-field col s3") do
                       [
                         label(form, :status, "Estado", class: "control-label"),
                         tag(:input, class: "form-control", name: "", type: "text", disabled: "", value: Registro.Datasheet.status_label(datasheet.status))
                       ]
                     end
                   else
                     content_tag(:div, [])
                   end

    [role_field, status_field]
  end

end
