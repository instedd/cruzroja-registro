defmodule Registro.UsersView do
  use Registro.Web, :view

  def branch_label(user) do
    case user.branch do
      nil -> ""
      b -> b.name
    end
  end
end
