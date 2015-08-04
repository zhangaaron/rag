require 'xqueue_ruby'
require_relative '../assignment/xqueue'
require_relative 'polling'

module Submission
  ENV['BASE_FOLDER'] ||= 'submissions/'
  FileUtils.mkdir ENV['BASE_FOLDER'] unless File.exist? ENV['BASE_FOLDER']
  puts "Autograder is downloading remote files to #{ENV['BASE_FOLDER']}"
  class Xqueue < Polling
    attr_reader :x_queue

    STRFMT = "%Y-%m-%d-%H-%M-%S"
    def initialize(config_hash)
      super(config_hash)
      # @halt = conf['halt']  # TODO: figure out what this is for
      initialize_x_queue(config_hash)
    end

    def initialize_x_queue(config_hash)
      @x_queue = ::XQueue.new(*create_xqueue_hash(config_hash))
    end

    def next_submission_with_assignment
      submission = @x_queue.get_submission
      return if submission.nil?
      submission.assignment = Assignment::Xqueue.new(submission)
      submission.write_to_location! File.join( [ENV['BASE_FOLDER'], submission.student_id].join(''),
                        submission.assignment.assignment_name, Time.new.strftime(STRFMT))
      submission
    end

    def submit_response(graded_submission)
      graded_submission.correct = graded_submission.score != 0  # as defined in edx_controller.rb in rag.
      graded_submission.post_back
    end

    def create_xqueue_hash(config_hash)
      [
        config_hash['django_auth']['username'],  # django_name
        config_hash['django_auth']['password'],  # django_pass
        config_hash['user_auth']['user_name'],   # user_name
        config_hash['user_auth']['user_pass'],   # user_pass
        config_hash['queue_name']                # queue_name
      ]
    end
  end
end
