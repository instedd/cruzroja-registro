defmodule Registro.Role do

  def is_valid?(role) do
    Enum.member?(["volunteer", "associate"], role)
  end

  def is_super_admin?(role) do
    role == "super_admin"
  end

  def label(role) do
    case role do
      "super_admin" -> "Administrador de Sede Central"
      "branch_admin" -> "Administrador de Filial"
      "volunteer" -> "Voluntario"
      "associate" -> "Asociado"
    end
  end

  def all do
    %{label("super_admin") => "super_admin",
      label("branch_admin") => "branch_admin",
      label("associate") => "associate",
      label("volunteer") => "volunteer"}
  end
end
