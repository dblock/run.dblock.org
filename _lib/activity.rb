class Strava::Models::Activity < Strava::Model
  property :workout_type, from: 'workout_type', with: ->(data) {
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
end
