This is a swiss-army knife for making prediction graphs using
the new Holt Winters functionality in Graphite 0.9.9

The sample is created using the most basic forecast helper:

        forecast :male, :data => "sumSeries(*.site.users.male)",
                        :alias => "Male"

In the sample graph the yellow line is actual numbers.
The blue line is the forecasted line and the grey lines
are the convidence lines.  Real data within the confidence
lines can be considered withtin predicted boundaries.

But there are many tweaks you can do or combine:

The following adds a 4th line to the graph that shows how far the
data is deviating from the confidence lines (basic-with-aberration):

        forecast :male, :data => "sumSeries(*.site.users.male)",
                        :alias => "Male",
                        :aberration_line => true

For high number data with small variance it might be useful to put the
aberration line on the 2nd y access (basic-with-aberration-on-y):

        forecast :male, :data => "sumSeries(web*.site.users.male)",
                        :alias => "Male",
                        :aberration_line => true,
                        :aberration_second_y => true

You can disable any of the lines, this will only draw the aberration
line (just-aberration):

        forecast :male, :data => "sumSeries(web*.site.users.male)",
                        :alias => "Male",
                        :aberration_line => true,
                        :forecast_line => false,
                        :bands_lines => false,
                        :actual_line => false

If you wanted to draw just the aberration line and lines for critical and
warning thresholds (aberration-with-thresholds):

        forecast :male, :data => "sumSeries(web*.site.users.male)",
                        :alias => "Male",
                        :aberration_line => true,
                        :forecast_line => false,
                        :bands_lines => false,
                        :actual_line => false,
                        :critical => [700, -700],
                        :warning => [300, -300],
                        :aberration_color => "blue"

And finally all the colors are adjustable (custom-colors):

        forecast :male, :data => "sumSeries(web*.site.users.male)",
                        :alias => "Male",
                        :forecast_color => "yellow",
                        :bands_color => "white",
                        :color => "green"
