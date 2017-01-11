defmodule Registro.Coherence.InvitationController do
  @moduledoc """
  Handle invitation actions.

  Handle the following actions:

  * new - render the send invitation form.
  * create - generate and send the invitation token.
  * edit - render the form after user clicks the invitation email link.
  * create_user - create a new user database record
  * resend - resend an invitation token email
  """
  use Coherence.Web, :controller
  use Timex
  alias __MODULE__
  alias Coherence.{Config}
  alias Coherence.ControllerHelpers, as: Helpers
  alias Registro.{Invitation, User, Repo, Role, Datasheet}
  import Ecto.Changeset
  require Logger

  plug Coherence.ValidateOption, :invitable
  plug :scrub_params, "user" when action in [:create_user]
  plug :layout_view

  plug Registro.Authorization, check: &InvitationController.check_authorization/2

  @doc false
  def layout_view(conn, _) do
    conn
    |> put_layout({Registro.LayoutView, "app.html"})
    |> put_view(Coherence.InvitationView)
  end

  @doc """
  Render the new invitation form.
  """
  def new(conn, _params) do
    changeset = Invitation.changeset(%Invitation{})
    conn
    |> load_invitation_form_data
    |> render("new.html", changeset: changeset)
  end

  @doc """
  Generate and send an invitation token.

  Creates a new invitation token, save it to the database and send
  the invitation email.
  """
  def create(conn, %{"invitation" =>  invitation_params} = params) do
    repo = Config.repo
    user_schema = Config.user_schema
    email = invitation_params["email"]
    invitation_params = add_default_datasheet_fields(invitation_params)

    cs = Invitation.changeset(%Invitation{}, invitation_params)

    case repo.one from u in user_schema, where: u.email == ^email do
      nil ->
        token = random_string 48
        url = router_helpers.invitation_url(conn, :edit, token)
        cs = put_change(cs, :token, token)
        case Config.repo.insert cs do
          {:ok, invitation} ->
            send_user_email :invitation, invitation, url
            conn
            |> put_flash(:info, "Invitation sent.")
            |> redirect_to(:invitation_create, params)
          {:error, changeset} ->
            {conn, changeset} = case repo.one from i in Invitation, where: i.email == ^email do
              nil -> {conn, changeset}
              invitation ->
                {assign(conn, :invitation, invitation), add_error(changeset, :email, "Invitation already sent.")}
            end

            conn
            |> load_invitation_form_data
            |> render("new.html", changeset: changeset)
        end
      _ ->
        cs = cs
        |> add_error(:email, "User already has an account!")
        |> struct(action: true)
        conn
        |> render("new.html", changeset: cs)
    end
  end

  @doc """
  Render the create user template.

  Sets the name and email address in the form based on what was entered
  when the invitation was sent.
  """
  def edit(conn, params) do
    token = params["id"]
    where(Invitation, [u], u.token == ^token)
    |> Config.repo.one
    |> case do
      nil ->
        conn
        |> put_flash(:error, "Invalid invitation token.")
        |> redirect(to: logged_out_url(conn))
      invite ->
        user_schema = Config.user_schema
        cs = Helpers.changeset(:invitation, user_schema, user_schema.__struct__,
          %{email: invite.email, name: invite.name})
        conn
        |> render(:edit, changeset: cs, token: invite.token)
    end
  end

  @doc """
  Create a new user action.

  Create a new user based from an invite token.
  """
  def create_user(conn, params) do
    require Ecto.Query

    token = params["token"]
    user_schema = Config.user_schema

    invite = Repo.one (from i in Invitation, where: i.token == ^token, preload: [:datasheet])

    case invite do
      nil ->
        conn
        |> put_flash(:error, "Invalid Invitation. Please contact the site administrator.")
        |> redirect(to: logged_out_url(conn))
      _ ->
        changeset = User.changeset(:create_from_invitation, invite, params["user"])

        case Repo.insert changeset do
          {:ok, user} ->
            Repo.delete invite
            conn
            |> send_confirmation(user, user_schema)
            |> redirect(to: logged_out_url(conn))
          {:error, changeset} ->
            render conn, "edit.html", changeset: changeset, token: token
        end
    end
  end

  @doc """
  Resent an invitation

  Resent the invitation based on the invitation's id.
  """
  def resend(conn, %{"id" => id}) do
    case Config.repo.get(Invitation, id) do
      nil ->
        conn
        |> put_flash(:error, "Can't find that token")
      invitation ->
        send_user_email :invitation, invitation,
          router_helpers.invitation_url(conn, :edit, invitation.token)
        put_flash conn, :info, "Invitation sent."
    end
    |> redirect(to: logged_out_url(conn))
  end

  defp load_invitation_form_data(conn) do
    conn
    |> assign(:branches, Registro.Branch.all |> Enum.map(&{&1.name, &1.id }))
  end

  def add_default_datasheet_fields(invitation_params) do
    defaults = %{ "name" => invitation_params["name"], "status" => "at_start" }

    invitation_params
    |> update_in(["datasheet"], fn(dp) -> Dict.merge(dp, defaults) end)
  end

  def check_authorization(conn, current_user) do
    action = action_name(conn)
    is_protected_action = Enum.member?([:new, :create, :resend], action)

    if is_protected_action do
      %Datasheet{ role: role, branch_id: branch_id } = current_user.datasheet

      case {action, role} do
        {:new, _} ->
          Role.is_admin?(role)

        {:create, "super_admin"} ->
          true

        {:create, "branch_admin"} ->
          target_branch_id = String.to_integer(conn.params["invitation"]["datasheet"]["branch_id"])
          branch_id == target_branch_id
      end
    else
      true
    end
  end
end
