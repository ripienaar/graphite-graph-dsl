Given a graph with critical and warning data on it
this Nagios compatible check will fetch the JSON data
of the graph and make sure no data is outside of the
warning and critical levels.

	title          "Down Network"
	hide_legend    true

	forecast :down, :data => "keepLastValue(my_net.munin.if_eth0.down)",
			:alias => "Down",
			:aberration_line => true,
			:forecast_line => false,
			:bands_lines => false,
			:actual_line => false,
			:aberration_color => "blue"

	# record the thresholds but do not draw them
        critical :value => [700, -700], :hide => true
        warning :value => [300, -300], :hide => true

This is a Holt Winters prediction graph of network data received
by a host, it has acceptable threshold for how aberrant the data
may be - if the prediction says the data is too far out of range
an alert will be raised.

    % check_graph.rb --graph monitor.graph --graphite "http://graphite.your.net/render/"
    CRITICAL - Down Aberration 1623 > 700
