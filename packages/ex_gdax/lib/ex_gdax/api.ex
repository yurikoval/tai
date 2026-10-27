defmodule ExGdax.Api do
  @moduledoc """
  Provides the basic HTTP interface for the Coinbase Exchange API.
  """
  alias ExGdax.{Config, Auth}

  def public_get(path, params \\ %{}, config \\ nil) do
    config = Config.config_or_env_config(config)
    qs = query_string(path, params)

    qs
    |> url(config)
    |> HTTPoison.get("Content-Type": "application/json")
    |> parse_response()
  end

  def get(path, params \\ %{}, config \\ nil) do
    config = Config.config_or_env_config(config)
    qs = query_string(path, params)

    qs
    |> url(config)
    |> HTTPoison.get(headers("GET", qs, %{}, config))
    |> parse_response()
  end

  def post(path, params \\ %{}, config \\ nil) do
    config = Config.config_or_env_config(config)

    path
    |> url(config)
    |> HTTPoison.post(Poison.encode!(params), headers("POST", path, params, config))
    |> parse_response()
  end

  def delete(path, config \\ nil) do
    config = Config.config_or_env_config(config)

    path
    |> url(config)
    |> HTTPoison.delete(headers("DELETE", path, %{}, config))
    |> parse_response()
  end

  defp url(path, config), do: config.api_url <> path

  defp query_string(path, params) when map_size(params) == 0, do: path

  defp query_string(path, params) do
    query = Enum.map_join(params, "&", fn {key, val} -> "#{key}=#{val}" end)

    path <> "?" <> query
  end

  defp headers(method, path, body, config) do
    timestamp = :os.system_time(:seconds) |> Integer.to_string()

    [
      "Content-Type": "application/json",
      "CB-ACCESS-KEY": config.api_key,
      "CB-ACCESS-SIGN": Auth.sign_request(timestamp, method, path, body, config),
      "CB-ACCESS-TIMESTAMP": timestamp,
      "CB-ACCESS-PASSPHRASE": config.api_passphrase
    ]
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: code}})
       when code in 200..299 do
    case Poison.decode(body) do
      {:ok, json} -> {:ok, json}
      {:error, _} -> {:error, {:invalid_json, body}}
    end
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: code}}) do
    case Poison.decode(body) do
      {:ok, %{"message" => message}} -> {:error, message, code}
      {:ok, json} -> {:error, json, code}
      {:error, _} -> {:error, body, code}
    end
  end

  defp parse_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, reason}
end
