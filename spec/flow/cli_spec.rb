require_relative '../spec_helper'

RSpec.describe Flow::CLI do
  describe '.start' do
    context 'with update_pr_description subcommand' do
      it 'calls PRDescriptionUpdater with correct arguments' do
        expect(Flow::PRDescriptionUpdater).to receive(:call).with('gem_name', 'compare_url', 'pr_number')
        Flow::CLI.start(['update_pr_description', 'gem_name', '-c', 'compare_url', '-p', 'pr_number'])
      end
    end

    context 'with gem_changes subcommand' do
      it 'calls GemRevisionChecker with correct arguments' do
        allow(Flow::GemRevisionChecker).to receive(:call).and_return('compare_url')
        expect(Flow::GemRevisionChecker).to receive(:call).with('gem_name', 'main', false)
        Flow::CLI.start(['gem_changes', 'gem_name', '-m', 'main'])
        expect(Flow::GemRevisionChecker).to receive(:call).with('gem_name', 'main', true)
        Flow::CLI.start(['gem_changes', 'gem_name', '-m', 'main', '-v'])
      end
    end

    context 'with unknown subcommand' do
      it 'outputs an error message' do
        expect { Flow::CLI.start(['unknown']) }.to output(/Unknown subcommand/).to_stdout
      end
    end
  end
end
