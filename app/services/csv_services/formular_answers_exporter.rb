module CsvServices
  class FormularAnswersExporter < CsvServices::BaseService
    require "csv"

    def initialize(formular)
      @formular = formular
      @formular_answers = @formular.formular_answers
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << headers

        @formular_answers.each do |formular_answer|
          csv << row(formular_answer)
        end
      end
    end

    private

      def headers
        @formular.formular_fields.map(&:name) + ["Submitter ID", "Submitter Email", "Submitted At"]
      end

      def row(formular_answer)
        @formular.formular_fields.map do |formular_field|
          sanitize_for_csv(formular_answer.answers[formular_field.key])
        end + [formular_answer.submitter_id, sanitize_for_csv(formular_answer.original_submitter_email), formular_answer.created_at]
      end
  end
end
