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
      %LegalIdKind{ id: "CI",  label: "Cédula de identidad" },
      %LegalIdKind{ id: "DNI", label: "Documento nacional de identidad" },
      %LegalIdKind{ id: "LC",  label: "Libreta cívica" },
      %LegalIdKind{ id: "LE",  label: "Libreta de enrolamiento" },
      %LegalIdKind{ id: "PAS", label: "Pasaporte" },
    ]
  end
end
