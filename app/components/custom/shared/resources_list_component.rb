# frozen_string_literal: true

class Shared::ResourcesListComponent < ApplicationComponent
  renders_one :bottom_content
  renders_one :custom_body
  renders_one :items_remark

  delegate :projekt_phase_feature?, to: :helpers

  attr_reader :filters, :remote_url, :resource_type, :resources

  def initialize(
    resources: nil,
    resource_type: nil,
    title: nil,
    filters: nil,
    current_filter: nil,
    filter_param: "filter",
    remote_url: nil,
    map_location: nil,
    map_coordinates: nil,
    filter_i18n_namespace: nil,
    only_content: false,
    text_search_enabled: false,
    hide_view_mode_button: false,
    projekt_phase: nil,
    additional_data: {}
  )
    @resources = resources
    @resource_type = resource_type
    @title = title
    @filters = filters
    @current_filter = current_filter
    @remote_url = remote_url
    @only_content = only_content
    @map_location = map_location
    @map_coordinates = map_coordinates
    @text_search_enabled = text_search_enabled
    @filter_i18n_namespace = filter_i18n_namespace
    @filter_param = filter_param
    @hide_view_mode_button = hide_view_mode_button
    @projekt_phase = projekt_phase
    @additional_data = additional_data
  end

  def filter_title
    if @filter_param == "order"
      t("custom.shared.sort_by")
    elsif @filter_param == "filter"
      t("custom.shared.filter_by")
    end
  end

  def wide?
    helpers.cookies["wide_resources"] == "true" || @wide
  end

  def class_names
    base = @css_class.to_s

    if wide?
      base += " -wide"
    end

    base
  end

  def selected_filter_otpion
    return if filters.blank?

    filters.find { |filter| filter == @current_filter }
  end

  def i18n_namespace
    return @filter_i18n_namespace if @filter_i18n_namespace.present?

    if resource_type == Projekt
      "custom.projekts"
    elsif resource_type == Debate
      "custom.debates.index"
    elsif resource_type == Proposal
      "custom.proposals.index"
    elsif resource_type == Budget::Investment
      "custom.budgets.investments.index"
    elsif resource_type == Poll
      "custom.polls.index"
    elsif resource_type == DeficiencyReport
      "custom.deficiency_reports.index"
    elsif resource_type == Topic
      "custom.topics.list"
    end
  end

  def empty_list_text
    t("empty_list_text", scope: i18n_namespace)
  end

  def switch_view_mode_icon
    wide? ? "fa-grip-vertical" : "fa-bars"
  end

  def proposal_resources_ids
    @resources.select { |r| r.is_a?(Proposal) }.map(&:id)
  end

  def resource_component(resource)
    case resource
    when Projekt
      Projekts::ListItemComponent.new(projekt: resource)
    when Proposal
      Proposals::ListItemComponent.new(proposal: resource)
    when Debate
      Debates::ListItemComponent.new(debate: resource)
    when Poll
      Polls::ListItemComponent.new(poll: resource)
    when DeficiencyReport
      DeficiencyReports::ListItemComponent.new(deficiency_report: resource)
    when Budget::Investment
      Budgets::Investments::ListItemComponent.new(
        budget_investment: resource,
        budget_investment_ids: resources.pluck(:id),
        ballot: @additional_data[:ballot]
        # top_level_active_projekts: @additional_data[:top_level_active_projekts],
        # top_level_archived_projekts: @additional_data[:top_level_archived_projekts]
      )
    when ProjektEvent
      Projekts::ProjektEvents::ListItemComponent.new(projekt_event: resource)
    when Topic
      Topics::ListItemComponent.new(topic: resource)
    end
  end

  def default_filter_options
    [
      "newest",
      "oldest"
    ]
  end

  def render_map?
    return false if @projekt_phase.present? && !projekt_phase_feature?(@projekt_phase, "form.show_map")

    @map_coordinates.present? || @map_location.present? || @projekt_phase&.map_location.present?
  end

  def hide_list_line_divider?
    resource_type == Topic
  end
end
