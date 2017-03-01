defmodule LegalIdKind do
  defstruct id: nil, label: nil

  def for_id(id) do
    kind = Enum.find(all, fn %LegalIdKind{id: kind_id} ->
      kind_id == id
    end)

    if !kind do
     raise "Invalid legal id kind: #{id}"
    end

    kind
  end

  def all do
    [
      %LegalIdKind{ id: "DNI", label: "Documento Nacional de Identidad" },
      %LegalIdKind{ id: "CI",  label: "Cédula de Identidad" },
      %LegalIdKind{ id: "LC",  label: "Libreta Cívica" },
      %LegalIdKind{ id: "LE",  label: "Libreta de Enrolamiento" },
      %LegalIdKind{ id: "PAS", label: "Pasaporte" },
    ]
  end
end
