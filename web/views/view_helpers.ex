defmodule Registro.ViewHelpers do
  def has_ability?(conn, ability) do
    Enum.member?(conn.assigns[:abilities], ability)
  end
end
