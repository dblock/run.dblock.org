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
    require './_lib/map'
    require './_lib/activity'

    require 'fileutils'
    require 'polylines'

    require 'dotenv/load'

    page = 1
    loop do
      activities = Strava.client.list_athlete_activities(page: page, per_page: 10)
      break unless activities.any?
      activities.each do |data|
        activity = Activity.new(data)

        FileUtils.mkdir_p "_posts/#{activity.start_date_local.year}"

        retrieved_activity = Strava.client.retrieve_an_activity(activity.strava_id)
        activity.description = retrieved_activity['description']

        File.open activity.filename, 'w' do |file|
          file.write <<-EOS
---
layout: post
title: "#{activity.name}"
date: "#{activity.start_date_local.strftime('%F %T')}"
tags: [#{activity.type.downcase}s, #{activity.rounded_distance_in_miles_s} miles]
race: #{activity.race?}
---
<ul>
 <li>Distance: #{activity.distance_in_miles_s}</li>
 <li>Time: #{activity.moving_time_in_hours_s}</li>
 <li>Pace: #{activity.pace_per_mile_s}</li>
</ul>
  EOS
          file.write "\n#{activity.description}" if activity.description && activity.description.length > 0
          file.write "\n<img src='#{activity.map.image_url}'>\n"if activity.map && activity.map.image_url

          Strava.client.list_activity_photos(activity.strava_id, size: '600').each do |photo|
            url = photo['urls']['600']
            file.write "\n<img src='#{url}'>\n"
          end
        end
        puts activity.filename
      end
      page += 1
    end
  end
end
