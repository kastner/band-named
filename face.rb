#!/usr/bin/env ruby

require 'hpricot'
require 'open-uri'

class TwitterFace
  def self.url(username)
    response = Hpricot::parse(open("http://twitter.com/#{username}"))
    element = (response / "h2.thumb img").first
    raise "Can't find it you on twitter" unless element
    element.attributes["src"]
  end
end

class FlickrFace
  @@api_key = "16fb5e4b6048568754eb7c4b401fd45c"
  
  def self.url(username)
    nsid = FlickrFace.fetch_api("flickr.people.findByUsername", "user", {:username => username, :attribute => "nsid"})
    raise "Username not found" unless nsid
    iconserver = FlickrFace.fetch_api("flickr.people.getInfo", "person", {:user_id => nsid, :attribute => "iconserver"})
    
    if iconserver
      "http://static.flickr.com/#{iconserver}/buddyicons/#{nsid}.jpg"
    else
      "http://www.flickr.com/images/buddyicon.jpg"
    end
  end
  
  def self.fetch_api(method, tag, options = {})
    attribute = options.delete(:attribute) || ""
    
    url = "http://api.flickr.com/services/rest/?method=#{method}&api_key=#{@@api_key}&"
    url += options.collect{|k,v| k.to_s + "=" + v}.join("&")
    response = Hpricot::XML(open(url))
    element = (response / tag).first
    raise "No element found #{response}" unless element
    unless attribute.empty?
      element.attributes[attribute]
    else
      element.innerHTML
    end
  end
end

if __FILE__ == $0
  puts FlickrFace.url("kastner")
end