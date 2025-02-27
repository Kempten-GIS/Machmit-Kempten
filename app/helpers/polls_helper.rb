module PollsHelper
  def poll_dates(poll)
    if poll.projekt_phase.start_date.blank? || poll.projekt_phase.end_date.blank?
      I18n.t("polls.no_dates")
    else
      I18n.t("polls.dates", open_at: l(poll.projekt_phase.start_date.to_date), closed_at: l(poll.projekt_phase.end_date.to_date))
    end
  end

  def booth_name_with_location(booth)
    location = booth.location.blank? ? "" : " (#{booth.location})"
    booth.name + location
  end

  def link_to_poll(text, poll)
    if can?(:results, poll)
      link_to text, results_poll_path(id: poll.id)
    elsif can?(:stats, poll)
      link_to text, stats_poll_path(id: poll.id)
    else
      link_to text, poll_path(id: poll.id)
    end
  end

  def results_menu?
    controller_name == "polls" && action_name == "results"
  end

  def stats_menu?
    controller_name == "polls" && action_name == "stats"
  end

  def info_menu?
    controller_name == "polls" && action_name == "show"
  end

  def show_polls_description?
    @active_poll.present? && @current_filter == "current"
  end
end
