defmodule Recaptcha do

  def verify(captcha_response) do
    case skip? do
      true ->
        :ok
      false ->
        case post_response(captcha_response) do
          {:ok, response} ->
            case Poison.decode(response.body) do
              {:ok, %{"success" => true}} ->
                :ok
              {:ok, _failed_json_response} ->
                :error
              {:error, _parse_error} ->
                :error
            end
          {:error, _http_error} ->
            :error
        end
    end
  end

  def site_key do
    get_setting(:site_key)
  end

  defp secret_key do
    get_setting(:secret_key)
  end

  def skip? do
    get_setting(:skip) || false
  end

  defp get_setting(key) do
    case Application.get_env(:registro, :recaptcha)[key] do
      {:system, env_key} ->
        System.get_env env_key
      value ->
        value
    end
  end

  defp post_response(captcha_response) do
    url = "https://www.google.com/recaptcha/api/siteverify?secret=#{secret_key}&response=#{captcha_response}"
    HTTPoison.post(url, "")
  end

end
