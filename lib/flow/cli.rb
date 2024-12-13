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
          opts.banner = "Usage: flow update_pr_description GEM_NAME COMPARE_URL PR_NUMBER"
          opts.on("-c", "--compare_url COMPARE_URL", "Compare URL") { |v| options[:compare_url] = v }
          opts.on("-p", "--pr_number PR_NUMBER", "Pull Request number") { |v| options[:pr_number] = v }
        end.parse!(args)

        options[:gem_name] = args.shift
        puts "Options: #{options.inspect}" if ENV['DEBUG']
        Flow::PRDescriptionUpdater.call(options[:gem_name], options[:compare_url], options[:pr_number])

      when 'gem_changes'
        options[:verbose] = false
        options[:format] = 'cli'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow gem_changes GEM_NAME MAIN_BRANCH"
          opts.on("-m", "--main_branch MAIN_BRANCH", "Main branch name") { |v| options[:main_branch] = v }
          opts.on("-v", "--verbose", "Show diff instead of URL") { options[:verbose] = true }
          opts.on("-f", "--format FORMAT", "Output format (cli, markdown, html)") { |v| options[:format] = v }
        end.parse!(args)

        options[:gem_name] = args.shift
        options[:main_branch] ||= `gh pr view --json 'baseRefName' --jq '.baseRefName'`.strip
        puts "Options: #{options.inspect}" if ENV['DEBUG']
        compare_output = Flow::GemRevisionChecker.call(gem_name: options[:gem_name], main_branch: options[:main_branch], verbose: options[:verbose], format: options[:format])
        if compare_output
          puts compare_output
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
