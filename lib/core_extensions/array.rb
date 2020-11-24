# frozen_string_literal: true

module CoreExtensions
  module Array
    def include_regexp?(object, regexp_options: nil)
      any? do |regex_string_or_object|
        # convert objects in array to regexp if needed
        regexp = if regex_string_or_object.is_a?(Regexp)
                   regex_string_or_object
                 else
                   Regexp.new(regex_string_or_object, regexp_options: regexp_options)
                 end
        # compare with nil to force a boolean return type
        !(object =~ regexp).nil?
      end
    end

    def reject_regexp(regex_or_regexp_array, regexp_options: nil)
      if regex_or_regexp_array.is_a?(Array)
        reject do |object|
          regex_or_regexp_array.include_regexp?(object, regexp_options: regexp_options)
        end
      else
        reject do |object|
          object =~ regex_or_regexp_array
        end
      end
    end

    def select_regexp(regex_or_regexp_array, regexp_options: nil)
      if regex_or_regexp_array.is_a?(Array)
        select do |object|
          regex_or_regexp_array.include_regexp?(object, regexp_options: regexp_options)
        end
      else
        select do |object|
          object =~ regex_or_regexp_array
        end
      end
    end
  end
end
