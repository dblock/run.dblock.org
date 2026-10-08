# frozen_string_literal: true

require 'json'
require 'yaml'
require 'polylines'

module Strava
  module PlaceTags
    DATA_FILE = '_data/places.yml'
    PLACE_TAG_PREFIX = 'p/'
    EARTH_RADIUS_MILES = 3958.8
    SAMPLE_INTERVAL_MILES = 1.0

    def self.tags(activity, places = load_places, compiled_places = nil)
      points = sampled_route(activity)
      compiled_places ||= compile_places(places)
      route_box = bounding_box(points)
      compiled_places.filter_map do |slug, polygons|
        "#{PLACE_TAG_PREFIX}#{slug}" if intersects?(points, route_box, polygons)
      end
    end

    def self.sampled_route(activity, interval_miles: SAMPLE_INTERVAL_MILES)
      sample_route(route_points(activity), interval_miles)
    end

    def self.load_places(include_disabled: false)
      data = YAML.safe_load_file(DATA_FILE) || {}
      places = data.fetch('places', data)
      places.each do |slug, place|
        next if place['enabled'] == false

        raise "#{DATA_FILE}: #{slug} must have a name" unless place['name'].is_a?(String)

        validate_bounds!(slug, place['bounds'])
      end
      include_disabled ? places : places.reject { |_slug, place| place['enabled'] == false }
    end

    def self.update_counts!(tags)
      places = load_places(include_disabled: true)
      places.each do |slug, place|
        next if place['enabled'] == false

        place['count'] = tags.fetch("#{PLACE_TAG_PREFIX}#{slug}", 0)
      end
      save_places(places)
    end

    def self.update_posts!
      places = load_places
      compiled_places = compile_places(places)
      activities = Dir['_activities/**/*.json'].to_h do |file|
        activity = JSON.parse(File.read(file))
        [activity.fetch('id').to_s, activity]
      end

      updated = 0
      Dir['_posts/**/*.md'].each do |file|
        content = File.binread(file)
        strava_id = content[/^strava_id: (\d+)\r?$/, 1]
        next unless strava_id && activities[strava_id]

        place_tags = tags(activities.fetch(strava_id), places, compiled_places)
        rewritten = content.sub(/^tags: \[(.*)\](\r?)$/) do
          tags = Regexp.last_match(1).split(',').map(&:strip)
          line_ending = Regexp.last_match(2)
          tags.reject! { |tag| tag.start_with?(PLACE_TAG_PREFIX) }
          "tags: [#{(tags + place_tags).join(', ')}]#{line_ending}"
        end
        next if rewritten == content

        File.binwrite(file, rewritten)
        updated += 1
      end
      updated
    end

    def self.prune_places!
      configured_places = load_places(include_disabled: true)
      disabled_places = configured_places.select { |_slug, place| place['enabled'] == false }
      places = configured_places.reject { |_slug, place| place['enabled'] == false }
      compiled_places = compile_places(places)
      matches = Hash.new { |hash, slug| hash[slug] = {} }
      Dir['_activities/**/*.json'].each do |file|
        activity = JSON.parse(File.binread(file))
        tags(activity, places, compiled_places).each do |tag|
          matches[tag.delete_prefix(PLACE_TAG_PREFIX)][activity.fetch('id')] = true
        end
      end

      eligible = places.select { |slug, _place| matches[slug].any? }
      eligible.each { |slug, place| place['count'] = matches[slug].length }
      geometry_groups = eligible.group_by { |_slug, place| JSON.generate(place.fetch('bounds')) }
      geometry_slugs = geometry_groups.values.map do |group|
        canonical_slug = preferred_slug(group, matches, places)
        merge_aliases!(eligible.fetch(canonical_slug), group, canonical_slug)
        canonical_slug
      end
      unique_geometry = eligible.select { |slug, _place| geometry_slugs.include?(slug) }

      duplicate_groups = unique_geometry.group_by do |slug, place|
        [
          normalized_name(place.fetch('name')),
          place['location'].to_s.split(', ').last,
          matches[slug].keys.sort
        ]
      end
      canonical_slugs = duplicate_groups.values.map do |group|
        canonical_slug = preferred_slug(group, matches, places)
        merge_aliases!(unique_geometry.fetch(canonical_slug), group, canonical_slug)
        canonical_slug
      end
      retained = unique_geometry.select { |slug, _place| canonical_slugs.include?(slug) }
      result = {
        unmatched: places.keys - eligible.keys,
        duplicates: eligible.keys - retained.keys
      }
      save_places(disabled_places.merge(retained))
      result
    end

    def self.route_points(activity)
      if activity.respond_to?(:map) && !activity.is_a?(Hash)
        points = activity.map&.decoded_summary_polyline
        points = [activity.start_latlng] if points.nil? || points.empty?
      else
        polyline = activity.dig('map', 'summary_polyline') || activity.dig(:map, :summary_polyline)
        points = if polyline && !polyline.empty?
                   Polylines::Decoder.decode_polyline(polyline)
                 else
                   [activity['start_latlng'] || activity[:start_latlng]]
                 end
      end

      points.select do |point|
        point.is_a?(Array) && point.length >= 2 && point.first(2).all? { |coordinate| coordinate.is_a?(Numeric) }
      end
    end

    def self.sample_route(points, interval_miles)
      return points if points.length < 2

      sampled = [points.first]
      distance = 0.0
      next_sample = interval_miles
      points.each_cons(2) do |segment_start, segment_end|
        segment_distance = distance_between(segment_start, segment_end)
        while segment_distance.positive? && distance + segment_distance >= next_sample
          fraction = (next_sample - distance) / segment_distance
          sampled << [
            segment_start[0] + ((segment_end[0] - segment_start[0]) * fraction),
            segment_start[1] + ((segment_end[1] - segment_start[1]) * fraction)
          ]
          next_sample += interval_miles
        end
        distance += segment_distance
      end
      sampled << points.last unless sampled.last == points.last
      sampled
    end

    def self.distance_between(first, second)
      latitude_delta = radians(second[0] - first[0])
      longitude_delta = radians(second[1] - first[1])
      first_latitude = radians(first[0])
      second_latitude = radians(second[0])
      haversine = Math.sin(latitude_delta / 2)**2 +
                  (Math.cos(first_latitude) * Math.cos(second_latitude) * Math.sin(longitude_delta / 2)**2)
      haversine = [[haversine, 0.0].max, 1.0].min
      EARTH_RADIUS_MILES * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
    end

    def self.radians(degrees)
      degrees * Math::PI / 180
    end

    def self.normalized_name(name)
      name.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '')
          .unicode_normalize(:nfkd)
          .encode('ASCII', invalid: :replace, undef: :replace, replace: '')
          .downcase
          .gsub(/[^a-z0-9]+/, '')
    end

    def self.preferred_slug(group, matches, places)
      normalized_names = group.map { |_slug, place| normalized_name(place.fetch('name')) }.uniq
      group.max_by do |slug, place|
        accent_preference = normalized_names.length == 1 && !place.fetch('name').ascii_only? ? 1 : 0
        [accent_preference, matches[slug].length, -places.keys.index(slug)]
      end.first
    end

    def self.merge_aliases!(canonical, group, canonical_slug)
      aliases = canonical.fetch('aliases', [])
      group.each do |slug, place|
        next if slug == canonical_slug

        aliases.concat(place.fetch('aliases', []))
        aliases << place['name'] if place['name']
      end
      aliases.reject! { |name| name == canonical.fetch('name') }
      aliases.uniq!
      aliases.empty? ? canonical.delete('aliases') : canonical['aliases'] = aliases.sort
    end

    def self.save_places(places)
      active, disabled = places.partition { |_slug, place| place['enabled'] != false }
      active.sort_by! { |_slug, place| [-place.fetch('count', 0), place.fetch('name')] }
      lines = [
        '---',
        '# Two points define a rectangle; three or more define a polygon.',
        '# An array of polygons supports disconnected areas.',
        '# Coordinates are [latitude, longitude]. Overlapping places all match.',
        'places:'
      ]
      (active + disabled).each do |slug, place|
        lines << "  #{slug}:"
        if place['enabled'] == false
          lines << '    enabled: false'
          next
        end
        lines << "    name: #{JSON.generate(place.fetch('name'))}"
        lines << "    aliases: #{JSON.generate(place.fetch('aliases'))}" if place.key?('aliases')
        lines << "    location: #{JSON.generate(place.fetch('location'))}" if place.key?('location')
        lines << "    osm: #{JSON.generate(place.fetch('osm'))}" if place.key?('osm')
        lines << "    count: #{place.fetch('count', 0)}"
        lines << "    bounds: #{JSON.generate(place.fetch('bounds'))}"
      end
      temporary_file = "#{DATA_FILE}.tmp"
      File.binwrite(temporary_file, "#{lines.join("\n")}\n")
      File.rename(temporary_file, DATA_FILE)
    ensure
      File.delete(temporary_file) if temporary_file && File.exist?(temporary_file)
    end

    def self.validate_bounds!(slug, bounds)
      valid = polygons(bounds).all? { |polygon| polygon.length >= 2 }
      raise "#{DATA_FILE}: #{slug} bounds must contain at least two [latitude, longitude] points" unless valid
    end

    def self.compile_places(places)
      places.to_h do |slug, place|
        compiled = polygons(place.fetch('bounds')).map do |polygon|
          polygon = rectangle(polygon) if polygon.length == 2
          edges = polygon.each_with_index.map do |boundary_start, index|
            boundary_end = polygon[(index + 1) % polygon.length]
            [boundary_start, boundary_end, bounding_box([boundary_start, boundary_end])]
          end
          [polygon, bounding_box(polygon), edges]
        end
        [slug, compiled]
      end
    end

    def self.intersects?(route, route_box, compiled_polygons)
      return false if route.empty?

      compiled_polygons.any? do |polygon, polygon_box, edges|
        next false unless boxes_intersect?(route_box, polygon_box)

        route.any? { |point| point_in_polygon?(point, polygon) } ||
          route.each_cons(2).any? do |route_start, route_end|
            segment_box = bounding_box([route_start, route_end])
            next false unless boxes_intersect?(segment_box, polygon_box)

            edges.any? do |boundary_start, boundary_end, boundary_box|
              next false unless boxes_intersect?(segment_box, boundary_box)

              segments_intersect?(route_start, route_end, boundary_start, boundary_end)
            end
          end
      end
    end

    def self.bounding_box(points)
      latitudes = points.map(&:first)
      longitudes = points.map(&:last)
      [latitudes.min, latitudes.max, longitudes.min, longitudes.max]
    end

    def self.boxes_intersect?(first, second)
      first[0] <= second[1] &&
        first[1] >= second[0] &&
        first[2] <= second[3] &&
        first[3] >= second[2]
    end

    def self.polygons(bounds)
      return [] unless bounds.is_a?(Array) && !bounds.empty?
      return [bounds] if bounds.all? { |point| point?(point) }
      return bounds if bounds.all? { |polygon| polygon.is_a?(Array) && polygon.all? { |point| point?(point) } }

      []
    end

    def self.point?(point)
      point.is_a?(Array) &&
        point.length == 2 &&
        point.all? { |coordinate| coordinate.is_a?(Numeric) }
    end

    def self.rectangle(bounds)
      south, north = bounds.map(&:first).minmax
      west, east = bounds.map(&:last).minmax
      [[south, west], [south, east], [north, east], [north, west]]
    end

    def self.point_in_polygon?(point, polygon)
      return true if polygon.each_with_index.any? do |boundary_start, index|
        on_segment?(boundary_start, point, polygon[(index + 1) % polygon.length])
      end

      latitude, longitude = point
      inside = false
      previous = polygon[-1]

      polygon.each do |current|
        current_latitude, current_longitude = current
        previous_latitude, previous_longitude = previous
        crosses = (current_latitude > latitude) != (previous_latitude > latitude)
        if crosses
          intersection = ((previous_longitude - current_longitude) *
            (latitude - current_latitude) / (previous_latitude - current_latitude)) + current_longitude
          inside = !inside if longitude < intersection
        end
        previous = current
      end
      inside
    end

    def self.segments_intersect?(a_start, a_end, b_start, b_end)
      orientations = [
        orientation(a_start, a_end, b_start),
        orientation(a_start, a_end, b_end),
        orientation(b_start, b_end, a_start),
        orientation(b_start, b_end, a_end)
      ]
      if orientations.none?(&:zero?)
        return true if orientations[0] != orientations[1] && orientations[2] != orientations[3]
      end

      on_segment?(a_start, b_start, a_end) ||
        on_segment?(a_start, b_end, a_end) ||
        on_segment?(b_start, a_start, b_end) ||
        on_segment?(b_start, a_end, b_end)
    end

    def self.orientation(start_point, end_point, point)
      value = ((end_point[1] - start_point[1]) * (point[0] - end_point[0])) -
              ((end_point[0] - start_point[0]) * (point[1] - end_point[1]))
      return 0 if value.abs < 1e-12

      value.positive? ? 1 : 2
    end

    def self.on_segment?(start_point, point, end_point)
      orientation(start_point, end_point, point).zero? &&
        point[0].between?(*[start_point[0], end_point[0]].minmax) &&
        point[1].between?(*[start_point[1], end_point[1]].minmax)
    end

    private_class_method :sample_route, :distance_between, :radians, :normalized_name, :preferred_slug,
                         :merge_aliases!, :validate_bounds!, :compile_places, :intersects?, :bounding_box,
                         :boxes_intersect?, :polygons, :point?, :rectangle, :point_in_polygon?,
                         :segments_intersect?, :orientation, :on_segment?
  end
end
