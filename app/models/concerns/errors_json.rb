module ErrorsJson
  extend ActiveSupport::Concern

  included do
    fields do
      errors_json :text, null: true
      ignore_errors :boolean, default: false, null: false
    end

    scope :with_errors, lambda { where("errors_json IS NOT NULL AND errors_json <> '[]'") }
    scope :with_unignored_errors, lambda { with_errors.where(ignore_errors: false) }

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

    def self.get_error_counts(error_json_objects)
      error_counts = {}
      error_json_objects.each do |error_json_object|
        error_json_object.error_list.each do |error|
          error_counts[error] = error_counts[error].to_i + 1
        end
      end
      error_counts
    end

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

    def has_error?(error) # rubocop:disable Naming/PredicateName
      error_list.include?(error)
    end
  end
end
