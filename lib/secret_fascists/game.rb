require 'secret_fascists/choice'
require 'secret_fascists/decision'
require 'secret_fascists/election'
require 'secret_fascists/legislature'
require 'secret_fascists/player'
require 'secret_fascists/round'

module SecretFascists; class Game
  using GameEditor

  GAME_NAME = 'Secret Fascists'.freeze
  MIN_PLAYERS = 5
  MAX_PLAYERS = 10

  INITIAL_POLICY_DECK = ([:fascist] * 11 + [:liberal] * 6).freeze
  ELECTION_CHANCES = 3
  POLICY_CHOICES = 3
  FASCIST_LEADER_THREAT = 3
  FASCIST_POLICIES_TO_VETO = 5
  FASCIST_POLICIES_TO_WIN = 6
  LIBERAL_POLICIES_TO_WIN = 5

  attr_reader :id, :channel_name, :original_size
  attr_reader :liberal_policies, :fascist_policies
  attr_reader :winning_party, :winning_players

  class << self
    attr_accessor :games_created
  end

  def self.fascist_power(original_size, fascist_policies)
    if [4, 5].include?(fascist_policies)
      return :execute
    elsif fascist_policies == 3
      return original_size >= 7 ? :special_election : :policy_peek
    elsif fascist_policies == 2 && original_size >= 7
      return :investigate
    elsif fascist_policies == 1 && original_size >= 9
      return :investigate
    end
  end

  POWERS = {
    policy_peek: {
      name: 'Policy Peek',
      description: 'look at the next three upcoming policies',
    },
    special_election: {
      name: 'Call Special Election',
      description: 'choose someone to become candidate in a Special Election',
      verbs: %w(president elect),
    },
    investigate: {
      name: 'Investigate Loyalty',
      description: 'choose someone whose party affiliation you wish to Investigate',
      verbs: %w(see inspect investigate),
    },
    execute: {
      name: 'Execution',
      description: 'choose someone whom you wish to Execute',
      verbs: %w(execute kill),
    },
  }.freeze
  POWERS.values.each { |v|
    v.freeze
    v.values.each(&:freeze)
  }

  @games_created = 0

  def initialize(
    channel_name, users,
    # You can pass in subscribers here,
    # but there won't be an easy way to unsubscribe them unless you guess their ID.
    subscribers: [],
    # for testing
    fascist_policies_enacted: 0,
    liberal_policies_enacted: 0,
    shuffle_players: true,
    rigged_policy_deck: nil,
    rigged_discards: nil,
    rigged_roles: nil
  )
    self.class.games_created += 1
    @id = self.class.games_created

    @channel_name = channel_name

    @current_decision = nil

    @rounds = []
    @policy_deck = rigged_policy_deck ? rigged_policy_deck.reverse : INITIAL_POLICY_DECK.shuffle
    @discards = rigged_discards || []
    @fascist_policies = fascist_policies_enacted
    @liberal_policies = liberal_policies_enacted

    @next_subscriber_id = 0
    @subscribers = {}
    subscribers.each { |s| subscribe(s) }

    @players = users.map { |u| Player.new(u) }
    @players.shuffle! if shuffle_players

    @dead_players = []
    @original_players = @players.dup
    @original_size = users.size

    @special_election = false

    @winning_party = nil
    @winning_players = nil

    # Assign roles
    if rigged_roles
      roles = rigged_roles
    else
      fascists = (@original_size - 3) / 2
      liberals = @original_size - fascists - 1
      roles = [:fascist] * fascists + [:liberal] * liberals + [:fascist_leader]
      roles.shuffle!
    end
    @players.zip(roles) { |p, r| p.role = r }

    each_subscriber { |s| s.game_started(@players.dup) }

    new_round
  end

  #----------------------------------------------
  # Required methods for player management
  #----------------------------------------------

  def users
    @players.map(&:user)
  end

  def replace_player(replaced, replacing)
    player = find_player(replaced)
    return false unless player
    player.user = replacing
    true
  end

  #----------------------------------------------
  # Please use externally sparingly.
  #----------------------------------------------

  def find_player(user)
    @players.find { |p| p.user == user }
  end

  #----------------------------------------------
  # Subscriptions
  #----------------------------------------------

  def subscribe(subscriber)
    @next_subscriber_id += 1
    id = @next_subscriber_id
    @subscribers[id] = subscriber
    id
  end

  def unsubscribe(id)
    @subscribers.delete(id)
  end

  #----------------------------------------------
  # Game state getters
  #----------------------------------------------

  def decision_type
    @current_decision ? @current_decision.type : []
  end

  def choice_names
    @current_decision ? @current_decision.choice_names : []
  end

  def choice_explanations(user)
    return [] unless @current_decision
    player = find_player(user)
    return [] unless player
    @current_decision.choice_explanations(player)
  end

  def rounds
    @rounds.dup
  end

  def liberals
    @original_players.select { |p| p.role == :liberal }
  end

  def fascists
    @original_players.select { |p| p.role == :fascist }
  end

  def fascist_leader
    @original_players.find { |p| p.role == :fascist_leader }
  end

  def fascists_and_leader
    fascists + [fascist_leader]
  end

  def policy_deck_size
    @policy_deck.size
  end

  def discards_size
    @discards.size
  end

  def ineligible_players
    return [] if @rounds.size <= 1
    last_round = @rounds[-2]
    return [] if last_round.populace_enacted
    last_legislature = last_round.last_legislature

    return [last_legislature.chancellor] if only_chancellor_ineligible?
    [last_legislature.president, last_legislature.chancellor]
  end

  def only_chancellor_ineligible?
    # TODO: Unconfirmed whether this is original size or current size.
    @original_size == 5
  end

  def fascist_leader_sees_fascists?
    @original_size <= 6
  end

  def veto_enabled?
    @fascist_policies >= FASCIST_POLICIES_TO_VETO
  end

  def current_round
    @rounds.last
  end

  def current_election
    current_round && current_round.current_election
  end

  def not_yet_voted
    election = current_election
    election && election.not_yet_voted
  end

  def next_presidential_candidate
    current_round && current_round.next_presidential_candidate
  end

  #----------------------------------------------
  # Game state changers
  #----------------------------------------------

  def take_choice(user, choice, *args)
    player = find_player(user)
    return [false, "#{user} is not in the game"] unless player
    return [false, 'No decision to make'] unless @current_decision
    @current_decision.take_choice(player, choice, args)
  end

  private

  def each_subscriber
    @subscribers.each { |id, s|
      begin
        yield s
      rescue => e
        $stderr.puts("When sending to subscriber #{id}: #{e}")
      end
    }
  end

  def new_round(special_candidate: nil)
    round_id = @rounds.size + 1
    candidates = special_candidate ? [special_candidate] + @players.take(ELECTION_CHANCES - 1) : @players.take(ELECTION_CHANCES)
    @rounds << Round.new(round_id, candidates)

    each_subscriber { |s| s.new_round(round_id, candidates, ineligible_players) }

    new_presidential_candidate
  end

  def new_presidential_candidate
    president = next_presidential_candidate
    each_subscriber { |s| s.new_presidential_candidate(president) }

    @current_decision = Decision.single_player_single(
      [:pick_chancellor],
      president,
      %w(nominate chancellor),
      Choice.new { |args| chancellor_chosen(president, args) }
    )
  end

  def complete_election(election)
    @players.rotate! unless @special_election
    @special_election = false

    votes = election.votes
    each_subscriber { |s| s.votes_in(election.president, election.chancellor, votes) }

    jas = (votes[:ja] || []).size
    neins = (votes[:nein] || []).size

    if jas > neins
      government_elected(election)
    else
      each_subscriber(&:government_rejected)
      next_president_or_frustration
    end
  end

  def government_elected(election)
    each_subscriber(&:government_elected)

    if @fascist_policies >= FASCIST_LEADER_THREAT
      if election.chancellor.role == :fascist_leader
        fascists_win
        each_subscriber { |s| s.chancellor_was_leader(election.chancellor) }
        return
      else
        each_subscriber { |s| s.chancellor_was_not_leader(election.chancellor) }
      end
    end

    drawn_cards = @policy_deck.pop(POLICY_CHOICES).reverse
    legislature = Legislature.new(
      current_round.id, election.id,
      election.president, election.chancellor,
      drawn_cards,
      veto_enabled: veto_enabled?
    )
    election.legislature = legislature
    each_subscriber { |s| s.president_cards(election.president, drawn_cards) }
    @current_decision = Decision.single_player(
      [:president_cards],
      election.president,
      legislature.current_cards.each_with_index.map { |card, i|
        ["discard#{i + 1}", Choice.new("Discard #{card.capitalize}, passing #{legislature.cards_without_index(i).map(&:capitalize).join(', ')}") {
          president_discards(election.president, legislature, i)
        }]
      }.to_h
    )
  end

  def next_president_or_frustration
    if current_round.size >= ELECTION_CHANCES
      frustrated_populace
    else
      new_presidential_candidate
    end
  end

  def frustrated_populace
    policy = @policy_deck.pop
    current_round.populace_enacted = policy
    each_subscriber { |s| s.frustrated_populace(policy) }
    increment_policy(policy)
    return if @winning_party
    check_policy_reshuffle
    new_round
  end

  def increment_policy(policy)
    case policy
    when :liberal
      @liberal_policies += 1
      if @liberal_policies >= LIBERAL_POLICIES_TO_WIN
        liberals_win
        each_subscriber(&:liberal_policy_win)
      end
    when :fascist
      @fascist_policies += 1
      if @fascist_policies >= FASCIST_POLICIES_TO_WIN
        fascists_win
        each_subscriber(&:fascist_policy_win)
      end
    else raise "Unknown policy #{policy}"
    end
  end

  def check_policy_reshuffle
    return unless @policy_deck.size < POLICY_CHOICES
    each_subscriber { |s| s.policy_reshuffle(@policy_deck.size, @discards.size) }
    @policy_deck += @discards
    @policy_deck.shuffle!
    @discards.clear
  end

  def grant_power(president, power)
    power_info = POWERS[power]
    raise "Unknown power #{power}" unless power_info

    each_subscriber { |s| s.power_granted(president, power) }

    # Policy peek requires no input from president.
    if power == :policy_peek
      drawn_cards = @policy_deck.last(POLICY_CHOICES).reverse
      each_subscriber { |s| s.policy_peek(president, drawn_cards) }
      new_round
      return
    end

    @current_decision = Decision.single_player_single(
      [power],
      president,
      power_info[:verbs],
      Choice.new { |args| invoke_power(president, power, args) }
    )
  end

  def liberals_win
    @winning_party = :liberal
    @winning_players = liberals.freeze
    @current_decision = nil
  end

  def fascists_win
    @winning_party = :fascist
    @winning_players = fascists_and_leader.freeze
    @current_decision = nil
  end

  #----------------------------------------------
  # Decision makers
  #----------------------------------------------

  def chancellor_decision(legislature, veto_allowed:)
    options = legislature.current_cards.each_with_index.map { |card, i|
      ["discard#{i + 1}", Choice.new("Discard #{card.capitalize}, enacting #{legislature.cards_without_index(i).map(&:capitalize).join(', ')}") {
        chancellor_discards(legislature.chancellor, legislature, i)
      }]
    }.to_h

    options['veto'] = Choice.new('Propose Veto') {
      legislature.chancellor_requests_veto
      each_subscriber { |s| s.chancellor_requests_veto(legislature.chancellor, legislature.president) }
      # I could have inlined this, but maybe creating a Choice in a Choice is confusing.
      @current_decision = president_veto_decision(legislature)
    } if veto_allowed

    Decision.single_player([:chancellor_cards, veto_allowed], legislature.chancellor, options)
  end

  def president_veto_decision(legislature)
    president = legislature.president
    chancellor = legislature.chancellor

    @current_decision = Decision.single_player([:veto], president, {
      'accept' => Choice.new('Accept Veto (Policies discarded)') {
        @discards.concat(legislature.current_cards)
        legislature.president_accepts_veto
        each_subscriber { |s| s.president_accepts_veto(president, chancellor) }
        next_president_or_frustration
      },
      'reject' => Choice.new('Reject Veto (Chancellor must enact policy)') {
        legislature.president_rejects_veto
        each_subscriber { |s| s.president_rejects_veto(president, chancellor) }
        @current_decision = chancellor_decision(legislature, veto_allowed: false)
      }
    })
  end

  #----------------------------------------------
  # Callbacks
  #----------------------------------------------

  def chancellor_chosen(president, args)
    return [false, 'Please select a player'] if args.empty?
    chancellor = find_player(args.first)
    return [false, "No such player #{args.first}"] unless chancellor
    return [false, 'You must pick a player other than yourself'] if chancellor == president
    return [false, "#{chancellor} is ineligible this round because of enacting the previous policy"] if ineligible_players.include?(chancellor)

    election = Election.new(current_round.id, current_round.size + 1, president, chancellor, @players)
    current_round << election
    each_subscriber { |s| s.chancellor_chosen(
      president, chancellor,
      leader_warning: @fascist_policies >= FASCIST_LEADER_THREAT,
      populace_warning: current_round.size >= ELECTION_CHANCES,
    )}

    @current_decision = Decision.new([:vote, president, chancellor], @players.map { |p| [p, {
      'ja' => Choice.new {
        election.vote_ja(p)
        complete_election(election) if election.voting_complete?
        [true, '']
      },
      'nein' => Choice.new {
        election.vote_nein(p)
        complete_election(election) if election.voting_complete?
        [true, '']
      },
    }]}.to_h)

    [true, '']
  end

  def president_discards(president, legislature, index)
    discarded = legislature.president_discards(index)
    @discards << discarded

    each_subscriber { |s| s.president_discarded(president, discarded, legislature.current_cards, legislature.chancellor) }

    # TODO: Not certain that these are shuffled (though seems like they would be)
    legislature.current_cards.shuffle!

    each_subscriber { |s| s.chancellor_cards(legislature.chancellor, legislature.current_cards, veto_allowed: veto_enabled?) }

    @current_decision = chancellor_decision(legislature, veto_allowed: veto_enabled?)
    [true, '']
  end

  def chancellor_discards(chancellor, legislature, index)
    discarded, enacted = legislature.chancellor_discards(index)
    @discards << discarded

    each_subscriber { |s| s.chancellor_discarded(chancellor, discarded, enacted) }

    increment_policy(enacted)
    return [true, ''] if @winning_party
    check_policy_reshuffle

    if enacted == :fascist
      each_subscriber(&:veto_unlocked) if @fascist_policies == FASCIST_POLICIES_TO_VETO
      if (power = self.class.fascist_power(@original_size, @fascist_policies))
        grant_power(legislature.president, power)
      else
        new_round
      end
    else
      new_round
    end
    [true, '']
  end

  def invoke_power(president, power, args)
    return [false, 'Please select a player'] if args.empty?
    target = find_player(args.first)
    return [false, "No such player #{args.first}"] unless target
    return [false, 'You must pick a player other than yourself'] if target == president

    case power
    when :investigate
      return [false, "#{target} has already been investigated"] if target.investigated?
      party = target.investigate!
      each_subscriber { |s| s.investigated(president, target, party) }
    when :special_election
      @special_election = true
      each_subscriber { |s| s.special_election_called(president, target) }
      new_round(special_candidate: target)
      return [true, '']
    when :execute
      if target.role == :fascist_leader
        each_subscriber { |s| s.leader_executed(president, target) }
        liberals_win
        return [true, '']
      else
        each_subscriber { |s| s.non_leader_executed(president, target) }
        @players.delete(target)
      end
    else raise "unknown power #{power} used by #{president} on #{target}"
    end

    new_round
    [true, '']
  end
end; end
