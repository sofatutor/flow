require_relative 'system_helper'

module Flow
  class PRDescriptionUpdater
    class << self
      def call(gem_name:, pr_number:, diff_link:, diff_text: nil)
        @gem_name = gem_name
        @diff_link = diff_link
        @diff_text = diff_text
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
        marker = "flow:#{@gem_name}_changes"
        pattern = /#{marker}.*?---\n/m

        new_content = "#{marker}\n\n## #{@gem_name} Changes\n\n[#{@gem_name} changes](#{@diff_link})"
        new_content += "\n\n```diff\n#{@diff_text}\n```\n" if @diff_text
        new_content += "\n---\n"

        updated_body = if current_body.match?(pattern)
                         current_body.gsub(pattern, new_content)
                       else
                         "#{current_body}\n\n#{new_content}"
                       end

        update_pr_body(updated_body)
      end
    end
  end
end