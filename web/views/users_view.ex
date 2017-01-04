defmodule Registro.UsersView do
  use Registro.Web, :view

  def branch_label(user) do
    case user.branch do
      nil -> ""
      b -> b.name
    end
  end

  def role_option(role) do
    content_tag(:option, value: role) do
      Registro.Role.label(role)
    end
  end
end
