class FaxNumber < ApplicationRecord
	acts_as_paranoid
	include FaxTags

	STATE_AND_PROVINCE_NAME_TO_ABBR = {
		'Alabama' => 'AL','Alaska' => 'AK','America Samoa' => 'AS','Arizona' => 'AZ','Arkansas' => 'AR','California' => 'CA','Colorado' => 'CO','Connecticut' => 'CT','Delaware' => 'DE','District of Columbia' => 'DC','Federated States of Micronesia' => 'FM','Florida' => 'FL','Georgia' => 'GA','Guam' => 'GU','Hawaii' => 'HI','Idaho' => 'ID','Illinois' => 'IL','Indiana' => 'IN','Iowa' => 'IA','Kansas' => 'KS','Kentucky' => 'KY','Louisiana' => 'LA','Maine' => 'ME','Maryland' => 'MD','Massachusetts' => 'MA','Marshall Islands' => 'MH','Michigan' => 'MI','Minnesota' => 'MN','Mississippi' => 'MS','Missouri' => 'MO','Montana' => 'MT','Nebraska' => 'NE','Nevada' => 'NV', 'Non-Geographic' => 'Non-Geographic', 'New Hampshire' => 'NH','New Jersey' => 'NJ','New Mexico' => 'NM','New York' => 'NY','North Carolina' => 'NC','North Dakota' => 'ND','Northern Mariana Islands' => 'MP','Ohio' => 'OH','Oklahoma' => 'OK','Oregon' => 'OR','Palau' => 'PW','Pennsylvania' => 'PA','Puerto Rico' => 'PR','Rhode Island' => 'RI','South Carolina' => 'SC','South Dakota' => 'SD','Tennessee' => 'TN','Texas' => 'TX','Utah' => 'UT','Vermont' => 'VT','Virgin Island' => 'VI','Virginia' => 'VA','Washington' => 'WA','West Virginia' => 'WV','Wisconsin' => 'WI','Wyoming' => 'WY', 
		# These code chunks are the same hash, I'm seperating them for the inevitable bug that comes from hard-coding
		'Alberta'=>'AB', 'British Columbia' => 'BC', 'Manitoba' => 'MB', 'New Brunswick' => 'NB', 'Newfoundland and Labrador' => 'NL', 'Nova Scotia, Prince Edward Island' => 'NS', 'Northwest Territories, Nunavut, Yukon' => 'NT', 'Ontario' => 'ON', 'Quebec' => 'QC', 'Saskatchewan' => 'SK'
	}.freeze
	FAX_NUMBER_CHARACTER_LIMIT = 36
	FAX_NUMBER_DIGIT_LIMIT = 60

	attr_accessor :unassigned_organization_users

	belongs_to :organization, optional: true
	has_one :manager, through: :organization
	has_many :user_fax_numbers, dependent: :destroy
	has_many :users, through: :user_fax_numbers

	validates :fax_number, presence: true, length: { maximum: FAX_NUMBER_DIGIT_LIMIT }, phone: {possible: true}, uniqueness: true
	validates :label, :manager_label, length: { maximum: FAX_NUMBER_CHARACTER_LIMIT }

	before_validation :fax_number, :format_fax_number

	private
		def format_fax_number
			self.fax_number = Phonelib.parse(fax_number).e164
	  end

		class << self
			# Converts '+12223334444' to '(222) 333-4444'
			def format_pretty_fax_number(fax_number)
				return if fax_number.nil? # <-- for edge case when a User object's caller_id_number attribute is nil
				fax_number.slice(2, fax_number.length).insert(0,"(").insert(4,") ").insert(9, "-") if fax_number[0] != "("
			end

			# Converts '210' to '$2.10'
			def format_cost(cost) # this will fail if an integer with many preceding zero's (000020) is used
				"$".concat("%.2f" % (cost / 100.00))
			end

			def format_time(time)
				time.to_time.strftime("%B %-d, %Y")
			end

			def provision(area_code)
				Fax.set_phaxio_creds
				Phaxio::PhoneNumber.create({ :area_code => area_code, :country_code => 1 })
			end

			def get_area_code_list(options = {})
				Fax.set_phaxio_creds
				options.merge!({ country_code: 1, per_page: 1000 })
				begin
					area_codes_from_api = Phaxio::Public::AreaCode.list(options)
				rescue Phaxio::Error::PhaxioError => error
					area_codes_from_api = error.message
				end
				area_codes_from_api.is_a?(String) ? area_codes_from_api : format_area_codes(area_codes_from_api.raw_data, options)
			end

			def format_area_codes(area_codes_from_api, options, area_codes = {})
				area_codes_from_api = area_codes_from_api.sort_by { |area_code| area_code['area_code'] }

				area_codes_from_api.each do |area_code_object|
					area_codes[area_code_object['area_code'].to_s] = {
						city: area_code_object['city'],
						state: area_code_object['state'],
						toll_free: area_code_object['toll_free']
					}
				end
				area_codes
			end

			def create_states_for_numbers(area_codes, states = [])
				area_codes.each { |area_code_key, area_code_data| states.push(area_code_data[:state]) if !states.include?(area_code_data[:state]) }
				states.sort!
			end

			# Retrieves all fax numbers from Phaxio
			def format_and_retrieve_fax_numbers_from_api
				Fax.set_phaxio_creds
				begin
					api_response = Phaxio::PhoneNumber.list per_page: 1000
				rescue Phaxio::Error::PhaxioError => error
					api_response = error.message
				end
				api_response.is_a?(String) ? api_response : format_fax_numbers(api_response.raw_data)
			end

			# Creates a new hash with desired data from data received from the Phaxio API
			def format_fax_numbers(fax_numbers_from_api, phaxio_numbers = {})
				all_current_db_fax_numbers = FaxNumber.includes(:organization).all

				fax_numbers_from_api.each do |api_fax_number|
					phaxio_numbers[api_fax_number[:phone_number]] = {
						:city => api_fax_number[:city],
						:state => api_fax_number[:state],
						:provisioned_at => format_time(api_fax_number[:provisioned_at]),
						:cost => format_cost(api_fax_number[:cost]),
						:callback_url => !!api_fax_number[:callback_url]
					}

					db_number = all_current_db_fax_numbers.find { |db_number| db_number.fax_number == api_fax_number[:phone_number] }

					if db_number.nil?
						db_number = FaxNumber.create!(
							fax_number: api_fax_number[:phone_number],
							has_webhook_url: !!api_fax_number[:callback_url],
							org_switched_at: Time.now
							)
					else
						if db_number.has_webhook_url != !!api_fax_number[:callback_url]
							db_number.update_attributes(has_webhook_url: !!api_fax_number[:callback_url])
						end
					end

					phaxio_numbers[api_fax_number[:phone_number]][:id] = db_number.id

					# Add associated Organization data to hash
					if db_number.organization
						phaxio_numbers[api_fax_number[:phone_number]][:organization] = db_number.organization.label
						phaxio_numbers[api_fax_number[:phone_number]][:organization_id] = db_number.organization.id
					end

					phaxio_numbers[api_fax_number[:phone_number]][:label] = db_number.label if db_number.label
				end

				remove_released_fax_numbers(phaxio_numbers)
				sort_fax_numbers_by_callback_url(phaxio_numbers)
			end

			# Removes released numbers from the database and deletes them from the hash created for the table in the index view
			def remove_released_fax_numbers(phaxio_numbers)
				if phaxio_numbers.keys.count != self.count
					# Delete from database
					deleted_numbers = self.where.not({fax_number: phaxio_numbers.keys}).destroy_all
					# If a user has a deleted number as a caller_id_number, reset user's caller_id_number to nil
					deleted_numbers.each do |deleted_number|
						User.where(caller_id_number: deleted_number.fax_number).each do |user|
							user.update_attributes(caller_id_number: nil)
						end
						UserFaxNumber.where(fax_number_id: deleted_number.id).each do |user_fax_number|
							user_fax_number.destroy
						end
					end
					# Delete the removed number from the fax number hash used to populate the data table
					phaxio_numbers.each { |deleted_number| phaxio_numbers.delete(deleted_number) }
				end
			end

			# Moves all fax numbers with a fax number specific callback_url attribute to the bottom of the fax_number list
			def sort_fax_numbers_by_callback_url(phaxio_numbers)
				phaxio_numbers = phaxio_numbers.sort_by do |fax_number, data_hash|
					data_hash[:callback_url] ? 1 : data_hash[:callback_url] <=> data_hash[:callback_url]
				end
				phaxio_numbers.to_h
			end

			def get_unassigned_organization_users(fax_number)
				fax_number.organization.users.select { |org_user| !org_user.fax_numbers.include?(fax_number) && org_user.deleted_at.nil? }
			end
		end
end
