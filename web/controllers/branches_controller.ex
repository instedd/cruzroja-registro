defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.{Authorization,
                  Repo,
                  Branch,
                  Pagination,
                  Datasheet,
                  User,
                  Invitation,
                  UserAuditLogEntry}

  plug Authorization, [ check: &BranchesController.authorize_detail/2 ] when action in [:show, :update]
  plug Authorization, [ check: &BranchesController.authorize_creation/2 ] when action in [:new, :create]

  def index(conn, params) do
    authorized = Datasheet.is_admin?(Coherence.current_user(conn).datasheet)
    render_raw = params["raw"] != nil

    case {authorized, render_raw} do
      { true, _ } ->
        import Ecto.Query

        datasheet = Coherence.current_user(conn).datasheet

        query = if datasheet.is_super_admin do
                  from b in Branch
                else
                  branch_ids = datasheet.admin_branches |> Enum.map(&(&1.id))

                  from b in Branch, where: b.id in ^branch_ids
                end

        query = from b in query, order_by: :name

        page = Pagination.requested_page(params)
        total_count = Repo.aggregate(query, :count, :id)
        page_count = Pagination.page_count(total_count)
        branches = Pagination.all(query, page_number: page)

        {template, conn} = if render_raw do
                             { "listing.html", put_layout(conn, false) }
                           else
                             { "index.html", conn }
                           end

        render(conn, template,
          branches: branches,
          page: page,
          page_count: page_count,
          page_size: Pagination.default_page_size,
          total_count: total_count
        )

      { false, false } ->
        Authorization.handle_unauthorized(conn, redirect: true)

      { false, true } ->
        Authorization.handle_unauthorized(conn, redirect: false)
    end
  end

  def show(conn, params) do
    branch = Repo.one(from u in Branch, where: u.id == ^params["id"], preload: [admins: [:user, :invitation]])

    admin_emails = branch.admins |> Enum.map(&Datasheet.email/1)

    changeset = Branch.changeset(branch)

    conn
    |> render("show.html", changeset: changeset, branch: branch, admin_emails: admin_emails)
  end

  def update(conn, %{"branch" => branch_params, "admin_emails" => encoded_emails} = params) do
    branch = Repo.one!(from b in Branch, where: b.id == ^params["id"], preload: [admins: :user])
    emails = String.split(encoded_emails, "|")
           |> Enum.filter(&(String.match?(&1, ~r/@/)))

    [preexisting_datasheets, new_datasheets] = existing_and_new_from_emails(emails)
    admin_datasheets = preexisting_datasheets ++ new_datasheets

    changeset = branch
              |> Branch.changeset(branch_params)
              |> Branch.update_admins(admin_datasheets)
              |> validate_admin_not_removing_himself(Coherence.current_user(conn))

    log_changes(conn, changeset)

    case Repo.update(changeset) do
      {:ok, _branch} ->
        msg = msg_for_admin_invites(new_datasheets)
        conn
        |> put_flash(:info, msg)
        |> redirect(to: branches_path(conn, :show, branch))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Error al actualizar los datos de la filial")
        |> render("show.html", changeset: changeset, branch: branch, admin_emails: emails)
    end
  end

  def new(conn, _params) do
    changeset = Branch.changeset(%Branch{})
    conn
    |> render("new.html", changeset: changeset)
  end

  def create(conn, %{"branch" => branch_params, "admin_emails" => encoded_emails}) do
    emails = String.split(encoded_emails, "|")
           |> Enum.filter(&(String.match?(&1, ~r/@/)))

    [preexisting_datasheets, new_datasheets] = existing_and_new_from_emails(emails)
    admin_datasheets = preexisting_datasheets ++ new_datasheets

    changeset = Branch.changeset(%Branch{}, branch_params)
              |> Branch.update_admins(admin_datasheets)
              |> validate_admin_not_removing_himself(Coherence.current_user(conn))

    case Repo.insert(changeset) do
      {:ok, _branch} ->
        msg = msg_for_admin_invites(new_datasheets)
        conn
        |> put_flash(:info, msg)
        |> redirect(to: branches_path(conn, :index))
      {:error, changeset} ->
        conn
        |> render("new.html", changeset: changeset, admin_emails: emails)
    end
  end

  def authorize_detail(conn, %User{datasheet: datasheet}) do
    branch_id = String.to_integer(conn.params["id"])

    datasheet.is_super_admin || Datasheet.is_admin_of?(datasheet, branch_id)
  end

  def authorize_creation(_conn, %User{datasheet: datasheet}) do
    datasheet.is_super_admin
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

  defp existing_and_new_from_emails(emails) do
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
                    |> Enum.map(&BranchesController.invite!/1)

    [preexisting_datasheets,new_datasheets]
  end

  defp msg_for_admin_invites(new_datasheets) do
    case new_datasheets do
      [] ->
        "Los cambios en la filial fueron efectuados."
      [d] ->
        "Se envió una invitación a #{Datasheet.email(d)} para ser administrador de la filial."
      [_|_] ->
        "Se enviaron #{Enum.count(new_datasheets)} invitaciones para los nuevos administradores de la filial."
    end
  end

  defp log_changes(conn, changeset) do
    current_user = Coherence.current_user(conn)

    previous_admins = changeset.data.admins |> Enum.map(&(&1.id))
    updated_admins  = changeset |> Ecto.Changeset.get_field(:admins) |> Enum.map(&(&1.id))

    added_admins = updated_admins
                 |> Enum.reject(fn id -> Enum.member?(previous_admins, id) end)

    removed_admins = previous_admins
                   |> Enum.reject(fn id -> Enum.member?(updated_admins, id) end)

    Enum.each(added_admins, fn id ->
      UserAuditLogEntry.add(id, current_user, :branch_admin_granted)
    end)

    Enum.each(removed_admins, fn id ->
      UserAuditLogEntry.add(id, current_user, :branch_admin_revoked)
    end)

    :ok
  end
end
