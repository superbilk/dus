#!/usr/bin/env ruby

require 'twitter'
require 'redis'
require 'logger'

class Bot

  attr_reader :client

  def initialize
    self.setup_twitter_client
    @redis = Redis.new()
    @redis.setnx('last_mention_id:like', '651723102708064256') #random tweet from october 2015
    @logger = Logger.new(STDOUT)
  end

  def like_mentions
    @last_mention_id = @redis.get('last_mention_id:like')
    mentions = @client.mentions_timeline(since_id: @last_mention_id)
    unless mentions.empty?
      mentions.each do |mention|
        @logger.info "ID: #{mention.id} || #{mention.user.screen_name}: #{mention.text}"
        @client.favorite(mention.id) if likeable_tweet(mention.text)
      end
      @redis.set('last_mention_id:like', mentions.first.id)
    end
  end

protected

  def likeable_tweet text
    checks = {}
    checks[:abbrev] = !(/@dus…/ =~ text)
    checks[:mention] = !(/^@dus\b/ =~ text)
    checks[:endoftext] = !((/@dus$/ =~ text) && (text.length == 140))
    checks[:encoding] = !(/&amp;/ =~ text)
    @logger.debug "#{checks.inspect}"
    @logger.info "liked? #{checks[:abbrev] && checks[:mention] && checks[:endoftext] && checks[:encoding]}"
    return checks[:abbrev] && checks[:mention] && checks[:endoftext] && checks[:encoding]
  end

  def setup_twitter_client
    @client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
      config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    end
  end
end



dus = Bot.new
dus.like_mentions

# dus.client.mentions_timeline(count: 5).each do |item|
#   puts item.text
#   puts "--- reply screenname"
#   puts item.in_reply_to_screen_name
#   puts "--- reply status id"
#   puts item.in_reply_to_status_id
#   puts "--- reply user id"
#   puts item.in_reply_to_user_id
#   puts "---"
#   puts item.full_text
#   puts "================"
# end
