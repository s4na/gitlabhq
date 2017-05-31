require 'spec_helper'

describe WikiPages::CreateService, services: true do
  let(:project) { create(:empty_project) }
  let(:user)    { create(:user) }

  let(:opts) do
    {
      title: 'Title',
      content: 'Content for wiki page',
      format: 'markdown'
    }
  end

  subject(:service) { described_class.new(project, user, opts) }

  before do
    project.add_master(user)
  end

  describe '#execute' do
    it 'creates wiki page with valid attributes' do
      page = service.execute

      expect(page).to be_valid
      expect(page).to have_attributes(title: opts[:title], content: opts[:content], format: opts[:format].to_sym)
    end

    it 'executes webhooks' do
      expect(service).to receive(:execute_hooks).once.with(instance_of(WikiPage), 'create')

      service.execute
    end

    context 'when running on a Geo primary node' do
      before do
        allow(Gitlab::Geo).to receive(:primary?) { true }
      end

      it 'triggers Geo::PushEventStore when Geo is enabled' do
        expect(Geo::PushEventStore).to receive(:new).with(instance_of(Project), source: Geo::PushEvent::WIKI).and_call_original
        expect_any_instance_of(Geo::PushEventStore).to receive(:create)

        service.execute
      end

      it 'triggers wiki update on secondary nodes' do
        expect(Gitlab::Geo).to receive(:notify_wiki_update).with(instance_of(Project))

        service.execute
      end
    end
  end
end
