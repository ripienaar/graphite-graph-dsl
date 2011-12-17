#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'graphite_graph'
require 'net/http'
require 'uri'
require 'optparse'

crits = []
warns = []
check_data = {}
url = "http://localhost/render/?"
graph = nil
check_number = 3

opt = OptionParser.new

opt.on("--graphite [URL]", "Base URL for the Graphite installation") do |v|
    url = v
end

opt.on("--graph [GRAPH]", "Graph defintition") do |v|
  graph = v
end

opt.on("--check [NUM]", Integer, "Number of past data items to check") do |v|
  check_number = v
end

opt.parse!

def status_exit(msg, code)
  puts msg
  exit code
end

unless (graph && File.exist?(graph))
  status_exit "UNKNOWN - Can't find graph defintion #{graph}", 3
end

def check_data(data, min, max)
  fails = []

  data.keys.each do |target|
    if (data[target].min < min)
      fails << {:target => target, :item => data[target].min, :operator => "<", :expected => min}
    end

    if (data[target].max > max)
      fails << {:target => target, :item => data[target].max, :operator => ">", :expected => max}
    end
  end

  fails.empty? ? false : fails
end

def print_and_exit(results, code)
  exitcodes = ["OK", "WARNING", "CRITICAL", "UNKNOWN"]

  msg = results.map do |r|
    "%s %s %s %s" % [r[:target], r[:item], r[:operator], r[:expected]]
  end.join(", ")

  status_exit "%s - %s" % [exitcodes[code], msg], code
end


GraphiteGraph.new(graph).url(:json)

uri = URI.parse("%s?%s" % [ url, GraphiteGraph.new(graph).url(:json) ])

json = Net::HTTP.get_response(uri)

status_exit("UNKNOWN - Could not request graph data for HTTP code #{json.code}", 3) unless json.code == "200"

data = JSON.load(json.body)

data.each do |d|
  if d["target"] =~ /crit_[01]$/
    crits << d["datapoints"].first.first
  elsif d["target"] =~ /warn_[01]$/
    warns << d["datapoints"].first.first
  else
    check_data[ d["target"] ] = d["datapoints"].last(check_number).map{|i| i.first}
  end
end

if crits.empty? || warns.empty? || check_data.empty?
  status_exit "UNKNOWN: Graph does not have Data, Warning and Critical information", 3
end

if results = check_data(check_data, crits.min, crits.max)
  print_and_exit results, 2

elsif results = check_data(check_data, warns.min, warns.max)
  print_and_exit results, 1

else
  status_exit "OK - All data within expected ranges", 0
end
