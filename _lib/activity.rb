class Activity < Hashie::Trash
  include Hashie::Extensions::IgnoreUndeclared

  property :strava_id, from: 'id'
  property :name, from: 'name'
  property :start_date, from: 'start_date', with: ->(data) { DateTime.parse(data) }
  property :start_date_local, from: 'start_date_local', with: ->(data) { DateTime.parse(data) }
  property :distance, from: 'distance'
  property :moving_time, from: 'moving_time'
  property :elapsed_time, from: 'elapsed_time'
  property :average_speed, from: 'average_speed'
  property :total_elevation_gain, from: 'total_elevation_gain'
  property :type, from: 'type'
  property :map, from: 'map', with: ->(data) { Map.new(data) }
  property :description, from: 'description'
  property :workout_type, from: 'workout_type', with: ->(data) {
    case data
    when 1 then 'race'
    when 2 then 'long run'
    when 3 then 'workout'
    else 'run'
    end
  }

  def start_date_local_s
    return unless start_date_local
    start_date_local.strftime('%A, %B %d, %Y at %I:%M %p')
  end

  def distance_in_miles
    distance * 0.00062137
  end

  def distance_in_miles_s
    return unless distance && distance.positive?
    format('%gmi', format('%.2f', distance_in_miles))
  end

  def distance_in_yards
    distance * 1.09361
  end

  def distance_in_yards_s
    return unless distance && distance.positive?
    format('%gyd', format('%.1f', distance_in_yards))
  end

  def distance_in_kilometers
    distance / 1000
  end

  def distance_in_kilometers_s
    return unless distance && distance.positive?
    format('%gkm', format('%.2f', distance_in_kilometers))
  end

  def distance_s
    if type == 'Swim'
      distance_in_yards_s
    else
      case user.team.units
      when 'km' then distance_in_kilometers_s
      when 'mi' then distance_in_miles_s
      end
    end
  end

  def moving_time_in_hours_s
    time_in_hours_s moving_time
  end

  def elapsed_time_in_hours_s
    time_in_hours_s elapsed_time
  end

  def pace_per_mile_s
    convert_meters_per_second_to_pace average_speed, :mi
  end

  def pace_per_100_yards_s
    convert_meters_per_second_to_pace average_speed, :"100yd"
  end

  def pace_per_kilometer_s
    convert_meters_per_second_to_pace average_speed, :km
  end

  def total_elevation_gain_in_feet
    total_elevation_gain_in_meters * 3.28084
  end

  def total_elevation_gain_in_meters
    total_elevation_gain
  end

  def total_elevation_gain_in_meters_s
    return unless total_elevation_gain && total_elevation_gain.positive?
    format('%gm', format('%.1f', total_elevation_gain_in_meters))
  end

  def total_elevation_gain_in_feet_s
    return unless total_elevation_gain && total_elevation_gain.positive?
    format('%gft', format('%.1f', total_elevation_gain_in_feet))
  end

  def total_elevation_gain_s
    case user.team.units
    when 'km' then total_elevation_gain_in_meters_s
    when 'mi' then total_elevation_gain_in_feet_s
    end
  end

  def pace_s
    if type == 'Swim'
      pace_per_100_yards_s
    else
      case user.team.units
      when 'km' then pace_per_kilometer_s
      when 'mi' then pace_per_mile_s
      end
    end
  end

  def to_s
    "name=#{name}, start_date=#{start_date}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, #{map}"
  end

  def strava_url
    "https://www.strava.com/activities/#{strava_id}"
  end

  def filename
    [
      "_posts/#{start_date_local.year}/#{start_date_local.strftime('%Y-%m-%d')}",
      type.downcase,
      distance_in_miles_s,
      moving_time_in_hours_s
    ].join('-') + '.md'
  end

  def race?
    workout_type == 'race'
  end

  def rounded_distance_in_miles_s
    format('%d-%0d', distance_in_miles, distance_in_miles + 1)
  end

  private

  def time_in_hours_s(time)
    return unless time
    hours = time / 3600 % 24
    minutes = time / 60 % 60
    seconds = time % 60
    [
      hours.to_i.positive? ? format('%dh', hours) : nil,
      minutes.to_i.positive? ? format('%dm', minutes) : nil,
      seconds.to_i.positive? ? format('%ds', seconds) : nil
    ].compact.join
  end

  def emoji
    case type
    when 'Run' then '🏃'
    when 'Ride' then '🚴'
    when 'Swim' then '🏊'
    when 'Walk' then '🚶'
    # when 'Hike' then ''
    when 'Alpine Ski' then '⛷️'
    when 'Backcountry Ski' then '🎿️'
    # when 'Canoe' then ''
    # when 'Crossfit' then ''
    when 'E-Bike Ride' then '🚴'
    # when 'Elliptical' then ''
    # when 'Handcycle' then ''
    when 'Ice Skate' then '⛸️'
    # when 'Inline Skate' then ''
    # when 'Kayak' then ''
    # when 'Kitesurf Session' then ''
    # when 'Nordic Ski' then ''
    when 'Rock Climb' then '🧗'
    when 'Roller Ski' then ''
    when 'Row' then '🚣'
    when 'Snowboard' then '🏂'
    # when 'Snowshoe' then ''
    # when 'Stair Stepper' then ''
    # when 'Stand Up Paddle' then ''
    when 'Surf' then '🏄'
    when 'Virtual Ride' then '🚴'
    when 'Virtual Run' then '🏃'
    when 'Weight Training' then '🏋️'
    # when 'Windsurf Session' then ''
    when 'Wheelchair' then '♿'
      # when 'Workout' then ''
      # when 'Yoga'' then ''
    end
  end

  def type_with_emoji
    [type, emoji].compact.join(' ')
  end

  # Convert speed (m/s) to pace (min/mile or min/km) in the format of 'x:xx'
  # http://yizeng.me/2017/02/25/convert-speed-to-pace-programmatically-using-ruby
  def convert_meters_per_second_to_pace(speed, unit = :mi)
    return unless speed && speed.positive?
    total_seconds = case unit
                    when :mi then 1609.344 / speed
                    when :km then 1000 / speed
                    when :"100yd" then 91.44 / speed
                    end
    minutes, seconds = total_seconds.divmod(60)
    seconds = seconds.round < 10 ? "0#{seconds.round}" : seconds.round.to_s
    "#{minutes}m#{seconds}s/#{unit}"
  end
end
