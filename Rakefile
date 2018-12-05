desc 'Re-generate tag pages.'
task :tags do
  Dir['tags/*.md'].each { |f| File.delete(f) }
  tags = {}
  Dir['_posts/**/*.md'].each do |file|
    tagline = File.read(file).split("\n").detect { |line| line.start_with?('tags: ') }
    next unless tagline

    tagline.tr('[', '').tr(']', '').split(':').last.split(',').map(&:strip).each do |tag|
      next if tag.empty?

      tags[tag] ||= 0
      tags[tag] += 1
    end
  end
  # tags.delete_if { |_k, v| v < 5 }
  tags.keys.each do |tag|
    filename = "tags/#{tag}.md"
    puts filename
    File.write filename, <<-EOS
---
layout: tag
tag: #{tag}
permalink: /tags/#{tag}/
---
    EOS
  end

  tag_keys = tags.keys.sort_by do |tag|
    # mile ranges in order
    m = tag.match(/^\d*/)
    m && m[0].to_i > 0 ? format('%02d', m[0].to_i) : tag
  end

  tag_lines = tag_keys.map do |tag|
    "#{tag}:\n  name: #{tag}\n  count: #{tags[tag]}"
  end

  File.write '_data/tags.yml', tag_lines.join("\n")
end

desc 'Check for broken links and such.'
task :check do
  require 'html-proofer'
  sh 'bundle exec jekyll build'
  HTMLProofer.check_directory(
    './_site',
    alt_ignore: [/.*/],
    http_status_ignore: [999]
  ).run
end

desc 'Update NYRR ID.'
namespace :nyrr do
  namespace :results do
    task :update do
      require './_lib/nyrr_results'
      config = YAML.load_file('_config.yml')
      name = config['owner']['name']
      puts "Searching NYRR for #{name} ..."
      runner_id = NYRR::Results.search(name).first['runnerId']
      if config['owner']['nyrr-results'] != runner_id
        puts "Updated runner ID #{runner_id} ..."
        config['owner']['nyrr-results'] = runner_id
        File.write('_config.yml', config.to_yaml)
      else
        puts "Unchanged runner ID #{runner_id} ..."
      end
    end
  end
end

desc 'Generate runs from Strava.'
namespace :strava do
  task :update do
    require 'hashie'

    require 'strava-ruby-client'

    require './_lib/strava'
    require './_lib/map'
    require './_lib/activity'

    require 'fileutils'
    require 'polylines'

    require 'dotenv/load'

    start_at_year = 2018

    activities_options = { per_page: 10, after: Time.new(start_at_year).to_i }
    activities = Strava.client.athlete_activities(activities_options.merge(page: 1))

    Dir['_posts/*'].each do |folder|
      year = folder.split('/').last
      next if year.to_i < start_at_year

      FileUtils.rm(Dir.glob("#{folder}/#{year}-*-run-*mi-*s.md"))
    end

    page = 1
    loop do
      break unless activities.any?

      activities.each do |activity|
        next unless activity.type == 'Run'
        activity = Strava.client.activity(activity.id)

        FileUtils.mkdir_p "_posts/#{activity.start_date_local.year}"

        File.open activity.filename, 'w' do |file|
          tags = [
            "#{activity.type.downcase}s",
            "#{activity.rounded_distance_in_miles_s} miles",
            activity.race? ? 'races' : nil
          ].compact

          file.write <<-EOS
---
layout: post
title: "#{activity.name}"
date: "#{activity.start_date_local.strftime('%F %T')}"
tags: [#{tags.join(', ')}]
race: #{activity.race?}
strava: true
---
          EOS

          file.write "\n### Stats\n"
          file.write "\n| Distance | Time | Pace |"
          file.write "\n|----------|------|------|"
          file.write "\n|#{activity.distance_in_miles_s}|#{activity.moving_time_in_hours_s}|#{activity.pace_per_mile_s}|\n"

          file.write "\n#{activity.description}\n" if activity.description && !activity.description.empty?
          file.write "\n<img src='#{activity.map.image_url}'>\n" if activity.map && activity.map.image_url

          if activity.splits_standard && activity.splits_standard.any?
            file.write "\n### Splits\n"
            file.write "\n| Mile | Pace | Elevation |"
            file.write "\n|------|------|-----------|"
            activity.splits_standard.each do |split|
              file.write "\n|#{split.split}|#{split.pace_per_mile_s}|#{split.total_elevation_gain_in_feet_s}|"
            end
            file.write "\n"
          end

          photos = Strava.client.activity_photos(activity.id, size: '600')
          if photos.any?
            file.write "\n### Photos"
            photos.each do |photo|
              url = photo.urls['600']
              file.write "\n<img src='#{url}'>\n"
            end
          end
        end
        puts activity.filename
      end
      page += 1
      activities = Strava.client.athlete_activities(activities_options.merge(page: page))
    end
  end
end
