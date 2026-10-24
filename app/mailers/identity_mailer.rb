class IdentityMailer < ApplicationMailer
  self.logger = nil
  default from: "nao-responda@questify.invalid"

  def link(email, purpose, token)
    subject = purpose == "verify" ? "Confirme seu e-mail" : "Redefina sua senha"
    host = Rails.application.config.action_mailer.default_url_options.fetch(:host)
    port = Rails.application.config.action_mailer.default_url_options[:port]
    authority = port ? "#{host}:#{port}" : host
    scheme = Rails.env.production? ? "https" : "http"
    url = "#{scheme}://#{authority}/##{purpose}=#{token}"
    mail(to: email, subject: subject) do |format|
      format.text { render plain: "#{subject}: #{url}" }
    end
  end
end
