# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear user by UUID, email, name, or the literal +"me"+
    # (which short-circuits through the +viewer+ query).
    class UserResolver < Base
      shortcut "me", via: :viewer
      lookup_by :email, :name
    end
  end
end
