# frozen_string_literal: true

module CoreExtensions
  module String
    def escape_double_quotes
      gsub('"', '\\"')
    end

    def escape_double_quotes!
      gsub!('"', '\\"')
    end
  end
end
