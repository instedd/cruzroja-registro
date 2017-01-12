defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias __MODULE__
  alias Registro.Repo
  alias Registro.Branch
  alias Registro.Pagination

  plug Registro.Authorization, check: &BranchesController.authorize_request/2

  def index(conn, params) do
    import Ecto.Query

    page = Pagination.requested_page(params)
    total_count = Repo.aggregate(Branch, :count, :id)
    page_count = Pagination.page_count(total_count)

    {template, conn} = case params["raw"] do
                       nil ->
                         { "index.html", conn }

                       _   ->
                         { "listing.html", put_layout(conn, false) }
                     end

    branches = Pagination.all((from b in Branch, order_by: :name), page_number: page)

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

  def authorize_request(_conn, current_user) do
    current_user.datasheet.is_super_admin
  end
end
