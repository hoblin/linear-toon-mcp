# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::UserResolver do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(client, uuid)).to eq(uuid)
  end

  it "resolves 'me' through the viewer shortcut" do
    allow(client).to receive(:query).and_return("viewer" => {"id" => uuid})
    expect(described_class.call(client, "me")).to eq(uuid)
  end

  it "raises when viewer returns no id" do
    allow(client).to receive(:query).and_return("viewer" => {})
    expect { described_class.call(client, "me") }
      .to raise_error(LinearToonMcp::Error, /Could not resolve current user/)
  end

  it "uses the email filter when the value contains '@'" do
    allow(client).to receive(:query).and_return("users" => {"nodes" => [{"id" => uuid}]})
    described_class.call(client, "alice@example.com")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {email: {eq: "alice@example.com"}}}
    )
  end

  it "falls back to the name filter otherwise" do
    allow(client).to receive(:query).and_return("users" => {"nodes" => [{"id" => uuid}]})
    described_class.call(client, "Alice")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Alice"}}}
    )
  end

  it "raises when user not found" do
    allow(client).to receive(:query).and_return("users" => {"nodes" => []})
    expect { described_class.call(client, "Nobody") }
      .to raise_error(LinearToonMcp::Error, /\AUser not found: Nobody\z/)
  end
end
