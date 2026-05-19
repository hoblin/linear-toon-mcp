# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListInitiatives do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:initiatives) do
    {"nodes" => [], "pageInfo" => {"hasNextPage" => false, "endCursor" => nil}}
  end

  before do
    LinearToonMcp.client = client
    allow(client).to receive(:query).and_return("initiatives" => initiatives)
  end

  describe ".call" do
    it "passes default variables (50/updatedAt/includeArchived=false)" do
      described_class.call
      expect(client).to have_received(:query).with(
        anything,
        variables: {first: 50, orderBy: "updatedAt", includeArchived: false}
      )
    end

    it "clamps limit to 250 max" do
      described_class.call(limit: 500)
      expect(client).to have_received(:query).with(anything, variables: hash_including(first: 250))
    end

    it "passes cursor to after" do
      described_class.call(cursor: "abc")
      expect(client).to have_received(:query).with(anything, variables: hash_including(after: "abc"))
    end

    describe "filter building" do
      it "uses containsIgnoreCase for query" do
        described_class.call(query: "roadmap")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: {name: {containsIgnoreCase: "roadmap"}})
        )
      end

      it "uses eq for status" do
        described_class.call(status: "Active")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: {status: {eq: "Active"}})
        )
      end

      it 'uses isMe for owner "me" without resolving' do
        described_class.call(owner: "me")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: {owner: {isMe: {eq: true}}})
        )
      end

      it "resolves owner names through Resolvers::User" do
        allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "Alice").and_return("u1")
        described_class.call(owner: "Alice")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: {owner: {id: {eq: "u1"}}})
        )
      end

      it "passes parentInitiative UUIDs straight through" do
        uuid = "12345678-1234-1234-1234-123456789012"
        described_class.call(parentInitiative: uuid)
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: {parentInitiative: {id: {eq: uuid}}})
        )
      end

      it "resolves parentInitiative names through Resolvers::Initiative" do
        allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
          .with(value: "Yearly Goals").and_return("p1")
        described_class.call(parentInitiative: "Yearly Goals")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: {parentInitiative: {id: {eq: "p1"}}})
        )
      end

      it "resolves ISO-8601 durations to gte dates" do
        described_class.call(createdAt: "-P7D")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(
            filter: hash_including(createdAt: {gte: match(/\A\d{4}-\d{2}-\d{2}T/)})
          )
        )
      end

      it "passes ISO dates through unchanged" do
        described_class.call(updatedAt: "2026-01-01T00:00:00Z")
        expect(client).to have_received(:query).with(
          anything,
          variables: hash_including(filter: hash_including(updatedAt: {gte: "2026-01-01T00:00:00Z"}))
        )
      end

      it "rejects invalid durations with a clear error" do
        response = described_class.call(createdAt: "-PINVALID")
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Invalid duration")
      end
    end

    describe "includeProjects" do
      it "adds initiativeToProjects to the GraphQL query body when true" do
        described_class.call(includeProjects: true)
        expect(client).to have_received(:query).with(
          a_string_matching(/initiativeToProjects \{ nodes \{ id project \{ id name \} \} \}/),
          anything
        )
      end

      it "omits initiativeToProjects when false (default)" do
        described_class.call
        expect(client).to have_received(:query).with(
          satisfy { |q| !q.include?("initiativeToProjects") },
          anything
        )
      end
    end
  end
end
