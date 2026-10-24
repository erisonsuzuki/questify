Rails.application.config.session_store(
  :cookie_store,
  key: "_questify_session",
  httponly: true,
  secure: Rails.env.production?,
  same_site: :lax,
  expire_after: 30.days
)
