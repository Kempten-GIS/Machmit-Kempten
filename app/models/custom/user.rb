require_dependency Rails.root.join("app", "models", "user").to_s

class User < ApplicationRecord
  audited only: [:username, :first_name, :last_name, :registered_address_id,
                 :city_name, :plz, :street_name, :street_number, :street_number_extension,
                 :unique_stamp, :verified_at]

  include Imageable
  has_one_attached :background_image

  SORTING_OPTIONS = { id: "id", name: "username", email: "email", city_name: "city_name",
    created_at: "created_at", verified_at: "verified_at" }.freeze

  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :timeoutable,
         :trackable, :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  delegate :registered_address_street, to: :registered_address, allow_nil: true
  delegate :registered_address_city, to: :registered_address, allow_nil: true

  attr_accessor :form_registered_address_city_id,
                :form_registered_address_street_id,
                :form_registered_address_id

  before_validation :strip_whitespace

  before_create :set_default_privacy_settings_to_false, if: :gdpr_conformity?
  after_create :attempt_verification, if: -> { Setting["feature.melderegister"].present? }
  after_create :take_votes_from_erased_user
  after_create -> { update_column(:geozone_id, geozone_with_plz&.id) }
  after_create :assign_individual_group_values_based_on_email_pattern

  has_secure_token :frame_sign_in_token

  has_many :projekts, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :projekt_questions, foreign_key: :author_id #, inverse_of: :author
  has_many :memos
  has_many :deficiency_reports, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :user_individual_group_values, dependent: :destroy
  has_many :individual_group_values, through: :user_individual_group_values
  has_one :deficiency_report_officer, class_name: "DeficiencyReport::Officer"
  has_one :projekt_manager
  has_one :deficiency_report_manager
  has_one :officing_manager
  belongs_to :registered_address, optional: true

  has_many :projekt_subscriptions, -> { where(active: true) }
  has_many :projekt_phase_subscriptions

  scope :projekt_managers, -> { joins(:projekt_manager) }
  scope :verified, -> { where.not(verified_at: nil) }
  scope :to_reverify, -> { verified.where("verified_at < ?", 6.months.ago).where(reverify: true) }
  scope :not_guests, -> { where(guest: false) }

  validate :email_should_not_be_used_by_hidden_user
  validate :password_complexity, if: :password_required?

  validates :first_name, presence: true, on: :create, if: :extended_registration?
  validates :last_name, presence: true, on: :create, if: :extended_registration?
  validates :gender, presence: true, on: :create, if: :extended_registration?
  validates :date_of_birth, presence: true, on: :create, if: :extended_registration?

  validates :registered_address_id, presence: true, on: :create, if: :validate_registered_address?

  validates :city_name, presence: true, on: :create, if: :validate_regular_address_fields?
  validates :plz, presence: true, on: :create, if: :validate_regular_address_fields?
  validates :street_name, presence: true, on: :create, if: :validate_regular_address_fields?
  validates :street_number, presence: true, on: :create, if: :validate_regular_address_fields?

  validates :document_type, presence: true, on: :create, if: :document_required?
  validates :document_last_digits, presence: true, on: :create, if: :document_required?

  validates :terms_data_storage, acceptance: { allow_nil: false }, on: :create, unless: :guest?
  validates :terms_data_protection, acceptance: { allow_nil: false }, on: :create
  validates :terms_general, acceptance: { allow_nil: false }, on: :create

  def self.order_filter(params)
    sorting_key = params[:sort_by]&.downcase&.to_sym
    allowed_sort_option = SORTING_OPTIONS[sorting_key]
    direction = params[:direction] == "desc" ? "desc" : "asc"

    if allowed_sort_option.present?
      order("#{allowed_sort_option} #{direction}")
    elsif sorting_key == :roles
      if direction == "asc"
        all.sort_by { |user| role = user.roles.first.to_s; [role.empty? ? 1 : 0, role] }
      else
        all.sort_by { |user| role = user.roles.first.to_s; [role.empty? ? 0 : 1, role] }.reverse
      end
    else
      order(id: :desc)
    end
  end

  def validate_registered_address?
    return false unless extended_registration?
    return false unless RegisteredAddress.present?

    acceptable_values = ["0", nil]

    [form_registered_address_city_id,
      form_registered_address_street_id,
      form_registered_address_id].none? { |v| acceptable_values.include?(v) }
  end

  def validate_regular_address_fields?
    return false unless extended_registration?
    return true if RegisteredAddress.none?

    form_registered_address_city_id == "0" ||
      form_registered_address_street_id == "0" ||
      form_registered_address_id == "0"
  end

  def verify!
    return false unless stamp_unique?

    take_votes_from_erased_user
    update!(
      verified_at: Time.current,
      geozone_id: geozone_with_plz&.id,
      unique_stamp: prepare_unique_stamp
    )

    update_conditional_ballots_for_relevant_budgets
    true
  end

  def unverify!
    update!(
      verified_at: nil,
      geozone_id: nil,
      unique_stamp: nil
    )
  end

  def take_votes_from_erased_user
    return if erased?
    return if unique_stamp.blank?

    erased_user = User.erased.find_by(unique_stamp: unique_stamp)

    if erased_user.present?
      take_votes_from(erased_user)
      erased_user.update!(unique_stamp: nil)
    end
  end

  def stamp_unique?
    User.where.not(id: id).find_by(unique_stamp: prepare_unique_stamp).blank?
  end

  def prepare_unique_stamp
    return nil if first_name.blank? || last_name.blank? || date_of_birth.blank? || plz.blank?

    first_name.downcase + "_" +
      last_name.downcase + "_" +
      date_of_birth.to_date.strftime("%Y_%m_%d") + "_" +
      plz.to_s
  end

  def gdpr_conformity?
    Setting["extended_feature.gdpr.gdpr_conformity"].present?
  end

  def set_default_privacy_settings_to_false
    self.public_activity = false
    self.public_interests = false
    self.email_on_comment = false
    self.email_on_comment_reply = false
    self.newsletter = false
    self.email_digest = false
    self.email_on_direct_message = false
  end

  def deficiency_report_votes(deficiency_reports)
    voted = votes.for_deficiency_reports(Array(deficiency_reports).map(&:id))
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def deficiency_report_officer?
    deficiency_report_officer.present?
  end

  def projekt_manager?(projekt = nil)
    if projekt.present?
      projekt_manager.present? && projekt.projekt_managers.include?(projekt_manager)
    else
      projekt_manager.present?
    end
  end

  def has_pm_permission_to?(permission, projekt)
    return true if administrator?
    return false unless projekt_manager?

    projekt_manager.allowed_to?(permission, projekt)
  end

  def officing_manager?
    officing_manager.present?
  end

  def extended_registration?
    !organization? && !erased? && !guest? && Setting["extra_fields.registration.extended"].present?
  end

  def document_required?
    !organization? && !erased? && !guest? && Setting["extra_fields.registration.check_documents"].present?
  end

  def current_city_citizen?
    return false if geozone.nil?

    @geozone_ids ||= Geozone.ids

    @geozone_ids.include?(geozone.id)
  end

  def not_current_city_citizen?
    !current_city_citizen?
  end

  def verified?
    !unverified?
  end

  def data_complete?
    first_name.present? && last_name.present? && date_of_birth.present? &&
      city_name.present? && plz.present? && street_name.present? && street_number.present?
  end

  def formatted_address
    return registered_address.formatted_name if registered_address.present?

    "#{street_name} #{street_number}#{street_number_extension}"
  end

  def reverify!
    return if organization?

    initially_verified = verified?
    unverify!
    verification_attempt_successful = attempt_verification

    if initially_verified && !verification_attempt_successful
      NotificationServices::UserReverificationFailedNotifier.call(id)
    elsif !initially_verified && verification_attempt_successful
      NotificationServices::UserReverificationSucceededNotifier.call(id)
    end
  end

  def roles
    roles = []
    roles << :admin if administrator?
    roles << :moderator if moderator?
    roles << :valuator if valuator?
    roles << :manager if manager?
    roles << :poll_officer if poll_officer?
    roles << :official if official?
    roles << :organization if organization?
    roles
  end

  def full_name
    if first_name.present? && last_name.present?
      "#{first_name} #{last_name}"
    else
      name
    end
  end

  def first_letter_of_name
    (first_name || name)&.chars&.first&.upcase
  end

  def unread_notifications_count
    notifications.where(read_at: nil).count
  end

  def deficiency_report_manager?
    deficiency_report_manager.present?
  end

  def generate_frame_sign_in_token!
    regenerate_frame_sign_in_token

    update!(frame_sign_in_token_valid_until: 1.minute.from_now)
  end

  def frame_sign_in_token_valid?
    frame_sign_in_token_valid_until > Time.current
  end

  private

    def geozone_with_plz
      Geozone.find_with_plz(plz)
    end

    def strip_whitespace
      self.first_name = first_name.strip unless first_name.nil?
      self.last_name = last_name.strip unless last_name.nil?
      self.city_name = city_name.strip unless city_name.nil?
      self.street_name = street_name.strip unless street_name.nil?
      self.street_number = street_number.strip unless street_number.nil?
      self.street_number_extension = street_number_extension.strip unless street_number_extension.nil?
    end

    def email_should_not_be_used_by_hidden_user
      return if email.blank?

      if User.only_hidden.where.not(id: id).find_by(email: email).present?
        errors.add(:email, "Diese E-Mail-Adresse wurde bereits verwendet. Ggf. wurde das Konto geblockt. Bitte kontaktieren Sie uns per E-Mail.")
      end
    end

    def password_complexity
      return unless password.present?

      # at least three of the following four elements: a capital letter, a small letter, a digit, or a special symbol
      special_symbols = "~!@#$%^&*()_-+={}[]|:;,<>.?/"
      escaped_special_symbols = Regexp.escape(special_symbols)

      regex_pattern = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)|(?=.*[A-Z])(?=.*[a-z])(?=.*[#{escaped_special_symbols}])|(?=.*[A-Z])(?=.*\d)(?=.*[#{escaped_special_symbols}])|(?=.*[a-z])(?=.*\d)(?=.*[#{escaped_special_symbols}])/

      unless password.match?(regex_pattern)
        errors.add :password, :low_complexity
      end
    end

    def attempt_verification
      return false if organization?
      return false unless residency_valid?

      verify!
    end

    def census_data
      RemoteCensusApi.new.call(first_name: first_name,
                               last_name: last_name,
                               street_name: registered_address&.registered_address_street&.name.presence || street_name,
                               street_number: registered_address&.street_number.presence || street_number,
                               plz: registered_address&.registered_address_street&.plz.presence || plz,
                               city_name: registered_address&.registered_address_city&.name.presence || city_name,
                               date_of_birth: date_of_birth&.strftime("%Y-%m-%d"),
                               gender: gender)
    end

    def residency_valid?
      return true if organization?

      census_data.valid?
    end

    def remove_audits
      audits.destroy_all
    end

    def remove_subscriptions
      projekt_subscriptions.destroy_all
      projekt_phase_subscriptions.destroy_all
    end

    def update_conditional_ballots_for_relevant_budgets
      Budget::Ballot.where(user_id: id).joins(:budget).select { |b| b.budget.balloting? }.each do |ballot|
        permission_problem_present = ballot.budget.projekt_phase.permission_problem(self).present?
        next if permission_problem_present

        ballot.update!(conditional: false)
      end
    end

    def assign_individual_group_values_based_on_email_pattern
      return unless email.present?

      IndividualGroupValue.where.not(email_pattern: "").find_each do |group_value|
        next if group_value.users.include?(self)
        next unless group_value.email_pattern.start_with?("@")
        next unless email.ends_with?(group_value.email_pattern)

        group_value.users << self
      end
    end
end
