require "./wsc/*"
require "http"
require "openssl"
require "option_parser"
require "uri"

DEFAULT_URI = "ws://127.0.0.1/"
uri = DEFAULT_URI
insecure = false

OptionParser.parse! do |parser|
  parser.banner = "Usage: wsc [arguments]"
  parser.on("-u URI", "--uri URI", "ws uri") { |name| uri = name }
  parser.on("-i", "--insecure", "ignore certificate verify") { insecure = true }
  parser.on("-V", "--version", "version") { puts Wsc::VERSION; exit 0 }
  parser.on("-h", "--help", "Show this help") { puts parser; exit 1 }
  parser.missing_option { exit 1 }
  parser.invalid_option { exit 255 }
end

module Wsc
  class App
    DEFAULT_HOST     = "127.0.0.1"
    DEFAULT_PORT     = 80
    DEFAULT_TLS_PORT = 443
    DEFAULT_PATH     = "/"

    def initialize(uri : String, headers : HTTP::Headers, insecure : Bool)
      @uri = URI.parse(uri)
      scheme = @uri.scheme
      host = @uri.host || DEFAULT_HOST
      path = @uri.path || DEFAULT_PATH
      _query = @uri.query
      query = "?#{_query}" if (_query && !_query.empty?) || ""
      tls = false

      if scheme == "wss"
        port = @uri.port || DEFAULT_PORT
        if insecure
          tls = OpenSSL::SSL::Context::Client.new
          tls.verify_mode = OpenSSL::SSL::VerifyMode::NONE
        else
          tls = true
        end
      elsif scheme == "ws"
        port = @uri.port || DEFAULT_PORT
      else
        raise "UNEXPECTED-URI"
      end

      @ws = HTTP::WebSocket.new(host, "#{path}#{query}", port, tls, headers)
    end

    def on_message
      @ws.on_message do |message|
        puts "on_message: #{message}"
      end
    end

    def on_message(proc : Proc)
      @ws.on_message do |message|
        proc.call(message)
      end
    end

    def on_message(&block : String ->)
      @ws.on_message &block
    end

    def on_binary(proc : Proc)
      @ws.on_binary do |binary|
        proc.call(binary)
      end
    end

    def on_binary
      @ws.on_binary do |binary|
        puts "on_binary: #{binary.hexdump}"
      end
    end

    def on_binary(&block : Bytes ->)
      @ws.on_binary &block
    end

    def on_close
      @ws.on_close do |message|
        puts "on_close: #{message}"
      end
    end

    def on_close(&block : String ->)
      @ws.on_close &block
    end

    def on_ping(&block : String ->)
      @ws.on_ping &block
    end

    def on_pong(&block : String ->)
      @ws.on_pong &block
    end

    def ping(message : String | Nil = nil)
      @ws.ping message
    end

    def pong(message : String | Nil = nil)
      @ws.pong message
    end

    def run
      @ws.run
    end

    def close
      @ws.close
    end

    def self.run(uri : String)
      Wsc::App.run(uri, HTTP::Headers.new)
    end

    def self.run(uri : String, headers : HTTP::Headers)
      Wsc::App.run(uri, headers, false)
    end

    def self.run(uri : String, headers : HTTP::Headers, insecure : Bool)
      wsc = Wsc::App.new(uri, headers, insecure)
      wsc.run
    end
  end
end

begin
  headers = HTTP::Headers.new
  wsc = Wsc::App.new(uri, headers, insecure)
  wsc.on_message do |message|
    puts message
    message
  end
  wsc.on_binary do |binary|
    puts binary.hexdump
  end
  wsc.on_close do |message|
    puts message
  end
  wsc.run
rescue ex
  puts ex.message
  exit 1
end
