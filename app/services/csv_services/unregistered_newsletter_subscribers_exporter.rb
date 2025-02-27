module CsvServices
  class UnregisteredNewsletterSubscribersExporter < CsvServices::BaseService
    require "csv"
    include AdminHelper

    def initialize(unregistered_newsletter_subscribers)
      @unregistered_newsletter_subscribers = unregistered_newsletter_subscribers
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << headers

        @unregistered_newsletter_subscribers.each do |subscriber|
          csv << row(subscriber)
        end
      end
    end

    private

      def headers
        [
          "Id",
          "Email",
          "Angelegt am"
        ]
      end

      def row(subscriber)
        [
          subscriber.id,
          sanitize_for_csv(subscriber.email),
          subscriber.created_at
        ]
      end
  end
end
