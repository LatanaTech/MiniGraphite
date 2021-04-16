require "minitest/autorun"
require "mocha/setup"
require_relative "../lib/mini_graphite"

class MiniGraphiteTest < MiniTest::Test

  def within_timezone(tz = "UTC")
    original_tz = ENV["TZ"]
    ENV["TZ"] = "UTC"
    yield
    ENV["TZ"] = original_tz
  end

  def test_send_tcp_on_host
    socket_mock = mock()
    TCPSocket.expects(:new).with("HOST", "PORT").returns(socket_mock)
    socket_mock.expects(:print).with("MESSAGE\n")
    socket_mock.expects(:close)

    Dalia::MiniGraphite.send_tcp_on_host("HOST", "PORT", "MESSAGE")
  end

  def test_send_udp_on_host
    socket_mock = mock()
    UDPSocket.expects(:new).returns(socket_mock)
    socket_mock.expects(:send).with("MESSAGE", 0, "HOST", "PORT" )
    socket_mock.expects(:close)

    Dalia::MiniGraphite.send_udp_on_host("HOST", "PORT", "MESSAGE")
  end

  def test_send_tcp
    Dalia::MiniGraphite.config({ :graphite_host => "HOST", :graphite_port => "PORT" })
    Dalia::MiniGraphite.expects(:send_tcp_on_host).with("HOST", "PORT", "MESSAGE")
    Dalia::MiniGraphite.send_tcp("MESSAGE")
  end

  def test_send_tcp_when_multiple_hosts
    Dalia::MiniGraphite.config({ :graphite_host => ["HOST1", "HOST2"], :graphite_port => "PORT" })

    Dalia::MiniGraphite.expects(:send_tcp_on_host).with("HOST1", "PORT", "MESSAGE")
    Dalia::MiniGraphite.expects(:send_tcp_on_host).with("HOST2", "PORT", "MESSAGE")

    Dalia::MiniGraphite.send_tcp("MESSAGE")
  end

  def test_send_udp
    Dalia::MiniGraphite.config({ :statsd_host => "HOST", :statsd_port => "PORT" })
    Dalia::MiniGraphite.expects(:send_udp_on_host).with("HOST", "PORT", "MESSAGE")
    Dalia::MiniGraphite.send_udp("MESSAGE")
  end

  def test_send_udp_when_multiple_hosts
    Dalia::MiniGraphite.config({ :statsd_host => ["HOST1", "HOST2"], :statsd_port => "PORT" })

    Dalia::MiniGraphite.expects(:send_udp_on_host).with("HOST1", "PORT", "MESSAGE")
    Dalia::MiniGraphite.expects(:send_udp_on_host).with("HOST2", "PORT", "MESSAGE")

    Dalia::MiniGraphite.send_udp("MESSAGE")
  end

  def test_datapoint
    within_timezone "UTC" do
      Dalia::MiniGraphite.config({ :graphite_host => "graphite.host.com", :graphite_port => 2003 })
      Dalia::MiniGraphite.expects(:send_tcp).with("test.age 31 1357121460")
      Dalia::MiniGraphite.datapoint("test.age", 31, Time.new(2013,1,2,10,11))
    end
  end

  def test_counter
    Dalia::MiniGraphite.config({ :statsd_host => "statsd.host.com", :statsd_port => 8125 })
    Dalia::MiniGraphite.expects(:send_udp).with("height:231|c")
    Dalia::MiniGraphite.counter("height", 231)
  end

  def test_time
    Dalia::MiniGraphite.config({ :statsd_host => "statsd.host.com", :statsd_port => 8125 })
    Dalia::MiniGraphite.expects(:send_udp).with("my_time:231|ms")
    Dalia::MiniGraphite.time("my_time", 231)
  end

  def test_counter_when_nil_value
    Dalia::MiniGraphite.config({ :statsd_host => "statsd.host.com", :statsd_port => 8125 })
    Dalia::MiniGraphite.expects(:send_udp).with("height:1|c")
    Dalia::MiniGraphite.counter("height", nil)
  end

  def test_on_config_should_debug
    Dalia::MiniGraphite::Logger.any_instance.expects(:debug).at_least_once
    Dalia::MiniGraphite.config()
  end

  def test_on_counter_should_debug
    Dalia::MiniGraphite.expects(:send_udp)
    Dalia::MiniGraphite.config()

    Dalia::MiniGraphite::Logger.any_instance.expects(:debug).with("Sending counter: 'test.age:31|c'")
    Dalia::MiniGraphite.counter("test.age", 31)
  end

  def test_on_datapoint_connection_timeout
    within_timezone "UTC" do
      Dalia::MiniGraphite.stubs(:send_tcp).raises(Errno::ETIMEDOUT.new("timeout"))
      Dalia::MiniGraphite.config()
      Dalia::MiniGraphite::Logger.any_instance.expects(:debug).with("Sending datapoint: 'test.age 31 1357121460'")
      Dalia::MiniGraphite.datapoint("test.age", 31, Time.new(2013,1,2,10,11))
    end
  end

  def test_on_datapoint_should_debug
    within_timezone "UTC" do
      Dalia::MiniGraphite.expects(:send_tcp)
      Dalia::MiniGraphite.config()
      Dalia::MiniGraphite::Logger.any_instance.expects(:debug).with("Sending datapoint: 'test.age 31 1357121460'")
      Dalia::MiniGraphite.datapoint("test.age", 31, Time.new(2013,1,2,10,11))
    end
  end

  def test_on_datapoint_not_send_tcp_if_mock_mode
    Dalia::MiniGraphite.config(:mock_mode => true)
    Dalia::MiniGraphite.expects(:send_tcp).never
    Dalia::MiniGraphite.datapoint("test.age")
  end

  def test_on_counter_not_send_udp_if_mock_mode
    Dalia::MiniGraphite.config(:mock_mode => true)
    Dalia::MiniGraphite.expects(:send_udp).never
    Dalia::MiniGraphite.counter("test.age")
  end

  def test_benchmark_wrapper
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.ini").never
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.time", is_a(Float))
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.result").never
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.end")

    result =
      Dalia::MiniGraphite.benchmark_wrapper("key_prefix") do
        sleep(1)
        "RESULT"
      end

    assert_equal("RESULT", result)
  end

  def test_benchmark_wrapper_sending_result
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.ini").never
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.time", is_a(Float))
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.result", 6)
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.end")

    result =
      Dalia::MiniGraphite.benchmark_wrapper("key_prefix", :length) do
        sleep(1)
        "RESULT"
      end

    assert_equal("RESULT", result)
  end

  def test_benchmark_wrapper_sending_ini
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.ini")
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.time", is_a(Float))
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.result").never
    Dalia::MiniGraphite.expects(:counter).with("key_prefix.end")

    result =
      Dalia::MiniGraphite.benchmark_wrapper("key_prefix", nil, true) do
        sleep(1)
        "RESULT"
      end

    assert_equal("RESULT", result)
  end

  def test_benchmark_method_on_instance_method
    Dalia::MiniGraphite.expects(:counter).with("key_my_instance_method.time", is_a(Float))
    Dalia::MiniGraphite.expects(:counter).with("key_my_instance_method.end")

    # The test class
    # - https://stackoverflow.com/questions/3194290/why-cant-there-be-classes-inside-methods-in-ruby
    self.class.const_set :MyClass1, Class.new {
      extend Dalia::MiniGraphite::MethodWrapper
      def my_instance_method(params)
        "RESULT: #{params}"
      end
      mini_graphite_benchmark_method(:my_instance_method, "key_my_instance_method")
    }

    assert_equal("RESULT: params", MyClass1.new.my_instance_method("params"))
  end

  def test_benchmark_method_on_class_method
    Dalia::MiniGraphite.expects(:counter).with("key_my_class_method.time", is_a(Float))
    Dalia::MiniGraphite.expects(:counter).with("key_my_class_method.end")

    # The test class
    # - https://stackoverflow.com/questions/3194290/why-cant-there-be-classes-inside-methods-in-ruby
    self.class.const_set :MyClass2, Class.new {
      def self.my_class_method(params)
        "RESULT: #{params}"
      end

      class << self
        extend Dalia::MiniGraphite::MethodWrapper
        mini_graphite_benchmark_method(:my_class_method, "key_my_class_method")
      end
    }

    assert_equal("RESULT: params", MyClass2.my_class_method("params"))
  end

end
