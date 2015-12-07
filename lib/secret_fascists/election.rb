# Represents a president/chancellor pair and the votes on this pair.
# Can be exposed to clients.
# Is read-only unless using the GameEditor refinement.
module SecretFascists; class Election
  attr_reader :round_id, :id
  attr_reader :president, :chancellor
  attr_reader :legislature

  def initialize(round_id, id, president, chancellor, voters)
    @round_id = round_id
    @id = id
    @president = president
    @chancellor = chancellor
    @voters = voters.map { |v| [v, nil] }.to_h
    @legislature = nil
  end

  def not_yet_voted
    @voters.select { |_, v| v.nil? }.keys
  end

  def voting_complete?
    @voters.none? { |_, v| v.nil? }
  end

  def votes
    @voters.keys.group_by { |k| @voters[k] }
  end
end; end

module SecretFascists; module GameEditor; refine Election do
  def vote_ja(v)
    @voters[v] = :ja
  end

  def vote_nein(v)
    @voters[v] = :nein
  end

  def legislature=(legislature)
    raise "Election #{@round_id}.#{@id} already has legislature #{@legislature}, can't set to #{legislature}" if @legislature
    @legislature = legislature
  end
end; end; end
