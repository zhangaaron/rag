class SubmissionAdapter
  #this is an abstract class which all submission adapters must implement
  
  def initialize raise 'must be implemented by subclass' end
  #if no submission in queue, return nil. Otherwise, return a submission object. 
  def get_submission raise 'must be implemented by subclass' end
  #returns a submission to the submission service once it has been graded.
  def return_submission raise 'must be implemented by subclass' end
end 