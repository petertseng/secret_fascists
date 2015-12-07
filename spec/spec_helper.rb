require 'simplecov'
SimpleCov.start { add_filter '/spec/' }

require 'secret_fascists/game'

RSpec.configure { |c|
  c.warnings = true
  c.disable_monkey_patching!
}

def example_players(num_players)
  (1..num_players).map { |i| "p#{i}" }
end
