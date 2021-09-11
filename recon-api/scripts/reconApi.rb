#!/usr/bin/env ruby
# => This script interfaces with my Recon API @ localhost:6301
# => Author: DJ Nelson

require 'optimist'
require 'httparty'
require 'json'


opts = Optimist::options do 
	opt :ipinfo, "Interact with the ipinfo module", :type => :string
	opt :range, "Interact with the IP range module", :type => :string
	opt :pretty, "Print JSON results in pretty format"
end

begin
  case 
  when opts[:ipinfo]
    response = HTTParty.get("http://localhost:6301/ipv4/#{opts[:ipinfo]}")
  when opts[:range]
    response = HTTParty.get("http://localhost:6301/ip-range/#{opts[:range]}")
  else
    Optimist::educate
  end
rescue Errno::ECONNREFUSED
  print "Failed to connect to the Recon server. Check to see if port 6301 is running." 
end

puts opts[:pretty] ? JSON.pretty_generate(JSON.parse(response.to_s)) : response

