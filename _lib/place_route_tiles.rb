# frozen_string_literal: true

require 'fileutils'
require 'json'

require './_lib/line_json'
require './_lib/place_tags'

module Strava
  module PlaceRouteTiles
    OUTPUT_DIR = 'assets/data/place-routes'
    TILE_ZOOM = 14
    DETAIL_ZOOM = 12
    GRID_SIZE_METERS = 50
    MAX_SEGMENT_METERS = 25
    MINIMUM_ACTIVITIES = 3
    WEB_MERCATOR_RADIUS_METERS = 6_378_137.0
    MAXIMUM_LATITUDE = 85.05112878
    METERS_PER_MILE = 1609.344

    def self.generate!
      activity_count = 0
      edge_activities = Hash.new(0)

      Dir['_activities/**/*.json'].sort.each do |file|
        activity = JSON.parse(File.binread(file))
        points = PlaceTags.route_points(activity)
        next if points.empty?

        activity_count += 1
        activity_edges = {}
        grid_cells(densify(points)).each_cons(2) do |first, second|
          next if first == second

          edge = (first <=> second).negative? ? [first, second] : [second, first]
          activity_edges[edge] = true
        end
        activity_edges.each_key { |edge| edge_activities[edge] += 1 }
      end

      retained = edge_activities.select { |_edge, count| count >= MINIMUM_ACTIVITIES }
      tile_segments = Hash.new { |hash, key| hash[key] = [] }
      retained.each do |edge, count|
        first = cell_center(edge[0])
        second = cell_center(edge[1])
        segment = [*first.map { |value| value.round(5) }, *second.map { |value| value.round(5) }, count]
        segment_tiles(first, second).each { |tile| tile_segments[tile] << segment }
      end
      tile_segments.each_value(&:sort!)

      temporary_dir = "#{OUTPUT_DIR}.tmp"
      FileUtils.rm_rf(temporary_dir)
      tile_segments.sort.each do |(x, y), segments|
        directory = File.join(temporary_dir, TILE_ZOOM.to_s, x.to_s)
        FileUtils.mkdir_p(directory)
        File.binwrite(File.join(directory, "#{y}.json"), tile_json(segments))
      end

      manifest = {
        version: 1,
        tile_zoom: TILE_ZOOM,
        detail_zoom: DETAIL_ZOOM,
        grid_size_meters: GRID_SIZE_METERS,
        minimum_activities: MINIMUM_ACTIVITIES,
        activity_count: activity_count,
        maximum: retained.values.max || 0,
        segment_count: retained.length,
        tiles: tile_segments.keys.sort.map { |x, y| "#{x}/#{y}" }
      }
      FileUtils.mkdir_p(temporary_dir)
      File.binwrite(File.join(temporary_dir, 'manifest.json'), LineJson.generate(manifest, array_key: :tiles))

      FileUtils.rm_rf(OUTPUT_DIR)
      FileUtils.mv(temporary_dir, OUTPUT_DIR)
      manifest
    ensure
      FileUtils.rm_rf(temporary_dir) if temporary_dir && Dir.exist?(temporary_dir)
    end

    def self.densify(points)
      return points if points.length < 2

      points.each_cons(2).with_object([points.first]) do |(first, second), result|
        steps = [(distance_miles(first, second) * METERS_PER_MILE / MAX_SEGMENT_METERS).ceil, 1].max
        1.upto(steps) do |step|
          fraction = step.to_f / steps
          result << [
            first[0] + ((second[0] - first[0]) * fraction),
            first[1] + ((second[1] - first[1]) * fraction)
          ]
        end
      end
    end

    def self.tile_json(segments)
      lines = segments.map { |segment| "    #{JSON.generate(segment)}" }.join(",\n")
      "{\n  \"segments\": [\n#{lines}\n  ]\n}\n"
    end

    def self.grid_cells(points)
      points.map { |point| grid_cell(point) }.each_with_object([]) do |cell, cells|
        cells << cell if cells.last != cell
      end
    end

    def self.grid_cell(point)
      x, y = project(point)
      [(x / GRID_SIZE_METERS).floor, (y / GRID_SIZE_METERS).floor]
    end

    def self.cell_center(cell)
      x = (cell[0] + 0.5) * GRID_SIZE_METERS
      y = (cell[1] + 0.5) * GRID_SIZE_METERS
      unproject([x, y])
    end

    def self.segment_tiles(first, second)
      midpoint = [(first[0] + second[0]) / 2, (first[1] + second[1]) / 2]
      [tile_for(first), tile_for(midpoint), tile_for(second)].uniq
    end

    def self.tile_for(point)
      latitude = [[point[0], -MAXIMUM_LATITUDE].max, MAXIMUM_LATITUDE].min
      longitude = point[1]
      tiles = 2**TILE_ZOOM
      x = (((longitude + 180) / 360) * tiles).floor % tiles
      latitude_radians = radians(latitude)
      y = ((1 - (Math.log(Math.tan(latitude_radians) + (1 / Math.cos(latitude_radians))) / Math::PI)) /
        2 * tiles).floor
      [x, [[y, 0].max, tiles - 1].min]
    end

    def self.project(point)
      latitude = [[point[0], -MAXIMUM_LATITUDE].max, MAXIMUM_LATITUDE].min
      [
        WEB_MERCATOR_RADIUS_METERS * radians(point[1]),
        WEB_MERCATOR_RADIUS_METERS * Math.log(Math.tan((Math::PI / 4) + (radians(latitude) / 2)))
      ]
    end

    def self.unproject(point)
      [
        degrees((2 * Math.atan(Math.exp(point[1] / WEB_MERCATOR_RADIUS_METERS))) - (Math::PI / 2)),
        degrees(point[0] / WEB_MERCATOR_RADIUS_METERS)
      ]
    end

    def self.distance_miles(first, second)
      latitude_delta = radians(second[0] - first[0])
      longitude_delta = radians(second[1] - first[1])
      first_latitude = radians(first[0])
      second_latitude = radians(second[0])
      haversine = Math.sin(latitude_delta / 2)**2 +
                  (Math.cos(first_latitude) * Math.cos(second_latitude) * Math.sin(longitude_delta / 2)**2)
      haversine = [[haversine, 0.0].max, 1.0].min
      3958.8 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
    end

    def self.radians(degrees)
      degrees * Math::PI / 180
    end

    def self.degrees(radians)
      radians * 180 / Math::PI
    end

    private_class_method :densify, :tile_json, :grid_cells, :grid_cell, :cell_center, :segment_tiles, :tile_for,
                         :project, :unproject, :distance_miles, :radians, :degrees
  end
end
