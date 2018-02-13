# == Schema Information
#
# Table name: conversations
#
#  id              :integer          not null, primary key
#  title           :string(255)
#  listing_id      :integer
#  created_at      :datetime
#  updated_at      :datetime
#  last_message_at :datetime
#  community_id    :integer
#  starting_page   :string(255)
#
# Indexes
#
#  index_conversations_on_community_id     (community_id)
#  index_conversations_on_last_message_at  (last_message_at)
#  index_conversations_on_listing_id       (listing_id)
#  index_conversations_on_starting_page    (starting_page)
#

class Conversation < ApplicationRecord
  STARTING_PAGES = [
    PROFILE = 'profile',
    LISTING = 'listing',
    PAYMENT = 'payment'
  ]

  has_many :messages, :dependent => :destroy

  has_many :participations
  has_many :participants, :through => :participations, :source => :person
  belongs_to :listing
  has_one :tx, class_name: "Transaction", foreign_key: "conversation_id"
  belongs_to :community

  validates :starting_page, inclusion: { in: STARTING_PAGES }, allow_nil: true

  scope :for_person, -> (person){
    joins(:participations)
    .where( { participations: { person_id: person }} )
  }
  scope :non_payment, -> { where(starting_page: nil).or(Conversation.where.not(starting_page: PAYMENT)) }
  scope :payment, -> { where(starting_page: nil).or(Conversation.where(starting_page: PAYMENT)) }
  scope :by_community, -> (community_id) { where(community_id: community_id) }
  scope :non_payment_or_free, -> (community_id) do
    subquery = Transaction.non_free.by_community(community_id).select('conversation_id').to_sql
    by_community(community_id).where("id NOT IN (#{subquery})").non_payment
  end

  # Creates a new message to the conversation
  def message_attributes=(attributes)
    if attributes[:content].present? || attributes[:action].present?
      messages.build(attributes)
    end
  end

  # Sets the participants of the conversation
  def conversation_participants=(conversation_participants)
    conversation_participants.each do |participant, is_sender|
      last_at = is_sender.eql?("true") ? "last_sent_at" : "last_received_at"
      participations.build(:person_id => participant,
                           :is_read => is_sender,
                           :is_starter => is_sender,
                           last_at.to_sym => DateTime.now)
    end
  end

  def participation_for(person)
    participations.find { |participation| participation.person_id == person.id }
  end

  def build_starter_participation(person)
    participations.build(
      person: person,
      is_read: true,
      is_starter: true,
      last_sent_at: DateTime.now
    )
  end

  def build_participation(person)
    participations.build(
      person: person,
      is_read: false,
      is_starter: false,
      last_received_at: DateTime.now
    )
  end

  # Returns last received or sent message
  def last_message
    return messages.last
  end

  def first_message
    return messages.first
  end

  def other_party(person)
    participants.reject { |p| p.id == person.id }.first
  end

  def read_by?(person)
    participation_for(person).is_read
  end

  # Send email notification to message receivers and returns the receivers
  #
  # TODO This should be removed. It's not model's resp to send emails.
  def send_email_to_participants(community)
    recipients(messages.last.sender).each do |recipient|
      if recipient.should_receive?("email_about_new_messages")
        MailCarrier.deliver_now(PersonMailer.new_message_notification(messages.last, community))
      end
    end
  end

  # Returns all the participants except the message sender
  def recipients(sender)
    participants.reject { |p| p.id == sender.id }
  end

  def starter
    Maybe(participations.find { |p| p.is_starter? }).person.or_else(nil)
  end

  def participant?(user)
    participants.include? user
  end

  def with_type(&block)
    block.call(:conversation)
  end

  def with(expected_type, &block)
    with_type do |own_type|
      if own_type == expected_type
        block.call
      end
    end
  end
end
