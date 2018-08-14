require "rails_helper"

RSpec.feature "Organization Pages", :type => :feature do
	let! (:admin) { User.create!( email: 'fake@phaxio.com', user_permission_attributes: { permission: UserPermission::ADMIN }) }
	let!(:org) { Organization.create(label: "Phaxio Test Company", admin_id: admin.id) }
	let!(:org2) { Organization.create(label: "Phaxio Test Company2", admin_id: admin.id) }
	let! (:manager) do 
		User.create!(email: 'manager@phaxio.com', user_permission_attributes: { permission: UserPermission::MANAGER },organization_id: org.id)
	end
	let! (:manager2) do
		User.create!(email: 'manager2@phaxio.com', user_permission_attributes: { permission: UserPermission::MANAGER }, organization_id: org2.id, caller_id_number: '17738675309')
	end
	let!(:user1) do 
		User.create(email: 'matt@phaxio.com', user_permission_attributes: { permission: UserPermission::USER }, caller_id_number: '17738675309', organization_id: org.id)
	end
	let!(:user2) do 
		User.create(email: 'matt2@phaxio.com', user_permission_attributes: { permission: UserPermission::USER }, caller_id_number: '17738675309', organization_id: org.id)
	end
	let!(:fax_number1) { FaxNumber.create!(fax_number: '17738675307', organization_id: org.id) }
	let!(:fax_number2) { FaxNumber.create!(fax_number: '17738675308', organization_id: org.id) }
	let!(:fax_number3) { FaxNumber.create!(fax_number: '17738675309') }

	before(:each) do 
		org.update_attributes(manager_id: manager.id)
		org2.update_attributes(manager_id: manager2.id)
		org.fax_numbers << fax_number1
		org.fax_numbers << fax_number2
		org.users << user1
		org.users << user2
		user1.fax_numbers << fax_number1
		user1.fax_numbers << fax_number2
		user2.fax_numbers << fax_number1
	end

	describe "organization index when logged in as an admin" do
		it "redirects to the user_sign_in page if no user is logged in" do
			visit(organizations_path)
			expect(page).to have_button("Log In")
			expect(page).to have_field("user[email]")
			expect(page).to have_field("user[password]")
			expect(page.current_url).to eq("http://www.example.com/users/sign_in")
			expect(page).to have_link('Log In', href: new_user_session_path)
		end

		it "allows the admin to access the organization index route" do
			login_as(admin)
			visit(organizations_path)
			expect(page.current_url).to eq("http://www.example.com/organizations")

			# The following are the navbar links
			expect(page).to have_link('Add New Organization') # This appears as a button
			expect(page).to have_link('Manage Organizations', href: organizations_path)
			expect(page).to have_link('Manage Numbers', href: fax_numbers_path)
			expect(page).to have_link('Edit Profile')
			expect(page).to have_link('Fax Logs', href: fax_logs_path)
			expect(page).to have_link("Phaxio Test Company", href: organization_path(org))
			expect(page).to have_link("Phaxio Test Company2", href: organization_path(org2))
			expect(page).to have_button("Delete Organization")
			expect(page).not_to have_button("Invite Manager") # Both orgs have a manager
		end

		it "allows the admin to create a new organization with no linked fax numbers. Manager invitation should not be an option until a fax number has been added" do
			login_as(admin)
			visit(organizations_path)
			click_on("Add New Organization")

			expect(page.current_url).to eq("http://www.example.com/organizations/new")
			expect(page).to have_field("organization[label]")

			fill_in('organization[label]', with: "Brand New Organization")
			click_button("Submit")

			expect(page.current_url).to eq('http://www.example.com/organizations')
			expect(page).to have_link("Brand New Organization")
			expect(page).not_to have_button("Invite Manager")
			expect(page).to have_text("You must link a fax number before you can invite a manager")
			expect(page).to have_text("Managed by: manager@phaxio.com")
			expect(page).to have_text("Managed by: manager2@phaxio.com")
		end

		it "allows the admin to create a new organization with no linked fax numbers. Manager invitation should not be an option until a fax number has been added" do
			login_as(admin)
			visit(organizations_path)
			click_on("Add New Organization")
			expect(page.current_url).to eq("http://www.example.com/organizations/new")
			expect(page).to have_field("organization[label]")
			fill_in('organization[label]', with: "Brand New Organization")
			click_button("Submit")
			expect(page.current_url).to eq('http://www.example.com/organizations')
			expect(page).to have_link("Brand New Organization")
			expect(page).not_to have_button("Invite Manager")
		end

		it "allows the admin to create a new organization with a linked fax number. Manager invitation should not be an option until a fax number has been added." do
			login_as(admin)
			visit(organizations_path)
			click_on("Add New Organization")

			expect(page.current_url).to eq("http://www.example.com/organizations/new")
			expect(page).to have_field("organization[label]")
			expect(page).to have_field("fax_numbers[to_add][#{fax_number3.id}]")

			check("fax_numbers[to_add][#{fax_number3.id}]")
			fill_in('organization[label]', with: "Organization With Fax Number")
			click_button("Submit")

			expect(page.current_url).to eq('http://www.example.com/organizations')
			expect(page).to have_link("Organization With Fax Number")
			expect(page).to have_field("user[email]")
			expect(page).to have_field("user[caller_id_number]")
			expect(page).to have_button("Invite Manager")
		end

		it "the admin can delete an organization" do
			login_as(admin)
			visit(organizations_path)
			expect(page).to have_button('Delete Organization', count: 2)
			click_on("Delete Organization", match: :first)
			expect(page).to have_button('Delete Organization', count: 1)
			expect(page).not_to have_link("Phaxio Test Company", href: organization_path(org)) # <-- deleted Organization
			expect(page).to have_link("Phaxio Test Company2", href: organization_path(org2))
		end
	end

	describe "organization index when not logged in as an admin" do
		it "redirects to root if a non-admin user tries to access the fax_numbers_path (index)" do
			login_as(user1)
			visit(organizations_path)
			expect(page.current_url).to eq("http://www.example.com/")
		end

		it "redirects to root if a non-admin and non-manager user tries to access the organizations_path (index)" do
			login_as(manager)
			visit(organizations_path)
			expect(page.current_url).to eq("http://www.example.com/")
		end
	end

	describe "organization show page functions" do
		it "admin level show page functions" do
			login_as(admin)
			visit(organization_path(org))
			expect(page).to have_link("Manage #{org.label} Fax Numbers / Details")
		end

		it "manager level show page functions" do
			login_as(manager)
			visit(organization_path(org))
			expect(page).not_to have_link("Manage #{org.label} Fax Numbers / Details")
		end

		it "user level show page should deny and redirect to root" do
			login_as(user1)
			visit(organization_path(org))
			expect(page.current_url).to eq("http://www.example.com/")
		end
	end

	describe "admin swapping organization phone numbers and editing its name" do
		it "allows the admin to add/remove fax numbers and edit the organization name" do
			login_as(admin)
			visit(organization_path(org))
			click_link("Manage Phaxio Test Company Fax Numbers / Details")
			
			expect(page.current_url).to eq("http://www.example.com/organizations/#{org.id}/edit")
			expect(page).to have_field("organization[label]")
			expect(page).to have_table("unlinked-numbers")
			expect(page).to have_table("linked-numbers")
			expect(page).to have_field("fax_numbers[to_remove][#{fax_number1.id}]")
			expect(page).to have_field("fax_numbers[to_remove][#{fax_number2.id}]")
			expect(page).to have_field("fax_numbers[to_add][#{fax_number3.id}]")

			# Remove(unlink) fax_number1, add(link) fax_number3
			check("fax_numbers[to_remove][#{fax_number1.id}]")
			check("fax_numbers[to_add][#{fax_number3.id}]")
			fill_in("organization[label]", with: "An Edited Label")
			click_button("Submit")

			expect(page.current_url).to eq("http://www.example.com/organizations/#{org.id}")
		end
	end

end