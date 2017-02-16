defmodule Registro.Branch do
  use Registro.Web, :model

  @derive {Poison.Encoder, only: [:name, :id, :eligible]}

  schema "branches" do
    field :name, :string
    field :address, :string
    field :phone_number, :string
    field :cell_phone_number, :string
    field :email, :string
    field :president, :string
    field :authorities, :string

    field :eligible, :boolean
    field :identifier, :integer
    timestamps

    many_to_many :admins, Registro.Datasheet,
      join_through: "branches_admins",
      on_replace: :delete # allow to delete admins by updating the branch

    many_to_many :clerks, Registro.Datasheet,
      join_through: "branches_clerks",
      on_replace: :delete # allow to delete admins by updating the branch
  end

  def creation_changeset(params \\ %{}) do
    %Registro.Branch{}
    |> changeset(params)
    |> generate_identifier
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :address, :phone_number, :cell_phone_number, :email, :president, :authorities, :eligible])
    |> validate_required([:name, :eligible])
    |> unique_constraint(:name, message: "ya pertenece a otra filial")
  end

  def update_admins(changeset, admin_datasheets) do
    Ecto.Changeset.put_assoc(changeset, :admins, admin_datasheets)
  end

  def update_clerks(changeset, clerk_datasheets) do
    Ecto.Changeset.put_assoc(changeset, :clerks, clerk_datasheets)
  end

  def eligible do
    Registro.Repo.all(from b in Registro.Branch, where: b.eligible, select: b, order_by: :name)
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end

  def count do
    Registro.Repo.one(from b in Registro.Branch, select: count(b.id))
  end

  def accessible_by(datasheet) do
    if Registro.Datasheet.has_global_access?(datasheet) do
      all
    else
      datasheet.admin_branches ++ datasheet.clerk_branches
    end
  end

  def generate_identifier(changeset) do
    {:ok, identifier} = PgSql.next_branch_seq_num
    put_change(changeset, :identifier, identifier)
  end
end
