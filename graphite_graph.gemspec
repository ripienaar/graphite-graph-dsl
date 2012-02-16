# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "graphite_graph/version"

Gem::Specification.new do |s|
  s.name        = "graphite_graph"
  s.version     = GraphiteGraph::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["R.I.Pienaar", "Tom Taylor"]
  s.email       = ["rip@devco.net", "tom@tomtaylor.co.uk"]
  s.homepage    = "https://github.com/ripienaar/graphite-graph-dsl"
  s.summary     = %q{DSL for generating Graphite graphs}

  s.rubyforge_project = "graphite_graph"

  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
