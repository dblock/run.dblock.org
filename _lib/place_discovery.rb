# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open3'
require 'uri'

require './_lib/place_tags'

module Strava
  module PlaceDiscovery
    NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
    USER_AGENT = 'run.dblock.org place discovery (https://github.com/dblock/run.dblock.org)'
    COUNTRY_ALIASES = {
      'USA' => 'United States',
      'UK' => 'United Kingdom'
    }.freeze

    def self.discover!(only: nil, full: false)
      places = PlaceTags.load_places(include_disabled: true)
      records = activity_records
      touched_files = only || full ? records.keys : changed_activity_files
      candidates = candidates(records, touched_files)
      candidates.select! { |candidate| slugify(candidate[:name]) == only } if only

      added = []
      changed = false
      candidates.each do |candidate|
        slug = available_slug(candidate, places)
        next if slug.nil?

        result = search(candidate)
        unless result
          warn "No boundary found for #{candidate[:query]}."
          next
        end

        discovered_bounds = bounds(result)
        source = [result['osm_type'], result['osm_id']].compact.join('/')
        canonical_name = result['name'] || candidate[:name]
        duplicate_slug = duplicate_slug(places, canonical_name, candidate[:country], source, discovered_bounds)
        if duplicate_slug
          changed = add_aliases!(places.fetch(duplicate_slug), candidate[:name], canonical_name) || changed
          next
        end

        place = {
          'name' => canonical_name,
          'count' => 0,
          'bounds' => discovered_bounds
        }
        aliases = [candidate[:name]].reject { |name| name == canonical_name }
        place['aliases'] = aliases unless aliases.empty?
        place['osm'] = source unless source.empty?
        location = [candidate[:state], candidate[:country]].compact.join(', ')
        place['location'] = location unless location.empty?
        places[slug] = place
        added << slug
        changed = true
      end
      PlaceTags.save_places(places) if changed
      added
    end

    def self.activity_records
      Dir['_activities/**/*.json'].to_h { |file| [file.tr('\\', '/'), JSON.parse(File.binread(file))] }
    end

    def self.changed_activity_files
      output, error, status = Open3.capture3(
        'git', 'status', '--porcelain=v1', '--untracked-files=all', '--', '_activities'
      )
      raise "Unable to inspect changed activities: #{error}" unless status.success?

      output.lines.filter_map do |line|
        path = line[3..]&.strip
        path&.tr('\\', '/') if path&.end_with?('.json')
      end
    end

    def self.candidates(records, touched_files)
      touched_files = touched_files.to_h { |file| [file, true] }
      cities = Hash.new do |hash, key|
        hash[key] = { activity_ids: {}, queries: Hash.new(0), touched: false }
      end

      records.each do |file, activity|
        activity_cities = {}
        activity.fetch('segment_efforts', []).each do |effort|
          segment = effort['segment'] || {}
          city = segment['city']
          next if city.nil? || city.empty?

          state = segment['state']
          raw_country = segment['country']
          city = normalize_city(city, state, raw_country)
          country = COUNTRY_ALIASES.fetch(raw_country, raw_country)
          key = city_key(city, state, country)
          query = [city, state, country].compact.reject(&:empty?).join(', ')
          activity_cities[key] = { name: city, state: state, country: country, query: query }
          cities[key][:queries][query] += 1
        end

        activity_cities.each do |key, city|
          cities[key][:activity_ids][activity.fetch('id')] = true
          cities[key][:name] = city.fetch(:name)
          cities[key][:state] = city[:state]
          cities[key][:country] = city[:country]
          cities[key][:touched] ||= touched_files.key?(file)
        end
      end

      city_candidates = cities.values.filter_map do |city|
        count = city.fetch(:activity_ids).length
        next unless city.fetch(:touched) && count.positive?

        query = city.fetch(:queries).max_by { |_value, occurrences| occurrences }.first
        {
          type: :city,
          name: city.fetch(:name),
          state: city[:state],
          country: city[:country],
          count: count,
          query: query
        }
      end

      touched_countries = city_candidates.map { |candidate| candidate[:country] }.compact.uniq
      country_candidates = touched_countries.filter_map do |country|
        country_cities = cities.values.select do |city|
          city[:country] == country && city.fetch(:activity_ids).any?
        end
        next if country.empty? || country_cities.length == 1

        {
          type: :country,
          name: country,
          count: country_cities.sum { |city| city.fetch(:activity_ids).length },
          query: country
        }
      end

      (city_candidates + country_candidates).sort_by { |candidate| [-candidate[:count], candidate[:query]] }
    end

    def self.city_key(name, state, country)
      [name, state, country].map { |value| value.to_s.downcase }.join("\0")
    end

    def self.normalize_city(city, state, country)
      canonical_country = COUNTRY_ALIASES.fetch(country, country)
      country_names = [country, canonical_country]
      country_names.concat(COUNTRY_ALIASES.filter_map { |alias_name, name| alias_name if name == canonical_country })
      country_names.compact!
      country_names.uniq!
      suffixes = country_names.map { |name| [state, name].compact.reject(&:empty?).join(', ') }
      suffixes.concat([state], country_names)
      suffixes.compact!
      suffixes.reject!(&:empty?)
      suffix = suffixes.find { |value| city.end_with?(", #{value}") }
      suffix ? city.delete_suffix(", #{suffix}") : city
    end

    def self.search(candidate)
      uri = URI(NOMINATIM_URL)
      parameters = {
        q: candidate[:query],
        format: 'jsonv2',
        addressdetails: 1,
        polygon_geojson: 1,
        polygon_threshold: 0.002,
        limit: 1
      }
      parameters[:featuretype] = 'country' if candidate[:type] == :country
      uri.query = URI.encode_www_form(parameters)
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30
      response = http.request(request)
      raise "Nominatim request failed for #{candidate[:query]}: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).first
    ensure
      sleep 1.1
    end

    def self.bounds(result)
      geometry = result['geojson']
      polygons = case geometry&.fetch('type', nil)
                 when 'Polygon'
                   [geometry.fetch('coordinates').first]
                 when 'MultiPolygon'
                   geometry.fetch('coordinates').map(&:first)
                 else
                   []
                 end
      converted = polygons.map do |polygon|
        polygon.map { |longitude, latitude| [latitude.round(5), longitude.round(5)] }
      end
      converted.reject! { |polygon| polygon.length < 3 }
      return converted.first if converted.length == 1
      return converted if converted.any?

      south, north, west, east = result.fetch('boundingbox').map(&:to_f)
      [[south, west], [north, east]]
    end

    def self.available_slug(candidate, places)
      base = slugify(candidate[:name])
      return nil if places[base]&.fetch('enabled', true) == false
      return nil if place_named(places, candidate[:name], candidate[:country])
      return base unless places.key?(base)

      suffix = slugify(candidate[:state] || candidate[:country])
      slug = "#{base}-#{suffix}"
      return nil if places[slug]&.fetch('enabled', true) == false

      places.key?(slug) ? nil : slug
    end

    def self.place_named(places, name, country)
      places.any? do |_slug, place|
        next false if place['enabled'] == false

        names = [place.fetch('name'), *place.fetch('aliases', [])]
        next false unless names.any? { |candidate| slugify(candidate) == slugify(name) }

        existing_country = place['location'].to_s.split(', ').last.to_s
        country.nil? || existing_country.empty? || existing_country == country
      end
    end

    def self.duplicate_slug(places, name, country, source, discovered_bounds)
      places.find do |_slug, place|
        next false if place['enabled'] == false

        names = [place.fetch('name'), *place.fetch('aliases', [])]
        same_source = !source.empty? && place['osm'] == source
        same_bounds = place.fetch('bounds') == discovered_bounds
        same_name = names.any? { |candidate| slugify(candidate) == slugify(name) }
        existing_country = place['location'].to_s.split(', ').last
        same_source || same_bounds || (same_name && (country.nil? || existing_country == country))
      end&.first
    end

    def self.add_aliases!(place, *names)
      aliases = place.fetch('aliases', []).dup
      original_aliases = aliases.dup
      names.compact.each do |name|
        next if name == place.fetch('name') || aliases.include?(name)

        aliases << name
      end
      return false if aliases == original_aliases

      place['aliases'] = aliases.sort
      true
    end

    def self.slugify(value)
      value.to_s
           .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '')
           .downcase
           .unicode_normalize(:nfkd)
           .encode('ASCII', invalid: :replace, undef: :replace, replace: '')
           .gsub(/[^a-z0-9]+/, '-')
           .gsub(/\A-|-\z/, '')
    end

    private_class_method :activity_records, :changed_activity_files, :candidates, :city_key, :normalize_city,
                         :search, :bounds, :available_slug, :place_named, :duplicate_slug, :add_aliases!, :slugify
  end
end
