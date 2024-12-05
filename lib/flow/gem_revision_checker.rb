module Flow
  class GemRevisionChecker
    class << self
      def call(gem_name, main_branch)
        @gem_name = gem_name
        @main_branch = main_branch
        puts "Checking revisions for gem: #{@gem_name} on branch: #{@main_branch}" if ENV['DEBUG']
        compare_revisions
      end

      private

      def get_revision_from_branch(branch)
        content = `git show origin/#{branch}:Gemfile.lock`
        extract_revision(content)
      end

      def get_local_revision
        content = File.read('Gemfile.lock')
        extract_revision(content)
      end

      def extract_revision(content)
        match = content.match(/#{@gem_name}\n.*revision: (\w+)/)
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

        gem_repo_url = "https://github.com/sofatutor/#{@gem_name}"
        compare_url = "#{gem_repo_url}/compare/#{old_revision}...#{new_revision}"
        puts "Compare URL: #{compare_url}" if ENV['DEBUG']
        compare_url
      end
    end
  end
end
