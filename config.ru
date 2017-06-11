require "json"
require "date"
require "socket"
require "sinatra"


META_SERVERS = {
  "212.59.241.214" => 7775,
}


get "/" do
  timestamp = (Time.now.to_datetime << 1).to_time.to_i
  response.headers['Access-Control-Allow-Origin'] = '*'
  content_type :json

  META_SERVERS.each_pair.inject({}) do |acc, (host, port)|
    hostKey = "#{host}:#{port}"
    acc[hostKey] = {}
    begin
      TCPSocket.open(host, port) do |s|
        s.send("LISTGAMES\n", 0)
        begin
          Timeout.timeout(1) do
            loop do
              line = s.readline
              break if line =~ /LISTGAMES_OK/
              /LISTGAMES (?<id>\d+) "(?<description>.+)" "(?<map>.+)" (?<open_slots>\d+) (?<max_slots>\d+) (?<ip>[^ ]+) (?<port>[^ ]+)/ =~ line
              acc[hostKey][id] = {
                description: description,
                map: map,
                openSlots: open_slots,
                maxSlots: max_slots
              }
            end
          end
        rescue Timeout::Error
        end
        s.send("STATS #{timestamp}\n", 0)
        if line = s.readline =~ /GAMES SINCE [^:]+: (\d+)/
          acc[host][:games_last_month] = $1.to_i
        end
      end
    rescue Exception
    end
    acc
  end.to_json
end


run Sinatra::Application
