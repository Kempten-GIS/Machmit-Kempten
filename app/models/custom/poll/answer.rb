require_dependency Rails.root.join("app", "models", "poll", "answer").to_s

class Poll::Answer < ApplicationRecord
  audited if: :audit_changes?

  private

    def max_votes
      return if !question || question&.unique? || question.votation_type&.rating_scale?

      author.save! if author.guest? && author.changed == ["locale"]
      author.lock!

      available_weight = [ (question.max_votes - question.answers.by_author(author).where.not(answer: answer).sum(:answer_weight)), question.votation_type.max_votes_per_answer].compact.min

      if answer_weight > available_weight
        raise "Maximum number of votes per user exceeded"
      end
    end

    def audit_changes?
      officing_manager_id.present?
    end
end
