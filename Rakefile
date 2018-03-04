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
    require 'strava/api/v3'
    require 'fileutils'
    require 'polylines'
    require 'dotenv/load'

    strava_api_token = ENV['STRAVA_API_TOKEN']
    raise 'Missing STRAVA_API_TOKEN' unless strava_api_token

    google_maps_api_key = ENV['GOOGLE_STATIC_MAPS_API_KEY']
    raise 'Missing GOOGLE_STATIC_MAPS_API_KEY' unless google_maps_api_key

    client = Strava::Api::V3::Client.new(access_token: strava_api_token)

    client.list_athlete_activities.each do |activity|
      start_date_local = DateTime.parse(activity['start_date_local'])
      distance_in_miles_f = activity['distance'] * 0.00062137
      distance_in_miles = format('%.2fmi', distance_in_miles_f)
      rounded_distance_in_miles = format('%d-%0d', distance_in_miles_f, distance_in_miles_f + 1)
      time_in_hours = format('%dh%02dm%02ds', activity['moving_time'] / 3600 % 24, activity['moving_time'] / 60 % 60, activity['moving_time'] % 60)
      average_speed = format('%.2fmph', (activity['average_speed'] * 2.23694))
      pace_per_mile = Time.at((60 * 60) / (activity['average_speed'] * 2.23694)).utc.strftime('%M:%S')
      summary_polyline = activity['map']['summary_polyline']
      workout_type = case activity['workout_type']
                     when 1 then 'race'
                     when 2 then 'long run'
                     when 3 then 'workout'
                     else 'run'
      end
      decoded_polyline = Polylines::Decoder.decode_polyline(summary_polyline)
      start_latlng = decoded_polyline[0]
      end_latlng = decoded_polyline[-1]

      filename = [
        "_posts/#{start_date_local.year}/#{start_date_local.strftime('%Y-%m-%d')}",
        activity['type'].downcase,
        distance_in_miles,
        time_in_hours
      ].join('-') + '.md'

      FileUtils.mkdir_p "_posts/#{start_date_local.year}"

      File.open filename, 'w' do |file|
        file.write <<-EOS
---
layout: post
title: "#{activity['name']}"
date: "#{start_date_local.strftime('%F %T')}"
tags: [#{workout_type}s, #{rounded_distance_in_miles} miles]
race: #{workout_type == 'race'}
---
<ul>
 <li>Distance: #{distance_in_miles}</li>
 <li>Time: #{time_in_hours}</li>
 <li>Pace: #{pace_per_mile}</li>
</ul>

<img src='https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{summary_polyline}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}'>
  EOS

        client.list_activity_photos(activity['id'], size: '600').each do |photo|
          url = photo['urls']['600']
          file.write "\n<img src='#{url}'>\n"
        end
      end

      puts filename
    end
  end
end
