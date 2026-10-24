import Config

# OrderRepo
config :tai, Tai.Orders.OrderRepo, pool_size: 10

if System.get_env("ORDER_REPO_ADAPTER") == "postgres" do
  default_database_url = "postgres://postgres:postgres@localhost:5432/tai_?"
  configured_database_url = System.get_env("DATABASE_URL") || default_database_url
  database_url = String.replace(configured_database_url, "?", "dev")
  config :tai, Tai.Orders.OrderRepo, url: database_url
end

# Toolkit
config :tai, send_orders: false
config :tai, broadcast_change_set: true
config :tai, venues: %{}

# Logger
config :logger, utc_log: true

if config_env() != :test do
  config :logger, backends: [{LoggerFileBackendWithFormatters, :file_log}]
  config :logger, :file_log, path: "./log/#{Mix.env()}.log"
end

# Conditional configuration
if config_env() == :dev do
  config :libcluster,
    topologies: [
      gossip: [
        strategy: Cluster.Strategy.Gossip
      ]
    ]

  config :tai, Tai.Orders.OrderRepo, show_sensitive_data_on_connection_error: true

  config :tai,
    fleets: %{
      log_spread: %{
        advisor: Examples.LogSpread.Advisor,
        factory: Tai.Advisors.Factories.OnePerProduct,
        # TODO: Support other types of streams e.g...
        # index_streams: "btc_usd",
        # candle_streams: %{
        #   min_1: "binance.btc_usdt gdax.btc_usd"
        # },
        # indicator_streams: %{
        #   distance_from_mean_avg_fast: "binance.btc_usdt gdax.btc_usd",
        #   distance_from_mean_avg_slow: "binance.btc_usdt gdax.btc_usd"
        # }
        market_streams: "binance.btc_usdt gdax.btc_usd"
      },
      log_trade: %{
        advisor: Examples.LogTrade.Advisor,
        factory: Tai.Advisors.Factories.OnePerProduct,
        market_streams: "binance.btc_usdt"
      }
    }

  config :tai,
    venues: %{
      binance: [
        start_on_boot: true,
        adapter: Tai.VenueAdapters.Binance,
        products: "btc_usdt ltc_usdt eth_usdt"
      ],
      gdax: [
        start_on_boot: true,
        adapter: Tai.VenueAdapters.Gdax,
        products: "btc_usd eth_usd",
        market_streams: "* -eth_usd"
      ],
      delta_exchange: [
        start_on_boot: true,
        adapter: Tai.VenueAdapters.DeltaExchange,
        products: "*",
        # market_streams: "btcusdt"
        market_streams: "*"
      ]
    }

  # TODO: Calculate an index value on each tick
  # config :tai, indexes: %{
  #   btc_usd: []
  # }

  # TODO: Calculate an indicator value on each tick
  # config :tai, indicators: %{
  #   distance_from_mean_avg_fast: {Examples.Indicators.DistanceFromMean, :calculate, [period: :min_1, avg_periods: 1440]},
  #   distance_from_mean_avg_slow: {Examples.Indicators.DistanceFromMean, :calculate, [period: :min_1, avg_periods: 10080]},
  # }
end

