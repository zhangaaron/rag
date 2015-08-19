require 'logger'

module RagLogger

  #Create a singleton logger used across all rag classes. Write to a timestamped log file
  def self.configure_logger(log_to_file, level)
    if log_to_file
      @@logger = Logger.new(File.open("logs/log-#{Time.now.to_s}.txt", 'w'))
    else
      @@logger = Logger.new(STDOUT)
    end
    @@logger.level = level
  end

  #If not configured, set logger to be stdout
  def logger
    @@logger ||= Logger.new(STDOUT)
  end
end