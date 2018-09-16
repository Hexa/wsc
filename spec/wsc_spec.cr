require "./spec_helper"

class TestWsServer
  CERTIFICATES = "./spec/server.pem"
  PRIVATE_KEY  = "./spec/server.key"

  def self.run(host : String, port : Int, handlers)
    TestWsServer.run(host, port, handlers, false)
  end

  def self.run(host : String, port : Int, handlers, tls : Bool = false)
    server = HTTP::Server.new(handlers)
    if tls
      context = OpenSSL::SSL::Context::Server.new
      context.certificate_chain = CERTIFICATES
      context.private_key = PRIVATE_KEY
      server.bind_tls(host, port, context)
    else
      server.bind_tcp host, port
    end
    spawn do
      server.listen
    end
    server
  end
end

HOST = "127.0.0.1"
PORT = 50000
handlers = [
  HTTP::WebSocketHandler.new do |context|
    spawn do
      context.send("open")
      sleep 1
      context.close("close")
    end
  end,
] of HTTP::Handler

describe Wsc do
  it "" do
    server = TestWsServer.run(HOST, PORT, handlers)
    headers = HTTP::Headers.new
    uri = "ws://#{HOST}:#{PORT}/"
    wsc = Wsc::App.new(uri, headers, false)
    ch1 = Channel(String).new
    ch2 = Channel(String).new
    wsc.on_message { |message| ch1.send(message) }
    wsc.on_close { |message| ch2.send(message) }
    spawn do
      wsc.run
    end
    ch3 = Channel(Symbol).new
    spawn do
      sleep 2
      ch3.send(:timeout)
    end
    loop do
      select
      when message = ch1.receive
        message.should eq("open")
        ch1.close
      when message = ch2.receive
        message.should eq("close")
        ch2.close
        ch3.close
        break
      when ch3.receive
        ch3.close
        fail "Timeout"
        break
      end
    end
    server.close
    wsc.close
  end
end
