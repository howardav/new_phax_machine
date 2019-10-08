class PhaxMachineMailer < Devise::Mailer
  helper :application
	include Devise::Mailers::Helpers
  include Devise::Controllers::UrlHelpers
  default template_path: 'devise/mailer'
  ALTERNATE_LOGO_PATH = 'https://image4.owler.com/logo/phaxio_owler_20180322_183958_original.png'.freeze

  def manager_welcome_invite(record, token, opts = {})
  	opts[:from] = ENV["FROM_EMAIL"]
  	opts[:subject] = "You've been invited to manage #{record.organization.label}."
    @token = token
    @logo_link = LogoLink.first ? LogoLink.first.logo_url : ALTERNATE_LOGO_PATH
    devise_mail(record, :manager_welcome_invite, opts)
  end

  def user_welcome_invite(record, token, opts = {})
  	opts[:from] = record.manager&.email || ENV.fetch('FROM_EMAIL', 'phax_machine@phaxio.com')
  	opts[:subject] = "You've been invited to Phax Machine."
    @token = token
    @logo_link = LogoLink.first ? LogoLink.first.logo_url : ALTERNATE_LOGO_PATH
    devise_mail(record, :user_welcome_invite, opts)
  end

  def admin_welcome_invite(record, token, opts = {})
  	opts[:subject] = "You've been invited to be the administrator of Phax Machine"
    @token = token
    @logo_link = LogoLink.first ? LogoLink.first.logo_url : ALTERNATE_LOGO_PATH
    devise_mail(record, :admin_welcome_invite, opts)
  end

  def reset_password_instructions(record, token, opts = {})
  	@token = token
  	@logo_link = LogoLink.first ? LogoLink.first.logo_url : ALTERNATE_LOGO_PATH
    devise_mail(record, :reset_password_instructions, opts)
  end
end
