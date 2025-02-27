class Pages::Projekts::BudgetsTabComponent < ApplicationComponent
  delegate :can?, :projekt_feature?, :projekt_phase_feature?, to: :helpers
  attr_reader :budget, :ballot, :current_user, :heading

  def initialize(budget, ballot, current_user)
    @budget = budget
    @ballot = ballot
    @current_user = current_user
    @heading = @budget.heading
  end

  private

  def render_map?
    !budget.informing? &&
      projekt_phase_feature?(budget.projekt_phase, "form.show_map") &&
      controller_name != "offline_ballots" &&
      Setting.old_design_enabled?
  end

  def phases
    budget.published_phases
  end

  def phase_dom_id(phase)
    "phase-#{phases.index(phase) + 1}-#{phase.name.parameterize}"
  end

  def coordinates
    return unless budget.present?

    if budget.publishing_prices_or_later? && budget.investments.selected.any?
      investments = budget.investments.selected
    else
      investments = budget.investments
    end

    MapLocation.where(investment_id: investments).map do |map_location|
      map_location.shape_json_data.presence || map_location.json_data
    end
  end
end
