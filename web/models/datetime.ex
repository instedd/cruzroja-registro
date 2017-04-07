defmodule Registro.DateTime do
  # Finally added Timex as a dependency.
  # We might want to start switching all these to Timex whenever possible.

  def now() do
    :calendar.universal_time()
  end

  def now_locally() do
    Registro.DateTime.to_local(Registro.DateTime.now())
  end

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

  def less_than_a_year_ago?(d) do
    a_year_ago = Timex.Date.today |> Timex.shift(years: -1)
    {:ok, erl_date} = d |> Ecto.Date.cast! |> Ecto.Date.dump
    before_a_year_ago = Timex.to_date(erl_date) |> Timex.before?(a_year_ago)

    !before_a_year_ago
  end
end
