class Officing::OfflineBallotsController < Officing::BaseController
  def verify_user
    render
  end

  def find_or_create_user
    unique_stamp = User.new(user_params).prepare_unique_stamp

    if (unique_stamp.blank? ||
        params[:"date_of_birth(1i)"].blank? ||
        params[:"date_of_birth(2i)"].blank? ||
        params[:"date_of_birth(3i)"].blank?)
      flash.now[:error] = "Bitte stellen Sie sicher, dass alle Felder ausgefüllt sind"
      render :verify_user

    else
      @user = User.find_by(unique_stamp: unique_stamp)
      @user ||= User.find_by(
        first_name: user_params[:first_name],
        last_name: user_params[:last_name],
        plz: user_params[:plz],
        date_of_birth: Date.new(
          params[:"date_of_birth(1i)"].to_i,
          params[:"date_of_birth(2i)"].to_i,
          params[:"date_of_birth(3i)"].to_i
        ).beginning_of_day
      )
      @user ||= User.new

      if @user.new_record?
        @user.assign_attributes(user_params)
        @user.email = nil
        @user.verified_at = Time.current
        @user.erased_at = Time.current
        @user.password = (0...20).map { ("a".."z").to_a[rand(26)] }.join
        # @user.terms_of_service = "1" #custom
        @user.terms_data_storage = "1" #custom
        @user.terms_data_protection = "1" #custom
        @user.terms_general = "1" #custom
        @user.unique_stamp = unique_stamp
        @user.geozone = Geozone.find_with_plz(params[:plz])
        @user.save!
      end

      @user.verify! if @user.verified_at.nil?

      redirect_to officing_offline_ballots_investments_path(params[:budget_id], user_id: @user.id)
    end
  end

  def investments
    @user = User.find(params[:user_id])
    @budget = Budget.find(params[:budget_id])
    @heading = @budget.heading
    @ballot = Budget::Ballot.where(user: @user, budget: @budget).first_or_create!(conditional: false, physical: true)
    @investments = @budget.investments.selected
    @investment_ids = @investments.ids
  end

  private

    def user_params
      params
        .slice(:first_name, :last_name, :plz, :"date_of_birth(1i)", :"date_of_birth(2i)", :"date_of_birth(3i)")
        .permit(:first_name, :last_name, :plz, :date_of_birth)
    end
end
