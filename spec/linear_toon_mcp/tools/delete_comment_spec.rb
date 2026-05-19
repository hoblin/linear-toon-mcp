# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::DeleteComment do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  it "submits commentDelete with the comment id" do
    allow(client).to receive(:query)
      .and_return("commentDelete" => {"success" => true, "entityId" => "c-1"})
    described_class.call(id: "c-1")
    expect(client).to have_received(:query).with(
      a_string_matching(/commentDelete/),
      variables: {id: "c-1"}
    )
  end
end
