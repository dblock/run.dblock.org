class Activity < Hashie::Trash
  include Hashie::Extensions::IgnoreUndeclared
  include Moving

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

  property :splits, from: 'splits_standard', with: ->(data) {
    data.map do |row|
      Split.new(row)
    end.sort_by(&:split)
  }

  def start_date_local_s
    return unless start_date_local

    start_date_local.strftime('%A, %B %d, %Y at %I:%M %p')
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

  private

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
end
