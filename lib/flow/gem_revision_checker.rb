require 'tmpdir'
require_relative 'system_helper'

module Flow
  class GemRevisionChecker
    class << self
      def call(gem_name:, main_branch:, verbose: false, format: nil)
        @gem_name = gem_name
        @main_branch = main_branch
        @verbose = verbose
        @format = format
        puts "Checking revisions for gem: #{@gem_name} on branch: #{@main_branch}" if ENV['DEBUG']
        compare_revisions
      end

      private

      def get_revision_from_branch(branch)
        content = SystemHelper.call("git show origin/#{branch}:Gemfile.lock")
        extract_revision(content)
      end

      def get_local_revision
        content = File.read('Gemfile.lock')
        extract_revision(content)
      end

      def extract_revision(content)
        match = content.match(/sofatutor\/#{@gem_name}\.git\n.*revision: (\w+)/)
        revision = match ? match[1] : nil
        puts "Extracted revision: #{revision}" if ENV['DEBUG']
        revision
      end

      def compare_revisions
        old_revision = get_revision_from_branch(@main_branch)
        new_revision = get_local_revision

        if old_revision.nil? || new_revision.nil? || old_revision == new_revision
          puts "No revision change detected" if ENV['DEBUG']
          return nil
        end

        if @verbose
          Dir.mktmpdir do |dir|
            clone_command = "git clone https://github.com/sofatutor/#{@gem_name}.git #{dir} > /dev/null"
            SystemHelper.call(clone_command)
            Dir.chdir(dir) do
              result = SystemHelper.call("git diff --minimal #{old_revision} #{new_revision}")
              puts result
            end
          end
        else
          gem_repo_url = "https://github.com/sofatutor/#{@gem_name}"
          compare_url = "#{gem_repo_url}/compare/#{old_revision}...#{new_revision}"
          puts "Compare URL: #{compare_url}" if ENV['DEBUG']
          compare_url
        end
      end
    end
  end
end
