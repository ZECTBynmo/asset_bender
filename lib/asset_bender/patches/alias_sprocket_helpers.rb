# Include backwards compatible names for the script and javascript tag helpers
module Sprockets
  module Helpers
    alias_method :javascript_include_tag, :javascript_tag
    alias_method :stylesheet_link_tag, :stylesheet_tag
  end
end
