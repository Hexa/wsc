require "./spec_helper"

class TestWsServer
  CERTIFICATES = "./spec/server.pem"
  PRIVATE_KEY = "./spec/server.key"
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
    context.on_message do |message|
      context.send(message)
    end
  end
] of HTTP::Handler

describe Wsc do
  it "" do
    server = TestWsServer.run(HOST, PORT, handlers)
    headers = HTTP::Headers.new
    uri = "ws://#{HOST}:#{PORT}/"
    Wsc::App.run(uri, headers)
    server.close
  end

  it "" do
    server = TestWsServer.run(HOST, PORT, handlers, true)
    headers = HTTP::Headers.new
    uri = "wss://#{HOST}:#{PORT}/"
    Wsc::App.run(uri, headers, true)
    server.close
  end
end
