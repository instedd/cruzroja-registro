defmodule AddAddressSubfields do
  def run do
    Registro.Repo.query!("UPDATE datasheets SET address_province = 'Buenos Aires', address_city = 'Vicente Lopez', address_street = '-', address_number = 1")
  end
end

AddAddressSubfields.run()
