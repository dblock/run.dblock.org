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
  File.write '_data/tags.yml', tags.keys.sort_by { |tag|
    # mile ranges in order
    m = tag.match(/^\d*/)
    m && m[0].to_i > 0 ? format('%02d', m[0].to_i) : tag
  }.map { |tag|
    "#{tag}:\n  name: #{tag}\n  count: #{tags[tag]}"
  }.join("\n")
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

desc 'Generate runs from Strava.'
namespace :strava do
  task :update do
    require 'hashie'

    require 'strava/api/v3'

    require './_lib/strava'
    require './_lib/moving'
    require './_lib/map'
    require './_lib/split'
    require './_lib/activity'

    require 'fileutils'
    require 'polylines'

    require 'dotenv/load'

    Dir['_posts/*'].each do |folder|
      year = folder.split('/').last
      FileUtils.rm(Dir.glob("#{folder}/#{year}-*-run-*mi-*s.md"))
    end

    page = 1
    loop do
      activities = Strava.client.list_athlete_activities(page: page, per_page: 10)
      break unless activities.any?
      activities.each do |data|
        detailed_activity = Strava.client.retrieve_an_activity(data['id'])
        activity = Activity.new(data.merge(detailed_activity))

        FileUtils.mkdir_p "_posts/#{activity.start_date_local.year}"

        File.open activity.filename, 'w' do |file|
          file.write <<-EOS
---
layout: post
title: "#{activity.name}"
date: "#{activity.start_date_local.strftime('%F %T')}"
tags: [#{activity.type.downcase}s, #{activity.rounded_distance_in_miles_s} miles]
race: #{activity.race?}
---
  EOS

          file.write "\n### Stats\n"
          file.write "\n| Distance | Time | Pace |"
          file.write "\n|----------|------|------|"
          file.write "\n|#{activity.distance_in_miles_s}|#{activity.moving_time_in_hours_s}|#{activity.pace_per_mile_s}|\n"

          file.write "\n#{activity.description}\n" if activity.description && activity.description.length > 0
          file.write "\n<img src='#{activity.map.image_url}'>\n"if activity.map && activity.map.image_url

          if activity.splits && activity.splits.any?
            file.write "\n### Splits\n"
            file.write "\n| Mile | Pace | Elevation |"
            file.write "\n|------|------|-----------|"
            activity.splits.each do |split|
              file.write "\n|#{split.split}|#{split.pace_per_mile_s}|#{split.total_elevation_gain_in_feet_s}|"
            end
            file.write "\n"
          end

          photos = Strava.client.list_activity_photos(activity.strava_id, size: '600')
          if photos.any?
            file.write "\n### Photos"
            photos.each do |photo|
              url = photo['urls']['600']
              file.write "\n<img src='#{url}'>\n"
            end
          end
        end
        puts activity.filename
      end
      page += 1
    end
  end
end
