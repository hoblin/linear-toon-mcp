# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetUser do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:user_data) { {"id" => "u-1", "name" => "Alice", "email" => "alice@example.com"} }

  before do
    LinearToonMcp.client = client
    allow(client).to receive(:query)
      .with(a_string_matching(/\Aquery\(\$id: String!\) \{\s+user/), anything)
      .and_return("user" => user_data)
  end

  it 'resolves "me" through the viewer shortcut and queries the user' do
    allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "me").and_return("u-1")
    described_class.call(query: "me")
    expect(LinearToonMcp::Resolvers::User).to have_received(:call).with(value: "me")
    expect(client).to have_received(:query).with(a_string_matching(/user\(id:/), variables: {id: "u-1"})
  end

  it "resolves a name through Resolvers::User" do
    allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "Alice").and_return("u-1")
    described_class.call(query: "Alice")
    expect(LinearToonMcp::Resolvers::User).to have_received(:call).with(value: "Alice")
  end
end
