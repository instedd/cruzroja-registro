defmodule Registro.Role do

  def label(role) do
    case role do
      "volunteer" -> "Voluntario"
      "associate" -> "Asociado"
    end
  end

  def all do
    %{label("associate") => "associate",
      label("volunteer") => "volunteer"}
  end
end
