require 'xqueue_ruby'
require_relative 'adapter_interface'
class XQueueAdapter < SubmissionAdapter

  def initialize(django_name, django_pass, user_name, user_pass, queue_name)
    raise 'not yet implemented'
    @xqueue = XQueue.new(django_name, django_pass, user_name, user_pass, queue_name)
  end

  def get_submission
    @xqueue.get_submission
  end

  def return_submission(submission)
    submission.post_back
  end
end 