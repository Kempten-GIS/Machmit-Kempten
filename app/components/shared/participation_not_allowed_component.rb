class Shared::ParticipationNotAllowedComponent < ApplicationComponent
  attr_reader :votable, :cannot_vote_text
  delegate :current_user, :link_to_signin, :link_to_signup, to: :helpers

  def initialize(votable, cannot_vote_text:)
    @votable = votable
    @cannot_vote_text = cannot_vote_text
  end

  def render?
    body.present?
  end

  private

    def body
      @body ||=
        if organization?
          t("votes.organizations")
        elsif cannot_vote_text.present?
          sanitize(cannot_vote_text)
        end
    end

    def organization?
      current_user&.organization?
    end
end
