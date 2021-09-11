#!/usr/bin/env ruby
#    A simple script to help extract different types of data from files
#    Author: DJ Nelson

require 'optimist'
require 'nokogiri'
require 'open-uri'
require 'colorize'


# Set up your options parser
opts = Optimist::options do 
  opt :ip, "Extract IP addresses", :type => :string 
  opt :domain, "Extract domain names", :type => :string
  opt :email, "Extract email addresses", :type => :string
  opt :url, "Extract relative URLs", :type => :string
end

def extract(file, regex)
  puts open(file).read.scan(regex)
end

def sanitize_non_ascii(string)
  encoding_options = {
    invalid: :replace,
    undef: :replace,
    replace: '_',
  }

  string.encode Encoding.find('ASCII'), encoding_options
end

case
# Scan for valid IP addresses
when opts[:ip]
  extract(opts[:ip], /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/)

# Scan for FQDNs
when opts[:domain]
  extract(opts[:domain], /(?:(https|http)?:\/\/)?(?:www\.)?([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}/ix)

# Scan for email addresses
when opts[:email]
  extract(opts[:email], /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i)

# Scan a file for relative URL endpoints
when opts[:url]
  file_data = open(opts[:url]).read
  matched_endpoints = []

  sanitize_non_ascii(file_data).gsub(/;/, "\n").scan(/(^.*?("|')(\/[\w\d\?\/&=\#\.\!:_-]*?)(\2).*$)/).map do |string|
    next if matched_endpoints.include?(string[2])

    matched_endpoints << string[2]
 
    puts string[2]
  end
else
  puts "You must specify a file to scan!".red
  Optimist::educate
end

