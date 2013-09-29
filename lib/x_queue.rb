class XQueue
  require 'mechanize'
  require 'json'
  
  # Ruby interface to the Open edX XQueue class for external checkers
  # (autograders).  Lets you pull student-submitted work products from a
  # named queue and post back the results of grading them.
  #
  # == Authentication
  #
  # You need two sets of credentials to authenticate yourself to the
  # xqueue server.  For historical reasons, they are called
  # (+django_name+, +django_pass+) and (+user_name+, +user_pass+).
  # You also need to name the queue you want to use; edX creates queues
  # for you.  Each +XQueue+ instance is tied to a single queue name.


  attr_reader :queue_name
  # Queue from which to pull, established in constructor.  You need a
  # new +XQueue+ object if you want to use a different queue.

  attr_reader :base_uri
  # The base URI used for this queue; won't change for this queue even
  # if you later change the value of +XQueue.base_uri+

  attr_reader :session_cookie
  # The session cookie resulting from a successful authentication to
  # queue server 

  XQUEUE_DEFAULT_BASE_URI = 'https://xqueue.edx.org'
  # The base URI of the production server where queues live.

  def self.base_uri
    @@base_uri ||= URI(XQUEUE_DEFAULT_BASE_URI)
  end

  def self.base_uri=(uri)
    @@base_uri = URI(uri)
  end

  class AuthenticationError < StandardError ;  end
  # Raised if XQueue authentication fails
  class IOError < StandardError ; end
  # Raised if there are network or I/O errors connecting to queue server

  # Creates a new queue instance and attempts to authenticate to the
  # queue server.
  # * +django_name+, +django_pass+: first set of auth credentials (see
  # above)
  # * +user_name+, +user_pass+: second set of auth credentials (see
  # above)
  # * +queue_name+: logical name of the queue
  def initialize(django_name, django_pass, user_name, user_pass, queue_name)
    @queue_name = queue_name
    @base_uri = XQueue.base_uri
    @django_auth = {'username' => django_name, 'password' => django_pass}
    @session = Mechanize.new
    @session.add_auth(@base_uri, user_name, user_pass)
  end

  def authenticate
    response = @session.post_request(:post, 'xqueue/login/', @django_auth)
    if (error_message = login_error(response)).nil?
      @session_cookie = response['set-cookie'].split(';').first
    else
      raise AuthenticationError, error_message
    end
  end

  def queue_length
    response = send_request(:get, 'xqueue/get_queuelen/', :queue_name =>
      @queue_name)
    
  end

  private

  def login_error(response)
    return "Server error: #{response.code} #{response.message}" unless
      response.kind_of? Net::HTTPSuccess
    begin
      response_json = JSON(response.body)
      return (response_json['return_code'].zero? ?
        nil :
        "Authentication failure: #{response_json['content']}")
    rescue JSON::ParserError => e
      return "Non-JSON response from server: #{response.body}"
    end
  end

  def send_request(method, path, form_data=nil)
    begin
      uri = URI.join(base_uri, path)
      request = (method == :post ?
        Net::HTTP::Post.new(uri.request_uri) :
        Net::HTTP::Get.new(uri.request_uri))
      request.basic_auth(*@basic_auth)
      request.set_form_data(form_data) if form_data
      request['cookie'] = session_cookie if session_cookie
      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => (uri.scheme == 'https'),
        :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |connection|
        connection.request(request)
      end
    end
  rescue Exception => e
    raise IOError, e.message
  end

end
