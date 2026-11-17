# frozen_string_literal: true

require 'rspec'
require 'active_support/core_ext/object/blank'
require 'polylines'
require 'strava-ruby-client'
require 'webrick'

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
end
