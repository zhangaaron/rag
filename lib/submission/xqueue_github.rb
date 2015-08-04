require 'xqueue_ruby'
require_relative 'xqueue'

module SubmissionAdapter
  class XqueueGithub < Xqueue
    def initialize_x_queue(config_hash)
      @x_queue = ::XQueue.new(*create_xqueue_hash(config_hash), retrieve_files=false)
    end

    def next_submission_with_assignment
      submission = @x_queue.get_submission
      return if submission.nil?
      submission.assignment = Assignment::Xqueue.new(submission)

      location = File.join(
        ENV['BASE_FOLDER'] + submission.student_id],
        submission.assignment.assignment_name,
        Time.new.strftime(STRFMT)
      )
      # FileUtils.mkdir_p location
      Git.clone(submission.GIT_URL_FIELD, location)  # TODO: fill this in
      submission.files = { "files": location }
      submission
    end
  end
end


# first attempt
# submission = super
# repo = submission.body['github_repo']
# branch = submission.body['github_branch']
# # TODO: get rid of this test access_token
# url = [
#   "https://api.github.com/repos/#{repo}/zipball/#{branch}?",
#   "access_token=605391497040d15aacac18b618dc605637be4566",
# ].join ''
# submission.files = [url]
# submission.fetch_files!
# submission
