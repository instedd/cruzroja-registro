defmodule FillVolunteerToAssociateDate do
  def run do
    Registro.Repo.query!("UPDATE datasheets SET volunteer_to_associate_date = registration_date WHERE role = 'associate'")
  end
end

FillVolunteerToAssociateDate.run()
