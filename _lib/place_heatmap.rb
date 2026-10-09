# frozen_string_literal: true

require 'fileutils'
require 'json'

require './_lib/line_json'
require './_lib/place_tags'

module Strava
  module PlaceHeatmap
    OUTPUT_FILE = 'assets/data/place-heatmap.json'
    CELL_SIZE_METERS = 500
    MINIMUM_ACTIVITIES = 3
    SAMPLE_INTERVAL_MILES = 0.25
    WEB_MERCATOR_RADIUS_METERS = 6_378_137.0
    MAXIMUM_LATITUDE = 85.05112878

    def self.generate!
      activity_count = 0
      cell_activities = Hash.new(0)

      Dir['_activities/**/*.json'].sort.each do |file|
        activity = JSON.parse(File.binread(file))
        cells = PlaceTags.sampled_route(activity, interval_miles: SAMPLE_INTERVAL_MILES)
                         .map { |point| cell_for(point) }
                         .uniq
        next if cells.empty?

        activity_count += 1
        cells.each { |cell| cell_activities[cell] += 1 }
      end

      retained = cell_activities.select { |_cell, count| count >= MINIMUM_ACTIVITIES }
      cells = retained.sort_by { |cell, _count| cell }.map do |cell, count|
        latitude, longitude = cell_center(cell)
        [latitude.round(5), longitude.round(5), count]
      end
      data = {
        version: 1,
        cell_size_meters: CELL_SIZE_METERS,
        minimum_activities: MINIMUM_ACTIVITIES,
        activity_count: activity_count,
        maximum: retained.values.max || 0,
        cells: cells
      }

      FileUtils.mkdir_p(File.dirname(OUTPUT_FILE))
      temporary_file = "#{OUTPUT_FILE}.tmp"
      File.binwrite(temporary_file, LineJson.generate(data, array_key: :cells))
      File.rename(temporary_file, OUTPUT_FILE)
      data
    ensure
      File.delete(temporary_file) if temporary_file && File.exist?(temporary_file)
    end

    def self.cell_for(point)
      latitude = [[point[0], -MAXIMUM_LATITUDE].max, MAXIMUM_LATITUDE].min
      longitude = point[1]
      x = WEB_MERCATOR_RADIUS_METERS * radians(longitude)
      y = WEB_MERCATOR_RADIUS_METERS *
          Math.log(Math.tan((Math::PI / 4) + (radians(latitude) / 2)))
      [(x / CELL_SIZE_METERS).floor, (y / CELL_SIZE_METERS).floor]
    end

    def self.cell_center(cell)
      x = (cell[0] + 0.5) * CELL_SIZE_METERS
      y = (cell[1] + 0.5) * CELL_SIZE_METERS
      longitude = degrees(x / WEB_MERCATOR_RADIUS_METERS)
      latitude = degrees((2 * Math.atan(Math.exp(y / WEB_MERCATOR_RADIUS_METERS))) - (Math::PI / 2))
      [latitude, longitude]
    end

    def self.radians(degrees)
      degrees * Math::PI / 180
    end

    def self.degrees(radians)
      radians * 180 / Math::PI
    end

    private_class_method :cell_for, :cell_center, :radians, :degrees
  end
end
