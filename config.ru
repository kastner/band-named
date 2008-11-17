require 'rubygems'
require 'rack'
require 'camping'
require 'bandnamed'

run Rack::Adapter::Camping.new(BandName)
