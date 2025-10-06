desc 'Generate PRs.'
task :prs do
  require 'yaml'
  prs = {
    1 => nil,
    3.1 => nil,
    4.0 => nil,
    6.2 => nil,
    10.0 => nil,
    13.1 => nil,
    26.2 => nil
  }
  Dir['_posts/**/*.md'].each do |file|
    distance = nil
    time = nil
    title = nil
    distance_s = nil
    time_s = nil
    pace_s = nil
    File.read(file).split("\n").each do |line|
      distance = line.split(':', 2)[1].to_f if line.start_with?('distance: ')
      time = line.split(':', 2)[1].to_f if line.start_with?('time: ')
      title = line.split(':', 2)[1].strip.delete_prefix('"').delete_suffix('"') if line.start_with?('title: ')
      distance_s, time_s, pace_s = line.split('|')[1..3] if line.start_with?('|') && line.end_with?('/mi|')
    end
    next unless distance && time
    pr_key = nil
    prs.each_pair do |pr_distance, _|
      if distance > pr_distance && (distance - pr_distance) <= 0.2
        pr_key = pr_distance
        break
      end
    end
    next unless pr_key
    file = file.split('/')[2].split('-')[0...3].join('/') + '/' + file.split('/')[2].split('-', 4)[3].gsub('.md', '.html')
    prs[pr_key] = { 
      'file' => file, 
      'time' => time, 
      'title' => title,
      'distance_s' => distance_s,
      'time_s' => time_s,
      'pace_s' => pace_s
    } if prs[pr_key].nil? || prs[pr_key]['time'] > time
  end
  File.open('_data/prs.yml', 'w') do |f| 
    f.write prs.to_yaml
  end
  puts "Written data/prs.yml with #{prs}."
end

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
    tag_filename = tag.gsub('<', 'lt').gsub('/', '_')
    filename = "tags/#{tag_filename}.md"
    puts filename
    File.write filename, <<-EOS
---
layout: tag
tag: #{tag}
permalink: /tags/#{tag_filename}/
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
    tag_filename = tag.gsub('<', 'lt').gsub('/', '_')
    "#{tag_filename}:\n  name: #{tag}\n  count: #{tags[tag]}"
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
      runner = NYRR::Results.search(name).first
      raise "Cannot find runner #{name}." unless runner
      runner_id = runner['runnerId']
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

    require 'active_support'
    require 'active_support/core_ext/date/calculations'

    start_at_month = Date.today.at_beginning_of_month.prev_month
    start_at_year = start_at_month.year

    Strava::Web::Client.configure do |config|
      config.ca_file = nil
      config.ca_path = nil
    end

    activities_options = { per_page: 10, after: start_at_month.to_datetime.to_i }
    activities = Strava.client.athlete_activities(activities_options.merge(page: 1))

    if activities.none?
      start_at_month = start_at_month.prev_month
      activities_options[:after] = start_at_month.to_datetime.to_i
      activities = Strava.client.athlete_activities(activities_options.merge(page: 1))
    end

    current_month = start_at_month
    while current_month < Date.today
      ['_posts', '_activities'].each do |path|
        glob = "#{path}/#{current_month.year}/#{current_month.year}-#{"%02d" % current_month.month}-*-run-*mi-*s.md"
        puts "Deleting #{glob}"
        FileUtils.rm_f(Dir.glob(glob))
      end
      current_month = current_month.next_month
    end

    page = 1
    loop do
      break unless activities.any?

      activities.each do |activity|
        next unless activity.type == 'Run'
        activity = Strava.client.activity(activity.id)

        FileUtils.mkdir_p "_activities/#{activity.start_date_local.year}"
        File.open activity.json_filename, 'w' do |file|
          file.write(JSON.pretty_generate(activity.to_h))
        end

        FileUtils.mkdir_p "_posts/#{activity.start_date_local.year}"

        run_with_names = []
        [/run with (?<name>\w*)/i, /run with .* and (?<name>\w*)/i].each do |regex|
          run_with_match = activity.name.match(regex)
          run_with_names << run_with_match['name'] if run_with_match
        end

        File.open activity.filename, 'w' do |file|
          tags = [
            "#{activity.type.downcase}s",
            "#{activity.rounded_distance_in_miles_s} miles",
            activity.rounded_pace_per_mile_s,
            activity.race? ? 'races' : nil,
            activity.max_heartrate ? "μ#{activity.rounded_max_heartrate_s} bpm" : nil,
            activity.average_heartrate ? "→#{activity.rounded_average_heartrate_s} bpm" : nil,
            run_with_names.any? ? run_with_names.map { |name| "w/#{name.downcase}" } : nil
          ].compact

          data = {
            layout: 'post',
            title: "\"#{activity.name}\"",
            date: "\"#{activity.start_date_local.strftime('%F %T')}\"",
            tags: "[#{tags.join(', ')}]",
            race: activity.race?,
            distance: activity.distance_in_miles,
            time: activity.moving_time,
            average_heartrate: activity.average_heartrate,
            max_heartrate: activity.max_heartrate,
            strava_id: activity.id,
            strava: true
          }.compact

          file.write "---\n"
          data.each_pair do |k, v|
            file.write "#{k}: #{v}\n"
          end
          file.write "---\n"

          file.write "\n### Stats\n"
          file.write "\n| Distance | Time | Pace |"
          file.write "\n|----------|------|------|"
          file.write "\n|#{activity.distance_in_miles_s}|#{activity.moving_time_in_hours_s}|#{activity.pace_per_mile_s}|\n"

          file.write "\n#{activity.description}\n" if activity.description && !activity.description.empty?

          unless File.exist?(activity.map_filename)
            FileUtils.mkdir_p(File.dirname(activity.map_filename))
            File.write(activity.map_filename, activity.map.png)
          end

          file.write "\n![]({{ site.url }}/#{activity.map_filename})\n"

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
