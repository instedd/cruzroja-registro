defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.{Authorization,
                  Repo,
                  Branch,
                  BranchManagement,
                  Pagination,
                  Datasheet,
                  User}

  plug Authorization, [ check: &BranchesController.authorize_detail/2 ] when action in [:show]
  plug Authorization, [ check: &BranchesController.authorize_update/2 ] when action in [:update]
  plug Authorization, [ check: &BranchesController.authorize_creation/2 ] when action in [:new, :create]

  def index(conn, params) do
    datasheet = Coherence.current_user(conn).datasheet
    authorized = Datasheet.is_staff?(datasheet)
    render_raw = params["raw"] != nil

    if authorized do
      import Ecto.Query

      query = if Datasheet.has_global_access?(datasheet) do
        from b in Branch
      else
        # TODO: here we are using the full list to build the paginated query,
        # which doesn't seem to make a lot of sense. We expect non-global-admins
        # to only be allowed to access a few branches at most, so it shouldn't be
        # that bad.
        branch_ids = Branch.accessible_by(datasheet) |> Enum.map(&(&1.id))

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
    else
      Authorization.handle_unauthorized(conn, redirect: !render_raw)
    end
  end

  def show(conn, params) do
    branch = Repo.one(from u in Branch,
                      where: u.id == ^params["id"],
                      preload: [admins: [:user, :invitation],
                                clerks: [:user, :invitation]])

    admin_emails = branch.admins |> Enum.map(&Datasheet.email/1)
    clerk_emails = branch.clerks |> Enum.map(&Datasheet.email/1)

    changeset = Branch.changeset(branch)

    conn
    |> render("show.html", changeset: changeset, branch: branch, admin_emails: admin_emails, clerk_emails: clerk_emails)
  end

  def update(conn, params) do
    %{
      "id" => id,
      "branch" => branch_params,
      "admin_emails" => encoded_admin_emails,
      "clerk_emails" => encoded_clerk_emails
    } = params

    branch = Repo.one!(from b in Branch, where: b.id == ^id, preload: [admins: :user, clerks: :user])

    current_user = Coherence.current_user(conn)
    admin_emails = decode_email_list(encoded_admin_emails)
    clerk_emails = decode_email_list(encoded_clerk_emails)

    %{changeset: changeset,
      new_datasheets: new_datasheets} = Branch.changeset(branch, branch_params)
                                      |> BranchManagement.update_staff(current_user, admin_emails, clerk_emails)

    case Repo.update(changeset) do
      {:ok, branch} ->
        BranchManagement.log_changes(current_user, changeset)

        msg = msg_for_staff_invites(new_datasheets)
        conn
        |> put_flash(:info, msg)
        |> redirect(to: branches_path(conn, :show, branch))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Error al actualizar los datos de la filial")
        |> render("show.html",
                  changeset: changeset,
                  branch: branch,
                  admin_emails: admin_emails,
                  clerk_emails: clerk_emails,
                  )
    end
  end

  def new(conn, _params) do
    changeset = Branch.changeset(%Branch{})

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"branch" => branch_params, "admin_emails" => encoded_admin_emails, "clerk_emails" => encoded_clerk_emails}) do
    current_user = Coherence.current_user(conn)
    admin_emails = decode_email_list(encoded_admin_emails)
    clerk_emails = decode_email_list(encoded_clerk_emails)

    %{changeset: changeset, new_datasheets: new_datasheets} =
      branch_params
      |> Branch.creation_changeset
      |> BranchManagement.update_staff(current_user, admin_emails, clerk_emails)

    case Repo.insert(changeset) do
      {:ok, _branch} ->
        msg = msg_for_staff_invites(new_datasheets)
        conn
        |> put_flash(:info, msg)
        |> redirect(to: branches_path(conn, :index))
      {:error, changeset} ->
        conn
        |> render("new.html", changeset: changeset, admin_emails: admin_emails, clerk_emails: clerk_emails)
    end
  end

  def authorize_detail(conn, %User{datasheet: datasheet}) do
    branch_id = String.to_integer(conn.params["id"])

    cond do
      Datasheet.is_global_admin?(datasheet) ->
        {true, [:view, :update, :update_eligibility]}

      Datasheet.is_admin_of?(datasheet, branch_id) ->
        {true, [:view, :update]}

      Datasheet.is_global_reader?(datasheet) ->
        {true, [:view]}

      Datasheet.is_clerk_of?(datasheet, branch_id) ->
        {true, [:view]}

      true ->
        false
    end
  end

  def authorize_update(conn, user) do
    case authorize_detail(conn, user) do
      {true, abilities} ->
        if Enum.member?(abilities, :update) do
          if !Enum.member?(abilities, :update_eligibility) && eligibility_updated(conn.params) do
            false
          else
            {true, abilities}
          end
        else
          false
        end
      _ ->
        false
    end
  end

  def authorize_creation(_conn, %User{datasheet: datasheet}) do
    Datasheet.is_global_admin?(datasheet)
  end

  defp decode_email_list(encoded_emails) do
    String.split(encoded_emails, "|")
    |> Enum.filter(fn s -> String.match?(s, ~r/@/) end)
  end

  defp msg_for_staff_invites(new_datasheets) do
    case new_datasheets do
      [] ->
        "Los cambios en la filial fueron efectuados."
      [d] ->
        "Se envió una invitación a #{Datasheet.email(d)} para unirse a la filial."
      [_|_] ->
        "Se enviaron #{Enum.count(new_datasheets)} invitaciones para los nuevos miembros de la filial."
    end
  end

  defp eligibility_updated(params) do
    branch = Repo.get!(Branch, params["id"])

    case Map.fetch(params["branch"], "eligible") do
      :error ->
        false
      {:ok, value} ->
        parse_bool(value) != branch.eligible
    end
  end

  defp parse_bool(b) do
    case b do
      true -> true
      "true" -> true
      false -> false
      "false" -> false
    end
  end
end
