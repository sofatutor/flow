require 'optparse'

module Flow
  class CLI
    def self.start(args = ARGV)
      options = {}
      subcommand = args.shift

      puts "Starting with args: #{args.inspect}" if ENV['DEBUG']

      case subcommand
      when 'update_pr_description'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow update_pr_description -c CONTENT -p PR_NUMBER GEM_NAME"
          opts.on("-c", "--content CONTENT", "Content to update") { |v| options[:content] = v }
          opts.on("-p", "--pr_number PR_NUMBER", "Pull Request number") { |v| options[:pr_number] = v }
        end.parse!(args)

        options[:gem_name] = args.shift
        puts "Options: #{options.inspect}" if ENV['DEBUG']
        Flow::PRDescriptionUpdater.call(options[:gem_name], options[:content], options[:pr_number])

      when 'check_gem_revision'
        options[:verbose] = false
        options[:format] = 'cli'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow check_gem_revision -m MAIN_BRANCH GEM_NAME"
          opts.on("-m", "--main_branch MAIN_BRANCH", "Main branch name") { |v| options[:main_branch] = v }
          opts.on("-v", "--verbose", "Show diff instead of URL") { options[:verbose] = true }
        end.parse!(args)

        options[:gem_name] = args.shift
        options[:main_branch] ||= `gh pr view --json 'baseRefName' --jq '.baseRefName'`.strip
        puts "Options: #{options.inspect}" if ENV['DEBUG']
        compare_output = Flow::GemRevisionChecker.call(gem_name: options[:gem_name], main_branch: options[:main_branch], verbose: options[:verbose])
        if compare_output
          puts compare_output
        else
          exit 1
        end

      else
        puts "Unknown subcommand: #{subcommand}"
        puts "Available subcommands: update_pr_description, check_gem_revision"
      end
    end
  end
end
