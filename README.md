What?
=====

Small DSL in progress to describe a graphite graph.

If you have data like in graphite:

	devco_net
	`-- munin
	    `-- cpu
		|-- idle
		|-- iowait
		|-- irq
		|-- nice
		|-- softirq
		|-- steal
		|-- system
		`-- user

You can describe the data like this:

_cpu/irq.graph_:

	title   "CPU IRQ Usage"
	vtitle  "percent"
	area    :stacked

	# helper to locate data in the tree.  You give it
	# the hostname in the constructor - see later example -
	# and it will then find mun/cpu/irq for example in
	# that specific host data tree
	service :munin, :cpu do
	  field :irq,    :derivative => true,
			 :scale => 0.001,
			 :color => "red",
			 :alias => "IRQ"

	  field :softirq, :derivative => true,
			  :scale => 0.001,
			  :color => "yellow",
			  :alias => "Batched IRQ"
	end

_cpu/overview.graph_

	title   "CPU Usage"
	vtitle  "percent"
	area    :stacked
	width   500
	height  250
	from	"-2hour"

	service :munin, :cpu do
	  field :iowait, :derivative => true,
			 :scale => 0.001,
			 :color => "red",
			 :alias => "IO Wait"

	  field :system, :derivative => true,
			 :scale => 0.001,
			 :color => "orange",
			 :alias => "System"

	  field :user,   :derivative => true,
			 :scale => 0.001,
			 :color => "yellow",
			 :alias => "User"
	end

	# draws a vertical line for every time that puppet ran on the host
	# info is the hash that gets passed into the constructor, see later
	# example
	field :puppet, :color => "blue",
		       :alias => "Puppet Run",
		       :data  => "drawAsInfinite(#{info[:hostname}.puppet.time.total)"

To use these 2 files in your own code simply do:

	g = GraphiteGraph.new("cpu/overview.graph", {}, :hostname => "devco_net")
	puts g.url

This will produce:

       title=CPU Usage&vtitle=percent&from=-2hour&width=500&height=250&areaMode=stacked&target=alias(scale(derivative(devco_net.munin.cpu.iowait),0.001),"IO Wait")&target=alias(scale(derivative(devco_net.munin.cpu.system),0.001),"System")&target=alias(scale(derivative(devco_net.munin.cpu.user),0.001),"User")&colorList=red,orange,yellow

You can also mix in any other kind of target:


	title   "Combined CPU Usage"
	vtitle  "percent"
	area    :stacked

	field :iowait, :scale => 0.001,
		       :color => "red",
		       :alias => "IO Wait",
		       :data  => "sumSeries(derivative(mw*munin.cpu.iowait))"

	field :system, :scale => 0.001,
		       :color => "orange",
		       :alias => "System",
		       :data  => "sumSeries(derivative(mw*.munin.cpu.system))"

	field :user, :scale => 0.001,
		     :color => "yellow",
		     :alias => "User",
		     :data  => "sumSeries(derivative(mw*.munin.cpu.user))"

This will use totally custom targets but still let you use some helpers for color etc.

In all cases the items will appear on the graph in the order it appears in the file
