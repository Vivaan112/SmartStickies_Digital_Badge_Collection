defmodule BadgeCollectorWeb.Router do
  use BadgeCollectorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug BadgeCollectorWeb.AuthPipeline
  end

  scope "/api", BadgeCollectorWeb do
    pipe_through :api

    post "/login", SessionController, :login
    post "/signup", SessionController, :signup
  end

  scope "/api", BadgeCollectorWeb do
    pipe_through [:api, :auth]

    # singleton because we use the guardian token as id
    resources "/badges", BadgeController, only: [:show], singleton: true
    resources "/actions", ActionController, only: [:create], singleton: true

    delete "/delete", UserController, :delete
  end
end
