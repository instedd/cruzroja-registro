defmodule Registro.Role do

  def label(role) do
    case role do
      "volunteer" -> "Voluntario"
      "associate" -> "Asociado"
    end
  end

  def all do
    ["associate", "volunteer"]
  end

end
