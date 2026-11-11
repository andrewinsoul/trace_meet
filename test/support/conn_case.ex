defmodule TraceMeetWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint TraceMeetWeb.Endpoint

      use TraceMeetWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import TraceMeetWeb.ConnCase
    end
  end

  setup tags do
    TraceMeet.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
