require_dependency Rails.root.join("app", "helpers", "comments_helper").to_s

module CommentsHelper
  def hide_comment_replies_by_default?
    if Setting["extended_feature.modulewide.hide_comment_replies_by_default"]
      ' js-hide-comment-replies-by-default'
    else
      ''
    end
  end

  def comment_tree_title_text(commentable)
    if commentable.class == Legislation::Question
      t("legislation.questions.comments.comments_title")
    elsif commentable.class == ProjektQuestion
      t("custom.projekts.projekt_questions.comments_title")
    else
      t("comments_helper.comments_title")
    end
  end

  def comment_button_text(parent_id, commentable)
    if commentable.class == Legislation::Question
      parent_id.present? ? t("comments_helper.reply_button") : t("legislation.questions.comments.comment_button")
    elsif commentable.class == ProjektQuestion
      t("custom.projekts.projekt_questions.comments_button")
    else
      parent_id.present? ? t("comments_helper.reply_button") : (@projekt_phase&.comment_form_button.presence || t("comments_helper.comment_button"))
    end
  end

  def commentable_path(comment)
    return page_path(comment.commentable.projekt.page.slug, projekt_phase_id: comment.commentable.projekt_phase.id, anchor: "filter-subnav") if comment.commentable.is_a?(ProjektQuestion)
    return page_path(comment.commentable.projekt.page.slug, projekt_phase_id: comment.commentable.id, anchor: "filter-subnav") if comment.commentable.is_a?(ProjektPhase)

    polymorphic_path(comment.commentable)
  end

  # TODO provide correct return
  def commentable_url(comment)
    if comment.commentable.class.name == "ProjektQuestion"
      return root_url + "/#{comment.commentable.projekt.page.slug}?projekt_phase_id=#{comment.commentable.projekt.question_phase.id}#filter-subnav"
    end

    polymorphic_url(comment.commentable)
  end
end
