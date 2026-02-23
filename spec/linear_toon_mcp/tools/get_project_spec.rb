# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetProject do
  describe ".call" do
    subject(:response) { described_class.call(query:, server_context: {client:}, **options) }

    let(:query) { "My Project" }
    let(:options) { {} }
    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:project_id) { "proj-uuid-123" }
    let(:project_data) do
      {
        "id" => project_id,
        "name" => "My Project",
        "slugId" => "my-project",
        "url" => "https://linear.app/test/project/my-project",
        "description" => "A test project",
        "state" => "started",
        "priority" => 2,
        "priorityLabel" => "High",
        "startDate" => "2026-01-01",
        "targetDate" => "2026-06-30",
        "createdAt" => "2026-01-01T00:00:00.000Z",
        "updatedAt" => "2026-01-15T00:00:00.000Z",
        "archivedAt" => nil,
        "progress" => 0.25,
        "scope" => 20,
        "completedScopeHistory" => [5, 10, 15],
        "lead" => {"id" => "user-1", "name" => "Alice"},
        "teams" => {"nodes" => [{"id" => "team-1", "name" => "Engineering"}]}
      }
    end

    before do
      allow(LinearToonMcp::Resolvers).to receive(:resolve_project).with(client, query).and_return(project_id)
      allow(client).to receive(:query).and_return("project" => project_data)
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      expect(response.content.first[:text]).to include("My Project")
      expect(response.content.first[:text]).to include("proj-uuid-123")
    end

    it "resolves project by query and queries Linear" do
      response
      expect(LinearToonMcp::Resolvers).to have_received(:resolve_project).with(client, "My Project")
      expect(client).to have_received(:query).with(
        a_string_matching(/project\(id: \$id\)/),
        variables: {id: project_id}
      )
    end

    context "with UUID query" do
      let(:query) { project_id }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_project).with(client, project_id).and_return(project_id)
      end

      it "passes UUID through resolver" do
        response
        expect(LinearToonMcp::Resolvers).to have_received(:resolve_project).with(client, project_id)
      end
    end

    context "when includeMembers is true" do
      let(:options) { {includeMembers: true} }
      let(:project_data) do
        super().merge("members" => {"nodes" => [{"id" => "user-1", "name" => "Alice", "email" => "alice@test.com"}]})
      end

      it "includes members in the query" do
        response
        expect(client).to have_received(:query).with(
          a_string_matching(/members \{ nodes \{ id name email \} \}/),
          variables: {id: project_id}
        )
      end

      it "returns members in response" do
        expect(response.content.first[:text]).to include("alice@test.com")
      end
    end

    context "when includeMilestones is true" do
      let(:options) { {includeMilestones: true} }
      let(:project_data) do
        super().merge("projectMilestones" => {"nodes" => [{"id" => "ms-1", "name" => "MVP", "targetDate" => "2026-03-01"}]})
      end

      it "includes milestones in the query" do
        response
        expect(client).to have_received(:query).with(
          a_string_matching(/projectMilestones \{ nodes \{ id name targetDate \} \}/),
          variables: {id: project_id}
        )
      end

      it "returns milestones in response" do
        expect(response.content.first[:text]).to include("MVP")
      end
    end

    context "when includeResources is true" do
      let(:options) { {includeResources: true} }
      let(:project_data) do
        super().merge(
          "documents" => {"nodes" => [{"id" => "doc-1", "title" => "Design Doc"}]},
          "links" => {"nodes" => [{"id" => "link-1", "url" => "https://example.com", "label" => "Example"}]}
        )
      end

      it "includes documents and links in the query" do
        response
        expect(client).to have_received(:query).with(
          a_string_matching(/documents \{ nodes \{ id title \} \}/),
          variables: {id: project_id}
        )
        expect(client).to have_received(:query).with(
          a_string_matching(/links \{ nodes \{ id url label \} \}/),
          variables: {id: project_id}
        )
      end

      it "returns resources in response" do
        expect(response.content.first[:text]).to include("Design Doc")
        expect(response.content.first[:text]).to include("https://example.com")
      end
    end

    context "when all includes are true" do
      let(:options) { {includeMembers: true, includeMilestones: true, includeResources: true} }
      let(:project_data) do
        super().merge(
          "members" => {"nodes" => [{"id" => "user-1", "name" => "Alice", "email" => "alice@test.com"}]},
          "projectMilestones" => {"nodes" => [{"id" => "ms-1", "name" => "MVP", "targetDate" => "2026-03-01"}]},
          "documents" => {"nodes" => [{"id" => "doc-1", "title" => "Design Doc"}]},
          "links" => {"nodes" => []}
        )
      end

      it "includes all optional fields in the query" do
        response
        query_string = client.as_null_object
        allow(client).to receive(:query) do |q, **_|
          query_string = q
          {"project" => project_data}
        end
        described_class.call(query:, server_context: {client:}, **options)
        expect(query_string).to include("members")
        expect(query_string).to include("projectMilestones")
        expect(query_string).to include("documents")
        expect(query_string).to include("links")
      end
    end

    context "when the project does not exist" do
      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_project).and_raise(LinearToonMcp::Error, "Project not found: #{query}")
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Project not found: My Project")
      end
    end

    context "when API returns nil project" do
      before do
        allow(client).to receive(:query).and_return("project" => nil)
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Project not found: My Project")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(query:, server_context: {}) }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("client missing")
      end
    end

    context "when the API returns an error" do
      before do
        allow(client).to receive(:query).and_raise(LinearToonMcp::Error, "HTTP 400: Cannot query field")
      end

      it "returns an error response with the error message" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("HTTP 400")
      end
    end
  end
end
