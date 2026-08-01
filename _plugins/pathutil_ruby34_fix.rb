# frozen_string_literal: true

# pathutil 0.16.2 passes keyword hashes positionally, which breaks on Ruby 3+.
# That prevents Jekyll watch / hawkins liveserve from starting.
require "pathutil"

module PathutilRuby34Fix
  def read(*args, **kwd)
    kwd[:encoding] ||= encoding

    if normalize[:read]
      File.read(self, *args, **kwd).encode(universal_newline: true)
    else
      File.read(self, *args, **kwd)
    end
  end
end

Pathutil.prepend(PathutilRuby34Fix)
