defmodule Registro.UserAuditLogEntry do
  use Registro.Web, :model

  alias Registro.Datasheet
  alias Registro.Repo
  alias Registro.UserAuditLogEntry

  @valid_actions ["create",
                  "update",
                  "approve",
                  "reject",
                  "reopen",
                  "associate_requested",
                  "invite_send",
                  "invite_confirm",
                  "branch_admin_granted",
                  "branch_admin_revoked",
                  "branch_clerk_granted",
                  "branch_clerk_revoked",
                  "changed_imported_data"
                 ]

  schema "user_audit_log_entries" do
    field :action, :string
    field :changes, {:array, :string}
    belongs_to :user, Registro.Datasheet, foreign_key: :target_datasheet_id
    belongs_to :actor, Registro.Datasheet, foreign_key: :actor_datasheet_id
    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:target_datasheet_id, :actor_datasheet_id, :action, :changes])
    |> validate_required([:target_datasheet_id, :actor_datasheet_id, :action])
    |> validate_action
  end

  def add(target_datasheet_id, actor, action) do
    UserAuditLogEntry.add(target_datasheet_id, actor, action, nil)
  end

  def add(target_datasheet_id, actor, action, changes_list) do
    changeset = changeset(%UserAuditLogEntry{}, %{ actor_datasheet_id: actor.datasheet_id,
                                                   target_datasheet_id: target_datasheet_id,
                                                   action: Atom.to_string(action),
                                                   changes: changes_list })

    case Repo.insert(changeset) do
      {:ok, _entry} ->
        :ok
      {:error, _changeset} ->
        :error
    end
  end

  def for(datasheet) do
    id = datasheet.id
    Repo.all from e in UserAuditLogEntry,
            where: e.target_datasheet_id == ^id,
            preload: [:user, :actor]
  end

  def for(datasheet, action) do
    Registro.UserAuditLogEntry
    |> where([e], e.action == ^action)
    |> where([e], e.target_datasheet_id == ^datasheet.id)
    |> Repo.all
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

      "reopen" ->
        actor <> " reabrió su solicitud" <> date

      "associate_requested" ->
        "Solicitó ser asociado" <> date

      "invite_send" ->
        actor <> " le envió una invitación a registrarse " <> date

      "invite_confirm" ->
        "Se registró " <> date

      "branch_admin_granted" ->
        actor <> " lo hizo administrador de una filial" <> date

      "branch_admin_revoked" ->
        actor <> " lo removió como administrador de una filial" <> date

      "branch_clerk_granted" ->
        actor <> " lo hizo participante de una filial" <> date

      "branch_clerk_revoked" ->
        actor <> " lo removió como participante de una filial" <> date

      "changed_imported_data" ->
        case entry.changes do
          nil -> actor <> " se registró recuperando datos importados " <> date
          changes -> actor <> " se registró recuperando datos importados " <> date <> " y cambió o agregó los siguientes campos: " <> Enum.join(changes, ", ")
        end
    end
  end

  defp validate_action(changeset) do
    action = Ecto.Changeset.get_field(changeset, :action)
    if !Enum.member?(@valid_actions, action) do
      changeset |> Ecto.Changeset.add_error(:action, "is invalid")
    else
      changeset
    end
  end

end
