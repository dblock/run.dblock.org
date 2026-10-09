# frozen_string_literal: true

require 'date'
require 'json'
require 'yaml'

module Strava
  module ActivityCache
    def self.activities
      posts = posts_by_strava_id
      parsed = Dir['_activities/**/*.json'].sort.filter_map do |file|
        activity = JSON.parse(File.binread(file))
        next unless activity['id'] && activity['start_date_local']

        activity.merge('_source_basename' => File.basename(file, '.json'))
      end
      parsed.group_by { |activity| activity.fetch('id').to_s }.map do |strava_id, candidates|
        post = posts[strava_id]
        candidates.find { |activity| activity.fetch('_source_basename') == post&.fetch(:basename) } ||
          candidates.max_by { |activity| activity['updated_at'].to_s }
      end.sort_by { |activity| activity.fetch('start_date_local') }.reverse
    end

    def self.posts_by_strava_id
      Dir['_posts/**/*.md'].sort.filter_map do |file|
        contents = File.read(file)
        front_matter = contents.match(/\A---\s*\n(?<yaml>.*?)\n---\s*\n/m)
        next unless front_matter

        data = YAML.safe_load(
          front_matter[:yaml],
          permitted_classes: [Date, Time],
          aliases: true
        )
        strava_id = data['strava_id']
        next unless strava_id

        [strava_id.to_s, { basename: File.basename(file, '.md') }]
      end.to_h
    end

    private_class_method :posts_by_strava_id
  end
end
