class CredentialDeliveryJob < ApplicationJob
  self.log_arguments = false
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(token_id)
    row = CredentialToken.find_by(id: token_id)
    return unless row

    # Match consumption's account-then-token lock order.
    row.account.with_lock do
      row.with_lock do
        if row.consumed_at || row.expires_at <= Time.current
          row.update!(delivery_payload: nil)
          return
        end
        return unless row.delivery_payload

        raw = CredentialToken.delivery_encryptor.decrypt_and_verify(row.delivery_payload)
        IdentityMailer.link(row.account.email, row.purpose, raw).deliver_now
        row.update!(delivery_payload: nil)
      end
    end
  end
end
