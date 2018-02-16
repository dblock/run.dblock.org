desc 'Re-generate tag pages.'
task :tags do
  Dir['tags/*.md'].each { |f| File.delete(f) }
  tags = {}
  Dir['**/*.md'].each do |file|
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
  File.write '_data/tags.yml', tags.keys.sort.map { |tag| "#{tag}:\n  name: #{tag}\n  count: #{tags[tag]}" }.join("\n")
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
    require 'strava/api/v3'
    require 'stringex'
    require 'fileutils'

    strava_api_token = ENV['STRAVA_API_TOKEN']
    raise 'Missing STRAVA_API_TOKEN' unless strava_api_token

    google_maps_api_key = 'AIzaSyC1MId7bFpkLXNAaYhBSTb8jLyiSqzbDtM'
    client = Strava::Api::V3::Client.new(access_token: strava_api_token)

    client.list_athlete_activities.each do |activity|
      start_date_local = DateTime.parse(activity['start_date_local'])
      distance_in_miles = '%.2fmi' % (activity['distance'] * 0.00062137)
      time_in_hours = '%dh%02dm%02ds' % [activity['moving_time']/3600%24, activity['moving_time']/60%60, activity['moving_time']%60]
      average_speed = '%.2fmph' % (activity['average_speed'] * 2.23694)
      pace_per_mile = Time.at((60*60)/(activity['average_speed'] * 2.23694)).utc.strftime("%M:%S")
      polyline = activity['map']['summary_polyline']
      workout_type = case activity['workout_type']
      when 1 then 'race'
      when 2 then 'long run'
      when 3 then 'workout'
      else 'run'
      end

      filename = [
        "_posts/#{start_date_local.year}/#{start_date_local.strftime('%Y-%m-%d')}",
        activity['type'].downcase,
        distance_in_miles,
        time_in_hours
      ].join('-') + '.md'

      FileUtils::mkdir_p "_posts/#{start_date_local.year}"

      File.open filename, "w" do |file|
  file.write <<-EOS
---
layout: post
title: "#{activity['name']}"
date: "#{start_date_local.strftime('%F %T')}"
tags: [#{workout_type}]
race: #{workout_type == 'race'}
---
<ul>
 <li>Distance: #{distance_in_miles}</li>
 <li>Time: #{time_in_hours}</li>
 <li>Pace: #{pace_per_mile}</li>
</ul>

<img src='https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{polyline}&key=#{google_maps_api_key}&size=800x800'>
  EOS
      end

      puts filename
    end
  end
end

