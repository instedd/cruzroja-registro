defmodule Registro.Role do
  def label(role) do
    case role do
      "super_admin" -> "Administrador de Sede Central"
      "branch_admin" -> "Administrador de Filial"
      "volunteer" -> "Voluntario"
      "associate" -> "Asociado"
    end
  end

  def is_admin?(role) do
    case role do
      "super_admin" -> true
      "branch_admin" -> true
      _ -> false
    end
  end

  def is_super_admin?(role) do
    role == "super_admin"
  end

  def all do
    %{label("super_admin") => "super_admin",
      label("branch_admin") => "branch_admin",
      label("associate") => "associate",
      label("volunteer") => "volunteer"}
  end
end
