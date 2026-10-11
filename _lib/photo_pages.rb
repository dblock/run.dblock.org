# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'yaml'

module Strava
  module PhotoPages
    OUTPUT_DIR = 'photos'

    def self.generate!
      years = photo_years
      raise 'No activity photos found.' if years.empty?

      temporary_dir = "#{OUTPUT_DIR}.tmp"
      FileUtils.rm_rf(temporary_dir)
      FileUtils.mkdir_p(temporary_dir)

      File.binwrite(
        File.join(temporary_dir, 'index.html'),
        front_matter(
          'layout' => 'photo-redirect',
          'title' => 'Photos',
          'photo_year' => years.first,
          'sitemap' => false
        )
      )
      years.each do |year|
        year_dir = File.join(temporary_dir, year)
        FileUtils.mkdir_p(year_dir)
        File.binwrite(
          File.join(year_dir, 'index.html'),
          front_matter(
            'layout' => 'photos',
            'title' => "Photos #{year}",
            'year' => year
          )
        )
      end

      FileUtils.rm_rf(OUTPUT_DIR)
      FileUtils.mv(temporary_dir, OUTPUT_DIR)
      years
    ensure
      FileUtils.rm_rf(temporary_dir) if temporary_dir && Dir.exist?(temporary_dir)
    end

    def self.photo_years
      Dir['_posts/**/*.md'].filter_map do |file|
        contents = File.binread(file)
        front_matter = contents.match(/\A---\s*\n(?<yaml>.*?)\n---\s*\n/m)
        next unless front_matter

        data = YAML.safe_load(
          front_matter[:yaml],
          permitted_classes: [Date, Time],
          aliases: true
        )
        next unless data.fetch('photos', []).any?

        data.fetch('date').to_s[0, 4]
      end.uniq.sort.reverse
    end

    def self.front_matter(data)
      "#{YAML.dump(data.compact)}---\n"
    end

    private_class_method :photo_years, :front_matter
  end
end
