class SessionsController < ApplicationController
	include SessionsHelper # contains logged_in?, current_user, login(user), authorized?, is_admin?, is_group_leader?

	def new
		if logged_in?
			flash[:alert] = "You must log out before you can log in."
			redirect_to root_path
		end
		@user = User.new
	end

	def create
		user = User.find_by(email: session_params[:email])
		if user && user.authenticate(session_params[:password])
			login(user)
			flash.now[:notice] = "You've been logged in."
			render :template => "users/show"
		else
			flash.now[:alert] = "Invalid username or password. Please try again."
			render :new
		end
	end

	def destroy
		if logged_in? && authorized?(session_params)
			session[:user_id] = nil
			flash[:notice] = "You've been logged out."
		else
			flash.now[:alert] = "Something went wrong."
		end
		redirect_to root_path
	end

	def homepage
	end

	private
		def session_params
			params.require(:session).permit(:password, :email, :id)
		end
end
