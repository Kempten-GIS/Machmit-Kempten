class Admin::Legislation::ProcessesController < Admin::Legislation::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes

  has_filters %w[active all], only: :index

  load_and_authorize_resource :process, class: "Legislation::Process", except: :create

  def index
    @processes = ::Legislation::Process.send(@current_filter).order(start_date: :desc)
                 .page(params[:page])
  end

  def create
    @process = ::Legislation::Process.new(process_params)

    if @process.save
      if @process.projekt_phase.present? #custom
        link = "#{@process.projekt_phase&.projekt&.page&.url}?projekt_phase_id=#{@process.projekt_phase.id}#filter-subnav"
      else
        link = legislation_process_path(@process)
      end

      notice = t("admin.legislation.processes.create.notice", link: link)
      redirect_to edit_admin_legislation_process_path(@process), notice: notice
    else
      flash.now[:error] = t("admin.legislation.processes.create.error")
      render :new
    end
  end

  def update
    if @process.update(process_params)

      if @process.projekt_phase.present? #custom
        link = "#{@process.projekt_phase&.projekt&.page&.url}?projekt_phase_id=#{@process.projekt_phase.id}#filter-subnav"
      else
        link = legislation_process_path(@process)
      end

      redirect_back(fallback_location: (request.referer || root_path),
                    notice: t("admin.legislation.processes.update.notice", link: link))
    else
      flash.now[:error] = t("admin.legislation.processes.update.error")
      render :edit
    end
  end

  def destroy
    @process.destroy!
    notice = t("admin.legislation.processes.destroy.notice")
    redirect_to admin_legislation_processes_path, notice: notice
  end

  private

    def process_params
      params.require(:legislation_process).permit(allowed_params)
    end

    def allowed_params
      [
        :start_date,
        :end_date,
        :debate_start_date,
        :debate_end_date,
        :draft_start_date,
        :draft_end_date,
        :draft_publication_date,
        :allegations_start_date,
        :allegations_end_date,
        :proposals_phase_start_date,
        :proposals_phase_end_date,
        :result_publication_date,
        :debate_phase_enabled,
        :draft_phase_enabled,
        :allegations_phase_enabled,
        :proposals_phase_enabled,
        :draft_publication_enabled,
        :result_publication_enabled,
        :published,
        :custom_list,
        :background_color,
        :font_color,
        :related_sdg_list,
        :projekt_phase_id,
        translation_params(::Legislation::Process),
        documents_attributes: document_attributes,
        image_attributes: image_attributes
      ]
    end

    def resource
      @process || ::Legislation::Process.find(params[:id])
    end
end
