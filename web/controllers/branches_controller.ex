defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.{Repo, Branch, Pagination, Datasheet, User}

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
    branch = Repo.one(from u in Branch, where: u.id == ^params["id"])
    changeset = Branch.changeset(branch)

    conn
    |> render("show.html", changeset: changeset, branch: branch)
  end

  def update(conn, %{"branch" => branch_params} = params) do
    branch = Repo.get(Branch, params["id"])
    changeset = Branch.changeset(branch, branch_params)
    case Repo.update(changeset) do
      {:ok, _branch} ->
        conn
        |> put_flash(:info, "Los cambios en la filial fueron efectuados.")
        |> redirect(to: branches_path(conn, :index))
      {:error, changeset} ->
        render(conn, "show.html", changeset: changeset)
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
end
