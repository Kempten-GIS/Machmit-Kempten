class Pages::Projekts::BudgetsSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, to: :helpers
  attr_reader :budget, :projekt_phase

  def initialize(budget, projekt_phase)
    @budget = budget
    @projekt_phase = projekt_phase
  end

  private

    def budget_subnav_items_for(budget)
      {
        results:    t("budgets.results.link"),
        stats:      t("stats.budgets.link")
      }.select { |section, _| can?(:"read_#{section}", budget) }.map do |section, text|
        {
          text: text,
          url:  url_to_footer_tab(section: section, remote: true),
          active: params[:section] == section.to_s
        }
      end.push(overview_item)
    end

    def overview_item
      {
        text: t("custom.projekts.page.footer.budget.investments_subtab"),
        url: url_to_footer_tab(section: "overview", remote: true),
        active: params[:section].blank? || params[:section] == "overview"
      }
    end
end
