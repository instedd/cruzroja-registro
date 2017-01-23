defmodule Registro.UserAuditLogEntry do
  use Registro.Web, :model

  alias Registro.Datasheet
  alias Registro.Repo
  alias Registro.UserAuditLogEntry

  schema "user_audit_log_entries" do
    field :action, :string
    belongs_to :user, Registro.Datasheet, foreign_key: :target_datasheet_id
    belongs_to :actor, Registro.Datasheet, foreign_key: :actor_datasheet_id
    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:target_datasheet_id, :actor_datasheet_id, :action])
    |> validate_required([:target_datasheet_id, :actor_datasheet_id, :action])
  end

  def add(datasheet_id, actor, action) do
    changeset = changeset(%UserAuditLogEntry{}, %{actor_datasheet_id: actor.datasheet_id, target_datasheet_id: datasheet_id, action: Atom.to_string(action)})

    case Repo.insert(changeset) do
      {:ok, _entry} ->
        :ok
      {:error, _changeset} ->
        :error
    end
  end

  def for(user) do
    id = user.datasheet_id
    Repo.all from e in UserAuditLogEntry,
            where: e.target_datasheet_id == ^id,
            preload: [:user, :actor]
  end

  def description(entry) do
    actor = Datasheet.full_name(entry.actor)
    date = Registro.DateTime.to_local(entry.inserted_at)
    date = " el " <> Registro.DateTime.format_date(date) <> " a las " <> Registro.DateTime.format_time(date)

    case entry.action do
      "create" ->
        if entry.actor_datasheet_id == entry.target_datasheet_id do
          "Se registró" <> date
        else
          actor <> " lo suscribió" <> date
        end

      "update" ->
        if actor == entry.target_datasheet_id do
          "Actualizó su perfil" <> date
        else
          actor <> " actualizó sus datos" <> date
        end

      "approve" ->
        actor <> " aprobó su solicitud" <> date

      "reject" ->
        actor <> " rechazó su solicitud" <> date

      "invite_send" ->
        actor <> " le envió una invitación a registrarse " <> date

      "invite_confirm" ->
        "Se registró " <> date

      "branch_admin_granted" ->
        actor <> " lo hizo administrador de una filial" <> date

      "branch_admin_revoked" ->
        actor <> " lo removió como administrador de una filial" <> date
    end
  end

end
