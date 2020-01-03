require "./wsc/*"
require "http"
require "option_parser"

DEFAULT_URI = "ws://127.0.0.1/"
uri = DEFAULT_URI
insecure = false

OptionParser.parse do |parser|
  parser.banner = "Usage: wsc [arguments]"
  parser.on("-u URI", "--uri URI", "ws uri") { |name| uri = name }
  parser.on("-i", "--insecure", "ignore certificate verify") { insecure = true }
  parser.on("-V", "--version", "version") { puts Wsc::VERSION; exit 0 }
  parser.on("-h", "--help", "Show this help") { puts parser; exit 1 }
  parser.missing_option { exit 1 }
  parser.invalid_option { exit 255 }
end

begin
  headers = HTTP::Headers.new
  wsc = Wsc::Base.new(uri, headers, insecure)
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
