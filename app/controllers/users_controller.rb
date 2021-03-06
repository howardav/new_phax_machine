# go to /users/registrations_controller.rb for create and destroy methods
class UsersController < ApplicationController
	include ApplicationHelper
	include SessionsHelper

	before_action :verify_is_admin, only: [:org_index]
	before_action :verify_is_manager_or_admin, except: [:org_index]
	before_action :set_user, only: [:edit, :update]
	before_action :set_organization, only: [:index]
	before_action :verify_authorized, only: [:edit, :update]
	
	# Get list of organizations for the Admin, after an org is selected, it goes to the Index route in this controller
	def org_index
		@organizations = Organization.all.order(:label)
	end

	def index # with_deleted is a Paranoia gem method that includes soft-deleted users
		check_for_revoked_caller_id_numbers_and_unlinked_users # ApplicationHelper
		@users = User.includes(:user_permission).with_deleted.where(organization_id: @organization.id).order(:email)
	end

	def edit
	end
	
	# Users editing their passwords is done through the Devise registration controller. This
	# method is only for Admins or Managers to change a User's caller_id_number, email, or permission level 
	def update
		# Adding this to params now b/c Rails strong_params requires it and it's better to avoid the hidden field in the view
		original_permission = @user.user_permission.permission
		params[:user_permission] = { permission: original_permission } if params[:user_permission].nil?

		if @user.update_attributes(user_params)
			# Update user permissions if needed. Demote manager to normal user, promote a normal user
			# See if the user's original permission is different than the one provided
			if original_permission != permission_params[:permission] && original_permission
				UserPermission.find_by(user_id: @user.id).update_attributes(permission: permission_params[:permission])
				# Make manager_id nil in org if Manager was demoted
				if original_permission == UserPermission::MANAGER && is_admin?
					Organization.find(@user.organization_id).update_attributes(manager_id: nil)
				# Promote new Manager
				elsif original_permission == UserPermission::USER && is_admin?
					Organization.find(@user.organization_id).update_attributes(manager_id: @user.id)
				end
			end
			flash[:notice] = "User updated successfully!"
			redirect_to(users_path(organization_id: @user.organization_id)) and return
		else
			flash[:alert] = @user.errors.full_messages.pop
			render :edit
		end
	end

	private
		def set_organization
			if is_admin?
				@organization = Organization.includes(:fax_numbers).find(org_index_params)
			else
				@organization = Organization.includes(:fax_numbers).find(current_user.organization_id)
			end
		end

		def org_index_params
			params.require(:organization_id)
		end

		def set_user
			@user ||= User.includes(:user_permission).with_deleted.find(params[:id])
			# For the rare edge case when a User object has no permission object associated with it
			if @user.user_permission.nil?
				UserPermission.create!(permission: UserPermission::USER, user_id: @user.id)
				@user.reload
			end
		end

		def user_params
			params.require(:user).permit(:caller_id_number, :email, :organization_id)
		end

		def permission_params
			params.require(:user_permission).permit(:permission)
		end

		def verify_authorized
			return if is_admin?
			if !authorized?(@user.manager, :id)
				flash[:alert] = DENIED
				redirect_to root_path
			end
		end
end