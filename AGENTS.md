# Agent guide

## Repository map

- `apps/tai`: the main Tai application and its tests.
- `apps/examples`: example applications in the root umbrella.
- `packages/tai_events`: a standalone package, not an umbrella child.
- `config`: root umbrella configuration.
- `docs`: user and architecture documentation.

Use Erlang/OTP 27.3 and Elixir 1.20.4-otp-27, as pinned in `.tool-versions`.

## Code map

- `apps/tai/lib/tai/venues` and `venue_adapters`: exchange configuration, clients, streams, and venue-specific normalization.
- `apps/tai/lib/tai/markets`: products, quotes, trades, order books, and in-memory stores.
- `apps/tai/lib/tai/orders`: order persistence, submissions, workers, queries, and lifecycle transitions.
- `apps/tai/lib/tai/advisors` and `fleets`: strategy processes and their supervision/configuration.
- `apps/tai/lib/tai/events`: serializable domain events; the event bus implementation is in `packages/tai_events`.
- `apps/examples`: executable examples and end-to-end support.

Tests mirror these areas under `apps/tai/test/tai`. Start with the matching focused test rather than the whole suite.

## Project boundaries

The root Mix project is an umbrella containing only `apps/*`. It does not include `packages/tai_events` as an umbrella child, but `apps/tai` uses it through a local path dependency. Root compilation exercises the package code; its ExUnit suite still requires a separate test run from that directory.

The standalone package shares the root `_build`, `deps`, and `mix.lock`. Run its tests after root checks to avoid changing shared artifacts before umbrella verification.

## Safe workflow

- Never use, read, copy, print, or modify real API keys, exchange credentials, account data, or other secrets.
- Never enable live order submission, connect tests to live trading venues, or record/re-record network cassettes without explicit user approval.
- Do not run `iex -S mix`, `mix run`, or otherwise start the development application without approval; development configuration starts external venue streams.
- Preserve the default `send_orders: false` safety setting outside tests.
- Use existing test fixtures and recorded cassettes. Keep tests deterministic and offline.
- Do not weaken safety checks or replace fixture credentials with real values.
- `mix tai.gen.migration` generates files under `apps/tai/priv/order_repo/migrations`; that output is ignored and must not be committed.

## Commands

Install dependencies and prepare the root project:

```bash
mix deps.get
mix setup
```

Run a focused root test from the repository root:

```bash
mix test apps/tai/test/path/to/test.exs
```

Run a focused standalone package test:

```bash
cd packages/tai_events
CI=true mix test test/path/to/test.exs
```

Run the complete local verification before handing off changes:

```bash
bin/check
```

`bin/check` assumes dependencies are installed. It generates migrations, checks formatting, runs root tests and Dialyzer, then checks and tests standalone `tai_events` last.
