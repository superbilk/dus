#!/usr/bin/env ruby

require_relative '../lib/twitter_handler'

dus = TwitterHandler.new
puts dus.client.home_timeline
