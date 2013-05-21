module Skylight
  module Messages
    class Batch
      include Beefcake::Message

      required :timestamp, :unit32,  1
      repeated :endpoints, Endpoint, 2

    end
  end
end