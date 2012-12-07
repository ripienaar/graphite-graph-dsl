require 'uri'
require 'cgi'
require "graphite_graph/version"
# A small DSL to assist in the creation of Graphite graphs
# see https://github.com/ripienaar/graphite-graph-dsl/wiki
# for full details
class GraphiteGraph
  attr_reader :info, :properties, :targets, :target_order, :critical_threshold, :warning_threshold

  def initialize(file, overrides={}, info={})
    @info = info
    @file = file
    @munin_mode = false
    @overrides = overrides
    @linecount = 0

    @critical_threshold = []
    @warning_threshold = []

    load_graph
  end

  def defaults
    @properties = {:title => nil,
                   :vtitle => nil,
                   :vtitle_right => nil,
                   :width => 500,
                   :height => 250,
                   :from => "-1hour",
                   :until => "now",
                   :surpress => false,
                   :description => nil,
                   :hide_legend => nil,
                   :hide_grid => nil,
                   :ymin => nil,
                   :yminright => nil,
                   :ymax => nil,
                   :ymaxright => nil,
                   :yunit_system => nil,
                   :linewidth => nil,
                   :linemode => nil,
                   :fontsize => nil,
                   :fontbold => false,
                   :fontname => nil,
                   :timezone => nil,
                   :xformat => nil,
                   :background_color => nil,
                   :foreground_color => nil,
                   :draw_null_as_zero => false,
                   :major_grid_line_color => nil,
                   :minor_grid_line_color => nil,
                   :area => :none,
                   :logbase => nil,
                   :area_alpha => nil,
                   :graph_type => nil,
                   :placeholders => nil}.merge(@overrides)
  end

  def [](key)
    if key == :url
      url
    else
      @properties[key]
    end
  end

  def method_missing(meth, *args)
    if properties.include?(meth)
      properties[meth] = args.first unless @overrides.include?(meth)
    else
      super
    end
  end

  def load_graph
    @properties = defaults
    @targets = {}
    @target_order = []

    self.instance_eval(File.read(@file)) unless @file == :none
  end

  def service(service, data, &blk)
    raise "No hostname given for this instance" unless info[:hostname]

    @service_mode = {:service => service, :data => data}

    blk.call

    @service_mode = false
  end

  # add forecast, bands, aberrations and actual fields using the
  # Holt-Winters Confidence Band prediction model
  #
  #    hw_predict :foo, :data => "some.data.item", :alias => "Some Item"
  #
  # You can tweak the colors by setting:
  #     :forecast_color => "blue"
  #     :bands_color => "grey"
  #     :aberration_color => "red"
  #
  # You can add an aberration line:
  #
  #     :aberration_line => true,
  #     :aberration_second_y => true
  #
  # You can disable the forecast line by setting:
  #
  #     :forecast_line => false
  #
  # You can disable the confidence lines by settings:
  #
  #     :bands_lines => false
  #
  # You can disable the display of the actual data:
  #
  #     :actual_line => false
  def hw_predict(name, args)
    raise ":data is needed as an argument to a Holt-Winters Confidence forecast" unless args[:data]

    unless args[:forecast_line] == false
      forecast_args = args.clone
      forecast_args[:data] = "holtWintersForecast(#{forecast_args[:data]})"
      forecast_args[:alias] = "#{args[:alias]} Forecast"
      forecast_args[:color] = args[:forecast_color] || "blue"
      field "#{name}_forecast", forecast_args
    end

    unless args[:bands_lines] == false
      bands_args = args.clone
      bands_args[:data] = "holtWintersConfidenceBands(#{bands_args[:data]})"
      bands_args[:color] = args[:bands_color] || "grey"
      bands_args[:dashed] = true
      bands_args[:alias] = "#{args[:alias]} Confidence"
      field "#{name}_bands", bands_args
    end

    if args[:aberration_line]
      aberration_args = args.clone
      aberration_args[:data] = "holtWintersAberration(keepLastValue(#{aberration_args[:data]}))"
      aberration_args[:color] = args[:aberration_color] || "orange"
      aberration_args[:alias] = "#{args[:alias]} Aberration"
      aberration_args[:second_y_axis] = true if aberration_args[:aberration_second_y]
      field "#{name}_aberration", aberration_args
    end

    if args[:critical]
      color = args[:critical_color] || "red"
      critical :value => args[:critical], :color => color, :name => name
    end

    if args[:warning]
      color = args[:warning_color] || "orange"
      warning :value => args[:warning], :color => color, :name => name
    end

    args[:color] ||= "yellow"

    field name, args unless args[:actual_line] == false
  end

  alias :forecast :hw_predict

  # takes a series of metrics in a wildcard query and aggregates the values by a subgroup
  #
  # data must contain a wildcard query, a subgroup position, and an optional aggregate function.
  # if the aggregate function is omitted, sumSeries will be used.
  #
  # group :data => "metric.*.value", :subgroup => "2", :aggregator => "sumSeries"
  #
  def group(name, args)
    raise ":data is needed as an argument to group metrics" unless args[:data]
    raise ":subgroup is needed as an argument to group metrics" unless args.include?(:subgroup)

    args[:aggregator] = "sumSeries" unless args[:aggregator]

    group_args = args.clone
    group_args[:data] = "groupByNode(#{group_args[:data]},#{group_args[:subgroup]},\"#{group_args[:aggregator]}\")"
    field "#{name}_group", group_args

  end

  # draws a single dashed line with predictable names, defaults to red line
  #
  # data can be a single item or a 2 item array, it doesn't break if you supply
  # more but # more than 2 items just doesn't make sense generally
  #
  # critical :value => [700, -700], :color => "red"
  #
  # You can prevent the line from being drawn but just store the ranges for monitoring
  # purposes by adding :hide => true to the arguments
  def critical(options)
    raise "critical lines need a value" unless options[:value]

    @critical_threshold = [options[:value]].flatten

    options[:color] ||= "red"

    unless options[:hide]
      @critical_threshold.each_with_index do |crit, index|
        line :caption => "crit_#{index}", :value => crit, :color => options[:color], :dashed => true
      end
    end
  end

  # draws a single dashed line with predictable names, defaults to orange line
  #
  # data can be a single item or a 2 item array, it doesn't break if you supply
  # more but # more than 2 items just doesn't make sense generally
  #
  # warning :value => [700, -700], :color => "orange"
  #
  # You can prevent the line from being drawn but just store the ranges for monitoring
  # purposes by adding :hide => true to the arguments
  def warning(options)
    raise "warning lines need a value" unless options[:value]

    @warning_threshold = [options[:value]].flatten

    options[:color] ||= "orange"

    unless options[:hide]
      @warning_threshold.flatten.each_with_index do |warn, index|
        line :caption => "warn_#{index}", :value => warn, :color => options[:color], :dashed => true
      end
    end
  end

  # draws a simple line on the graph with a caption, value and color.
  #
  # line :caption => "warning", :value => 50, :color => "orange"
  def line(options)
    raise "lines need a caption" unless options.include?(:caption)
    raise "lines need a value" unless options.include?(:value)
    raise "lines need a color" unless options.include?(:color)

    options[:alias] = options[:caption] unless options[:alias]

    args = {:data => "threshold(#{options[:value]})", :color => options[:color], :alias => options[:alias]}

    args[:dashed] = true if options[:dashed]
    args[:second_y_axis] = true if options[:second_y_axis]

    field "line_#{@linecount}", args

    @linecount += 1
  end

  # adds a field to the graph, each field needs a unique name
  def field(name, args)
    raise "A field called #{name} already exist for this graph" if targets.include?(name)

    default = {}

    if @service_mode
      default[:data] = [info[:hostname], @service_mode[:service], @service_mode[:data], name].join(".")
    end

    targets[name] = default.merge(args)
    target_order << name
  end

  def url(format = nil, url=true)
    return nil if properties[:surpress]

    url_parts = []
    colors = []

    [:title, :vtitle, :from, :width, :height, :until].each do |item|
      url_parts << "#{item}=#{properties[item]}" if properties[item]
    end

    url_parts << "areaMode=#{properties[:area]}" if properties[:area]
    url_parts << "areaAlpha=#{properties[:area_alpha]}" if properties[:area_alpha]
    url_parts << "hideLegend=#{properties[:hide_legend]}" unless properties[:hide_legend].nil?
    url_parts << "hideGrid=#{properties[:hide_grid]}" if properties[:hide_grid]
    url_parts << "yMin=#{properties[:ymin]}" if properties[:ymin]
    url_parts << "yMinRight=#{properties[:yminright]}" if properties[:yminright]
    url_parts << "yMax=#{properties[:ymax]}" if properties[:ymax]
    url_parts << "yMaxRight=#{properties[:ymaxright]}" if properties[:ymaxright]
    url_parts << "yUnitSystem=#{properties[:yunit_system]}" if properties[:yunit_system]
    url_parts << "lineWidth=#{properties[:linewidth]}" if properties[:linewidth]
    url_parts << "lineMode=#{properties[:linemode]}" if properties[:linemode]
    url_parts << "fontSize=#{properties[:fontsize]}" if properties[:fontsize]
    url_parts << "fontBold=#{properties[:fontbold]}" if properties[:fontbold]
    url_parts << "fontName=#{properties[:fontname]}" if properties[:fontname]
    url_parts << "drawNullAsZero=#{properties[:draw_null_as_zero]}" if properties[:draw_null_as_zero]
    url_parts << "tz=#{properties[:timezone]}" if properties[:timezone]
    url_parts << "xFormat=#{properties[:xformat]}" if properties[:xformat]
    url_parts << "majorGridLineColor=#{properties[:major_grid_line_color]}" if properties[:major_grid_line_color]
    url_parts << "minorGridLineColor=#{properties[:minor_grid_line_color]}" if properties[:minor_grid_line_color]
    url_parts << "bgcolor=#{properties[:background_color]}" if properties[:background_color]
    url_parts << "fgcolor=#{properties[:foreground_color]}" if properties[:foreground_color]
    url_parts << "vtitleRight=#{properties[:vtitle_right]}" if properties[:vtitle_right]
    url_parts << "logBase=#{properties[:logbase]}" if properties[:logbase]
    url_parts <<  "graphType=#{properties[:graph_type]}" if properties[:graph_type]

    target_order.each do |name|
      target = targets[name]

      if target[:target]
        url_parts << "target=#{target[:target]}"
      else
        raise "field #{name} does not have any data associated with it" unless target[:data]

        graphite_target = target[:data]

        graphite_target = "lineWidth(#{graphite_target},#{target[:field_linewidth]})" if target[:field_linewidth]
        graphite_target = "keepLastValue(#{graphite_target})" if target[:keep_last_value]
        graphite_target = "sum(#{graphite_target})" if target[:sum]
        if target[:derivative]
          graphite_target = "derivative(#{graphite_target})"
        elsif target[:non_negative_derivative]
          graphite_target = "nonNegativeDerivative(#{graphite_target})"
        end
        graphite_target = "highestAverage(#{graphite_target},#{target[:highest_average]})" if target[:highest_average]
        if target[:scale]
          graphite_target = "scale(#{graphite_target},#{target[:scale]})"
        elsif target[:scale_to_seconds]
          graphite_target = "scaleToSeconds(#{graphite_target},#{target[:scale_to_seconds]})"
        end
        if target[:as_percent] == true
          graphite_target = "asPercent(#{graphite_target})"
        elsif target[:as_percent]
          graphite_target = "asPercent(#{graphite_target},#{target[:as_percent]})"
        end
        graphite_target = "drawAsInfinite(#{graphite_target})" if target[:line]
        graphite_target = "movingAverage(#{graphite_target},#{target[:smoothing]})" if target[:smoothing]

        graphite_target = "color(#{graphite_target},\"#{target[:color]}\")" if target[:color]
        graphite_target = "dashed(#{graphite_target})" if target[:dashed]
        graphite_target = "secondYAxis(#{graphite_target})" if target[:second_y_axis]

        unless target.include?(:subgroup)
          if target[:alias_by_node]
            graphite_target = "aliasByNode(#{graphite_target},#{target[:alias_by_node]})"
          elsif target[:alias_sub_search]
            graphite_target = "aliasSub(#{graphite_target},\"#{target[:alias_sub_search]}\",\"#{target[:alias_sub_replace]}\")"
          elsif target[:alias]
            graphite_target = "alias(#{graphite_target},\"#{target[:alias]}\")"
          elsif target[:no_alias]
            graphite_target = graphite_target # no-op
          else
            graphite_target = "alias(#{graphite_target},\"#{name.to_s.capitalize}\")"
          end

          if target[:cacti_style]
            graphite_target = "cactiStyle(#{graphite_target})"
          elsif target[:legend_value]
            graphite_target = "legendValue(#{graphite_target},\"#{target[:legend_value]}\")"
          end
        end

        url_parts << "target=#{graphite_target}"
      end
    end

    url_parts << "format=#{format}" if format

    if url
      url_str = url_parts.map { |pair| k,v = pair.split('='); "#{k}=#{CGI.escape(v)}" }.join("&")
      properties[:placeholders].each { |k,v| url_str.gsub!("%{#{k}}", v.to_s) } if properties[:placeholders].is_a?(Hash)

      url_str
    else
      url_parts
    end
  end
end
