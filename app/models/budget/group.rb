class Budget
  class Group < ApplicationRecord
    include Sluggable

    translates :name, touch: true
    include Globalizable
    translation_class_delegate :budget

    # class Translation
    #   validate :name_uniqueness_by_budget

    #   def name_uniqueness_by_budget
    #     if budget.group.translations
    #                    .where(name: name)
    #                    .where.not("budget_group_translations.budget_group_id": budget_group_id).any?
    #       errors.add(:name, I18n.t("errors.messages.taken"))
    #     end
    #   end
    # end

    belongs_to :budget

    # has_many :headings, dependent: :destroy
    has_one :heading, dependent: :destroy

    validates_translation :name, presence: true
    validates :budget_id, presence: true
    validates :slug, presence: true, format: /\A[a-z0-9\-_]+\z/

    def self.sort_by_name
      all.sort_by(&:name)
    end

    def self.model_name # custom
      mname = super
      mname.instance_variable_set(:@route_key, "groups")
      mname.instance_variable_set(:@singular_route_key, "group")
      mname
    end

    def multiple_headings?
      headings.size > 1
    end

    private

      def generate_slug?
        slug.nil? || budget.drafting?
      end
  end
end
