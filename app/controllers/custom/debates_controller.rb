require_dependency Rails.root.join("app", "controllers", "debates_controller").to_s

class DebatesController < ApplicationController
  include ImageAttributes
  include ProjektControllerHelper
  include DocumentAttributes
  include Takeable
  include ProjektLabelAttributes
  include RandomSeed
  include GuestUsers

  before_action :authenticate_user!, except: [:index, :show], unless: -> { current_user&.guest? }
  before_action :set_projekts_for_selector, only: [:new, :edit, :create, :update]
  before_action :set_random_seed, only: :index

  def index_customization
    if params[:order].nil?
      @current_order = Setting["selectable_setting.debates.default_order"]
    end

    @resource_name = "debate"

    # related_projekt_ids = @resources.joins(projekt_phase: :projekt).pluck("projekts.id").uniq
    # related_projekts = Projekt.where(id: related_projekt_ids)

    @geozones = Geozone.all
    @selected_geozone_affiliation = params[:geozone_affiliation] || "all_resources"
    @affiliated_geozones = (params[:affiliated_geozones] || "").split(",").map(&:to_i)
    @selected_geozone_restriction = params[:geozone_restriction] || "no_restriction"
    @restricted_geozones = (params[:restricted_geozones] || "").split(",").map(&:to_i)

    @featured_debates = Debate.featured

    @scoped_projekt_ids = Debate.scoped_projekt_ids_for_index(current_user)

    @top_level_active_projekts = Projekt.top_level.current.where(id: @scoped_projekt_ids)
    @top_level_archived_projekts = Projekt.top_level.expired.where(id: @scoped_projekt_ids)

    # @categories = Tag.category.joins(:taggings)
    #   .where(taggings: { taggable_type: "Projekt", taggable_id: related_projekt_ids }).order(:name).uniq
    #
    # if params[:sdg_goals].present?
    #   sdg_goal_ids = SDG::Goal.where(code: params[:sdg_goals].split(",")).ids
    #   @sdg_targets = SDG::Target.where(goal_id: sdg_goal_ids).joins(:relations)
    #     .where(sdg_relations: { relatable_type: "Projekt", relatable_id: related_projekt_ids })
    # end

    @resources = @resources.by_projekt_id(@scoped_projekt_ids)
    @all_resources = @resources

    unless params[:search].present?
      take_by_my_posts
      # take_by_tag_names(related_projekts)
      # take_by_sdgs(related_projekts)
      take_by_geozone_affiliations
      take_by_geozone_restrictions
      take_by_projekts(@scoped_projekt_ids)
    end

    @debates = @resources.perform_sort_by(@current_order, session[:random_seed]).page(params[:page]).per(24)

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end

      format.csv do
        redirect_to debates_path and return unless current_user&.administrator?

        send_data CsvServices::DebatesExporter.call(@resources.limit(nil)),
          filename: "debates-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
      end
    end
  end

  def new
    @projekt_phase = ProjektPhase::DebatePhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?

    if @projekt_phase.blank? && Projekt.top_level.selectable_in_selector("debates", current_user).empty?
      redirect_to debates_path
    elsif @projekt_phase.present? && !@projekt_phase.selectable_by?(current_user)
      redirect_to page_path(@projekt_phase.projekt.page.slug,
                            projekt_phase_id: @projekt_phase.id,
                            anchor: "filter-subnav")
    end

    @resource = resource_model.new(projekt_phase: @projekt_phase)
    set_geozone
    set_resource_instance
    @selected_projekt = Projekt.find(params[:projekt_id]) if params[:projekt_id]
  end

  def edit
    @selected_projekt = @debate&.projekt_phase&.projekt
    params[:projekt_phase_id] = @debate&.projekt_phase&.id
  end

  def create
    custom_debate_params =
      if debate_params["image_attributes"]["cached_attachment"].blank?
        debate_params.except("image_attributes")
      else
        debate_params
      end

    @debate = Debate.new(custom_debate_params)
    @debate.author = current_user

    if @debate.save
      track_event
      NotificationServices::NewDebateNotifier.new(@debate.id).call

      if @debate.projekt_phase.active?
        redirect_to page_path(
          @debate.projekt_phase.projekt.page.slug,
          anchor: "filter-subnav",
          projekt_phase_id: @debate.projekt_phase.id,
          order: params[:order]
        ), notice: t("flash.actions.create.debate")
      else
        redirect_to proposals_path(
          resources_order: params[:order]
        ), notice: t("flash.actions.create.debate")
      end
    else
      @selected_projekt = @debate&.projekt_phase&.projekt
      render :new
    end
  end

  def update
    custom_debate_params =
      if debate_params["image_attributes"]["cached_attachment"].blank?
        debate_params.except("image_attributes")
      else
        debate_params
      end

    if resource.update(custom_debate_params)
      redirect_to resource, notice: t("flash.actions.update.#{resource_name.underscore}")
    else
      load_geozones
      set_resource_instance
      render :edit
    end
  end

  def show
    super

    @projekt = @debate.projekt_phase.projekt
    @related_contents = Kaminari.paginate_array(@debate.relationed_contents).page(params[:page]).per(5)

    @geozones = Geozone.all

    @selected_geozone_affiliation = params[:geozone_affiliation] || 'all_resources'
    @affiliated_geozones = (params[:affiliated_geozones] || '').split(',').map(&:to_i)

    @selected_geozone_restriction = params[:geozone_restriction] || 'no_restriction'
    @restricted_geozones = (params[:restricted_geozones] || '').split(',').map(&:to_i)


    if request.path != debate_path(@debate)
      redirect_to debate_path(@debate), status: :moved_permanently

    elsif !@projekt.visible_for?(current_user)
      @individual_group_value_names = @projekt.individual_group_values.pluck(:name)
      render "custom/pages/forbidden", layout: false

    elsif Setting.new_design_enabled?
      render :show_new

    else
      render :show

    end
  end

  def flag
    Flag.flag(current_user, @debate)
    @debate.update!(ignored_flag_at: nil)

    redirect_to @debate
  end

  def unflag
    Flag.unflag(current_user, @debate)
    redirect_to @debate
  end

  private

    def debate_params
      attributes = [:tag_list, :projekt_id, :projekt_phase_id, :related_sdg_list, :on_behalf_of,
                    :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general, :resource_terms,
                    :sentiment_id,
                    projekt_label_ids: [],
                    image_attributes: image_attributes,
                    documents_attributes: document_attributes]
      params.require(:debate).permit(attributes, translation_params(Debate))
    end
end
