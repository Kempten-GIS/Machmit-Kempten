module ProjektLivestreamAdminActions
  extend ActiveSupport::Concern

  included do
    before_action :set_projekt_phase, :set_namespace
    before_action :set_projekt_livestream, only: [:edit, :update, :destroy, :send_notifications]

    respond_to :js, only: [:new, :edit]
  end

  def new
    @projekt_livestream = ProjektLivestream.new(projekt_phase: @projekt_phase)
    authorize!(:new, @projekt_livestream)

    render "custom/admin/projekt_phases/projekt_livestreams/new"
  end

  def create
    @projekt_livestream = ProjektLivestream.new(projekt_livestream_params)
    @projekt_livestream.projekt_phase = @projekt_phase
    authorize!(:create, @projekt_livestream)

    @projekt_livestream.save!
    redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektLivestream]), notice: t("admin.settings.flash.updated")
  end

  def edit
    authorize!(:edit, @projekt_livestream)

    render "custom/admin/projekt_phases/projekt_livestreams/edit"
  end

  def update
    authorize!(:update, @projekt_livestream)

    @projekt_livestream.update!(projekt_livestream_params)
    redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektLivestream]), notice: t("admin.settings.flash.updated")
  end

  def destroy
    authorize!(:destroy, @projekt_livestream)

    @projekt_livestream.destroy!
    redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektLivestream])
  end

  def send_notifications
    @projekt_livestream = ProjektLivestream.find_by(id: params[:id])
    authorize!(:send_notifications, @projekt_livestream)

    NotificationServices::NewProjektLivestreamNotifier.call(@projekt_livestream.id)
    redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektLivestream]),
      notice: t("custom.admin.projekt_phases.projekt_livestreams.notifications_sent_notice")
  end

  private

    def projekt_livestream_params
      params.require(:projekt_livestream).permit(:projekt_phase_id, :url, :title, :starts_at, :description)
    end

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end

    def set_projekt_livestream
      @projekt_livestream = ProjektLivestream.find_by(id: params[:id])
    end

    def set_namespace
      @namespace = params[:controller].split("/").first.to_sym
    end
end
