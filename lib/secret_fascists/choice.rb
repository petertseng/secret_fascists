# Represents a choice that can be made for a Decision.
# Not to be exposed to clients.
module SecretFascists; class Choice
  attr_reader :description

  def initialize(description = nil, &block)
    @description = description.freeze
    @block = block
  end

  def requires_args?
    !@block.parameters.empty?
  end

  # Expected by Decision#take_choice to return [Boolean(success), String(error_message)]
  def call(args)
    @block.call(args)
  end
end; end
