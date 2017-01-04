defmodule Registro.Role do

  def super_admin do
    "super_admin"
  end

  def branch_admin do
    "branch_admin"
  end

  def volunteer do
    "volunteer"
  end

  def associate do
    "associate"
  end

  # -----------

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
end
