# Represents a round in the game, during which a single policy is enacted.
# The policy may be enacted through legislature or populace.
# Can be exposed to clients.
# Is read-only unless using the GameEditor refinement.
module SecretFascists; class Round
  attr_reader :id, :candidates
  attr_reader :populace_enacted

  def initialize(id, candidates)
    @id = id
    @candidates = candidates.freeze
    @elections = []
    @populace_enacted = nil
  end

  def size
    @elections.size
  end

  def next_presidential_candidate
    @candidates[@elections.size]
  end

  def elections
    @elections.dup
  end

  def current_election
    @elections.last
  end

  def last_legislature
    @elections.last && @elections.last.legislature
  end

  def legislature_enacted
    last_legislature && last_legislature.enacted
  end
end; end

module SecretFascists; module GameEditor; refine Round do
  def populace_enacted=(policy)
    raise "Populace already enacted #{@populace_enacted}, can't enact #{policy}" if @populace_enacted
    raise "Legislature already enacted #{legislature_enacted}, can't enact #{policy}" if legislature_enacted
    @populace_enacted = policy
  end

  def <<(election)
    raise "Too many elections for round #{@id}: #{@elections}" if @elections.size >= Game::ELECTION_CHANCES
    @elections << election
  end
end; end; end
