require 'webrick'
include WEBrick

class ForbiddenServlet < HTTPServlet::AbstractServlet
  def do_GET(req,res)
    res['Content-Type'] = "text/plain"
    res.status = 403
  end
end

class TestServer
  def self.start( log_file = nil, ssl = false, port = 9001 )
    new(log_file, ssl, port).start
  end

  def initialize( log_file = nil, ssl = false, port = 9001 )
    log_file ||= StringIO.new
    log = WEBrick::Log.new(log_file)

    options = {
      :Port => port,
      :Logger => log,
      :AccessLog => [
          [ log, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
          [ log, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
       ],
       :DocumentRoot => File.expand_path(__dir__),
    }

    if ssl
      options[:SSLEnable] = true
      options[:SSLCertificate] = OpenSSL::X509::Certificate.new(File.open("spec/certs/cacert.pem").read)
      options[:SSLPrivateKey] = OpenSSL::PKey::RSA.new(File.open("spec/certs/privkey.pem").read)
      options[:SSLCertName] = [ ["CN", WEBrick::Utils::getservername ] ]
    end

    @server = WEBrick::HTTPServer.new(options)
    @server.mount("/forbidden", ForbiddenServlet)
  end

  def start
    trap('INT') {
      begin
        @server.shutdown unless @server.nil?
      rescue Object => e
        $stderr.puts "Error #{__FILE__}:#{__LINE__}\n#{e.message}"
      end
    }

    @thread = Thread.new { @server.start }
    Thread.pass
    self
  end

  def join
    if defined? @thread and @thread
      @thread.join
    end
    self
  end
end
