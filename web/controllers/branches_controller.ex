defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.{Repo, Branch, Pagination, Datasheet, User, Invitation}

  plug Registro.Authorization, [ check: &BranchesController.authorize_listing/2 ] when action in [:index]
  plug Registro.Authorization, [ check: &BranchesController.authorize_detail/2 ] when action in [:show, :update]

  def index(conn, params) do
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

    {template, conn} = case params["raw"] do
                         nil ->
                           { "index.html", conn }

                         _   ->
                           { "listing.html", put_layout(conn, false) }
                       end

    render(conn, template,
      branches: branches,
      page: page,
      page_count: page_count,
      page_size: Pagination.default_page_size,
      total_count: total_count
    )
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

    admin_datasheets = preexisting_datasheets ++ new_datasheets

    changeset = branch
              |> Branch.changeset(branch_params)
              |> Branch.update_admins(admin_datasheets)
              |> validate_admin_not_removing_himself(Coherence.current_user(conn))

    case Repo.update(changeset) do
      {:ok, _branch} ->
        msg = case new_datasheets do
                [] ->
                  "Los cambios en la filial fueron efectuados."
                [d] ->
                  "Se envió una invitación a #{Datasheet.email(d)} para ser administrador de la filial."
                [_|_] ->
                  "Se enviaron #{Enum.count(new_datasheets)} invitaciones para los nuevos administradores de la filial."
              end
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

  def create(conn, %{"branch" => branch_params} = _params) do
    changeset = Branch.changeset(%Branch{}, branch_params)
    case Repo.insert(changeset) do
      {:ok, _branch} ->
        conn
        |> put_flash(:info, "Nueva filial agregada")
        |> redirect(to: branches_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def authorize_listing(_conn, %User{datasheet: datasheet}) do
    Datasheet.is_admin?(datasheet)
  end

  def authorize_detail(conn, %User{datasheet: datasheet}) do
    branch_id = String.to_integer(conn.params["id"])

    datasheet.is_super_admin || Datasheet.is_admin_of?(datasheet, branch_id)
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
    # TODO: We are currently validating that datasheets have a valid name, but when sending invitations
    # for branch admins we need to have a datasheet to grant permissions to, even if we only have the email.
    invitation_params = %{ "name" => "Completar",
                           "email" => email,
                           "datasheet" => %{
                             "name" => "Completar"
                           }}

    invitation_cs = Invitation.changeset(%Invitation{}, invitation_params)
    |> Invitation.generate_token

    invitation = Repo.insert!(invitation_cs)

    Coherence.ControllerHelpers.send_user_email :invitation, invitation, Invitation.accept_url(invitation)

    invitation.datasheet
  end
end
