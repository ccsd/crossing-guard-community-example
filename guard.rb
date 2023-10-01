require 'aws-sdk-sqs'
require 'sequel'
require 'logger'
require 'faraday'
require 'yaml'
require 'json'
require 'pp'
# require 'byebug'
require_relative 'src/settings'
require_relative 'src/database'
require_relative 'src/crossing_guard'

CrossingGuard.new.run!