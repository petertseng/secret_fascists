# Represents a decision that one or more players can make,
# containing one or more choices.
# Not to be exposed to clients.
module SecretFascists; class Decision
  attr_reader :type

  def initialize(type, choices)
    @type = type.freeze

    # All choices a player has currently.
    # Hash[Player => Hash[String => Choice]]
    @choices = choices
  end

  def self.single_player(type, decider, choices)
    new(type, {decider => choices})
  end

  def self.single_player_single(type, decider, synonyms, choice)
    new(type, {decider => synonyms.map { |s| [s, choice] }.to_h})
  end

  def choice_names
    @choices.each.map { |player, cs| [player.user, cs.keys] }.to_h
  end

  def choice_explanations(player)
    return [] unless @choices.has_key?(player)
    @choices[player].each.map { |label, choice|
      info = {
        description: choice.description,
        requires_args: choice.requires_args?,
      }
      [label, info]
    }.to_h
  end

  # Expected by Game#take_choice to return [Boolean(success), String(error_message)]
  def take_choice(player, choice_name, args)
    return [false, "#{player} has no choices to make"] unless @choices[player]

    if (choice = @choices[player][choice_name.downcase])
      choice.call(args)
    else
      return [false, "#{choice_name} is not a valid choice for #{player}"]
    end
  end
end; end
