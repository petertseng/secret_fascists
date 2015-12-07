# Represents a president/chancellor pair who have been elected.
# Keeps track of the policy cards for this legislative session.
# Can be exposed to clients.
# Is read-only unless using the GameEditor refinement.
module SecretFascists; class Legislature
  attr_reader :round_id, :election_id
  attr_reader :president, :chancellor
  attr_reader :drawn_cards
  attr_reader :president_discard, :chancellor_discard, :enacted, :veto_discard
  attr_reader :veto_status

  def initialize(round_id, election_id, president, chancellor, drawn_cards, veto_enabled: false)
    @round_id = round_id
    @election_id = election_id
    @president = president
    @chancellor = chancellor

    # Shuffle these so that it's not known which card President discards.
    # TODO: Not certain that these are shuffled (though seems like they would be)
    @current_cards = drawn_cards.shuffle
    # We keep the original drawn cards just so we can refer back to them though.
    @drawn_cards = drawn_cards.freeze
    @president_discard = nil
    @chancellor_discard = nil
    @veto_discard = nil
    @enacted = nil

    # disabled, enabled, requested, accepted, rejected
    @veto_status = veto_enabled ? :enabled : :disabled
  end

  def current_cards
    @current_cards.dup
  end

  def cards_without_index(idx)
    @current_cards[0...idx] + @current_cards[(idx + 1)..-1]
  end
end; end

module SecretFascists; module GameEditor; refine Legislature do
  def president_discards(index)
    raise "President already discarded #{@president_discard}, can't discard #{index}" if @president_discard
    discarded = @current_cards.delete_at(index)
    @president_discard = discarded
  end

  def chancellor_discards(index)
    raise "Chancellor already discarded #{@chancellor_discard}, can't discard #{index}" if @chancellor_discard
    raise 'President has not discarded yet' unless @president_discard
    raise 'No need to discard, veto was accepted' if @veto_status == :accepted
    discarded = @current_cards.delete_at(index)
    @chancellor_discard = discarded
    raise "Too many cards to enact, have #{@current_cards.size}" unless @current_cards.size == 1
    @enacted = @current_cards.first
    @current_cards = [].freeze
    [discarded, @enacted]
  end

  def chancellor_requests_veto
    raise "Veto status is #{@veto_status}, not enabled" if @veto_status != :enabled
    raise 'President has not discarded yet' unless @president_discard
    @veto_status = :requested
  end

  def president_accepts_veto
    raise "Veto status is #{@veto_status}, not requested" if @veto_status != :requested
    @veto_status = :accepted
    @veto_discard = @current_cards.freeze
    @current_cards = [].freeze
  end

  def president_rejects_veto
    raise "Veto status is #{@veto_status}, not requested" if @veto_status != :requested
    @veto_status = :rejected
  end
end; end; end
