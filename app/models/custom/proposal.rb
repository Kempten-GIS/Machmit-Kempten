require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord
  include Labelable
  include Sentimentable
  include ResourceBelongsToProjekt
  include OnBehalfOfSubmittable
  include Memoable

  belongs_to :old_projekt, class_name: 'Projekt', foreign_key: :projekt_id # TODO: remove column after data migration con1538

  delegate :projekt, to: :projekt_phase, allow_nil: true
  belongs_to :projekt_phase
  has_many :geozone_restrictions, through: :projekt_phase
  has_many :geozone_affiliations, through: :projekt_phase

  delegate :votable_by?, to: :projekt_phase
  delegate :comments_allowed?, to: :projekt_phase

  validates_translation :description, presence: true
  validates :projekt_phase, presence: true
  validate :description_sanitized

  # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
  validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom

  scope :base_selection, -> {
    published
      .not_archived
      .not_retired
  }

  scope :with_current_projekt, -> { joins(projekt_phase: :projekt).merge(Projekt.current) }
  scope :by_author, ->(user_id) {
    return if user_id.nil?

    where(author_id: user_id)
  }

  scope :sort_by_alphabet, -> {
    with_translations(I18n.locale).
    select("proposals.*, LOWER(proposal_translations.title)").
    reorder("LOWER(proposal_translations.title) ASC")
  }
  scope :sort_by_votes_up, -> { reorder(cached_votes_up: :desc) }

  scope :seen,                     -> { where.not(ignored_flag_at: nil) }
  scope :unseen,                   -> { where(ignored_flag_at: nil) }

  scope :for_public_render,        -> {
    includes(:tags)
      .published #discard_draft
      .not_archived # discard_archived
      .not_retired
  }

  def self.proposals_orders(user = nil)
    orders = %w[hot_score created_at alphabet votes_up random]
    # orders << "recommendations" if Setting["feature.user.recommendations_on_proposals"] && user&.recommended_proposals
    orders
  end

  # TODO: REFACTOR FOR NEW DESIGN
  def self.scoped_projekt_ids_for_index(current_user)
    Projekt
      .activated
      .show_in_sidebar_filter
      .includes(top_level_projekt: [:projekt_settings, :hard_individual_group_values])
      .includes(parent: [:projekt_settings, :hard_individual_group_values])
      .includes(:hard_individual_group_values, :base_selection_proposals, :proposal_phases, :projekt_settings)
      .includes_children_projekts_with(:proposal_phases)
      .select do |projekt|
        (
          ([projekt] + projekt.all_parent_projekts).none? { |p| p.hidden_for?(current_user) } &&
          ([projekt] + projekt.all_children_projekts).any?(&:can_filter_proposals?)
        )
      end
      .pluck(:id)
  end

  # TODO: REFACTOR FOR NEW DESIGN
  def self.scoped_projekt_ids_for_footer(projekt)
    projekt.top_parent.all_children_projekts.unshift(projekt.top_parent).select do |projekt|
      ProjektSetting.find_by( projekt: projekt, key: 'projekt_feature.main.activate').value.present? &&
        projekt.all_children_projekts.unshift(projekt).any? { |p| p.proposal_phases.any?(&:current?) || p.proposals.base_selection.any? }
    end.pluck(:id)
  end

  def successful?
    cached_votes_up >= custom_votes_needed_for_success
  end

  def self.successful
    ids = Proposal.select { |p| p.cached_votes_up >= p.custom_votes_needed_for_success }.pluck(:id)
    Proposal.where(id: ids)
	end

  def self.unsuccessful
    ids = Proposal.select { |p| p.cached_votes_up < p.custom_votes_needed_for_success }.pluck(:id)
    Proposal.where(id: ids)
	end

  def description_sanitized
    sanitized_description = ActionController::Base.helpers.strip_tags(description).gsub("\n", '').gsub("\r", '').gsub(" ", '').gsub(/^$\n/, '').gsub(/[\u202F\u00A0\u2000\u2001\u2003]/, "")
    errors.add(:description, :too_long, message: 'too long text') if
      sanitized_description.length > Setting[ "extended_option.proposals.description_max_length"].to_i
  end

  def custom_votes_needed_for_success
    return Proposal.votes_needed_for_success unless projekt_phase.present?

    projekt_phase.settings.find_by(key: "option.resource.votes_for_proposal_success").value.to_i
  end

  def publish
    update!(published_at: Time.current)
    NotificationServices::NewProposalNotifier.new(id).call
    send_new_actions_notification_on_published
  end

  def editable_by?(user)
    return false unless user
    return false unless editable?
    return false unless projekt_phase.present? && projekt_phase.selectable_by?(user)
    return true if author_id == user.id

    author.official_level > 0 && (author.official_level == user.official_level)
  end

  def likes
    cached_votes_up
  end

  def dislikes
    cached_votes_down
  end

  protected

    def set_responsible_name
      self.responsible_name = 'unregistriered'
    end
end
