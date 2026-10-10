# frozen_string_literal: true

require 'date'
require 'yaml'
require 'fileutils'
require_relative 'place_tags'

module Strava
  module TagPages
    def self.generate!
      places = PlaceTags.load_places(include_disabled: true)
      totals = {}
      Dir['_posts/**/*.md'].sort.each do |file|
        contents = File.binread(file)
        front_matter = contents.match(/\A---\s*\n(?<yaml>.*?)\n---\s*\n/m)
        next unless front_matter

        post = YAML.safe_load(front_matter[:yaml], permitted_classes: [Date, Time], aliases: true)
        tags = post.fetch('tags', [])
        tags = tags.split if tags.is_a?(String)
        tags.uniq.each do |tag|
          total = totals[tag] ||= { count: 0, distance: 0, time: 0, heartrate: 0, heartrates: 0 }
          total[:count] += 1
          total[:distance] += post.fetch('distance', 0).to_f
          total[:time] += post.fetch('time', 0).to_f
          if post['average_heartrate']
            total[:heartrate] += post.fetch('average_heartrate').to_f
            total[:heartrates] += 1
          end
        end
      end

      tags = totals.keys.sort_by { |tag| sort_key(tag) }
      directory = tags.to_h { |tag| [key(tag), { 'name' => tag, 'count' => totals.fetch(tag).fetch(:count) }] }
      generated_files = []
      FileUtils.mkdir_p('tags')
      page_tags = tags.reject do |tag|
        tag.start_with?('p/') && (places[tag.delete_prefix('p/')].nil? || places[tag.delete_prefix('p/')]['enabled'] == false)
      end
      neighbors = page_tags.each_with_index.to_h do |tag, index|
        [tag, {
          'previous_tag' => index.positive? ? navigation(page_tags[index - 1]) : nil,
          'next_tag' => page_tags[index + 1] ? navigation(page_tags[index + 1]) : nil
        }.compact]
      end
      tags.each do |tag|
        place = places[tag.delete_prefix('p/')] if tag.start_with?('p/')
        next if tag.start_with?('p/') && (place.nil? || place['enabled'] == false)

        total = totals.fetch(tag)
        data = {
          'layout' => 'tag',
          'title' => place ? place.fetch('name') : tag,
          'tag' => tag,
          'permalink' => "/tags/#{key(tag)}/",
          'total_distance' => total.fetch(:distance),
          'total_time' => total.fetch(:time),
          'average_heartrate' => total[:heartrates].positive? ? total[:heartrate] / total[:heartrates] : nil
        }.compact.merge(neighbors.fetch(tag))
        filename = "tags/#{key(tag)}.md"
        write_if_changed(filename, "#{YAML.dump(data)}---\n")
        generated_files << filename
      end
      (Dir['tags/*.md'] - generated_files).each { |file| File.delete(file) }
      write_if_changed('_data/tags.yml', YAML.dump(directory))
      PlaceTags.update_counts!(totals.transform_values { |total| total.fetch(:count) })
      generated_files
    end

    def self.key(tag)
      tag.gsub('<', 'lt').gsub('/', '_')
    end

    def self.sort_key(tag)
      miles = tag[/^\d+/]
      return format('%02d', miles.to_i) if miles && miles.to_i.positive?

      pace = tag.match(%r{^<(?<minutes>\d+)m(?<seconds>\d+)s/mi$})
      return "<#{format('%05d', pace[:minutes].to_i * 60 + pace[:seconds].to_i)}" if pace

      tag
    end

    def self.write_if_changed(filename, contents)
      return if File.exist?(filename) && File.binread(filename) == contents.b

      File.binwrite(filename, contents)
    end

    def self.navigation(tag)
      { 'key' => key(tag), 'name' => tag }
    end

    private_class_method :key, :sort_key, :write_if_changed, :navigation
  end
end
