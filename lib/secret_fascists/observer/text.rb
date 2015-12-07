module SecretFascists; module Observer; class Text
  POSITIONS = %w(top middle bottom).each(&:freeze).freeze
  # We know there can only be at most ten rounds per game.
  ORDINALS = %w(zeroth first second third fourth fifth sixth seventh eighth ninth tenth).freeze

  def self.format_voters(voters, label, &block)
    return "#{label} (0)" if voters.nil? || voters.empty?
    voter_text = block ? voters.map { |v| block.call(v) } : voters
    "#{label} (#{voters.size}): #{voter_text.join(', ')}"
  end

  def initialize(leader = 'the Fascist Leader')
    @leader = leader.freeze
  end

  def public_message(msg)
  end

  def private_message(player, msg)
  end

  def game_started(order)
    public_message("The game has started. Player order is: #{order.join(', ')}")
  end

  def game_ended
    # Overriding implementations may wish to do something like show everyone's role.
  end

  def player_removed_from_game(player)
    # Overriding implementations may wish to do something like release the player.
  end

  def new_round(id, candidates, ineligible)
    eligibility =
      if ineligible.empty?
        'Everybody is eligible'
      elsif ineligible.size == 1
        "#{ineligible.first} is ineligible"
      else
        "#{ineligible.join(' and ')} are ineligible"
      end
    public_message("Announcing the commencement of the #{ORDINALS[id]} government! Your Presidential Candidates are #{candidates.join(', ')}. #{eligibility} to be Chancellor for this government.")
  end

  def new_presidential_candidate(president)
    public_message("#{president} is the new Presidential Candidate. #{president}, please select a Chancellor.")
  end

  def chancellor_chosen(president, chancellor, leader_warning: false, populace_warning: false)
    warnings = [
      ("If this government is rejected, a frustrated populace will take matters into its own hands!" if populace_warning),
      ("If #{chancellor} is #{@leader}, the Fascists will prevail if this government is elected!" if leader_warning),
    ].compact
    warning_text = warnings.empty? ? '' : " Warning: #{warnings.join(' ')}"
    public_message("President #{president} has selected Chancellor #{chancellor}. Please vote on this proposed government.#{warning_text}")
  end

  def votes_in(president, chancellor, votes)
    public_message("The votes are in for President #{president} and Chancellor #{chancellor}!")
    jas = self.class.format_voters(votes[:ja], 'JA')
    neins = self.class.format_voters(votes[:nein], 'NEIN')
    public_message("#{jas}. #{neins}.")
  end

  def policy_reshuffle(policy_size, discard_size)
    reason =
      if policy_size == 0
        'no policies remain'
      elsif policy_size == 1
        'only 1 policy remains'
      else
        "only #{policy_size} policies remain"
      end
    public_message("As #{reason}, we must retrieve #{discard_size} discarded policies and re-enter them into consideration.")
  end

  def liberal_policy_win
    public_message('With five Liberal policies, the Liberals have prevailed!')
    game_ended
  end

  def fascist_policy_win
    public_message('With six Fascist policies, the Fascists have prevailed!')
    game_ended
  end

  def government_rejected
    public_message('The government is rejected!')
  end

  def frustrated_populace(policy)
    public_message("A frustrated populace takes matters into its own hands and enacts a #{policy.capitalize} policy!")
  end

  def government_elected
    public_message('The government is elected! The President and Chancellor are convening in the legislative chamber now. Remember that the sanctity of the legislative session is of the utmost importance.')
  end

  def chancellor_was_leader(chancellor)
    public_message("#{chancellor} was #{@leader}! #{chancellor} takes control of the government, and all hope is lost! The Fascists have prevailed!")
    game_ended
  end

  def chancellor_was_not_leader(chancellor)
    public_message("#{chancellor} was NOT #{@leader}. A sigh of relief is heard throughout.")
  end

  def president_cards(president, cards)
    cards = cards.zip(POSITIONS).map { |c, p| "#{c.capitalize} (#{p})" }
    private_message(president, "For your consideration are the policies #{cards.join(', ')}. Please choose one to discard. The remaining two will be shuffled before presenting them to the Chancellor.")
  end

  def president_discarded(president, discarded, passed, chancellor)
    private_message(president, "You discarded #{discarded.capitalize} and sent #{passed.map(&:capitalize).join(', ')} to Chancellor #{chancellor}.")
    public_message("President #{president} discards one policy and presents two policies to Chancellor #{chancellor}.")
  end

  def chancellor_cards(chancellor, cards, veto_allowed: false)
    message = "For your consideration are the policies #{cards.map(&:capitalize).join(' and ')}. Please choose one to discard and enact the other."
    message << " If neither policy is acceptable, you may veto the policies." if veto_allowed
    private_message(chancellor, message)
  end

  def chancellor_discarded(chancellor, discarded, enacted)
    private_message(chancellor, "You discarded #{discarded.capitalize} and enacted #{enacted.capitalize}.")
    public_message("Chancellor #{chancellor} discards one policy and enacts a #{enacted.capitalize} policy!")
  end

  def veto_unlocked
    public_message('As it is a time of great strife, the Executive branch is granted broader power over which policies are enacted. Veto power is now available!')
  end

  def power_granted(president, power)
    power_info = Game::POWERS[power]
    raise "unknown power #{power}" unless power_info
    public_message("President #{president} has been granted the #{power_info[:name]} power! #{president}, please #{power_info[:description]}.")
  end

  def policy_peek(president, cards)
    cards = cards.zip(POSITIONS).map { |c, p| "#{c.capitalize} (#{p})" }
    private_message(president, "You see that the next three policies will be #{cards.join(', ')}.")
  end

  def investigated(president, target, party)
    private_message(president, "Your investigation has revealed that #{target} is a #{party.capitalize}!")
    private_message(target, "You have been investigated by #{president} who now knows you are a #{party.capitalize}.")
  end

  def special_election_called(president, target)
    public_message("President #{president} has called a special election on #{target}!")
  end

  def non_leader_executed(president, target)
    player_removed_from_game(target)
    public_message("President #{president} has ordered that #{target} be executed! It is discovered that #{target} was NOT #{@leader}. The search continues....")
  end

  def leader_executed(president, target)
    public_message("President #{president} has ordered that #{target} be executed! It is discovered that #{target} was #{@leader}! Without their leader, the Fascists will surely fall into disarray! The Liberals have prevailed!")
    game_ended
  end

  def chancellor_requests_veto(chancellor, president)
    public_message("Chancellor #{chancellor} has declared an intention to veto the presented policies! President #{president}, do you consent to this veto?")
  end

  def president_accepts_veto(president, chancellor)
    public_message("President #{president} agrees to veto the presented policies. Both policies held by Chancellor #{chancellor} are discarded.")
  end

  def president_rejects_veto(president, chancellor)
    public_message("President #{president} does not consent to the veto! Chancellor #{chancellor}, now you must enact one of the two policies presented to you!")
  end
end; end; end
