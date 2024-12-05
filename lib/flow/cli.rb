require 'optparse'

module Flow
  class CLI
    def self.start(args = ARGV)
      options = {}
      subcommand = args.shift

      case subcommand
      when 'update_pr_description'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow update_pr_description GEM_NAME COMPARE_URL PR_NUMBER"
          opts.on("-g", "--gem_name GEM_NAME", "Name of the gem") { |v| options[:gem_name] = v }
          opts.on("-c", "--compare_url COMPARE_URL", "Compare URL") { |v| options[:compare_url] = v }
          opts.on("-p", "--pr_number PR_NUMBER", "Pull Request number") { |v| options[:pr_number] = v }
        end.parse!(args) 

        Flow::PRDescriptionUpdater.call(options[:gem_name], options[:compare_url], options[:pr_number])

      when 'check_gem_revision'
        OptionParser.new do |opts|
          opts.banner = "Usage: flow check_gem_revision GEM_NAME MAIN_BRANCH"
          opts.on("-g", "--gem_name GEM_NAME", "Name of the gem") { |v| options[:gem_name] = v }
          opts.on("-m", "--main_branch MAIN_BRANCH", "Main branch name") { |v| options[:main_branch] = v }
        end.parse!(args)

        options[:main_branch] ||= 'main'
        compare_url = Flow::GemRevisionChecker.call(options[:gem_name], options[:main_branch])
        puts compare_url if compare_url

      else
        puts "Unknown subcommand: #{subcommand}"
        puts "Available subcommands: update_pr_description, check_gem_revision"
      end
    end
  end
end
