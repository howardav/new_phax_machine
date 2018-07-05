# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
	include SessionsHelper
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  	before_action :verify_permissions, only: [:create, :destroy]
  	prepend_before_action :require_no_authentication, only: :cancel

  # POST /resource
  def create
    build_resource(sign_up_params)
    resource.save

    yield resource if block_given?
    if resource.persisted?
	    user = User.find(resource.id)

    	# Create a UserEmail object with the User object          
    	if resource.type == User::CLIENT_MANAGER
	    	client = Client.find(resource.client_id)
	    	client.update_attributes(client_manager_id: user.id)
	    	existing_email = UserEmail.find_by(email_address: user.email)
	    	if existing_email.nil?
		    	new_email = UserEmail.create(                           # Creating a ClientManager user from
		    		email_address: user.email,                            # scratch w/no previously persisted
		    		client_id: client.id,                                 # UserEmail object
		    		user_id: user.id,                                     # 
		    		caller_id_number: client.fax_numbers.first.fax_number #
		    	)
		    else																											#
		    	existing_email.update_attributes(user_id: user.id.to_i) # Creating ClientManager with an existing UserEmail object
		    end 																											#
	    else
	    	UserEmail.find_by(email_address: user.email).update(user_id: user.id) # Creating a User from existing UserEmail
	    end
	    
      if resource.active_for_authentication?
        flash[:notice] = "#{resource.email} has been invited."
      else
        flash[:notice] = "signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
      end
    else
    	flash[:alert] = resource.errors.full_messages.pop
      clean_up_passwords resource
      set_minimum_password_length
    end
    resource.type == User::USER ? redirect_to(client_path(resource.client)) : redirect_to(clients_path)
  end

  # DELETE /resource
  def destroy
  	resource = User.find(params[:id])
  	UserEmail.find_by(user_id: resource.id).update_attributes(user_id: nil) # retains the UserEmail obj

		client = current_user.client.nil? ? Client.find(resource.client.id) : current_user.client
		client.update_attributes(client_manager_id: nil) if resource.type == User::CLIENT_MANAGER # Removes client_manager privileges

    resource.destroy
    flash[:notice] = "Access for #{resource.email} revoked"
    yield resource if block_given?
    redirect_to(client_path(client))
  end

  protected

	# 'is_client_manager?' returns true if the user is a ClientManager or Admin, so if they're not an 
	# admin and a ClientManager user is trying to be created OR they're not an Admin or ClientManager 
	# and a generic user is being created, then redirect
	  def verify_permissions
	  	if !is_admin? && sign_up_params[:type] == User::CLIENT_MANAGER || !is_client_manager?
	  		flash[:alert] = "Permission denied."
	  		redirect_to_root_path
	  	end
	  end
end
