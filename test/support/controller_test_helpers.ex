defmodule Registro.ControllerTestHelpers do

  alias Registro.Repo
  alias Registro.{Branch, User, Role}

  def log_in(conn, %User{} = user) do
    Plug.Conn.assign(conn, :current_user, user)
  end

  def log_in(conn, email) do
    user = Repo.get_by!(User, email: email)
    log_in(conn, user)
  end

  def create_user(email: email, role: role) do
    create_user(email: email, role: role, branch_id: nil)
  end

  def create_user(email: email, role: role, branch_id: branch_id) do
    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated",
          password_confirmation: "generated",
          datasheet: %{
            name: "generated #{role}",
            role: role,
            branch_id: branch_id,
            status: (if Role.is_admin?(role), do: nil, else: "at_start")
          }
    })
    Repo.insert! changeset
  end

  def create_branch(name: name) do
    changeset = Branch.changeset(%Branch{}, %{
          name: name,
          address: "generated"
    })
    Repo.insert! changeset
  end
end
