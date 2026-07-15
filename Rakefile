# frozen_string_literal: true

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

    file = file
           .split('/')[2]
           .split('-')[0...3]
           .join('/') +
           '/' +
           file
           .split('/')[2]
           .split('-', 4)[3]
           .gsub('.md', '.html')
    next unless prs[pr_key].nil? || prs[pr_key]['time'] > time

    prs[pr_key] = {
      'file' => file,
      'time' => time,
      'title' => title,
      'distance_s' => distance_s,
      'time_s' => time_s,
      'pace_s' => pace_s
    }
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
  tags.each_key do |tag|
    tag_filename = tag.gsub('<', 'lt').gsub('/', '_')
    filename = "tags/#{tag_filename}.md"
    puts filename
    File.write filename, <<~EOS
      ---
      layout: tag
      title: "#{tag}"
      tag: #{tag}
      permalink: /tags/#{tag_filename}/
      ---
    EOS
  end

  tag_keys = tags.keys.sort_by do |tag|
    # mile ranges in order
    m = tag.match(/^\d*/)
    m && m[0].to_i.positive? ? format('%02d', m[0].to_i) : tag
  end

  tag_lines = tag_keys.map do |tag|
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
    require './_lib/post'
    require 'dotenv/load'

    year = ENV['YEAR']
    from = ENV['FROM']
    to = ENV['TO']

    if from
      parts = from.split('/')
      start_at = Time.local(parts[0].to_i, parts[1].to_i, 1, 0, 0, 0)
    elsif year
      start_at = Time.local(year.to_i, 1, 1, 0, 0, 0)
    else
      start_at = Date.today.at_beginning_of_month
    end

    if to
      parts = to.split('/')
      end_month = Time.local(parts[0].to_i, parts[1].to_i, 1, 0, 0, 0)
      end_at = end_month.to_date.next_month
      end_at = Time.local(end_at.year, end_at.month, 1)
    elsif year
      end_at = Time.local(year.to_i + 1, 1, 1, 0, 0, 0)
    else
      end_at = Date.today
    end

    activities_options = { per_page: 3, after: start_at.to_datetime.to_i }
    activities = Strava.client.athlete_activities(activities_options)

    if activities.none?
      start_at = start_at.prev_month
      activities_options[:after] = start_at.to_datetime.to_i
      activities = Strava.client.athlete_activities(activities_options)
    end

    current = start_at
    while current < end_at
      {
        '_posts' => 'md',
        '_activities' => 'json'
      }.each_pair do |path, ext|
        glob = "#{path}/#{current.year}/#{current.year}-#{'%02d' % current.month}-*-*-*mi-*s.#{ext}"
        puts "Deleting #{glob}"
        FileUtils.rm_f(Dir.glob(glob))
      end
      next_month = current.to_date.next_month
      current = Time.local(next_month.year, next_month.month, 1)
    end

    activities.each do |activity|
      next unless %w[Run TrailRun].include?(activity.sport_type)

      done = activity.start_date_local > end_at
      break if done

      post = Strava::Post.new(activity.id)
      post.save!
      puts post.filename
    end
  end

  desc 'Update all runs from Strava.'
  task :update_all do
    require './_lib/post'
    require 'dotenv/load'

    start_at_year = 2017
    start_at = Time.local(start_at_year, 1, 1, 0, 0, 0)

    Strava.client.athlete_activities({ per_page: 10, after: start_at.to_datetime.to_i }).each do |activity|
      next unless %w[Run TrailRun].include?(activity.sport_type)

      next if File.exist?(activity.json_filename)

      post = Strava::Post.new(activity.id)
      post.save!
      puts post.filename

      sleep 45 # avoid rate limits
    end
  end

  desc 'Update one run from Strava.'
  task :update_one do
    require './_lib/post'
    require 'dotenv/load'

    id = ENV['ID'] || raise("Missing ENV['ID'].")
    post = Strava::Post.new(id)
    post.save!
    puts post.filename
  end

  desc 'Generate markdown content from JSON.'
  task :generate_md do
    require './_lib/post'
    require 'dotenv/load'

    Dir.glob('_activities/**/*.json').each do |filename|
      json = JSON.load_file(filename)
      post = Strava::Post.new(json['id'], json)
      post.save!
      puts post.filename
    end
  end
end
