require_relative '../spec_helper'

RSpec.describe Flow::GemRevisionChecker do
  describe '.call' do
    it 'returns the compare URL when revisions differ' do
      allow(Open3).to receive(:capture3).with("git show origin/main:Gemfile.lock").and_return(["sofatutor/gem_name.git\n  revision: old_revision", '', double(success?: true)])
      allow(Open3).to receive(:capture3).with("git clone https://github.com/sofatutor/gem_name.git /tmp/dir > /dev/null 2>&1").and_return(['', '', double(success?: true)])
      allow(Open3).to receive(:capture3).with("git diff --minimal old_revision new_revision").and_return(['', '', double(success?: true)])
      allow(File).to receive(:read).with('Gemfile.lock').and_return("sofatutor/gem_name.git\n  revision: new_revision")

      result = described_class.call('gem_name', 'main', false)

      expect(result).to eq('https://github.com/sofatutor/gem_name/compare/old_revision...new_revision')
    end

    it 'returns nil when revisions are the same' do
      allow(Open3).to receive(:capture3).with("git show origin/main:Gemfile.lock").and_return(["sofatutor/gem_name.git\n  revision: same_revision", '', double(success?: true)])
      allow(File).to receive(:read).with('Gemfile.lock').and_return("sofatutor/gem_name.git\n  revision: same_revision")

      result = described_class.call('gem_name', 'main', false)

      expect(result).to be_nil
    end
  end
end
