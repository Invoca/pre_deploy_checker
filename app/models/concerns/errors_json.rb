# frozen_string_literal: true

module ErrorsJson
  extend ActiveSupport::Concern

  included do
    fields do
      errors_json :text, limit: 0xffff_ffff, null: true
      ignore_errors :boolean, default: false
    end

    class << self
      def with_errors
        where("errors_json IS NOT NULL AND errors_json != '[]'")
      end

      def with_unignored_errors
        with_errors.where(ignore_errors: false)
      end

      def get_error_counts(error_json_objects)
        error_json_objects.each_with_object(Hash.new(0)) do |error_json_object, error_counts|
          error_json_object.error_list.each do |error|
            error_counts[error] += 1
          end
        end
      end
    end

    # TODO: Refactor to use Rails Serializable
    def error_list
      @error_list ||= JSON.parse(errors_json || '[]').uniq
    end

    def error_list=(list)
      unless error_list.to_set == list.to_set
        self.errors_json = list.uniq.to_json
        @error_list = nil
        # clear the ignore_errors flag when the errors change
        self.ignore_errors = false
      end
    end

    # TODO: Refactor out this code smell
    def reload
      super
      # clear memoized data on reload
      @error_list = nil
    end

    def errors?
      error_list.any?
    end

    def unignored_errors?
      errors? && !ignore_errors
    end

    def ignored_errors?
      errors? && ignore_errors
    end

    # TODO: Rename this to include?
    def has_error?(error) # rubocop:disable Naming/PredicateName
      error_list.include?(error)
    end
  end
end
