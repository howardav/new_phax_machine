require 'rails_helper'

# not testing the validity of numbers due to Phonelib's inclusion

RSpec.describe FaxNumber, type: :model do

  describe "valid fax number formatting" do
  	before(:each) do
  		@admin = User.create!(email: 'tom@tom.com', password: 'tomtom', is_admin: true)
    	@fax_number = FaxNumber.new(fax_number: '12248675309', fax_number_label: "Fake Testing Number", admin_id: @admin.id)
  	end

  	it "persists to the database with valid attributes" do
  		expect(@fax_number).to be_valid
  	end

  	it "does not require a fax_number label to still be valid" do
  		@fax_number.fax_number_label = nil
  		expect(@fax_number).to be_valid
  	end

  end

  describe "invalid fax number formatting" do
  	before(:each) do
    	@fax_number = FaxNumber.new
  	end

  	it "persists to the database only if fax number is present" do
  		expect(@fax_number).to be_invalid
  	end

  	it "fax number label cannot be more than 60 characters long" do
  		@fax_number.admin_id = 1
  		@fax_number.fax_number = '12248675309'
  		@fax_number.fax_number_label = "A" * 61
  		expect(@fax_number).to be_invalid
  	end

  	it "does not persist without an admin_id" do
  		@fax_number.admin_id = nil
  		@fax_number.fax_number = '12248675309'
  		@fax_number.fax_number_label = "totally rad label"
  		expect(@fax_number).to be_invalid
  	end

  	it "fax_number must be unique" do
  		@fax_number = FaxNumber.create(fax_number: '12248675309', fax_number_label: "Fake Testing Number")
  		@fax_number2 = FaxNumber.new(fax_number: '12248675309', fax_number_label: "Different Fake Testing Number")
  		expect(@fax_number2).to be_invalid
  	end
  end
end