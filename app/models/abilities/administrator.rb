module Abilities
  class Administrator
    include CanCan::Ability

    def initialize(user)
      merge Abilities::Moderation.new(user)
      merge Abilities::SDG::Manager.new(user)

      can :restore, Comment
      cannot :restore, Comment, hidden_at: nil

      can :restore, Debate
      cannot :restore, Debate, hidden_at: nil

      can :restore, Proposal
      cannot :restore, Proposal, hidden_at: nil

      can :create, Legislation::Proposal
      can :show, Legislation::Proposal
      can :proposals, ::Legislation::Process

      can :restore, Legislation::Proposal
      cannot :restore, Legislation::Proposal, hidden_at: nil

      can :restore, Budget::Investment
      cannot :restore, Budget::Investment, hidden_at: nil

      can :restore, User
      cannot :restore, User, hidden_at: nil

      can :confirm_hide, Comment
      cannot :confirm_hide, Comment, hidden_at: nil

      can :confirm_hide, Debate
      cannot :confirm_hide, Debate, hidden_at: nil

      can :confirm_hide, Proposal
      cannot :confirm_hide, Proposal, hidden_at: nil

      can :confirm_hide, Legislation::Proposal
      cannot :confirm_hide, Legislation::Proposal, hidden_at: nil

      can :confirm_hide, Budget::Investment
      cannot :confirm_hide, Budget::Investment, hidden_at: nil

      can :confirm_hide, User
      cannot :confirm_hide, User, hidden_at: nil

      can :mark_featured, Debate
      can :unmark_featured, Debate

      can :comment_as_administrator, [Debate, Comment, Proposal, Poll, Poll::Question, Budget::Investment, Projekt,
                                      Legislation::Question, Legislation::Proposal, Legislation::Annotation, Topic, Projekt]

      can [:search, :create, :index, :destroy, :update], ::Administrator
      can [:search, :create, :index, :destroy], ::ProjektManager # custom
      can [:search, :create, :index, :destroy], ::DeficiencyReportManager # custom
      can [:search, :create, :index, :destroy], ::OfficingManager # custom
      can [:search, :create, :index, :destroy], ::Moderator
      can [:search, :show, :update, :create, :index, :destroy, :summary], ::Valuator
      can [:search, :create, :index, :destroy], ::Manager
      can [:create, :read, :destroy], ::SDG::Manager
      can [:search, :index], ::User

      can :manage, Dashboard::Action

      can [:index, :read, :create, :update, :destroy], Budget
      can :publish, Budget, id: Budget.where(id: Budget.drafting.pluck(:id)).ids
      can :calculate_winners, Budget, &:balloting_or_later?
      can :recalculate_winners, Budget, &:balloting_or_later?

      can :read_results, Budget do |budget|
        budget.balloting_or_later?
        # budget.balloting_finished? && budget.has_winning_investments?
      end

      can [:read, :create, :update, :destroy], Budget::Group
      can [:read, :create, :update, :destroy], Budget::Heading
      can [:hide, :admin_update, :toggle_selection], Budget::Investment
      can [:valuate, :comment_valuation], Budget::Investment
      cannot [:admin_update, :toggle_selection, :valuate, :comment_valuation],
        Budget::Investment, budget: { id: Budget.finished.pluck(:id) }

      can :create, Budget::ValuatorAssignment

      can :read_admin_stats, Budget, &:balloting_or_later?

      can [:search, :update, :create, :index, :destroy], Banner

      can [:index, :create, :update, :destroy], Geozone

      can [:read, :create, :update, :destroy, :add_question, :search_booths, :search_officers, :booth_assignments, :send_notifications], Poll
      can [:read, :create, :update, :destroy, :available], Poll::Booth
      can [:search, :create, :index, :destroy], ::Poll::Officer
      can [:create, :destroy, :manage], ::Poll::BoothAssignment
      can [:create, :destroy], ::Poll::OfficerAssignment

      can :read, Poll::Question
      can [:create], Poll::Question
      can [:update, :destroy], Poll::Question

      can [:read, :order_answer], Poll::Question::Answer
      can [:create, :update, :destroy], Poll::Question::Answer do |answer|
        can?(:update, answer.question)
      end

      can :read, Poll::Question::Answer::Video

      can [:create, :update, :destroy], Poll::Question::Answer::Video do |video|
        can?(:update, video.answer)
      end
      can [:destroy], Image do |image|
        image.imageable_type == "Poll::Question::Answer" && can?(:update, image.imageable)
      end

      can :manage, SiteCustomization::Page
      can :manage, SiteCustomization::Image
      can :manage, SiteCustomization::ContentBlock
      can :manage, Widget::Card

      can :access, :ckeditor
      can :manage, Ckeditor::Picture

      can [:read, :debate, :draft_publication, :allegations, :result_publication,
           :milestones], Legislation::Process
      can [:create, :update, :destroy], Legislation::Process
      can [:manage], ::Legislation::DraftVersion
      can [:manage], ::Legislation::Question
      can [:manage], ::Legislation::Proposal
      cannot :comment_as_moderator, [::Legislation::Question, Legislation::Annotation, ::Legislation::Proposal]

      can [:create], Document
      can [:destroy], Document, documentable_type: "Poll::Question::Answer"
      can [:create, :destroy], DirectUpload

      can [:deliver], Newsletter, hidden_at: nil
      can [:manage], Dashboard::AdministratorTask

      can :manage, LocalCensusRecord
      can [:create, :read], LocalCensusRecords::Import


      #custom
      can [:manage], ::DeficiencyReport::Officer
      can [:manage], ::DeficiencyReport::Category
      can [:manage], ::DeficiencyReport::Status
      can [:manage], ::DeficiencyReport::OfficialAnswerTemplate
      can [:manage], ::DeficiencyReport::OfficerGroup
      can [:manage], DeficiencyReport

      can [:csv_answers_votes], Poll
      can [:order_questions, :csv_answers_streets, :csv_answers_votes, :edit_votation_type, :update_votation_type], Poll::Question
      can [:update, :verify, :unverify, :reverify], User

      can :edit_physical_votes, Budget::Investment do |investment|
        investment.budget.current_phase.kind == "selecting"
      end

      can :manage, ModalNotification
      can [:index, :import], RegisteredAddress
      can [:index, :update, :destroy], RegisteredAddress::Grouping
      can [:index, :update], RegisteredAddress::District
      can [:index], RegisteredAddress::Street

      can [:results, :stats], Poll, projekt_phase: { settings: { key: "feature.resource.intermediate_poll_results_for_admins", value: "active" }}

      can :manage, Projekt
      can :manage, ProjektSetting
      can :manage, ProjektPhaseSetting
      can :manage, MapLayer
      can :manage, MapLocation
      can :manage, Milestone
      can :manage, ProjektQuestion
      can :manage, ProjektLivestream
      can :manage, ProjektLabel
      can :manage, ProjektPhase
      can :manage, Sentiment
      can :manage, ProjektNotification
      can :manage, ProgressBar
      can :manage, ProjektEvent
      can :manage, FormularField
      can :manage, FormularFollowUpLetter
      can :manage, ProjektArgument

      can :read_stats, Budget, id: Budget.where(id: Budget.valuating_or_later.pluck(:id)).ids

      can :destroy, RelatedContent

      can [:hide, :restore], Topic

      can :read_stats, Budget::Investment do |investment|
        can? :read_stats, investment.budget
      end

      can :add_memo, Budget::Investment

      can :get_coordinates_map_location, MapLocation
      can :send_notification, Memo, user_id: user.id

      can :index, Ckeditor::Asset
      can [:create, :update, :destroy], Ckeditor::Picture
      can [:create, :update, :destroy], Ckeditor::Document
    end
  end
end
