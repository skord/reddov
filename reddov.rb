require 'rubygems'
require 'sinatra'
require 'erubis'
require 'json'
require 'open-uri'
require 'lib/markov.rb'
require 'dalli'
require 'lib/cache.rb'

set :cache, Dalli::Client.new

configure :production do
end

get '/' do

  # Caching for something rediculously small. 
  # It should give the appearance of hitting refresh
  # and getting a new page, but the folks will be
  # be hitting the cache instead. 
  #
  # Three seconds about does it. It's the difference
  # between ~200 requests per second and 6
  
  cache 'cache1', :expiry => 2 do
    @markoved_headlines = markoved_headlines
    erubis :index
  end
end


def reddit_json
  @reddit_json ||= fetch_and_cache_reddit_json 
end

def fetch_and_cache_reddit_json
  # Cache the reddit stuff. We don't need it that often for fun.
  reddit_json_uri = 'http://www.reddit.com/.json?count=200'
  cached_reddit_json = settings.cache.get('reddit_json')
  if cached_reddit_json.nil? 
    parsed_json = JSON.parse(open(reddit_json_uri).read)
    settings.cache.set('reddit_json', parsed_json, ttl = 300)
    return parsed_json
  else
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
  random_titles = []
  m = MarkovNameGenerator::new(100, 5)
  i = 0
  headlines.each do |headline|
    m.input(headline)
  end
  until random_headlines.length == 15
    random_title = m.name
    unless headlines.include?(random_title) || random_titles.include?(random_title)
      random_titles << random_title
      random_headlines << {:title => random_title, :position => i, :author => random_redditor}
      i += 1
    end
  end
  random_headlines
end

