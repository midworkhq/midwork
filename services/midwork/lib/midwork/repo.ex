defmodule Midwork.Repo do
  use Ecto.Repo,
    otp_app: :midwork,
    adapter: Ecto.Adapters.Postgres
end
