defmodule Registro.BranchManagement do

  alias __MODULE__
  alias Registro.Datasheet
  alias Registro.Repo
  alias Registro.Branch
  alias Registro.Invitation
  alias Registro.UserAuditLogEntry

  def update_staff(changeset, current_user, admin_emails, clerk_emails) do
    {preexisting_admin_datasheets, new_admin_datasheets} = existing_and_new_from_emails(admin_emails)
    {preexisting_clerk_datasheets, new_clerk_datasheets} = existing_and_new_from_emails(clerk_emails)

    admin_datasheets = preexisting_admin_datasheets ++ new_admin_datasheets
    clerk_datasheets = preexisting_clerk_datasheets ++ new_clerk_datasheets
    new_datasheets = new_admin_datasheets ++ new_clerk_datasheets

    changeset = changeset
              |> Branch.update_admins(admin_datasheets)
              |> Branch.update_clerks(clerk_datasheets)
              |> validate_admin_not_removing_himself(current_user)

    %{changeset: changeset, new_datasheets: new_datasheets}
  end

  def log_changes(current_user, changeset) do
    {added_admins, removed_admins} = Branch.admin_changes(changeset)
    {added_clerks, removed_clerks} = Branch.clerk_changes(changeset)

    Enum.each(added_admins, fn id ->
      UserAuditLogEntry.add(id, current_user, :branch_admin_granted)
    end)

    Enum.each(removed_admins, fn id ->
      UserAuditLogEntry.add(id, current_user, :branch_admin_revoked)
    end)

    Enum.each(added_clerks, fn id ->
      UserAuditLogEntry.add(id, current_user, :branch_clerk_granted)
    end)

    Enum.each(removed_clerks, fn id ->
      UserAuditLogEntry.add(id, current_user, :branch_clerk_revoked)
    end)

    :ok
  end

  def admin_changes(changeset) do
    previous_admins = changeset.data.admins |> Enum.map(&(&1.id))
    updated_admins  = changeset |> Ecto.Changeset.get_field(:admins) |> Enum.map(&(&1.id))

    added_admins = updated_admins
    |> Enum.reject(fn id -> Enum.member?(previous_admins, id) end)

    removed_admins = previous_admins
    |> Enum.reject(fn id -> Enum.member?(updated_admins, id) end)

    {added_admins, removed_admins}
  end

  def clerk_changes(changeset) do
    previous_clerks = changeset.data.clerks |> Enum.map(&(&1.id))
    updated_clerks  = changeset |> Ecto.Changeset.get_field(:clerks) |> Enum.map(&(&1.id))

    added_clerks = updated_clerks
    |> Enum.reject(fn id -> Enum.member?(previous_clerks, id) end)

    removed_clerks = previous_clerks
    |> Enum.reject(fn id -> Enum.member?(updated_clerks, id) end)

    {added_clerks, removed_clerks}
  end

  defp existing_and_new_from_emails(emails) do
    import Ecto.Query

    preexisting_datasheets = Repo.all(from d in Datasheet,
      left_join: u in assoc(d, :user),
      left_join: i in assoc(d, :invitation),
      where: (u.email in ^emails) or (i.email in ^emails),
      preload: [:user, :invitation]
    )

    preexisting_emails = preexisting_datasheets
    |> Enum.map(&Datasheet.email/1)

    new_datasheets = emails
    |> Enum.filter(fn(email) -> !Enum.member?(preexisting_emails, email) end)
    |> Enum.map(&BranchManagement.invite!/1)

    {preexisting_datasheets, new_datasheets}
  end

  defp validate_admin_not_removing_himself(changeset, current_user) do
    if current_user.datasheet.is_super_admin do
      changeset
    else
      admin_emails = Ecto.Changeset.get_field(changeset, :admins) |> Enum.map(&Datasheet.email/1)

      if Enum.member?(admin_emails, current_user.email) do
        changeset
      else
        msg = "No es posible removerse a uno mismo como administrador de la filial"
        changeset |> Ecto.Changeset.add_error(:datasheet, msg)
      end
    end
  end

  def invite!(email) do
    invitation = Invitation.new_admin_changeset(email)
    |> Repo.insert!

    Registro.ControllerHelpers.send_coherence_email :invitation, invitation, Invitation.accept_url(invitation)

    invitation.datasheet
  end
end
