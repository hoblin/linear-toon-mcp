# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListIssues do
  describe ".call" do
    subject(:response) { described_class.call(**params, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:params) { {} }
    let(:issues_data) do
      {
        "nodes" => [
          {
            "id" => "uuid-1",
            "identifier" => "TEST-1",
            "title" => "First issue",
            "priority" => 2,
            "priorityLabel" => "High",
            "url" => "https://linear.app/test/issue/TEST-1",
            "createdAt" => "2026-01-01T00:00:00.000Z",
            "updatedAt" => "2026-01-02T00:00:00.000Z",
            "state" => {"name" => "In Progress"},
            "assignee" => {"id" => "user-1", "name" => "Alice"},
            "labels" => {"nodes" => [{"name" => "bug"}]},
            "project" => {"id" => "proj-1", "name" => "My Project"},
            "team" => {"id" => "team-1", "name" => "Engineering"}
          }
        ],
        "pageInfo" => {
          "hasNextPage" => false,
          "endCursor" => nil
        }
      }
    end

    before do
      allow(client).to receive(:query).and_return("issues" => issues_data)
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      expect(response.content.first[:text]).to include("TEST-1")
      expect(response.content.first[:text]).to include("First issue")
    end

    it "passes default variables to client" do
      response
      expect(client).to have_received(:query).with(
        described_class::QUERY,
        variables: {first: 50, orderBy: "updatedAt", includeArchived: true}
      )
    end

    context "with team name filter" do
      let(:params) { {team: "Engineering"} }

      it "builds name-based filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {team: {name: {eqCaseInsensitive: "Engineering"}}}
          )
        )
      end
    end

    context "with team UUID filter" do
      let(:params) { {team: "12345678-1234-1234-1234-123456789012"} }

      it "builds ID-based filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {team: {id: {eq: "12345678-1234-1234-1234-123456789012"}}}
          )
        )
      end
    end

    context 'with assignee "me"' do
      let(:params) { {assignee: "me"} }

      it "builds isMe filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {assignee: {isMe: {eq: true}}}
          )
        )
      end
    end

    context "with assignee email" do
      let(:params) { {assignee: "alice@example.com"} }

      it "builds email filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {assignee: {email: {eq: "alice@example.com"}}}
          )
        )
      end
    end

    context "with assignee name" do
      let(:params) { {assignee: "Alice"} }

      it "builds name filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {assignee: {name: {eqCaseInsensitive: "Alice"}}}
          )
        )
      end
    end

    context "with state filter" do
      let(:params) { {state: "In Progress"} }

      it "builds state name filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {state: {name: {eqCaseInsensitive: "In Progress"}}}
          )
        )
      end
    end

    context "with label filter" do
      let(:params) { {label: "bug"} }

      it "builds labels filter with some matcher" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {labels: {some: {name: {eqCaseInsensitive: "bug"}}}}
          )
        )
      end
    end

    context "with priority filter" do
      let(:params) { {priority: 1} }

      it "builds priority eq filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {priority: {eq: 1}}
          )
        )
      end
    end

    context "with parent ID filter" do
      let(:params) { {parentId: "parent-uuid"} }

      it "builds parent ID filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {parent: {id: {eq: "parent-uuid"}}}
          )
        )
      end
    end

    context "with cycle number" do
      let(:params) { {cycle: "42"} }

      it "builds cycle number filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {cycle: {number: {eq: 42}}}
          )
        )
      end
    end

    context "with cycle name" do
      let(:params) { {cycle: "Sprint 5"} }

      it "builds cycle name filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: {cycle: {name: {eqCaseInsensitive: "Sprint 5"}}}
          )
        )
      end
    end

    context "with query search" do
      let(:params) { {query: "bug"} }

      it "builds title/description search filter" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: hash_including(
              or: [
                {title: {containsIgnoreCase: "bug"}},
                {description: {containsIgnoreCase: "bug"}}
              ]
            )
          )
        )
      end
    end

    context "with pagination" do
      let(:params) { {limit: 10, cursor: "abc123"} }

      it "passes pagination variables" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(first: 10, after: "abc123")
        )
      end
    end

    context "with limit exceeding max" do
      let(:params) { {limit: 500} }

      it "caps limit at 250" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(first: 250)
        )
      end
    end

    context "with limit below minimum" do
      let(:params) { {limit: 0} }

      it "clamps limit to 1" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(first: 1)
        )
      end
    end

    context "with orderBy" do
      let(:params) { {orderBy: "createdAt"} }

      it "passes orderBy variable" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(orderBy: "createdAt")
        )
      end
    end

    context "with includeArchived false" do
      let(:params) { {includeArchived: false} }

      it "passes includeArchived variable" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(includeArchived: false)
        )
      end
    end

    context "with ISO-8601 duration" do
      let(:params) { {createdAt: "-P7D"} }

      it "resolves duration to ISO date" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: hash_including(
              createdAt: {gte: match(/\A\d{4}-\d{2}-\d{2}T/)}
            )
          )
        )
      end
    end

    context "with ISO-8601 date" do
      let(:params) { {createdAt: "2026-01-01T00:00:00Z"} }

      it "passes date as-is" do
        response
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: hash_including(
            filter: hash_including(
              createdAt: {gte: "2026-01-01T00:00:00Z"}
            )
          )
        )
      end
    end

    context "with invalid duration" do
      let(:params) { {createdAt: "-PINVALID"} }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Invalid duration")
      end
    end

    context "when issues field is nil" do
      before do
        allow(client).to receive(:query).and_return("issues" => nil)
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Unexpected response")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(server_context: {}) }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("client missing")
      end
    end

    context "when the API returns an error" do
      before do
        allow(client).to receive(:query).and_raise(LinearToonMcp::Error, "HTTP 400: Bad request")
      end

      it "returns an error response with the message" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("HTTP 400")
      end
    end
  end
end
