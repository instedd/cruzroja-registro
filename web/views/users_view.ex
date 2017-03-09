defmodule Registro.UsersView do
  use Registro.Web, :view

  import Registro.ListingsHelpers
  import Registro.ViewHelpers
  import Registro.FormHelpers

  def role_option(role) do
    content_tag(:option, value: role) do
      Registro.Role.label(role)
    end
  end

  def branch_label(datasheet) do
    case datasheet.branch do
      nil -> ""
      b -> b.name
    end
  end

  def readonly_colaboration_controls(form, selected_branch_name, branch_identifier) do
    [
      branch_control(selected_branch_name, branch_identifier, false),

      content_tag(:div, class: "input-field col s4") do
        [ label(form, :role, "Rol", class: "control-label"),
          tag(:input, class: "form-control", name: "", type: "text", disabled: "",
              value: Registro.Role.label(input_value(form, :role))) ]
      end,

      content_tag(:div, class: "input-field col s4") do
        [ label(form, :status, "Estado", class: "control-label"),
          tag(:input, class: "form-control", name: "", type: "text", disabled: "",
              value: role_label(form)) ]
      end,

      content_tag(:div, class: "input-field col s4") do
        validated_field(form, :registration_date, text: "Afiliado desde", disabled: true)
      end,
    ]
  end

  def pending_colaboration_controls(form, selected_branch_name, branch_identifier, current_user_datasheet) do
    branch_editable = Registro.Datasheet.is_global_admin?(current_user_datasheet)

    [
      branch_control(selected_branch_name, branch_identifier, branch_editable),

      content_tag(:div, class: "input-field col s6") do
        role_selector(form)
      end,

      content_tag(:div, class: "input-field col s4") do
        [ label(form, :registration_date, "Afiliado desde"),
          date_picker(form, :registration_date) ]
      end,
    ]
  end

  def editable_colaboration_controls(form, selected_branch_name, branch_identifier, current_user_datasheet) do
    status = input_value(form, :status)
    branch_editable = Registro.Datasheet.is_global_admin?(current_user_datasheet)

    [
      branch_control(selected_branch_name, branch_identifier, branch_editable),

      content_tag(:div, class: "input-field col s4") do
        role_selector(form)
      end,

      if status do
        # display the user status without allowing changes.
        # if a user doesn't have status then any change to {branch_id, role}
        # will automatically mark the status as "approved", so the user is not
        # required to select the status when marking a user as a colaborator of a branch.
        content_tag(:div, class: "input-field col s4") do
          [
            label(form, :status, "Estado", class: "control-label"),
            tag(:input, class: "form-control", name: "", type: "text", disabled: "", value: Registro.Datasheet.status_label(status))
          ]
        end
      end,

      content_tag(:div, class: "input-field col s4") do
        [ label(form, :registration_date, "Afiliado desde"),
          date_picker(form, :registration_date) ]
      end,
    ]
  end

  defp branch_control(selected_branch_name, branch_identifier, branch_editable) do
    if branch_identifier do
      [
        content_tag(:div, class: "input-field col s6") do
          branch_selector(selected_branch_name, branch_editable)
        end,

        content_tag(:div, class: "input-field col s6") do
          [ tag(:input, class: "form-control", type: "text", disabled: "", value: branch_identifier),
            content_tag(:label, "Número de orden", class: "control-label") ]
        end,
      ]
    else
      content_tag(:div, class: "input-field col s12") do
        branch_selector(selected_branch_name, branch_editable)
      end
    end
  end

  defp branch_selector(selected_branch_name, editable) do
    [
      content_tag(:label, "Filial", class: "control-label", for: "user_datasheet_branch_name"),

      if editable do
        tag(:input,
          type: "text", autocomplete: "off", class: "autocomplete form-control",
          id: "user_datasheet_branch_name", name: "branch_name",
          value: selected_branch_name,
        )
      else
        tag(:input,
          class: "form-control", type: "text", disabled: "",
          name: "", value: selected_branch_name
        )
      end
    ]
  end

  def role_label(form) do
    role_label(input_value(form, :role), input_value(form, :status), input_value(form, :is_paying_associate))
  end

  def role_label(role, status, is_paying_associate) do
    case {role, status, is_paying_associate} do
      {"associate", _, true} ->
        "Asociado por pago"

      {"associate", _, false} ->
        "Asociado por antigüedad"

      {"volunteer", "associate_requested", true} ->
        "Asociado por pago"

      {"volunteer", "associate_requested", false} ->
        "Asociado por antigüedad"

      {"volunteer", _, nil} ->
        "Voluntario"

      {nil, nil, nil} ->
        ""
    end
  end

  def role_selector(form) do
    field_name = "selected_role"
    role = input_value(form, :role)
    status = input_value(form, :status)
    is_paying_associate = input_value(form, :is_paying_associate)

    selection = case {role, status, is_paying_associate} do
                  { "volunteer", "associate_requested", true } -> "paying_associate"
                  { "volunteer", "associate_requested", false } -> "non_paying_associate"
                  { "volunteer", _, _ } -> "volunteer"
                  { "associate", _, true } -> "paying_associate"
                  { "associate", _, false } -> "non_paying_associate"
                  { nil, nil, nil } -> ""
                end

    [
      content_tag(:select, id: field_name, name: field_name, class: "form-control") do
          [
            opt("Seleccionar", "", true, selection),
            opt("Voluntario", "volunteer", false, selection),
            opt("Asociado por pago", "paying_associate", false, selection),
            opt("Asociado por antigüedad", "non_paying_associate", false, selection)
          ]
      end,

      content_tag(:label, "Rol", for: field_name)
    ]
  end

  defp opt(label, value, is_disabled, current_selection) do
    attrs = [value: value]

    attrs = if value == current_selection do
      [{:selected, ""} | attrs]
    else
      attrs
    end

    attrs = if is_disabled do
      [{:disabled, ""} | attrs]
    else
      attrs
    end

    content_tag(:option, label, attrs)
  end

  def pending_approval?(status) do
    status == "at_start" || status == "associate_requested"
  end
end
