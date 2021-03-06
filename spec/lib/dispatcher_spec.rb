describe Dispatcher do
  let(:cart) { FactoryGirl.create(:cart) }

  describe '.deliver_new_cart_emails' do
    it "uses the ParallelDispatcher for parallel approvals" do
      cart.proposal.flow = 'parallel'
      expect_any_instance_of(ParallelDispatcher).to receive(:deliver_new_cart_emails).with(cart)
      Dispatcher.deliver_new_cart_emails(cart)
    end

    it "uses the LinearDispatcher for linear approvals" do
      cart.proposal.flow = 'linear'
      expect_any_instance_of(LinearDispatcher).to receive(:deliver_new_cart_emails).with(cart)
      Dispatcher.deliver_new_cart_emails(cart)
    end
  end

  describe '#email_approver' do
    let(:dispatcher) { Dispatcher.new }

    it 'creates a new token for the approver' do
      approval = cart.add_approver('approver1@some-dot-gov.gov')
      expect(CommunicartMailer).to receive_message_chain(:cart_notification_email, :deliver)
      expect(approval).to receive(:create_api_token!).once

      dispatcher.email_approver(approval)
    end
  end
end
