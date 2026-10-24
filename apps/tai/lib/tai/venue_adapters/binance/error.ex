defmodule Tai.VenueAdapters.Binance.Error do
  def normalize({:error, :timeout}), do: {:error, :timeout}
  def normalize({:error, :connect_timeout}), do: {:error, :connect_timeout}
  def normalize({:error, :receive_window}), do: {:error, :receive_window}

  def normalize({:error, {:http_error, %HTTPoison.Error{reason: reason}}})
      when reason in [:timeout, "timeout"],
      do: {:error, :timeout}

  def normalize({:error, {:http_error, %HTTPoison.Error{reason: reason}}})
      when reason in [:connect_timeout, "connect_timeout"],
      do: {:error, :connect_timeout}

  def normalize({:error, {:binance_error, %{"code" => code, "msg" => reason}}})
      when code in [-2014, -2015],
      do: {:error, {:credentials, reason}}

  def normalize({:error, {:binance_error, %{"code" => -1003}}}), do: {:error, :rate_limited}
  def normalize({:error, {:binance_error, %{"code" => -1008}}}), do: {:error, :overloaded}
  def normalize({:error, {:binance_error, %{"code" => -2011}}}), do: {:error, :not_found}

  def normalize(
        {:error,
         {:binance_error,
          %{"code" => -2010, "msg" => "Account has insufficient balance for requested action."}}}
      ),
      do: {:error, :insufficient_balance}

  def normalize({:error, {:binance_error, %{"code" => code}}}) when code in [-2018, -2019],
    do: {:error, :insufficient_balance}

  def normalize({:error, {:binance_error, %{"code" => -4061}}}),
    do: {:error, {:unhandled, :hedge_mode_not_supported}}

  def normalize({:error, reason}), do: {:error, {:unhandled, reason}}
end
