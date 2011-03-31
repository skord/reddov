require 'rubygems'
require 'sinatra'
require 'erubis'
require 'json'
require 'open-uri'
require './lib/markov.rb'
require 'dalli'
require './lib/cache.rb'

set :cache, Dalli::Client.new

configure :production do
end

get '/' do
  response['Cache-Control'] = 'public, max-age=2'
  #
  # Caching for something rediculously small. 
  # It should give the appearance of hitting refresh
  # and getting a new page, but the folks will be
  # be hitting the cache instead. 
  #
  # Three seconds about does it. It's the difference
  # between ~200 requests per second and 6
  
  # cache 'cache1', :expiry => 2 do
    @markoved_headlines = markoved_headlines
    erubis :index
  # end
end


def reddit_json
  @reddit_json ||= fetch_and_cache_reddit_json 
end

def fetch_and_cache_reddit_json
  # Cache the reddit stuff. We don't need it that often for fun.
  reddit_json_uri = 'http://www.reddit.com/.json?count=100'
  cached_reddit_json = settings.cache.get('reddit_json')
  if cached_reddit_json.nil? 
    parsed_json = JSON.parse(open(reddit_json_uri).read)
    settings.cache.set('reddit_json', parsed_json, ttl = 300)
    puts "set"
    return parsed_json
  else
    puts 'get'
    return cached_reddit_json
  end
end

def headlines
  reddit_json['data']['children'].collect {|x| x['data']['title']}
end

def random_redditor
  m = MarkovNameGenerator::new(100,2)
  reddit_json['data']['children'].each do |article| 
    m.input(article['data']['author'])
  end
  m.name
end

def markoved_headlines
  random_headlines = []
  m = MarkovNameGenerator::new(100, 4)
  headlines.each do |headline|
    m.input(headline)
  end
  15.times do |i|
    random_headlines << {:title => m.name, :position => i, :author => random_redditor}
  end
  random_headlines
end

