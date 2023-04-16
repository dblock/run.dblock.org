class Strava::Models::Activity < Strava::Models::Response
  property :workout_type, from: 'workout_type', with: lambda { |data|
    case data
    when 1 then 'race'
    when 2 then 'long run'
    when 3 then 'workout'
    else 'run'
    end
  }

  def to_s
    "name=#{name}, start_date=#{start_date}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, #{map}"
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

  def rounded_max_heartrate_s
    rounded_max_heartrate = (max_heartrate / 5).to_i * 5
    format('%d-%d', rounded_max_heartrate, rounded_max_heartrate + 5)
  end

  def rounded_average_heartrate_s
    rounded_average_heartrate = (average_heartrate / 5).to_i * 5
    format('%d-%d', rounded_average_heartrate, rounded_average_heartrate + 5)
  end

  def round_up(n, increment)
    increment * ((n + increment - 1) / increment)
  end

  def rounded_pace_per_mile_s
    total_seconds = 1609.344 / average_speed
    minutes, seconds = total_seconds.divmod(60)
    # round the seconds to the nearest 15
    seconds = round_up(seconds.round, 15)
    if seconds == 60
      minutes += 1
      seconds = 0
    end
    seconds = seconds < 10 ? "0#{seconds}" : seconds.to_s
    "<#{minutes}m#{seconds}s/mi"
  end
end
