require "minitest/autorun"
require "mocha/setup"
require_relative "../lib/mini_graphite"

class MiniGraphiteTest < MiniTest::Test

  def test_debug
    Kernel.expects(:puts).with(regexp_matches(/MESSAGE/))
    logger = Dalia::MiniGraphite::Logger.new
    logger.debug("MESSAGE")
  end

  def test_debug_when_not_debug_mode
    Kernel.expects(:puts).never
    logger = Dalia::MiniGraphite::Logger.new(false)
    logger.debug("MESSAGE")
  end

  def test_debug_when_rails_actived
    unless defined? ::Rails
      Object.const_set("Rails", Module.new)
    end
    ::Rails.expects(:logger => mock(:info))
    logger = Dalia::MiniGraphite::Logger.new
    logger.debug("MESSAGE")
  end

end
