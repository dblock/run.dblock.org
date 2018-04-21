class Split < Hashie::Trash
  include Hashie::Extensions::IgnoreUndeclared
  include Moving

  property :distance, from: 'distance'
  property :elapsed_time, from: 'elapsed_time'
  property :total_elevation_gain, from: 'elevation_difference'
  property :moving_time, from: 'moving_time'
  property :split, from: 'split'
  property :average_speed, from: 'average_speed'
  property :pace_zone, from: 'pace_zone'
end
