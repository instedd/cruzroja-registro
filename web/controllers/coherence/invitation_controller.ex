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
  alias Registro.{Country,Invitation, User, Repo, Datasheet}
  import Ecto.Changeset
  import Registro.ControllerHelpers
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
    changeset = Invitation.changeset(%Invitation{}, %{datasheet: %{country_id: Country.default.id}})

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
        cs = Invitation.generate_token(cs)
        case Config.repo.insert cs do
          {:ok, invitation} ->
            send_coherence_email :invitation, invitation, Invitation.accept_url(invitation)
            Registro.UserAuditLogEntry.add(invitation.datasheet_id, Coherence.current_user(conn), :invite_send)

            conn
            |> put_flash(:info, "Invitación enviada.")
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
        |> put_flash(:error, "Invitación inválida.")
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
        |> put_flash(:error, "Invitación inválida. Por favor contactar al personal de la filial.")
        |> redirect(to: logged_out_url(conn))
      _ ->
        changeset = User.changeset(:create_from_invitation, invite, params["user"])

        case Repo.insert changeset do
          {:ok, user} ->
            Repo.delete invite
            Registro.UserAuditLogEntry.add(user.datasheet_id, user, :invite_confirm)

            conn
            |> send_confirmation(user, user_schema)
            |> translate_flash
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
        |> put_flash(:error, "No se pudo encontrar la invitación.")
      invitation ->
        send_coherence_email :invitation, invitation,
          router_helpers.invitation_url(conn, :edit, invitation.token)
        put_flash conn, :info, "Invitación enviada."
    end
    |> redirect(to: logged_out_url(conn))
  end

  defp load_invitation_form_data(conn) do
    datasheet = Coherence.current_user(conn).datasheet
    branches = Registro.Branch.accessible_by(datasheet) |> Enum.sort_by(fn b -> b.name end)

    conn
    |> assign(:branches, branches |> Enum.map(&{&1.name, &1.id }))
    |> assign(:countries, Country.all |> Enum.map(&{&1.name, &1.id }))
    |> assign(:legal_id_kinds, LegalIdKind.all |> Enum.map(&{&1.label, &1.id }))
  end

  def add_default_datasheet_fields(invitation_params) do
    datasheet_params = invitation_params["datasheet"]
                     |> Map.merge(%{ "status" => "at_start" })

    Map.merge(invitation_params, %{ "name" => datasheet_params["first_name"],
                                    "datasheet" => datasheet_params})
  end

  def check_authorization(conn, current_user) do
    action = action_name(conn)
    is_protected_action = Enum.member?([:new, :create, :resend], action)

    if is_protected_action do
      datasheet = current_user.datasheet

      if datasheet.is_super_admin do
        true
      else
        case action do
          :new ->
            Datasheet.is_staff?(datasheet)
          _ ->
            branch_id = target_branch_id(conn.params)
            Datasheet.is_admin_of?(datasheet, branch_id) || Datasheet.is_clerk_of?(datasheet, branch_id)
        end
      end
    else
      true
    end
  end

  defp target_branch_id(params) do
    String.to_integer(params["invitation"]["datasheet"]["branch_id"])
  end
end
