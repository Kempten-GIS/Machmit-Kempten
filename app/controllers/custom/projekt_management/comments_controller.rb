class ProjektManagement::CommentsController < ProjektManagement::BaseController
  include ModerateActions

  has_filters %w[all unseen seen], only: :index
  has_orders %w[flags newest], only: :index

  before_action :load_resources, only: [:index, :moderate]

  load_and_authorize_resource

  def index
    super

    respond_to do |format|
      format.html do
        render "moderation/comments/index"
      end

      format.csv do
        CsvJobs::CommentsJob.perform_later(current_user.id, @resources.limit(20_000).ids, "projekt_management")
        redirect_to projekt_management_comments_path, notice: "Export wird vorbereitet. Du erhältst eine E-Mail, sobald der Export fertig ist."
      end
    end
  end

  def moderate
    set_resource_params
    @resources = @resources.where(id: params[:resource_ids])

    if params[:hide_resources].present?
      @resources = @resources.where(hidden_at: nil).each { |resource| hide_resource resource }

    elsif params[:ignore_flags].present?
      @resources = @resources.where(ignored_flag_at: nil, hidden_at: nil).each(&:ignore_flag)

    elsif params[:block_authors].present?
      author_ids = @resources.pluck(author_id)
      User.where(id: author_ids).accessible_by(current_ability, :block).each { |user| block_user user }
    end

    redirect_with_query_params_to(action: :index)
  end

  private

    def resource_model
      Comment
    end

    def author_id
      :user_id
    end
end
