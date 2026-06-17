require 'aws-sdk-sqs'
# require 'aws-sdk-sns'
require 'sequel'
require 'logger'
require 'faraday'
require 'yaml'
require 'json'
require 'pp'
# require 'debug'
require_relative 'src/settings'
require_relative 'src/database'
require_relative 'src/crossing_guard'

CrossingGuard.new.run!
