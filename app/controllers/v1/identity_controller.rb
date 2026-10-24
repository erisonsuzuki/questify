module V1
  class IdentityController < ApplicationController
    DUMMY_PASSWORD = BCrypt::Password.create(SecureRandom.hex(32)).to_s

    def bootstrap
      render_bootstrap
    end

    def guest
      return render_bootstrap if current_user
      user = User.create!(kind: "guest", last_online_at: Time.current)
      establish_session!(user, authenticated: false)
      render_bootstrap
    end

    def register
      email = normalized_email
      LoginBucket.registration!(email: email, ip: request.remote_ip)
      unless valid_registration_input?
        return api_error("invalid_input", "Confira os dados informados.", :unprocessable_entity)
      end
      if Account.exists?(email: email)
        return render json: { status: "accepted" }, status: :accepted
      end

      raw = nil
      Account.transaction do
        user = User.create!(kind: "account", last_online_at: Time.current)
        account = Account.create!(user: user, email: email, password: params[:password])
        Registration.create!(account: account,
                             source_user: current_user&.kind == "guest" ? current_user : nil)
        account.with_lock do
          raw = CredentialToken.issue!(account, purpose: "verify", lifetime: 24.hours)
        end
      end
      CredentialToken.enqueue_delivery!(raw)
      render json: { status: "accepted" }, status: :accepted
    rescue ActiveRecord::RecordNotUnique
      render json: { status: "accepted" }, status: :accepted
    rescue ActiveRecord::RecordInvalid => error
      if error.record.is_a?(Account) &&
         error.record.errors.details.fetch(:email, []).any? { |detail| detail[:error] == :taken }
        render json: { status: "accepted" }, status: :accepted
      else
        raise
      end
    end

    def login
      if current_user&.kind == "guest"
        return api_error("guest_transition_required",
                         "Exporte ou descarte seus dados de convidado antes de trocar de conta.", :conflict)
      end
      account = LoginBucket.authenticate(email: normalized_email, ip: request.remote_ip) do
        candidate = Account.find_by(email: normalized_email)
        if candidate
          # Reload credentials and issue the session under reset's account lock.
          candidate.with_lock do
            if candidate.authenticate(params[:password].to_s)
              establish_session!(candidate.user, authenticated: true)
              candidate
            else
              false
            end
          end
        else
          BCrypt::Password.new(DUMMY_PASSWORD).is_password?(params[:password].to_s)
          false
        end
      end
      return api_error("invalid_credentials", "E-mail ou senha inválidos.", :unauthorized) unless account

      render_bootstrap
    end

    def verify
      CredentialToken.consume!(params[:token], purpose: "verify") do |account|
        account.update!(verified_at: account.verified_at || Time.current)
      end
      render json: { status: "verified" }
    end

    def password_reset
      LoginBucket.mail_request!(email: normalized_email, ip: request.remote_ip)
      account = Account.find_by(email: normalized_email)
      if account
        raw = nil
        account.with_lock do
          account.credential_tokens.where(purpose: "reset", consumed_at: nil)
                 .update_all(consumed_at: Time.current, delivery_payload: nil)
          raw = CredentialToken.issue!(account, purpose: "reset", lifetime: 30.minutes)
        end
        CredentialToken.enqueue_delivery!(raw)
      end
      render json: { status: "accepted" }, status: :accepted
    end

    def consume_reset
      replacement = params[:password]
      unless replacement.is_a?(String) && !replacement.strip.empty?
        return api_error("invalid_input", "Informe uma nova senha válida.", :unprocessable_entity)
      end
      CredentialToken.consume!(params[:token], purpose: "reset") do |account|
        account.update!(password: replacement)
        account.user.access_sessions.where(revoked_at: nil).update_all(revoked_at: Time.current)
        account.credential_tokens.where(purpose: "reset", consumed_at: nil)
               .update_all(consumed_at: Time.current, delivery_payload: nil)
      end
      render json: { status: "reset" }
    end

    def recent_auth
      return unless require_account!
      confirmed = LoginBucket.confirm(account_id: current_user.account.id) do
        current_user.account.authenticate(params[:password].to_s)
      end
      return api_error("invalid_credentials", "Senha inválida.", :unauthorized) unless confirmed

      @access_session.update!(authenticated_at: Time.current)
      render json: { status: "authenticated" }
    end

    def logout
      @access_session&.update!(revoked_at: Time.current)
      reset_session
      @access_session = nil
      render json: { status: "signed_out" }
    end

    def show_session
      return unless require_user!
      owned = current_user.access_sessions.find(params[:id])
      render json: { id: owned.id }
    end

    def revoke_session
      return unless require_recent_auth!
      owned = current_user.access_sessions.find(params[:id])
      owned.update!(revoked_at: Time.current)
      render json: { status: "revoked" }
    end

    def account_capability
      return unless require_verified_account!
      render json: { verified_account: true }
    end

    private

    def normalized_email
      params[:email].to_s.strip.downcase
    end

    def valid_registration_input?
      password = params[:password]
      URI::MailTo::EMAIL_REGEXP.match?(normalized_email) &&
        password.is_a?(String) && !password.strip.empty? &&
        password.length >= 10 && password.bytesize <= 72
    end

    def render_bootstrap
      user = current_user
      render json: {
        user: user && { id: user.id, kind: user.kind, namespace: user.namespace },
        capabilities: {
          online_authority: user.present?, verified_account: user&.account&.verified? || false
        },
        csrf_token: form_authenticity_token
      }
    end
  end
end
