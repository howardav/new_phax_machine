class User < ApplicationRecord
	include FaxTags
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable

	attr_readonly :type

	belongs_to :client, optional: true
	belongs_to :user_email, optional: true

	# has_one :admin, through: :client
	has_one :client_manager, through: :client


	validates :email, length: { in: 5..60 }, uniqueness: { case_senstive: false }
	validates :fax_tag, length: { maximum: 60 }, uniqueness: { case_sensitve: false }
	validates :client_id, presence: true, numericality: { integer_only: true }, if: :is_generic_user?

	before_validation :generate_fax_tag, :ensure_user_type
	# has_secure_password

	private
	  def ensure_user_type
	  	self.type = "User" if self.type.nil?
	  end

	  def is_generic_user?
	  	self.type == "User"
	  end
end