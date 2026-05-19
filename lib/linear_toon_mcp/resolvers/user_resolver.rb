# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear user by UUID, email, name, or the literal +"me"+.
    class UserResolver < Base
      shortcut "me", via: :viewer
      lookup_by :email, :name
    end
  end
end
