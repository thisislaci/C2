module UserSteps

  step 'a valid user' do
    @user = User.find_or_create_by(email_address: 'test.user@some-dot-gov.gov')
    @user.update_attributes(first_name: "George", last_name: "Jetson")
  end

  step "I should see alert text :text" do |text|
    page.assert_selector('.alert', :count => 1)
    page.find('.alert').should have_content(text)
  end

  step "I should see :text" do |text|
    page.find('body').should have_content(text)
  end

  step 'I should see a header :text' do |text|
    #TODO: Search through all header tags
    page.find('h3').should have_content(text)
  end

  step "I go to :page_name" do |page_name|
    visit "/#{page_name}"
  end

  step "I go to the cart view page" do
    visit "/carts/#{@cart.id}"
  end

  step "I login" do
    login_with_oauth
  end

  step 'show me the page' do
    save_and_open_page
  end

  step 'a cart with a cart item and approvals' do
    @cart = FactoryGirl.create(:cart_with_approvals_and_items)
  end

  step 'a cart :external_id with a cart item and approvals' do |external_id|
    @cart = FactoryGirl.create(:cart_with_approvals_and_items, external_id: external_id)
  end

  step 'I fill out :field with :text' do |field,text|
    Capybara.match = :first
    fill_in field, with: text
  end

  step 'I click :button_name button' do |button_name|
    Capybara.match = :first
    click_button(button_name)
  end

end