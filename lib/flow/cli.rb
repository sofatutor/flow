require 'optparse'
require 'open-uri'

module Flow
  class CLI
    def self.start(args = ARGV)
      options = {}
      subcommand = args.shift

      puts "Starting with args: #{args.inspect}" if ENV['DEBUG']

      case subcommand
      when 'update_pr_description'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow update_pr_description GEM_NAME COMPARE_URL PR_NUMBER"
          opts.on("-g", "--gem_name GEM_NAME", "Name of the gem") { |v| options[:gem_name] = v }
          opts.on("-c", "--compare_url COMPARE_URL", "Compare URL") { |v| options[:compare_url] = v }
          opts.on("-p", "--pr_number PR_NUMBER", "Pull Request number") { |v| options[:pr_number] = v }
        end.parse!(args)

        puts "Options: #{options.inspect}" if ENV['DEBUG']
        Flow::PRDescriptionUpdater.call(options[:gem_name], options[:compare_url], options[:pr_number])

      when 'gem_changes'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow check_gem_revision GEM_NAME MAIN_BRANCH"
          opts.on("-g", "--gem_name GEM_NAME", "Name of the gem") { |v| options[:gem_name] = v }
          opts.on("-m", "--main_branch MAIN_BRANCH", "Main branch name") { |v| options[:main_branch] = v }
          opts.on("-v", "--verbose", "Show diff instead of URL") { options[:verbose] = true }
        end.parse!(args)

        options[:main_branch] ||= `gh pr view --json 'baseRefName' --jq '.baseRefName'`.strip
        puts "Options: #{options.inspect}" if ENV['DEBUG']
        compare_url = Flow::GemRevisionChecker.call(options[:gem_name], options[:main_branch], options[:verbose])
        if compare_url
          puts compare_url unless options[:verbose]
        else
          exit 1
        end

      else
        puts "Unknown subcommand: #{subcommand}"
        puts "Available subcommands: update_pr_description, gem_changes"
      end
    end
  end
end
