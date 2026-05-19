# frozen_string_literal: true

module LinearToonMcp
  # MCP tool classes. Each tool inherits a verb base ({Tools::List},
  # {Tools::Get}, {Tools::Create}, {Tools::Delete}) or {Tools::Base}
  # directly for polymorphic and +save_*+ tools whose dispatch doesn't
  # fit a single verb.
  module Tools
  end
end

require_relative "tools/base"
require_relative "tools/list"
require_relative "tools/get"
require_relative "tools/create"
require_relative "tools/delete"
require_relative "tools/get_issue"
require_relative "tools/list_issues"
require_relative "tools/save_issue"
require_relative "tools/save_comment"
require_relative "tools/delete_comment"
require_relative "tools/list_comments"
require_relative "tools/list_issue_statuses"
require_relative "tools/list_teams"
require_relative "tools/list_users"
require_relative "tools/list_issue_labels"
require_relative "tools/list_projects"
require_relative "tools/list_cycles"
require_relative "tools/get_project"
require_relative "tools/list_initiatives"
require_relative "tools/get_initiative"
require_relative "tools/save_initiative"
require_relative "tools/delete_initiative"
require_relative "tools/add_project_to_initiative"
require_relative "tools/remove_project_from_initiative"
require_relative "tools/list_status_updates"
require_relative "tools/get_status_update"
require_relative "tools/save_status_update"
require_relative "tools/delete_status_update"
