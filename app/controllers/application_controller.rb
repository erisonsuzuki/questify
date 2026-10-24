class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :private_response
  before_action :resolve_access_session

  rescue_from ActionController::InvalidAuthenticityToken do
    api_error("csrf_rejected", "Recarregue a página para continuar.", :forbidden)
  end
  rescue_from ActiveRecord::RecordNotFound do
    api_error("not_found", "Não encontrado.", :not_found)
  end
  rescue_from ActiveRecord::RecordInvalid do
    api_error("invalid_input", "Confira os dados informados.", :unprocessable_entity)
  end
  rescue_from CredentialToken::Invalid do
    api_error("invalid_token", "Link inválido ou expirado.", :unprocessable_entity)
  end
  rescue_from LoginBucket::Limited do |error|
    response.headers["Retry-After"] = error.retry_after.to_s
    api_error("rate_limited", "Tente novamente mais tarde.", :too_many_requests)
  end
  rescue_from LoginBucket::InvalidConfiguration do
    api_error("security_configuration_required", "Entrada temporariamente indisponível.", :service_unavailable)
  end

  private

  def private_response
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def resolve_access_session
    @access_session = AccessSession.find_by(id: session[:access_session_id])
    unless @access_session&.active?
      @access_session&.update!(revoked_at: Time.current) unless @access_session&.revoked_at
      @access_session = nil
      session.delete(:access_session_id)
      return
    end
    @access_session.update!(last_seen_at: Time.current)
    @access_session.user.update!(last_online_at: Time.current)
  end

  def current_user
    @access_session&.user
  end

  def require_user!
    return true if current_user
    api_error("session_required", "Entre novamente para continuar.", :unauthorized)
    false
  end

  def require_account!
    return false unless require_user!
    return true if current_user.account
    api_error("account_required", "Esta ação exige uma conta.", :forbidden)
    false
  end

  def require_verified_account!
    return false unless require_account!
    return true if current_user.account.verified?
    api_error("verification_required", "Confirme seu e-mail.", :forbidden)
    false
  end

  def require_recent_auth!
    return false unless require_account!
    return true if @access_session.recent?
    api_error("recent_auth_required", "Confirme sua senha novamente.", :forbidden)
    false
  end

  def establish_session!(user, authenticated:)
    @access_session&.update!(revoked_at: Time.current)
    reset_session
    @access_session = AccessSession.create!(
      user: user, last_seen_at: Time.current, absolute_expires_at: 30.days.from_now,
      authenticated_at: authenticated ? Time.current : nil
    )
    session[:access_session_id] = @access_session.id
  end

  def api_error(code, message, status)
    render json: { error: { code: code, message: message } }, status: status
  end
end
