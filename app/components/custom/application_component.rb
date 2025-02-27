require_dependency Rails.root.join("app", "components", "application_component").to_s

class ApplicationComponent < ViewComponent::Base
  delegate :url_to_footer_tab, :current_user, :can, :can?,
    :embedded_and_frame_access_code_valid?, :t, to: :helpers

  def set_comment_flags(comments)
    @comment_flags = helpers.current_user ? helpers.current_user.comment_flags(comments) : {}
    @comment_flags
  end

  private

    def path_for_resource_with_params(resource, params)
      case resource
      when Debate
        debates_path(params)
      when Proposal
        proposals_path(params)
      when Poll
        polls_path(params)
      when Budget::Investment
        budget_investments_path(resource, params)
      when Legislation::Proposal
        legislation_process_proposals_path(resource, params)
      when Projekt
        projekts_path(params)
      else
        "#"
      end
    end

    def namespace
      @namespace ||= controller_path.split("/").first.to_sym
    end

    def projekts_with_authorization_to(action)
      return false unless current_user.projekt_manager?

      Projekt.with_pm_permission_to(action, current_user.projekt_manager)
    end
end
