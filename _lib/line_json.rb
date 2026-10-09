# frozen_string_literal: true

require 'json'

module Strava
  module LineJson
    def self.generate(data, array_key:)
      raise ArgumentError, "#{array_key} must be the final field" unless data.keys.last == array_key
      raise ArgumentError, "#{array_key} must contain an array" unless data[array_key].is_a?(Array)

      lines = ['{']
      data.each do |key, value|
        if key == array_key
          lines << "  #{JSON.generate(key.to_s)}: ["
          value.each_with_index do |entry, index|
            comma = index == value.length - 1 ? '' : ','
            lines << "    #{JSON.generate(entry)}#{comma}"
          end
          lines << '  ]'
        else
          lines << "  #{JSON.generate(key.to_s)}: #{JSON.generate(value)},"
        end
      end
      lines << '}'
      "#{lines.join("\n")}\n"
    end
  end
end
