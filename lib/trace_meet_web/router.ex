defmodule TraceMeetWeb.Router do
  use TraceMeetWeb, :router

  import TraceMeetWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TraceMeetWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TraceMeetWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/users/register", UserRegistrationController, :create
    post "/users/log_in", UserSessionController, :create
    post "/users/log_out", UserSessionController, :delete
  end

  scope "/", TraceMeetWeb do
    pipe_through :browser

    live_session :public_only,
      on_mount: [
        {TraceMeetWeb.UserAuth, :mount_current_user},
        {TraceMeetWeb.UserAuth, :redirect_if_authenticated}
      ] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
    end

    live_session :authenticated,
      on_mount: [
        {TraceMeetWeb.UserAuth, :mount_current_user},
        {TraceMeetWeb.UserAuth, :ensure_authenticated}
      ] do
      live "/dashboard", DashboardLive, :index
      live "/clients", ClientLive.Index, :index
      live "/clients/new", ClientLive.Form, :new
      live "/clients/:id", ClientLive.Show, :show
      live "/clients/:id/edit", ClientLive.Form, :edit
      live "/meetings", MeetingLive.Index, :index
      live "/meetings/new", MeetingLive.Form, :new
      live "/meetings/:id", MeetingLive.Show, :show
      live "/meetings/:id/edit", MeetingLive.Form, :edit
      live "/clients/:client_id/meetings/new", MeetingLive.Form, :new
      live "/settings/ai-configuration", AIConfigurationLive.Index, :index
      live "/settings/profile", PlaceholderLive, :settings_profile
      live "/settings/preferences", PlaceholderLive, :settings_preferences
      live "/settings/security", PlaceholderLive, :settings_security
      live "/actions", ActionsLive.Index, :index
      live "/settings", PlaceholderLive, :settings
    end
  end

  if Application.compile_env(:trace_meet, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: TraceMeetWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
