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
    wsc = Wsc::App.new(uri, headers, false)
    ch1 = Channel(String).new
    ch2 = Channel(String).new
    wsc.on_message { |message| ch1.send(message) }
    wsc.on_close { |message| ch2.send(message) }
    spawn { wsc.run }
    ch3 = Channel(Symbol).new
    spawn do
      sleep 2
      ch3.send(:timeout) unless ch3.closed?
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

   it do
     server = TestWsServer.run(HOST, PORT, handlers, true)
     headers = HTTP::Headers.new
     uri = "wss://#{HOST}:#{PORT}/"
     wsc = Wsc::App.new(uri, headers, true)
     ch1 = Channel(String).new
     ch2 = Channel(String).new
     wsc.on_message { |message| ch1.send(message) }
     wsc.on_close { |message| ch2.send(message) }
     spawn { wsc.run }
     ch3 = Channel(Symbol).new
     spawn do
       sleep 2
       ch3.send(:timeout) unless ch3.closed?
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

   it do
     server = TestWsServer.run(HOST, PORT, handlers, true)
     headers = HTTP::Headers.new
     uri = "wss://#{HOST}:#{PORT}/"
     wsc = Wsc::App.new(uri, headers, true)
     ch1 = Channel(String).new
     ch2 = Channel(String).new
     ch3 = Channel(String).new
     wsc.on_message { |message| ch1.send(message) }
     wsc.on_close { |message| ch2.send(message) }
     wsc.on_pong do |message|
       ch3.send(message)
     end
     wsc.ping("ping")
     spawn { wsc.run }
     ch4 = Channel(Symbol).new
     spawn do
       sleep 2
       ch4.send(:timeout) unless ch4.closed?
     end
     loop do
       select
       when message = ch1.receive
         message.should eq("open")
         ch1.close
       when message = ch2.receive
         message.should eq("close")
         ch2.close
         ch4.close
         break
       when message = ch3.receive
         message.should eq("ping")
         ch3.close
       when ch4.receive
         ch4.close
         fail "Timeout"
         break
       end
     end
     ch1.closed?.should eq(true)
     ch2.closed?.should eq(true)
     ch3.closed?.should eq(true)
     ch4.closed?.should eq(true)
     server.close
     wsc.close
   end
end
