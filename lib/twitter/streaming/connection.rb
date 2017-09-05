require 'http/parser'
require 'openssl'
require 'resolv'

module Twitter
  module Streaming
    class Connection
      def initialize(opts = {})
        @tcp_socket_class = opts.fetch(:tcp_socket_class) { TCPSocket }
        @ssl_socket_class = opts.fetch(:ssl_socket_class) { OpenSSL::SSL::SSLSocket }
      end
      attr_reader :tcp_socket_class, :ssl_socket_class

      def stream(request, response)
        client_context = OpenSSL::SSL::SSLContext.new
        client         = @tcp_socket_class.new(Resolv.getaddress(request.socket_host), request.socket_port)
        ssl_client     = @ssl_socket_class.new(client, client_context)

        ssl_client.connect
        request.stream(ssl_client)
        
        # Patch gotten from https://github.com/sferik/twitter/issues/664, by nidev.
        loop do
          begin
            body = ssl_client.read_nonblock(1024)
            response << body
          rescue IO::WaitReadable
            puts "[#{DateTime.now.to_s}] Calling IO.select() in Twitter::Streaming::Connection.stream."

            # The reason for setting 90 seconds as a timeout is documented on:
            # https://dev.twitter.com/streaming/overview/connecting
            r, w, e = IO.select([ssl_client], [], [], 90)

            if r.nil?
              ssl_client.close
              raise ::IOError
              break
            end

            retry
          end
        end

      end
    end
  end
end
