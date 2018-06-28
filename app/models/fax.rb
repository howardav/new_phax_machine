class Fax
	class << self
		def get_fax_information(sent_fax_object)
			Phaxio::Fax.get(sent_fax_object.get.id)
		end

		def create_fax(options)
			Phaxio::Fax.create(
				to: options[:to],
				file: options[:files],
				caller_id: options[:caller_id_number],
				tag: {
					sender_client_fax_tag: options[:sender_client_fax_tag],
					sender_email_fax_tag: options[:sender_email_fax_tag],
				},
			)
		end

		def send_fax_from_email(sender, recipient, files)
			set_phaxio_creds
			p "IN THE SEND_FAX_FROM_EMAIL METHOD"
			p sender.downcase
			user_email = UserEmail.find_by(email_address: sender.downcase)
			p "==================================================================="
			p user_email
      number = Mail::Address.new(recipient).local

      options = {
      	to: number,
      	caller_id: user_email.caller_id_number,
      	sender_client_fax_tag: user_email.client.fax_tag,
      	send_email_fax_tag: user_email.fax_tag,
      	files: files.map { |file| File.new(file) }
      }

      sent_fax_object = create_fax(options)
     	api_response = Fax.get_fax_information(sent_fax_object)
      p api_response
      # send an email to the sender if it fails
    end

		# if there are two error_codes with the same frequency, the error found first (first recipient) takes precedence
		def most_common_error(fax, errors = {})
			fax["recipients"].each do |recipient|
		  	key = recipient["error_code"]
		  	errors.has_key?(key) ? errors[key]["frequency"] += 1 : errors[key] = {"frequency" => 1}
			end
	  	errors.max_by { |error_code, amount| amount["frequency"] }.shift
		end

		def set_phaxio_creds
			Phaxio.api_key = ENV.fetch('PHAXIO_API_KEY')
			Phaxio.api_secret = ENV.fetch('PHAXIO_API_SECRET')
		end
	end
end