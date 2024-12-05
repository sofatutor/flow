require 'open3'

module SystemHelper
  def self.call(command)
    output, error, status = Open3.capture3(command)
    raise "Error executing command: #{error}" unless status.success?

    output
  end
end
