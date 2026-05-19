# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    class UserResolver < Base
      shortcut "me", via: :viewer
      lookup_by :email, :name
    end
  end
end
