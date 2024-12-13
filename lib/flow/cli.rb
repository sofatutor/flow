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
          opts.banner = "Usage: flow update_pr_description -l DIFF_LINK [-t DIFF_TEXT] GEM_NAME"
          opts.on("-l", "--diff_link DIFF_LINK", "Link to the diff") { |v| options[:diff_link] = v }
          opts.on("-t", "--diff_text DIFF_TEXT", "Text of the diff") { |v| options[:diff_text] = v }
        end.parse!(args)

        options[:gem_name] = args.shift
        puts "Options: #{options.inspect}" if ENV['DEBUG']
        Flow::PRDescriptionUpdater.call(gem_name: options[:gem_name], diff_link: options[:diff_link], diff_text: options[:diff_text])

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
