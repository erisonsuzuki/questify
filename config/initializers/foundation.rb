Rails.application.config.action_controller.forgery_protection_origin_check = true
Rails.application.config.filter_parameters += %i[
  password password_confirmation token verification_token reset_token
  authorization cookie email
]
ActiveJob::Base.log_arguments = false
ActionMailer::Base.logger = nil
