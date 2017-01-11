defmodule Registro.UserAuditLogEntry do
  use Registro.Web, :model

  alias Registro.Repo
  alias Registro.UserAuditLogEntry

  schema "user_audit_log_entries" do
    field :action_id, :integer
    belongs_to :user, Registro.Datasheet, foreign_key: :user_id
    belongs_to :actor, Registro.Datasheet, foreign_key: :actor_id
    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:user_id, :actor_id, :action_id])
    |> validate_required([:user_id, :actor_id, :action_id])
  end

  def add(datasheet_id, actor, action) do
    code = UserAuditLogEntry.action_to_code(action)
    changeset = changeset(%UserAuditLogEntry{}, %{actor_id: actor.datasheet_id, user_id: datasheet_id, action_id: code})
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
            where: e.user_id == ^id
  end

  def action_to_code(action) do
    case action do
      :create -> 0
      :update -> 1
      :approve -> 2
      :reject -> 3
      :invite_send -> 4
      :invite_confirm -> 5
      _ -> 100
    end
  end

  def description(entry) do
    actor = Repo.get(Registro.Datasheet, entry.actor_id).name
    date = Registro.DateTime.to_local(entry.inserted_at)
    date = " el " <> Registro.DateTime.format_date(date) <> " a las " <> Registro.DateTime.format_time(date)
    case entry.action_id do
      0 ->
        if entry.actor_id == entry.user_id do
          "Se registró" <> date
        else
          actor <> " lo suscribió" <> date
        end
      1 ->
        if actor == entry.user_id do
          "Actualizó su perfil" <> date
        else
          actor <> " actualizó sus datos" <> date
        end
      2 ->
        actor <> " aprobó su solicitud" <> date
      3 ->
        actor <> " rechazó su solicitud" <> date
      4 ->
        actor <> " le envió una invitación a registrarse " <> date
      5 ->
        "Se registró " <> date
      100 ->
        "Actualización sin detalle registrada"
    end
  end

end
