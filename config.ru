require 'rubygems'
require 'rack'
require 'camping'

Camping.goes :Bandnamed

Bandnamed::Models::Base.establish_connection :adapter => "sqlite3", :database => "./bandnamed.sqlite3"
Bandnamed::Models::Base.logger = Logger.new('log/camping.log')

run Rack::Adapter::Camping.new(BandName)
