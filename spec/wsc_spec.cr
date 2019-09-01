require "./spec_helper"

def timer(delay : Int) : Channel(Symbol)
  timer_ch = Channel(Symbol).new
  spawn do
    sleep delay
    timer_ch.send(:timeout) unless timer_ch.closed?
  end

  timer_ch
end

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
TLS_PORT = PORT + 1
handlers = [
  HTTP::WebSocketHandler.new do |ws, context|
    spawn do
      ws.send("open")
      sleep 1
      ws.close("close")
    end
  end,
]

describe Wsc do
  it do
    server = TestWsServer.run(HOST, PORT, handlers)
    headers = HTTP::Headers.new
    uri = "ws://#{HOST}:#{PORT}/"
    wsc = Wsc::Base.new(uri, headers, false)
    message_ch = Channel(String).new
    close_ch = Channel(String).new
    wsc.on_message { |message| message_ch.send(message) }
    wsc.on_close { |message| close_ch.send(message) }
    spawn { wsc.run }
    timer_ch = timer(2)
    loop do
      select
      when message = message_ch.receive
        message.should eq("open")
        message_ch.close
      when message = close_ch.receive
        message.should eq("close")
        close_ch.close
        timer_ch.close
        break
      when timer_ch.receive
        timer_ch.close
        fail "Timeout"
        break
      end
    end
    server.close
    wsc.close
  end

  it do
    server = TestWsServer.run(HOST, PORT, handlers, true)
    headers = HTTP::Headers.new
    uri = "wss://#{HOST}:#{PORT}/"
    wsc = Wsc::Base.new(uri, headers, true)
    message_ch = Channel(String).new
    close_ch = Channel(String).new
    wsc.on_message { |message| message_ch.send(message) }
    wsc.on_close { |message| close_ch.send(message) }
    spawn { wsc.run }
    timer_ch = timer(2)
    loop do
      select
      when message = message_ch.receive
        message.should eq("open")
        message_ch.close
      when message = close_ch.receive
        message.should eq("close")
        close_ch.close
        timer_ch.close
        break
      when timer_ch.receive
        timer_ch.close
        fail "Timeout"
        break
      end
    end
    server.close
    wsc.close
  end

  it do
    server = TestWsServer.run(HOST, PORT, handlers, true)
    headers = HTTP::Headers.new
    uri = "wss://#{HOST}:#{PORT}/"
    wsc = Wsc::Base.new(uri, headers, true)
    message_ch = Channel(String).new
    close_ch = Channel(String).new
    ping_pong_ch = Channel(String).new
    wsc.on_message { |message| message_ch.send(message) }
    wsc.on_close { |message| close_ch.send(message) }
    wsc.on_pong do |message|
      ping_pong_ch.send(message)
    end
    wsc.ping("ping")
    spawn { wsc.run }
    timer_ch = timer(2)
    loop do
      select
      when message = message_ch.receive
        message.should eq("open")
        message_ch.close
      when message = close_ch.receive
        message.should eq("close")
        close_ch.close
        timer_ch.close
        break
      when message = ping_pong_ch.receive
        message.should eq("ping")
        ping_pong_ch.close
      when timer_ch.receive
        timer_ch.close
        fail "Timeout"
        break
      end
    end
    message_ch.closed?.should eq(true)
    close_ch.closed?.should eq(true)
    ping_pong_ch.closed?.should eq(true)
    timer_ch.closed?.should eq(true)
    server.close
    wsc.close
  end
end
