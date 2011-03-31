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
  cache 'cache1', :expiry => 5 do
    # response['Cache-Control'] = 'public, max-age=5'
    @markoved_headlines = markoved_headlines
    erubis :index
  end
end


def reddit_json
  reddit_json_uri = 'http://www.reddit.com/.json?count=100'
  reddit_json_data = JSON.parse(open(reddit_json_uri).read)
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

