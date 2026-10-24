Rails.application.routes.draw do
  get "up", to: "rails/health#show", as: :rails_health_check
  namespace :v1 do
    get "bootstrap", to: "identity#bootstrap"
    post "guest", to: "identity#guest"
    post "register", to: "identity#register"
    post "login", to: "identity#login"
    post "verify", to: "identity#verify"
    post "password_reset", to: "identity#password_reset"
    post "password_reset/consume", to: "identity#consume_reset"
    post "recent_auth", to: "identity#recent_auth"
    delete "session", to: "identity#logout"
    get "sessions/:id", to: "identity#show_session"
    delete "sessions/:id", to: "identity#revoke_session"
    get "account_capability", to: "identity#account_capability"
  end
  root "shell#show"
end
