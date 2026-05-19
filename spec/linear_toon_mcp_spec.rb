# frozen_string_literal: true

RSpec.describe LinearToonMcp do
  it "has a version number" do
    expect(LinearToonMcp::VERSION).not_to be_nil
  end

  describe ".client" do
    let(:injected) { instance_double(LinearToonMcp::Client) }

    it "returns the assigned client" do
      described_class.client = injected
      expect(described_class.client).to eq(injected)
    end

    it "lazily instantiates a Client when unset" do
      described_class.client = nil
      built = instance_double(LinearToonMcp::Client)
      allow(LinearToonMcp::Client).to receive(:new).and_return(built)
      expect(described_class.client).to eq(built)
    end
  end
end
