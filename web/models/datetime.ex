defmodule Registro.DateTime do

  # This is set for argentinian timezone: UTC-3
  def to_local(datetime) do
    seconds = :calendar.datetime_to_gregorian_seconds(NaiveDateTime.to_erl(datetime))
    res = seconds - 3 * 3600
    res = :calendar.gregorian_seconds_to_datetime(res)
    elem(NaiveDateTime.from_erl(res), 1)
  end

  def format_date(datetime) do
    to_string(datetime.day) <> "/" <> to_string(datetime.month) <> "/" <> to_string(datetime.year)
  end

  def format_time(datetime) do
    zero_padded(datetime.hour) <> ":" <> zero_padded(datetime.minute)
  end

  defp zero_padded(number) do
    if number < 10 do
      "0" <> to_string(number)
    else
      to_string(number)
    end
  end
end
