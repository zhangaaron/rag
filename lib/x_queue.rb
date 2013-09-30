class XQueue
  require 'debugger'
  require 'mechanize'
  require 'json'
  
  # Ruby interface to the Open edX XQueue class for external checkers
  # (autograders).  Lets you pull student-submitted work products from a
  # named queue and post back the results of grading them.
  #
  # All responses from the XQueue server have a JSON object with
  # +return_code+ and +content+ slots.  A +return_code+ of 0 normally
  # means success.  
  #
  # == Example
  #
  # You need two sets of credentials to authenticate yourself to the
  # xqueue server.  For historical reasons, they are called
  # (+django_name+, +django_pass+) and (+user_name+, +user_pass+).
  # You also need to name the queue you want to use; edX creates queues
  # for you.  Each +XQueue+ instance is tied to a single queue name.
  #
  # === Retrieving an assignment:
  #
  #     queue = XQueue.new('dj_name', 'dj_pass', 'u_name', 'u_pass', 'my_q')
  #     queue.length  # => an integer showing queue length
  #     assignment = XQueue::Submission.new(queue.get_submission) # => the 'content' slot of the JSON response body
  #     assignment.raw_data # => contents of file the student uploaded
  #
  # === Posting results back
  #
  # The submission includes a secret key that is used in postback,
  # so the postback method is defined on the submission not the queue object.
  #
  #     assignment.msg = "Feedback to student"
  #     assignment.score = 90  # => points out of total possible
  #     assignment.correct = true  # => show green checkmark vs red "x"
  #     assignment.post_grade_response!
  #

  # The base URI of the production Xqueue server.
  XQUEUE_DEFAULT_BASE_URI = 'https://xqueue.edx.org'

  # Error message, if any, associated with last unsuccessful operation
  attr_reader :error
  
  # Queue from which to pull, established in constructor.  You need a
  # new +XQueue+ object if you want to use a different queue.
  attr_reader :queue_name

  # The base URI used for this queue; won't change for this queue even
  # if you later change the value of +XQueue.base_uri+
  attr_reader :base_uri

  # The base URI used when new queue instances are created
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
  class NoSuchQueueError < StandardError ; end
  # Raised if queue name doesn't exist

  # Creates a new instance and attempts to authenticate to the
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
    @valid_queues = nil
    @error = nil
    @authenticated = nil
  end

  # Authenticates to the server.  You can call this explicitly, but it
  # is called automatically if necessary on the first request in a new
  # session.  
  def authenticate
    response = request :post, '/xqueue/login/', @django_auth
    if response['return_code'] == 0
      @authenticated = true
    else
      raise(AuthenticationError, "Authentication failure: #{response['content']}")
    end
  end

  # Returns +true+ if the session has been properly authenticated to
  # server, that is, after a successful call to +authenticate+ or to any
  # of the request methods that may have called +authenticate+ automatically.
  def authenticated? ; @authenticated ; end

  # Returns length of the queue as an integer >= 0.
  def queue_length
    authenticate unless authenticated?
    response = request(:get, '/xqueue/get_queuelen/', {:queue_name => @queue_name})
    if response['return_code'] == 0 # success
      response['content'].to_i
    elsif response['return_code'] == 1 && response['content'] =~ /^Valid queue names are: (.*)/i
      @valid_queues = $1.split(/,\s+/)
      raise NoSuchQueueError, "No such queue: valid queues are #{$1}"
    else
      raise IOError, response['content']
    end
  end

  # Returns a list of all valid queue names; something of a hack since
  # an +XQueue+ instance is supposed to be tied to a queue name...
  def list_queues
    authenticate unless authenticated?
    if @valid_queues.nil?
      old, @queue_name = @queue_name, 'I_AM_NOT_A_QUEUE'
      begin queue_length rescue nil end
    end
    @valid_queues
  end

  # Record a result of grading something.  It may be easier to use
  # +XQueue::Submission#post_back+, which marshals the information
  # needed here automatically.
  #
  # * +header+: secret header key (from 'xqueue_header' slot in the
  # 'content' object of the original retrieved submission)
  # * +score+: integer number of points (not scaled)
  # * +correct+: true (default) means show green checkmark, else red 'x'
  # * +message+: (optional) plain text feedback; will be coerced to UTF-8

  def put_result(header, score, correct=true, message='')
    payload = JSON.generate({
        :xqueue_header => header,
        :xqueue_body => {
          :correct   => (!!correct).to_s.capitalize,
          :score     => score,
          :message   => message.encode('UTF-8',
            :invalid => :replace, :undef => :replace, :replace => '?'),
        }
      })
    request :post, '/xqueue/put_result', payload
  end

  private

  def request(method, path, args={})
    begin
      response = @session.send(method, @base_uri + path, args)
      response_json = JSON(response.body)
    rescue JSON::ParserError => e
      raise IOError, "Non-JSON response from server: #{response.body.force_encoding('UTF-8')}"
    rescue Exception => e
      raise IOError, e.message
    end
  end

end
