defmodule ImportAssociates do
  def parse_branch_line(line) do
    line
    |> String.replace("\n", "")
    |> String.split(",")
  end

  def clean(string) do
    res = string
          |> String.trim
          |> String.replace("\"","")
          |> String.replace("NULL","")
          |> String.replace("0000-00-00","")
    if res == "" do
      nil
    else
      res
    end
  end

  def date(s) do
    case clean(s) do
      nil -> nil
      d -> case Date.from_iso8601(d) do
        {:ok, e} -> e
        {:error, _} -> nil
      end
    end
  end

  def number(s) do
    case clean(s) do
      nil -> nil
      n -> case Integer.parse(n) do
        {m, _} -> m
        _ -> nil
      end
    end
  end

  def run do
    File.stream!("priv/data/rrhh.csv")
    |> CSV.decode
    |> Enum.each(fn line ->
      [img,reg_number,reg_date,reg_end_date,antiq,last_name,first_name,sex,birth_date,nationality,id_type,id_number,cuil,password,priviledge,passport,passport_expiry_date,blood_type,blood_factor,address_street,address_number,address_floor,address_block,address_apartement,address_neighbourhood,address_city,postal_code,district,address_province,home_phone,home_phone_area,mobile_phone,mobile_phone_area,work_phone,work_phone_area,other_phone,other_phone_area,email,email2,marital_status,children,school_education,school_title,current_school,occupation,driving_license,comments,branch,admittance_date,kind,associate_mode,branch_role,representative_title,hired_condition,hired_working_hours,empty,school_name,school_topic,second_language,third_language,fourth_language,fifth_language,school_location,school_passed_courses_count,school_pending_courses_count,school_current_year,school_year_start,school_year_end,school_estimated_year_end,school_average,school_observations,job_title,company,job_start,empty2,job_responsabilities,job_observations,associate_mode2,reg_date2,empty3,empty4,empty5,empty6,empty7,empty8,recruitment_kind,empty9,fib,fib_by_whom,sigrid_profile_id,extranet_profile_id] = line

      Registro.Repo.query!("INSERT INTO imported_users (legal_id_kind,legal_id,first_name,last_name,birth_date,occupation,phone_number,registration_date,address_street,address_number,address_block,address_floor,address_apartement,address_city,address_province,postal_code,is_paying_associate,role,email,sigrid_profile_id,extranet_profile_id) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21)", [clean(id_type),clean(id_number),clean(first_name),clean(last_name),date(birth_date),clean(occupation),clean(mobile_phone),date(reg_date2),clean(address_street),number(address_number),clean(address_block),number(address_floor),clean(address_apartement),clean(address_city),clean(address_province),number(postal_code),!String.contains?(associate_mode,"(TV)"),"associate",clean(email),number(sigrid_profile_id),number(extranet_profile_id)])
    end)
  end
end

ImportAssociates.run()
