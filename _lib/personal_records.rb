# frozen_string_literal: true

module Strava
  module PersonalRecords
    DISTANCES = {
      1 => '1mi',
      3.1 => '5K',
      4.0 => '4mi',
      6.2 => '10K',
      10.0 => '10mi',
      13.1 => 'Half',
      26.2 => 'Marathon'
    }.freeze

    def self.distance_key(distance)
      DISTANCES.keys.find { |known| distance > known && (distance - known) <= 0.2 }
    end

    def self.record(file, post)
      seconds = post.fetch('time').to_f.round
      hours, remainder = seconds.divmod(3600)
      minutes, seconds = remainder.divmod(60)
      {
        'label' => DISTANCES.fetch(distance_key(post.fetch('distance').to_f)),
        'time' => post.fetch('time').to_f,
        'time_display' => hours.positive? ? format('%d:%02d:%02d', hours, minutes, seconds) : format('%d:%02d', minutes, seconds),
        'pace_display' => post.fetch('pace_display').sub('m', ':').sub('s/mi', '/mi'),
        'url' => file.sub(%r{\A_posts/\d{4}/}, '/').sub(/\A\/(\d{4})-(\d{2})-(\d{2})-/, '/\1/\2/\3/').sub(/\.md\z/, '.html'),
        'title' => post.fetch('title')
      }
    end
  end
end
