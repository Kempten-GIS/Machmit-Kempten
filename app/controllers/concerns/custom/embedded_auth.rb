module EmbeddedAuth
  extend ActiveSupport::Concern

  included do
    before_action :set_iframe_content_security_policy
    helper_method :embedded? #, :frame_temp_token_valid?
    helper_method :frame_access_code_valid? #, :frame_temp_token_valid?
    helper_method :embedded_and_frame_access_code_valid?
    helper_method :skip_forgery_protection_for_frame_session?, :frame_session_from_authorized_source?, :frame_session

    skip_forgery_protection if: :skip_forgery_protection_for_frame_session?
  end

  private

    def set_iframe_content_security_policy
      response.headers["Content-Security-Policy"] =
        "frame-ancestors #{Rails.application.secrets.dt[:url]}"
    end

    def embedded?
      @embedded ||=
        (params[:embedded] == "true")
    end

    def frame_access_code_valid?(projekt)
      return false if params[:frame_code].blank?

      params[:frame_code] == projekt.frame_access_code
    end

    def embedded_and_frame_access_code_valid?(projekt)
      embedded? && frame_access_code_valid?(projekt)
    end

    def skip_forgery_protection_for_frame_session?
      @_frame_session_authentificated ||=
        frame_session_from_authorized_source? &&
          Current.frame_current_user.present?
    end

    # def frame_session_from_authorized_source?
    #   @_frame_session_from_authorized_source ||=
    #     frame_session.present? &&
    #       origin_allowed? &&
    #       frame_csrf_token_valid?(frame_session[:frame_csrf_token])
    # end

    def frame_session_from_authorized_source?
      @_frame_session_from_authorized_source ||=
        frame_session.present? && origin_allowed?
    end


    def frame_session
      return @_frame_session if @_frame_session.present?
      return if cookies.encrypted[:frame_session].nil?

      @_frame_session ||=
        begin
          JSON.parse(cookies.encrypted[:frame_session]).with_indifferent_access
        rescue
          nil
        end
    end

    def authentificate_frame_session_user!
      return unless embedded?

      if frame_session_from_authorized_source?
        user = User.find(frame_session["user_id"])

        if user.present?
          update_frame_session_data(user)
        else
          raise "Invalid auth"
        end
      end
    end

    def update_frame_session_data(user)
      new_frame_session = { user_id: user.id }

      cookies.encrypted[:frame_session] = {
        value: new_frame_session.to_json,
        same_site: :none,
        secure: true,
        httponly: true,
        expires: 5.hours
      }

      Current.frame_current_user = user
      request.env["warden"].set_user(user)
    end

    def default_url_options
      @default_url_options ||= gen_default_url_options(super)
    end

    def gen_default_url_options(options)
      options = options.presence || {}

      options =
        if params[:embedded].present?
          options.merge({ embedded: params[:embedded] })
        else
          {}
        end

      options
    end

    def origin_allowed?
      return true if request.get?

      frame_allowed_domain?(request.origin)
    end

    def frame_allowed_domain?(url)
      return false if url.blank?

      url_domain = URI.parse(url).host

      (Rails.application.secrets.server_name || request.host) == url_domain
    # rescue URI::InvalidURIError
    #   return false
    end

    # def frame_csrf_token_valid?(current_frame_csrf_token)
    #   # if Rails.env.development? && ENV["TURN_ON_DEV_FRAME_CSRF_PROTECTION"] != "true"
    #   #   return true
    #   # end

    #   current_frame_csrf_token && current_frame_csrf_token == params[:frame_csrf_token]
    # end
end
