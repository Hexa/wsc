require "./wsc/*"
require "http"
require "option_parser"

DEFAULT_URI = "ws://[::1]/"
uri = URI.parse(DEFAULT_URI)

OptionParser.parse! do |parser|
  parser.banner = "Usage: wsc [arguments]"
  parser.on("-u URI", "--uri URI", "ws uri") { |name| uri = name }
  parser.on("-V", "--version", "version") { puts Wsc::VERSION; exit 0 }
  parser.on("-h", "--help", "Show this help") { puts parser; exit 1 }
  parser.missing_option { exit 1 }
  parser.invalid_option { exit 255 }
end

module Wsc
  class App
    def initialize(uri : URI | String, headers : HTTP::Headers)
      @ws = HTTP::WebSocket.new(uri, headers)
    end

    def run
      @ws.on_message do |message|
        puts "on_message: #{message}"
      end

      @ws.on_binary do |binary|
        puts "on_binary: #{binary.hexdump}"
      end

      @ws.on_close do |message|
        puts "on_close: #{message}"
      end

      @ws.run
    end

    def self.run(uri : URI | String)
      Wsc::App.run(uri, HTTP::Headers.new)
    end

    def self.run(uri : URI | String, headers : HTTP::Headers)
      wsc = Wsc::App.new(uri, headers)
      wsc.run
    end
  end
end

begin
  Wsc::App.run(uri)
rescue ex
  puts ex.message
end
