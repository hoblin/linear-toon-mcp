# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Base do
  describe "conventions derived from class name" do
    it "splits CamelCase, strips Resolver, and pluralizes for the connection name" do
      expect(LinearToonMcp::Resolvers::WorkflowStateResolver.connection_name).to eq("workflowStates")
      expect(LinearToonMcp::Resolvers::IssueLabelResolver.connection_name).to eq("issueLabels")
      expect(LinearToonMcp::Resolvers::TeamResolver.connection_name).to eq("teams")
    end

    it "derives the filter type name from the entity name" do
      expect(LinearToonMcp::Resolvers::WorkflowStateResolver.filter_type_name).to eq("WorkflowStateFilter")
      expect(LinearToonMcp::Resolvers::ProjectMilestoneResolver.filter_type_name).to eq("ProjectMilestoneFilter")
      expect(LinearToonMcp::Resolvers::TeamResolver.filter_type_name).to eq("TeamFilter")
    end

    it "uses the trailing CamelCase word for the not-found label" do
      expect(LinearToonMcp::Resolvers::WorkflowStateResolver.entity_label).to eq("State")
      expect(LinearToonMcp::Resolvers::IssueLabelResolver.entity_label).to eq("Label")
      expect(LinearToonMcp::Resolvers::ProjectMilestoneResolver.entity_label).to eq("Milestone")
      expect(LinearToonMcp::Resolvers::TeamResolver.entity_label).to eq("Team")
    end
  end
end