if config_env() == :test do
  test_credential = Base.encode64("test")

  config :examples, :e2e_mappings, %{
    log_spread: ExamplesSupport.E2E.LogSpread,
    log_trade: ExamplesSupport.E2E.LogTrade,
    ping_pong: ExamplesSupport.E2E.PingPong
  }

  config :tai, Tai.Orders.OrderRepo,
    pool: Ecto.Adapters.SQL.Sandbox,
    show_sensitive_data_on_connection_error: true

  config :tai, send_orders: true
  config :tai, e2e_app: :examples

  config :tai,
    test_venue_adapters: %{
      mock: [
        enabled: true,
        adapter: Tai.VenueAdapters.Mock,
        credentials: %{main: %{}},
        opts: %{}
      ],
      bybit: [
        enabled: true,
        adapter: Tai.VenueAdapters.Bybit
      ],
      okex: [
        enabled: true,
        adapter: Tai.VenueAdapters.OkEx,
        credentials: %{
          main: %{
            api_key: test_credential,
            api_secret: test_credential,
            api_passphrase: test_credential
          }
        },
        opts: %{}
      ],
      okex_futures: [
        enabled: true,
        adapter: Tai.VenueAdapters.OkEx,
        credentials: %{
          main: %{
            api_key: test_credential,
            api_secret: test_credential,
            api_passphrase: test_credential
          }
        },
        opts: %{}
      ],
      okex_swap: [
        enabled: true,
        adapter: Tai.VenueAdapters.OkEx,
        credentials: %{
          main: %{
            api_key: test_credential,
            api_secret: test_credential,
            api_passphrase: test_credential
          }
        },
        opts: %{}
      ],
      okex_spot: [
        enabled: true,
        adapter: Tai.VenueAdapters.OkEx,
        credentials: %{
          main: %{
            api_key: test_credential,
            api_secret: test_credential,
            api_passphrase: test_credential
          }
        },
        opts: %{}
      ],
      huobi: [
        enabled: true,
        adapter: Tai.VenueAdapters.Huobi,
        opts: %{}
      ],
      huobi_futures: [
        enabled: true,
        adapter: Tai.VenueAdapters.Huobi,
        opts: %{}
      ],
      binance: [
        enabled: true,
        adapter: Tai.VenueAdapters.Binance,
        credentials: %{
          main: %{
            api_key: test_credential,
            secret_key: test_credential
          }
        }
      ],
      deribit: [
        enabled: true,
        adapter: Tai.VenueAdapters.Deribit,
        credentials: %{
          main: %{
            client_id: test_credential,
            client_secret: test_credential
          }
        }
      ],
      gdax: [
        enabled: true,
        adapter: Tai.VenueAdapters.Gdax,
        credentials: %{
          main: %{
            api_url: "https://api-public.sandbox.pro.coinbase.com",
            api_key: test_credential,
            api_secret: test_credential,
            api_passphrase: test_credential
          }
        }
      ],
      delta_exchange: [
        enabled: true,
        adapter: Tai.VenueAdapters.DeltaExchange,
        credentials: %{
          main: %{
            api_key: test_credential,
            api_secret: test_credential
          }
        }
      ]
    }

  config :tai, :test_venue_adapters_products, [
    :binance,
    :bybit,
    :deribit,
    :gdax,
    :mock,
    :okex,
    :huobi,
    :delta_exchange
  ]

  config :tai, :test_venue_adapters_accounts, [
    :binance,
    :deribit,
    :gdax,
    :mock,
    :okex
  ]

  config :tai, :test_venue_adapters_accounts_error, []
  config :tai, :test_venue_adapters_maker_taker_fees, [:mock, :binance, :gdax, :okex]

  config :tai, :test_venue_adapters_create_order_gtc_accepted, [
    :binance,
    :okex_futures,
    :okex_spot,
    :okex_swap
  ]

  config :tai, :test_venue_adapters_create_order_fok, [:binance]
  config :tai, :test_venue_adapters_create_order_ioc, []
  config :tai, :test_venue_adapters_create_order_ioc_accepted, [:binance]
  config :tai, :test_venue_adapters_create_order_close, [:okex_futures, :okex_swap]

  config :tai, :test_venue_adapters_create_order_error, []
  config :tai, :test_venue_adapters_create_order_error_size_too_small, []

  config :tai, :test_venue_adapters_create_order_error_insufficient_balance, [
    :okex_futures,
    :okex_swap,
    :binance
  ]

  config :tai, :test_venue_adapters_amend_order_accepted, []
  config :tai, :test_venue_adapters_amend_bulk_order_accepted, []

  config :tai, :test_venue_adapters_cancel_order_accepted, [
    :binance,
    :okex_futures,
    :okex_swap,
    :okex_spot
  ]

  config :tai, :test_venue_adapters_cancel_order_error_not_found, [
    :binance,
    :okex_futures,
    :okex_swap
  ]

  config :tai, :test_venue_adapters_cancel_order_error_timeout, [
    :okex_futures,
    :okex_swap
  ]

  config :tai, :test_venue_adapters_cancel_order_error_overloaded, []
  config :tai, :test_venue_adapters_cancel_order_error_nonce_not_increasing, []
  config :tai, :test_venue_adapters_cancel_order_error_rate_limited, []
  config :tai, :test_venue_adapters_cancel_order_error_unhandled, [:binance]
  config :tai, :test_venue_adapters_with_positions, [:deribit, :okex]

  config :exvcr,
    filter_request_headers: [
      # GDAX
      "CB-ACCESS-KEY",
      "CB-ACCESS-SIGN",
      "CB-ACCESS-TIMESTAMP",
      "CB-ACCESS-PASSPHRASE",
      # Binance
      "X-MBX-APIKEY",
      # OkEx
      "OK-ACCESS-KEY",
      "OK-ACCESS-SIGN",
      "OK-ACCESS-TIMESTAMP",
      "OK-ACCESS-PASSPHRASE",
      # Deribit
      "Authorization",
      # Delta Exchange
      "api-key",
      "signature",
      "timestamp"
    ],
    filter_sensitive_data: [
      # GDAX
      [pattern: "\"id\":\"[a-z0-9-]{36,36}\"", placeholder: "\"id\":\"***\""],
      [pattern: "\"profile_id\":\"[a-z0-9-]{36,36}\"", placeholder: "\"profile_id\":\"***\""],
      # Binance
      [pattern: "signature=[A-Z0-9]+", placeholder: "signature=***"]
    ],
    response_headers_blacklist: [
      # Shared
      "Set-Cookie",
      "ETag",
      "cf-request-id",
      "CF-RAY"
    ]

  config :echo_boy, port: 4100

  config :ex_deribit, domain: "test.deribit.com"
end
