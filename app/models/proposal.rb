class Proposal < ActiveRecord::Base
  include ThreeStateWorkflow

  workflow_column :status

  has_one :cart
  has_many :approvals
  has_many :approvers, through: :approvals, source: :user
  has_many :observations
  has_many :observers, through: :observations, source: :user
  belongs_to :client_data, polymorphic: true
  belongs_to :requester, class_name: 'User'

  # The following list also servers as an interface spec for client_datas
  delegate :fields_for_display, :client, :public_identifier, :total_price,
           :name, to: :client_data_legacy

  validates :flow, presence: true, inclusion: {in: ApprovalGroup::FLOWS}
  # TODO validates :requester_id, presence: true

  self.statuses.each do |status|
    scope status, -> { where(status: status) }
  end
  scope :closed, -> { where(status: ['approved', 'rejected']) }

  after_initialize :set_defaults


  def set_defaults
    self.flow ||= 'parallel'
  end

  # Use this until all clients are migrated to models (and we no longer have a
  # dependence on "Cart"
  def client_data_legacy
    self.client_data || self.cart
  end

  # Returns a list of all users involved with the Proposal.
  def users
    # TODO use SQL
    results = self.approvers + self.observers + [self.requester]
    results.compact
  end

  # returns the Approval
  def add_approver(email)
    user = User.find_or_create_by(email_address: email)
    self.approvals.create!(user_id: user.id)
  end

  def add_observer(email)
    user = User.find_or_create_by(email_address: email)
    self.observations.create!(user_id: user.id)
  end

  def add_requester(email)
    user = User.find_or_create_by(email_address: email)
    self.set_requester(user)
  end

  def set_requester(user)
    self.update_attributes!(requester_id: user.id)
  end


  #### state machine methods ####
  # TODO remove dependence on Cart

  def on_pending_entry(prev_state, event)
    if self.cart.all_approvals_received?
      self.approve!
    end
  end

  def on_rejected_entry(prev_state, event)
    if prev_state.name != :rejected
      Dispatcher.on_cart_rejected(self.cart)
    end
  end

  def restart
    # Note that none of the state machine's history is stored
    self.cart.api_tokens.update_all(expires_at: Time.now)
    self.cart.approvals.each do |approval|
      approval.restart!
    end
    Dispatcher.deliver_new_cart_emails(self.cart)
  end

  ###############################
end
