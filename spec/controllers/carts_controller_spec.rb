describe CartsController do
  let(:user) { FactoryGirl.create(:user) }
  let(:approval_group1) { FactoryGirl.create(:approval_group, name: 'test-approval-group1') }

  before do
    UserRole.create!(user_id: user.id, approval_group_id: approval_group1.id, role: 'requester')
    params = {'approvalGroup' => 'test-approval-group1', 'cartName' => 'cart1' }
    @cart1 = Commands::Approval::InitiateCartApproval.new.perform(params)
    login_as(user)
  end

  describe '#index' do
    it 'sets @carts' do
      approval_group1

      cart2 = FactoryGirl.create(:cart)
      cart2.proposal.approvals.create!(user: user)

      cart3 = FactoryGirl.create(:cart)
      cart3.proposal.observations.create!(user: user)

      get :index
      expect(assigns(:carts).sort).to eq [@cart1, cart2, cart3]
    end
  end

  describe '#archive' do
    it 'should show all the closed carts' do
      carts = Array.new
      (1..4).each do |i|
        params = {}
        params['approvalGroup'] =  'test-approval-group1'
        params['cartName'] = "cart#{i}"
        temp_cart = Commands::Approval::InitiateCartApproval.new.perform(params)
        temp_cart.approve! unless i==3
        carts.push(temp_cart)
      end
      get :archive
      expect(assigns(:closed_cart_full_list).size).to eq(3)
    end
  end
end
