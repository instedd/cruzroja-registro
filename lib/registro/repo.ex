defmodule Registro.Repo do
  use Ecto.Repo, otp_app: :registro

  def exists?(query) do
    count = Registro.Repo.aggregate(query, :count, :id)
    count > 0
  end
end
