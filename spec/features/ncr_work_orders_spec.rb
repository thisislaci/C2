describe "National Capital Region proposals" do
  it "requires sign-in" do
    visit '/ncr/work_orders/new'
    expect(current_path).to eq('/')
    expect(page).to have_content("You need to sign in")
  end

  context "when signed in" do
    let(:requester) { FactoryGirl.create(:user) }

    before do
      login_as(requester)
    end

    it "saves a Cart with the attributes" do
      expect(Dispatcher).to receive(:deliver_new_cart_emails)

      visit '/ncr/work_orders/new'
      fill_in 'Description', with: "buying stuff"
      choose 'BA80'
      fill_in 'Vendor', with: 'ACME'
      fill_in 'Amount', with: 123.45
      fill_in "Approving Official's Email Address", with: 'approver@example.com'
      select Ncr::BUILDING_NUMBERS[0], :from => 'ncr_work_order_building_number'
      select Ncr::OFFICES[0], :from => 'ncr_work_order_office'
      expect {
        click_on 'Submit for approval'
      }.to change { Cart.count }.from(0).to(1)

      cart = Cart.last
      expect(page).to have_content("Proposal submitted")
      expect(current_path).to eq("/carts/#{cart.id}")

      expect(cart.proposal.name).to eq("buying stuff")
      expect(cart.flow).to eq('linear')
      client_data = cart.proposal.client_data
      expect(client_data.client).to eq('ncr')
      expect(client_data.expense_type).to eq('BA80')
      expect(client_data.vendor).to eq('ACME')
      expect(client_data.amount).to eq(123.45)
      expect(client_data.building_number).to eq(Ncr::BUILDING_NUMBERS[0])
      expect(client_data.office).to eq(Ncr::OFFICES[0])
      expect(cart.requester).to eq(requester)
      expect(cart.approvers.map(&:email_address)).to eq(%w(
        approver@example.com
        communicart.budget.approver@gmail.com
      ))
    end

    it "defaults to the approver from the last request" do
      cart = FactoryGirl.create(:cart_with_approvals)
      cart.set_requester(requester)

      visit '/ncr/work_orders/new'
      expect(find_field("Approving Official's Email Address").value).to eq('approver1@some-dot-gov.gov')
    end

    it "doesn't save when the amount is too high" do
      visit '/ncr/work_orders/new'
      fill_in 'Description', with: "buying stuff"
      choose 'BA80'
      fill_in 'Vendor', with: 'ACME'
      fill_in 'Amount', with: 10_000

      expect {
        click_on 'Submit for approval'
      }.to_not change { Cart.count }

      expect(current_path).to eq('/ncr/work_orders')
      expect(page).to have_content("Amount must be less than or equal to 3000")
      # keeps the form values
      expect(find_field('Amount').value).to eq('10000')
    end

    it "includes has overwritten field names" do
      visit '/ncr/work_orders/new'
      fill_in 'Description', with: "buying stuff"
      choose 'BA80'
      fill_in 'RWA Number', with: 'NumNum'
      fill_in 'Vendor', with: 'ACME'
      fill_in 'Amount', with: 123.45
      fill_in "Approving Official's Email Address", with: 'approver@example.com'
      select Ncr::BUILDING_NUMBERS[0], :from => 'ncr_work_order_building_number'
      select Ncr::OFFICES[0], :from => 'ncr_work_order_office'
      click_on 'Submit for approval'
      expect(current_path).to eq("/carts/#{Cart.last.id}")
      expect(page).to have_content("RWA Number")
    end

    it "hides fields based on expense", :js => true do
      visit '/ncr/work_orders/new'
      expect(page).to have_no_field("RWA Number")
      expect(page).to have_no_field("Work Order")
      expect(page).to have_no_field("emergency")
      choose 'BA61'
      expect(page).to have_no_field("RWA Number")
      expect(page).to have_no_field("Work Order")
      expect(page).to have_field("emergency")
      expect(find_field("emergency", visible: false)).to be_visible
      choose 'BA80'
      expect(page).to have_field("RWA Number")
      expect(page).to have_field("Work Order")
      expect(page).to have_no_field("emergency")
      expect(find_field("RWA Number")).to be_visible
    end

    let (:work_order) {
      wo = FactoryGirl.create(:ncr_work_order)
      wo.init_and_save_cart('approver@email.com', 'Description Here', requester)
      wo
    }
    let(:ncr_cart) {
      work_order.proposal.cart
    }
    it "can be restarted if pending" do
      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(find_field("ncr_work_order_building_number").value).to eq(
        Ncr::BUILDING_NUMBERS[0])
      fill_in 'Vendor', with: 'New ACME'
      click_on 'Submit for approval'
      expect(current_path).to eq("/carts/#{ncr_cart.id}")
      expect(page).to have_content("New ACME")
      expect(page).to have_content("resubmitted")
      # Verify it is actually saved
      work_order.reload
      expect(work_order.vendor).to eq("New ACME")
    end

    it "can be restarted if rejected" do
      ncr_cart.proposal.update_attributes(status: 'rejected')  # avoid workflow

      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(current_path).to eq("/ncr/work_orders/#{work_order.id}/edit")
    end

    it "cannot be restarted if approved" do
      ncr_cart.proposal.update_attributes(status: 'approved')  # avoid workflow

      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(current_path).to eq("/ncr/work_orders/new")
      expect(page).to have_content('already approved')
    end

    it "cannot be edited by someone other than the requester" do
      ncr_cart.set_requester(FactoryGirl.create(:user))

      visit "/ncr/work_orders/#{work_order.id}/edit"
      expect(current_path).to eq("/ncr/work_orders/new")
      expect(page).to have_content('cannot restart')
    end

    it "shows a restart link from a pending cart" do
      visit "/carts/#{ncr_cart.id}"
      expect(page).to have_content('Restart this Cart?')
      click_on('Restart this Cart?')
      expect(current_path).to eq("/ncr/work_orders/#{work_order.id}/edit")
    end

    it "shows a restart link from a rejected cart" do
      ncr_cart.proposal.update_attribute(:status, 'rejected') # avoid state machine

      visit "/carts/#{ncr_cart.id}"
      expect(page).to have_content('Restart this Cart?')
    end

    it "does not show a restart link for an approved cart" do
      ncr_cart.proposal.update_attribute(:status, 'approved') # avoid state machine

      visit "/carts/#{ncr_cart.id}"
      expect(page).not_to have_content('Restart this Cart?')
    end

    it "does not show a restart link for another client" do
      ncr_cart.proposal.client_data = nil
      ncr_cart.proposal.save()
      visit "/carts/#{ncr_cart.id}"
      expect(page).not_to have_content('Restart this Cart?')
    end

    it "does not show a restart link for non requester" do
      ncr_cart.set_requester(FactoryGirl.create(:user))
      visit "/carts/#{ncr_cart.id}"
      expect(page).not_to have_content('Restart this Cart?')
    end

    context "selected common values on proposal page" do
      before do
        visit '/ncr/work_orders/new'

        fill_in 'Description', with: "buying stuff"
        fill_in 'Vendor', with: 'ACME'
        fill_in 'Amount', with: 123.45
        fill_in "Approving Official's Email Address", with: 'approver@example.com'
        select Ncr::BUILDING_NUMBERS[0], :from => 'ncr_work_order_building_number'
        select Ncr::OFFICES[0], :from => 'ncr_work_order_office'
      end

      it "approves emergencies" do
        choose 'BA61'
        check "I received a verbal NTP to address this emergency"
        expect {
          click_on 'Submit for approval'
        }.to change { Cart.count }.from(0).to(1)

        cart = Cart.last
        expect(page).to have_content("Proposal submitted")
        expect(current_path).to eq("/carts/#{cart.id}")
        expect(page).to have_content("0 of 0 approved")

        expect(cart.proposal.client_data.emergency).to eq(true)
        expect(cart.approved?).to eq(true)
      end

      it "does not set emergencies if form type changes" do
        choose 'BA61'
        check "I received a verbal NTP to address this emergency"
        choose 'BA80'
        fill_in 'RWA Number', with: "a 'number'"
        expect {
          click_on 'Submit for approval'
        }.to change { Cart.count }.from(0).to(1)

        cart = Cart.last
        expect(page).to have_content("Proposal submitted")
        expect(current_path).to eq("/carts/#{cart.id}")

        expect(cart.proposal.client_data.emergency).to eq(false)
        expect(cart.approved?).to eq(false)
      end
    end
  end
end
