defmodule Registro.Repo do
  use Ecto.Repo, otp_app: :registro

  def exists?(query) do
    count(query) > 0
  end

  def count(query) do
    Registro.Repo.aggregate(query, :count, :id)
  end
end
