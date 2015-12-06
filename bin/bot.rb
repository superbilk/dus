#!/usr/bin/env ruby

require 'twitter'
require 'redis'
require 'logger'

class Bot

  def initialize
    self.setup_twitter_client
    @redis = Redis.new()
    @redis.setnx('last_mention_id:like', '651723102708064256') #random tweet from october 2015
    @redis.setnx('last_mention_id:retweet', '651723102708064256') #random tweet from october 2015
    @logger = Logger.new(STDOUT)
  end

  def like_mentions
    mentions = get_timeline(:like)
    unless mentions.empty?
      mentions.each do |mention|
        @logger.info "ID: #{mention.id} || #{mention.user.screen_name}: #{mention.text}"
        @client.favorite(mention.id) if likeable_tweet(mention.text)
      end
      @redis.set('last_mention_id:like', mentions.first.id)
    end
  end

  def retweet_mentions
    mentions = get_timeline(:retweet)
    unless mentions.empty?
      mentions.each do |mention|
        @logger.info "ID: #{mention.id} || #{mention.user.screen_name}: #{mention.text}"
        begin
          @client.retweet(mention.id) if retweetable_tweet(mention.text)
        rescue Twitter::Error::Forbidden
          @logger.info "already retweeted"
        end
      end
      @redis.set('last_mention_id:retweet', mentions.first.id)
    end
  end

protected

  def get_timeline timeline_type
    case timeline_type
    when :like
      key = 'last_mention_id:like'
    when :retweet
      key = 'last_mention_id:retweet'
    end
    @client.mentions_timeline(since_id: @redis.get(key))
  end

  def likeable_tweet text
    checks = {}
    # list of regex we don't like
    checks[:abbrev] = !(/@dus…/i =~ text)
    checks[:mention] = !(/^@dus\b/i =~ text)
    checks[:endoftext] = !((/@dus$/i =~ text) && (text.length == 140))
    checks[:encoding] = !(/&amp;/i =~ text)
    checks[:different_name] = !(/@dus.*\s/i =~ text)
    @logger.debug "#{checks.inspect}"
    @logger.info "liked? #{checks.all? {|k,v| v}}"
    return checks.all? {|k,v| v}
  end

  def retweetable_tweet text
    if self.likeable_tweet(text)
      checks = {}
      checks[:airport] = !!(/airport/i =~ text)
      checks[:travel] = !!(/travel/i =~ text)
      checks[:lounge] = !!(/lounge/i =~ text)
      checks[:plane] = !!(/plane/i =~ text)
      @logger.debug "#{checks.inspect}"
      @logger.info "retweeted? #{checks.any? {|k,v| v}}"
      return checks.any? {|k,v| v}
    else
      return false
    end
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
dus.retweet_mentions

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
