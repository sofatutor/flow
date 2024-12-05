require_relative 'system_helper'

module Flow
  class PRDescriptionUpdater
    class << self
      def call(gem_name, compare_url, pr_number)
        @gem_name = gem_name
        @compare_url = compare_url
        @pr_number = pr_number
        update_description
      end

      private

      def fetch_pr_body
        pr_body = SystemHelper.call("gh pr view #{@pr_number} --json body -q .body")
        pr_body.strip
      end

      def update_pr_body(updated_body)
        SystemHelper.call("gh pr edit #{@pr_number} --body '#{updated_body}'")
      end

      def update_description
        current_body = fetch_pr_body
        link_marker = "[#{@gem_name} Changes]"
        new_link = "#{link_marker}(#{@compare_url})"

        updated_body = if current_body.include?(link_marker)
                         current_body.gsub(/\[#{@gem_name} Changes\]\(.*\)/, new_link)
                       else
                         "#{new_link}\n\n#{current_body}"
                       end

        update_pr_body(updated_body)
      end
    end
  end
end
