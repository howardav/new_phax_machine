class FaxNumbersController < ApplicationController
	include SessionsHelper

	before_action :verify_is_admin, only: [:index]
	before_action :set_fax_number, only: [:edit, :update]
	before_action :verify_authorized, except: [:create, :new]
	before_action :verify_can_purchase_numbers, only: [:new, :create]

	# Table of all fax numbers in your account
	def index
		area_codes = FaxNumber.get_area_code_list(list_area_code_params)
		if area_codes.is_a?(String)
			flash[:alert] = area_codes
			# Weird redirect because the root path for admin is the fax_num index, so this avoids and infinite redirect loop
			redirect_to(fax_logs_path)
		else
			@area_codes = area_codes
			@states = FaxNumber.create_states_for_numbers(area_codes)
		end

		@fax_numbers = FaxNumber.format_and_retrieve_fax_numbers_from_api
		if @fax_numbers.is_a?(String)
			flash[:alert] = @fax_numbers
			redirect_to(fax_logs_path)
		end
	end

	# Purchase Number Form page
	def new
		verify_is_manager_or_admin
		area_codes = FaxNumber.get_area_code_list
		if area_codes.is_a?(String)
			flash[:alert] = area_codes
			redirect_to(fax_logs_path)
		else
			@area_codes = area_codes
			@states = FaxNumber.create_states_for_numbers(area_codes)
		end
	end

	 # Post request for purchasing the new number
	def create
		api_response = FaxNumber.provision(provision_number_params[:area_code])
		if api_response.phone_number
			FaxNumber.create!(fax_number: api_response.phone_number, has_webhook_url: false, org_switched_at: Time.now)
			flash[:notice] = "Fax number provisioned successfully. Your new number is #{FaxNumber.format_pretty_fax_number(api_response.phone_number)}."

			# Adds fax number to the organization immediately 
			if provision_number_params[:organization_id]
				number = FaxNumber.find_by(fax_number: api_response.phone_number)
				number.update_attributes(organization_id: provision_number_params[:organization_id])
				redirect_to organization_path(provision_number_params[:organization_id])
			else
				redirect_to fax_numbers_path
			end
		else
			flash[:alert] = "Something went wrong"
			render :new
		end
	end

	# Form for editing a fax number
	def edit
		@user = User.new
		@organizations = Organization.order(label: :asc) if is_admin?
	end

	def update
		param_filter_type = is_admin? ? admin_fax_number_params : manager_fax_number_params
		original_organization = @fax_number.organization

		if @fax_number.update_attributes(param_filter_type)
			# this if block spoofs the "user[:to_remove]" portion of params by creating and passing in a similar hash
			if original_organization && original_organization.id != @fax_number.organization_id
				User.where(caller_id_number: @fax_number.fax_number).all.each { |user| user.update_attributes(caller_id_number: nil) }
				@fax_number.update_attributes(manager_label: nil, org_switched_at: Time.now)
				original_organization_user_ids = {}
				original_organization.users.each { |user| original_organization_user_ids[user.id] = 'on' }
				remove_user_associations(original_organization_user_ids, @fax_number)
			end

			flash[:notice] = "Changes successfully saved."
			is_admin? ? redirect_to(fax_numbers_path) : redirect_to(organization_path(@fax_number.organization))
		else
			flash[:alert] = @fax_number.errors.full_messages.pop
			redirect_to(edit_fax_number_path(@fax_number))
		end
	end

	private
		def set_fax_number
			@fax_number ||= FaxNumber.find(params[:id])
		end

		def admin_fax_number_params
			params.require(:fax_number).permit(:fax_number, :label, :id, :manager_label, :organization_id)
		end

		def manager_fax_number_params
			params.require(:fax_number).permit(:id, :manager_label, :organization_id)
		end

		def provision_number_params
			params.require(:fax_number).permit(:area_code, :organization_id)
		end

		def list_area_code_params
			params.permit(:area_code, :toll_free, :state)
		end

		def remove_user_associations(param_input, fax_number_object)
			destroyed_associations = param_input.keys.each do |user_object_id|
				UserFaxNumber.where( { user_id: user_object_id, fax_number_id: @fax_number.id} ).destroy_all
			end
		end

		def verify_can_purchase_numbers
			return if is_admin?
			@organization = Organization.find(manager_fax_number_params[:organization_id])
			if is_manager? && !@organization.fax_numbers_purchasable
				flash[:alert] = DENIED
				redirect_to root_path
			else #
				if !authorized?(@organization.manager, :id)
					flash[:alert] = DENIED
					redirect_to root_path
				end
			end
		end

		def verify_authorized
			return if is_admin?
			if !authorized?(@fax_number.manager, :id)
				flash[:alert] = DENIED
				redirect_to root_path
			end
		end
end
