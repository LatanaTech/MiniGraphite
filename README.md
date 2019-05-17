# MiniGraphite

Simple wrapper for Graphite and Statsd

## Instructions

Check the `test` folder for examples, if you need more explanations please contact us.

## Installation

Add this line to your application's Gemfile:

    gem 'mini_graphite'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mini_graphite

## Usage

### Config

    Dalia::MiniGraphite.config({
      :graphite_host => "my.graphite.server.com",
      :graphite_port => 2003, # default 2003
      :statsd_host => "my.statsd.server.com",
      :statsd_port => 8125, # default 8125
      :mock_mode => false, # default false
      :debug_mode => true # default false
    })

Also support multiple servers:

    Dalia::MiniGraphite.config({
      :graphite_host => ["my.graphite1.server.com", "my.graphite2.server.com"],
      :graphite_port => 2003, # default 2003
      :statsd_host => ["my.statsd1.server.com", "my.statsd2.server.com", "my.statsd3.server.com"],
      :statsd_port => 8125, # default 8125
      :mock_mode => false, # default false
      :debug_mode => true # default false
    })

### Simple signals

    Dalia::MiniGraphite.datapoint("my.key", 120, Time.now) # to Graphite
    Dalia::MiniGraphite.counter("my.key", 120) # to StatSD with `c` modifyer
    Dalia::MiniGraphite.time("my.key", 120) # to StatSD with `ms` modifyer

### Block wrapper benchmark

     # Dalia::MiniGraphite.benchmark_wrapper(key_prefix, result_send_method)
     result =
       Dalia::MiniGraphite.benchmark_wrapper("key_prefix", :length) do
         sleep(1)
         "RESULT"
       end

     puts result # => RESULT

This will send several signals:

- *key_prefix.ini:1|c*            # At the begining of the block
- *key_prefix.result:6|c*         # At the end of the block, send the block `result.send(result_send_method)`. Only if `result_send_method` paramater is present.
- *key_prefix.time:1000|c*        # At the end of the block, with the Benchmark.realtime result of the execution
- *key_prefix.end:1|c*            # At the end of the block
- *key_prefix.time_stats:1000|ms* # At the end of the block, with the Benchmark.realtime result of the execution

### Method wrapper benchmark

    # Dalia::MiniGraphite::MethodWrapper.mini_graphite_benchmark_method(method_name, key_prefix)
    class MyClass
      # Trigger the method wrapper in an instance method
      extend Dalia::MiniGraphite::MethodWrapper

      def my_instance_method
      end

      mini_graphite_benchmark_method(:my_instance_method)


      # Trigger the method wrapper in a class method
      def self.my_class_method
      end

      class << self
        extend Dalia::MiniGraphite::MethodWrapper
        mini_graphite_benchmark_method(:my_class_method)
      end
    end

This will send several signals:

- *key_prefix.time:1000|c*        # At the end of the method, with the Benchmark.realtime result of the execution
- *key_prefix.end:1|c*            # At the end of the method

### Routes reporter for Sinatra

The rack middleware must be added to the Rack chain in config.ru passing along with it a block with  config options:

- *set_graphite_key "graphite_key", /route_regexp/*   #  The regular expression will be used to match the Sinatra route and the corresponding graphite_key will be used to build the Graphite metrics:

- "[graphite\_key].count"           # The counter of the times a particular route is requested.
- "[graphite\_key].duration"        # The duration in milliseconds of each request/response cycle.
- "[graphite\_key].duration\_stats" # The duration in milliseconds of each request/response cycle in a "ms" metric

If the requested url doesn't match any configured regular expression the Graphite metrics will not be sent.

Example:

    # config.ru

    use Dalia::MiniGraphite::RoutesReporter do
      set_graphite_key "app.my_app.production.routes.active_surveys", /active_surveys\/this_should_be_a_password/
      set_graphite_key "app.my_app.production.routes.get_surveys", /\:offer_click_id\/\:panel_user_id\/\:panel_user_id_kind/
      set_graphite_key "app.my_app.production.routes.error", /error/
      set_graphite_key "app.my_app.production.routes.homepage", /\/$/
    end

    run MyApp::App

## Contributing

1. Fork it ( http://github.com/<my-github-username>/mini_graphite/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
