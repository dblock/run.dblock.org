# frozen_string_literal: true

require 'json'
require 'date'

module Strava
  module ShoeTags
    def self.first_use_months
      Dir['_activities/**/*.json'].each_with_object({}) do |file, months|
        activity = JSON.parse(File.read(file))
        gear = activity['gear']
        next unless gear && gear['name']

        id = gear.fetch('id')
        month = Date.iso8601(activity.fetch('start_date_local')[0, 10]).strftime('%Y/%m')
        months[id] = [months[id], month].compact.min
      end
    end

    def self.tag(gear_id, name, month, first_use_months = self.first_use_months)
      first_month = [first_use_months[gear_id], month].compact.min
      "s/#{first_month}/#{name.downcase}"
    end
  end
end
