require_relative 'system_helper'

module Flow
  class PRDescriptionUpdater
    class << self
      def call(gem_name, content, pr_number)
        @gem_name = gem_name
        @content = content
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
        marker = "[#{@gem_name} Changes]"
        new_content = "#{marker}\n\n#{@content}"

        updated_body = if current_body.include?(marker)
                         current_body.gsub(/#{marker}\n\n.*(?=\n\n|$)/m, new_content)
                       else
                         "#{new_content}\n\n#{current_body}"
                       end

        update_pr_body(updated_body)
      end
    end
  end
end
