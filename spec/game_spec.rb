require 'spec_helper'

require 'secret_fascists/game'
require 'secret_fascists/observer/text'

RSpec.describe SecretFascists::Game do
  RSpec::Matchers.define(:be_successful) { match { |actual| actual == [true, ''] } }
  RSpec::Matchers.define(:be_error) { |expected| match { |actual|
    actual.size == 2 && actual[0] == false && actual[1] =~ expected
  }}

  let(:observer) { instance_double(SecretFascists::Observer::Text) }

  # This is just used to make sure arguments are being passed to observers correctly.
  # Any error will print out a message.
  before(:each) { subject.subscribe(SecretFascists::Observer::Text.new) }

  describe 'fascist_power' do
    # Just to have a subject so before(:each) { subscribe } doesn't break.
    subject { SecretFascists::Game.new('testgame', example_players(5)) }

    def powers(players)
      (1..5).map { |i| SecretFascists::Game.fascist_power(players, i) }
    end

    it 'works for 5 and 6 players' do
      expected = [nil, nil, :policy_peek, :execute, :execute]
      expect(powers(5)).to be == expected
      expect(powers(6)).to be == expected
    end

    it 'works for 7 and 8 players' do
      expected = [nil, :investigate, :special_election, :execute, :execute]
      expect(powers(7)).to be == expected
      expect(powers(8)).to be == expected
    end

    it 'works for 9 and 10 players' do
      expected = [:investigate, :investigate, :special_election, :execute, :execute]
      expect(powers(9)).to be == expected
      expect(powers(10)).to be == expected
    end
  end

  describe 'choice help' do
    subject { SecretFascists::Game.new('testgame', example_players(5)) }

    it 'shows choice type' do
      expect(subject.decision_type).to be == [:pick_chancellor]
    end

    it 'shows choice names' do
      pres = subject.next_presidential_candidate.user
      expect(subject.choice_names).to include(pres)
      expect(subject.choice_names[pres]).to include('chancellor')
    end

    it 'shows choice explanations' do
      pres = subject.next_presidential_candidate.user
      expect(subject.choice_explanations(pres)).to include('chancellor')
    end
  end

  describe '#not_yet_voted' do
    subject { SecretFascists::Game.new('testgame', example_players(5)) }

    it 'shows players yet to vote' do
      pres = subject.next_presidential_candidate.user
      chanc = (subject.users - [pres]).sample
      subject.take_choice(pres, 'chancellor', chanc)
      expect(subject.not_yet_voted.map(&:user)).to match_array(subject.users)
    end

    it 'updates players yet to vote if someone votes' do
      pres = subject.next_presidential_candidate.user
      chanc = (subject.users - [pres]).sample
      subject.take_choice(pres, 'chancellor', chanc)
      subject.take_choice(pres, 'ja')
      expect(subject.not_yet_voted.map(&:user)).to match_array(subject.users - [pres])
    end
  end

  describe '#take_choice' do
    subject { SecretFascists::Game.new('testgame', example_players(5)) }
    it 'rejects invalid choices' do
      pres = subject.next_presidential_candidate.user
      result = subject.take_choice(pres, 'bogus')
      expect(result).to be_error(/not a valid choice/)
    end

    it 'errors if missing chancellor argument' do
      pres = subject.next_presidential_candidate.user
      result = subject.take_choice(pres, 'chancellor')
      expect(result).to be_error(/Please select a player/)
    end

    it 'errors if invalid chancellor argument' do
      pres = subject.next_presidential_candidate.user
      result = subject.take_choice(pres, 'chancellor', 'bogus')
      expect(result).to be_error(/No such player bogus/)
    end
  end

  describe 'subscriptions' do
    subject { SecretFascists::Game.new('testgame', example_players(5)) }

    it 'accepts subscriptions on init' do
      expect(observer).to receive(:game_started)
      expect(observer).to receive(:new_round)
      expect(observer).to receive(:new_presidential_candidate)
      SecretFascists::Game.new('testgame', example_players(5), subscribers: [observer])
    end

    it 'accepts text subscriptions on init' do
      SecretFascists::Game.new('testgame', example_players(5), subscribers: [SecretFascists::Observer::Text.new])
    end

    it 'tolerates subscribers who raise' do
      expect(observer).to receive(:game_started).and_raise(StandardError)
      expect(observer).to receive(:new_round)
      expect(observer).to receive(:new_presidential_candidate)
      SecretFascists::Game.new('testgame', example_players(5), subscribers: [observer])
    end

    it 'accepts subscriptions after init' do
      expect(subject.subscribe(observer)).to_not be_nil
      pres = subject.next_presidential_candidate.user
      chanc = (subject.users - [pres]).sample
      expect(observer).to receive(:chancellor_chosen)
      subject.take_choice(pres, 'chancellor', chanc)
    end

    it 'accepts unsubscriptions' do
      id = subject.subscribe(observer)
      expect(subject.unsubscribe(id)).to_not be_nil
      pres = subject.next_presidential_candidate.user
      chanc = (subject.users - [pres]).sample
      expect(observer).not_to receive(:chancellor_chosen)
      subject.take_choice(pres, 'chancellor', chanc)
    end
  end

  describe '#replace_player' do
    subject { SecretFascists::Game.new('testgame', example_players(5)) }

    it 'replaces a player' do
      result = subject.replace_player('p1', 'p6')
      expect(result).to be == true
      expect(subject.find_player('p1')).to be_nil
      expect(subject.find_player('p6')).to_not be_nil
    end

    it 'rejects replacement of nonexistent players' do
      result = subject.replace_player('p6', 'p7')
      expect(result).to be == false
      expect(subject.find_player('p6')).to be_nil
      expect(subject.find_player('p7')).to be_nil
    end
  end

  context 'basic 5p game' do
    subject { SecretFascists::Game.new('testgame', example_players(5)) }

    it 'runs through an all-no-vote game' do
      # The game ends in at most 10 policies (4 liberal, 5 fascist, one winner).
      # That means we need at most 30 elections
      30.times {
        pres = subject.next_presidential_candidate.user
        chanc = (subject.users - [pres]).sample

        result = subject.take_choice(pres, 'chancellor', chanc)
        expect(result).to be_successful

        subject.users.each { |u|
          result = subject.take_choice(u, 'nein')
          expect(result).to be_successful
        }

        break if subject.winning_party
      }

      expect([:liberal, :fascist]).to include(subject.winning_party)
    end

    it 'initially has no ineligible players' do
      expect(subject.ineligible_players).to be_empty
    end

    it 'forbids previous chancellor' do
      pres = subject.next_presidential_candidate.user
      chanc = subject.users.last

      subject.take_choice(pres, 'chancellor', chanc)
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice(pres, 'discard1')
      subject.take_choice(chanc, 'discard1')

      expect(subject.ineligible_players.map(&:user)).to be == [chanc]

      pres = subject.next_presidential_candidate.user
      result = subject.take_choice(pres, 'chancellor', subject.ineligible_players.first.user)
      expect(result).to be_error(/ineligible this round because of enacting the previous policy/)
    end

    it 'shows leader the Fascists' do
      expect(subject.fascist_leader_sees_fascists?).to be == true
    end

  end

  context 'basic 6p game' do
    subject { SecretFascists::Game.new('testgame', example_players(6)) }

    it 'initially has no ineligible players' do
      expect(subject.ineligible_players).to be_empty
    end

    it 'forbids previous president and chancellor' do
      pres = subject.next_presidential_candidate.user
      chanc = subject.users.last

      subject.take_choice(pres, 'chancellor', chanc)
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice(pres, 'discard1')
      subject.take_choice(chanc, 'discard1')

      expect(subject.ineligible_players.map(&:user)).to match_array([pres, chanc])

      pres = subject.next_presidential_candidate.user
      result = subject.take_choice(pres, 'chancellor', subject.ineligible_players.first.user)
      expect(result).to be_error(/ineligible this round because of enacting the previous policy/)
      result = subject.take_choice(pres, 'chancellor', subject.ineligible_players.last.user)
      expect(result).to be_error(/ineligible this round because of enacting the previous policy/)
    end

    it 'shows leader the Fascists' do
      expect(subject.fascist_leader_sees_fascists?).to be == true
    end
  end

  context 'basic 7p game' do
    subject { SecretFascists::Game.new('testgame', example_players(7)) }

    it 'hides Fascists from leader' do
      expect(subject.fascist_leader_sees_fascists?).to be == false
    end
  end

  shared_examples 'correct shuffling behavior after legislation' do
    it 'reshuffles if necessary' do
      pres = subject.next_presidential_candidate.user
      chanc = (subject.users - subject.ineligible_players.map(&:user) - [pres]).sample

      subject.take_choice(pres, 'chancellor', chanc)
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice(pres, 'discard1')
      subject.take_choice(chanc, 'discard1')
      expect(subject.policy_deck_size).to be == expected_policy_deck_size
      expect(subject.discards_size).to be == expected_discards_size
    end
  end

  context 'when three cards are left in the policy deck after legislation' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 6, rigged_discards: [:fascist] * 11) }

    let(:expected_policy_deck_size) { 3 }
    let(:expected_discards_size) { 13 }

    it_should_behave_like 'correct shuffling behavior after legislation'
  end

  context 'when two cards are left in the policy deck after legislation' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 5, rigged_discards: [:fascist] * 11) }

    let(:expected_policy_deck_size) { 15 }
    let(:expected_discards_size) { 0 }

    it_should_behave_like 'correct shuffling behavior after legislation'
  end

  context 'when one card is left in the policy deck after legislation' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 4, rigged_discards: [:fascist] * 11) }

    let(:expected_policy_deck_size) { 14 }
    let(:expected_discards_size) { 0 }

    it_should_behave_like 'correct shuffling behavior after legislation'
  end

  context 'when policy deck is empty after legislation' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 3, rigged_discards: [:fascist] * 11) }

    let(:expected_policy_deck_size) { 13 }
    let(:expected_discards_size) { 0 }

    it_should_behave_like 'correct shuffling behavior after legislation'
  end

  shared_examples 'correct shuffling behavior after frustrated populace' do
    it 'reshuffles if necessary' do
      3.times { |i|
        pres = subject.next_presidential_candidate.user
        chanc = (subject.users - subject.ineligible_players.map(&:user) - [pres]).sample

        subject.take_choice(pres, 'chancellor', chanc)
        subject.users.each { |u| subject.take_choice(u, 'nein') }
      }

      expect(subject.policy_deck_size).to be == expected_policy_deck_size
      expect(subject.discards_size).to be == expected_discards_size
    end
  end

  context 'when three cards are left in the policy deck is empty after frustrated populace' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 4, rigged_discards: [:fascist] * 11) }

    let(:expected_policy_deck_size) { 3 }
    let(:expected_discards_size) { 11 }

    it_should_behave_like 'correct shuffling behavior after frustrated populace'
  end

  context 'when two cards are left in the policy deck is empty after frustrated populace' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 3, rigged_discards: [:fascist] * 11) }

    let(:expected_policy_deck_size) { 13 }
    let(:expected_discards_size) { 0 }

    it_should_behave_like 'correct shuffling behavior after frustrated populace'
  end

  context 'rigged 5p game for liberals' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:liberal] * 17) }

    it 'runs through an all-yes-vote game' do
      5.times {
        expect(subject.winning_party).to be_nil

        pres = subject.next_presidential_candidate.user
        chanc = (subject.users - subject.ineligible_players.map(&:user) - [pres]).sample

        result = subject.take_choice(pres, 'chancellor', chanc)
        expect(result).to be_successful

        subject.users.each { |u|
          result = subject.take_choice(u, 'ja')
          expect(result).to be_successful
        }

        result = subject.take_choice(pres, 'discard1')
        expect(result).to be_successful

        result = subject.take_choice(chanc, 'discard1')
        expect(result).to be_successful
      }

      expect(subject.winning_party).to be == :liberal
    end

    it 'runs through an all-no-vote game' do
      # 3 rejects per round, 5 rounds to liberal victory
      15.times {
        expect(subject.winning_party).to be_nil

        pres = subject.next_presidential_candidate.user
        chanc = (subject.users - [pres]).sample

        result = subject.take_choice(pres, 'chancellor', chanc)
        expect(result).to be_successful

        subject.users.each { |u|
          result = subject.take_choice(u, 'nein')
          expect(result).to be_successful
        }
      }

      expect(subject.winning_party).to be == :liberal
    end
  end

  context 'rigged 5p game for fascists' do
    subject { SecretFascists::Game.new('testgame', example_players(5), rigged_policy_deck: [:fascist] * 11 + [:liberal] * 6) }

    it 'does policy peek' do
      3.times { |i|
        expect(subject.winning_party).to be_nil

        pres_player = subject.next_presidential_candidate
        pres = pres_player.user
        chanc = (subject.users - subject.ineligible_players.map(&:user) - [pres]).sample

        subject.take_choice(pres, 'chancellor', chanc)
        subject.users.each { |u| subject.take_choice(u, 'ja') }
        subject.take_choice(pres, 'discard1')

        if i == 2
          subject.subscribe(observer)
          expect(observer).to receive(:chancellor_discarded)
          expect(observer).to receive(:power_granted).with(pres_player, :policy_peek)
          # Three election rounds have taken 9 fascist cards off the top.
          # so I should see two fascists then a liberal.
          expect(observer).to receive(:policy_peek).with(pres_player, [:fascist, :fascist, :liberal])
          expect(observer).to receive(:new_round)
          expect(observer).to receive(:new_presidential_candidate)
        end

        subject.take_choice(chanc, 'discard1')
      }

      # policy peek shouldn't change deck size
      expect(subject.policy_deck_size).to be == 8
    end

    it 'runs through an all-no-vote game' do
      # 3 rejects per round, 6 rounds to fascist victory
      18.times {
        expect(subject.winning_party).to be_nil

        pres = subject.next_presidential_candidate.user
        chanc = (subject.users - [pres]).sample

        result = subject.take_choice(pres, 'chancellor', chanc)
        expect(result).to be_successful

        subject.users.each { |u|
          result = subject.take_choice(u, 'nein')
          expect(result).to be_successful
        }
      }

      expect(subject.winning_party).to be == :fascist
    end
  end

  context 'rigged 7p game for fascists' do
    subject { SecretFascists::Game.new('testgame', example_players(7), rigged_policy_deck: [:fascist] * 17) }
    let(:fascist_leader) { subject.fascist_leader.user }

    # We need 7p for an all-yes-vote game because a 5p game might be forced to pick the leader as chancellor:
    # Two players get killed, so just A B and C are left. A is president, B is leader, C was last president.
    # A has to pick B as chancellor.
    # A 6p game has the same problem because two players become ineligible.
    it 'runs through an all-yes-vote game' do
      6.times { |i|
        expect(subject.winning_party).to be_nil

        pres = subject.next_presidential_candidate.user
        # Don't elect the leader as that would result in a game that ends early.
        chanc = (subject.users - subject.ineligible_players.map(&:user) - [pres, fascist_leader]).sample

        result = subject.take_choice(pres, 'chancellor', chanc)
        expect(result).to be_successful

        subject.users.each { |u|
          result = subject.take_choice(u, 'ja')
          expect(result).to be_successful
        }

        result = subject.take_choice(pres, 'discard1')
        expect(result).to be_successful

        result = subject.take_choice(chanc, 'discard1')
        expect(result).to be_successful

        power = [nil, 'inspect', 'president', 'kill', 'kill'][i]
        if power
          # Just use the power on the Chancellor
          result = subject.take_choice(pres, power, chanc)
          expect(result).to be_successful
        end
      }

      expect(subject.winning_party).to be == :fascist
    end
  end

  describe 'investigate' do
    subject { SecretFascists::Game.new(
      'testgame',
      example_players(9),
      shuffle_players: false,
      rigged_roles: [:liberal, :liberal, :fascist_leader, :liberal, :fascist, :liberal, :fascist, :liberal, :fascist],
      rigged_policy_deck: [:fascist] * 17
    )}

    before(:each) do
      pres = 'p1'
      chanc = 'p2'
      subject.take_choice(pres, 'chancellor', chanc)
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice(pres, 'discard1')
      subject.take_choice(chanc, 'discard1')
    end

    it 'inspects Fascist leader as Fascist' do
      subject.subscribe(observer)
      expect(observer).to receive(:investigated).with(anything, anything, :fascist)
      expect(observer).to receive(:new_round)
      expect(observer).to receive(:new_presidential_candidate)

      subject.take_choice('p1', 'inspect', 'p3')
    end

    it 'inspects Fascist member as Fascist' do
      subject.subscribe(observer)
      expect(observer).to receive(:investigated).with(anything, anything, :fascist)
      expect(observer).to receive(:new_round)
      expect(observer).to receive(:new_presidential_candidate)

      subject.take_choice('p1', 'inspect', 'p5')
    end

    it 'inspects Liberal member as Liberal' do
      subject.subscribe(observer)
      expect(observer).to receive(:investigated).with(anything, anything, :liberal)
      expect(observer).to receive(:new_round)
      expect(observer).to receive(:new_presidential_candidate)

      subject.take_choice('p1', 'inspect', 'p4')
    end

    context 'with a player already investigated' do
      before(:each) do
        subject.take_choice('p1', 'inspect', 'p3')
        pres = 'p2'
        chanc = 'p4'
        subject.take_choice(pres, 'chancellor', chanc)
        subject.users.each { |u| subject.take_choice(u, 'ja') }
        subject.take_choice(pres, 'discard1')
        subject.take_choice(chanc, 'discard1')
      end

      it 'forbids repeat investigation' do
        result = subject.take_choice('p2', 'inspect', 'p3')
        expect(result).to be_error(/p3 has already been investigated/)
      end

      it 'allows different investigation' do
        result = subject.take_choice('p2', 'inspect', 'p4')
        expect(result).to be_successful
      end
    end
  end

  describe 'special elections' do
    subject { SecretFascists::Game.new(
      'testgame',
      example_players(7),
      # So that it's easier to keep track of who's who in order
      shuffle_players: false,
      # So that we don't elect or kill the fascist leader
      rigged_roles: [:liberal, :liberal, :fascist, :liberal, :fascist_leader],
      # To ensure that fascist policy is enacted to trigger the election
      rigged_policy_deck: [:fascist] * 15,
      fascist_policies_enacted: 2
    )}

    it 'inserts target next in line' do
      subject.take_choice('p1', 'chancellor', 'p2')
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice('p1', 'discard1')
      subject.take_choice('p2', 'discard1')

      subject.subscribe(observer)
      expect(observer).to receive(:special_election_called)
      expect(observer).to receive(:new_round) { |_id, candidates, _ineligible|
        expect(candidates.map(&:user)).to be == %w(p2 p2 p3)
      }
      expect(observer).to receive(:new_presidential_candidate) { |u|
        expect(u.user).to be == 'p2'
      }

      result = subject.take_choice('p1', 'president', 'p2')
      expect(result).to be_successful
    end

    shared_examples 'a return to the normal order' do
      it 'restores normal order after election' do
        subject.take_choice('p1', 'chancellor', 'p2')
        subject.users.each { |u| subject.take_choice(u, 'ja') }
        subject.take_choice('p1', 'discard1')
        subject.take_choice('p2', 'discard1')

        subject.take_choice('p1', 'president', special_candidate)
        subject.take_choice(special_candidate, 'chancellor', 'p3')

        subject.users.each { |u| subject.take_choice(u, 'ja') }
        subject.take_choice(special_candidate, 'discard1')
        subject.take_choice('p3', 'discard1')

        subject.subscribe(observer)
        expect(observer).to receive(:non_leader_executed)
        expect(observer).to receive(:new_round)
        expect(observer).to receive(:new_presidential_candidate) { |u|
          expect(u.user).to be == 'p2'
        }

        subject.take_choice(special_candidate, 'kill', 'p3')
      end

      it 'restores normal order after reject' do
        subject.take_choice('p1', 'chancellor', 'p2')
        subject.users.each { |u| subject.take_choice(u, 'ja') }
        subject.take_choice('p1', 'discard1')
        subject.take_choice('p2', 'discard1')

        subject.take_choice('p1', 'president', special_candidate)
        subject.take_choice(special_candidate, 'chancellor', 'p3')

        subject.subscribe(observer)
        expect(observer).to receive(:votes_in)
        expect(observer).to receive(:government_rejected)
        expect(observer).to receive(:new_presidential_candidate) { |u|
          expect(u.user).to be == 'p2'
        }

        subject.users.each { |u| subject.take_choice(u, 'nein') }
      end
    end

    context 'when special candidate was already next in line' do
      let(:special_candidate) { 'p2' }

      it_should_behave_like 'a return to the normal order'
    end

    context 'when special candidate was not next in line' do
      let(:special_candidate) { 'p5' }

      it_should_behave_like 'a return to the normal order'
    end
  end

  context 'with three fascist policies already enacted' do
    # Ensure non-leader is chancellor.
    subject { SecretFascists::Game.new(
      'testgame',
      example_players(5),
      rigged_roles: [:liberal, :fascist_leader, :fascist, :liberal, :liberal],
      shuffle_players: false,
      fascist_policies_enacted: 3
    )}

    it 'causes fascist victory if fascist leader is elected' do
      expect(subject.winning_party).to be_nil

      subject.take_choice('p1', 'chancellor', 'p2')
      subject.users.each { |u| subject.take_choice(u, 'ja') }

      expect(subject.winning_party).to be == :fascist
    end
  end

  context 'with five fascist policies already enacted' do
    # Ensure non-leader is chancellor.
    subject { SecretFascists::Game.new(
      'testgame',
      example_players(5),
      rigged_roles: [:liberal, :fascist_leader, :fascist, :liberal, :liberal],
      shuffle_players: false,
      fascist_policies_enacted: 5
    )}

    it 'allows veto' do
      expect(subject.winning_party).to be_nil

      subject.take_choice('p1', 'chancellor', 'p3')
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice('p1', 'discard1')

      expect(subject.choice_names['p3']).to match_array(%w(discard1 discard2 veto))
    end

    it 'allows president to accept or reject' do
      expect(subject.winning_party).to be_nil

      subject.take_choice('p1', 'chancellor', 'p3')
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice('p1', 'discard1')
      subject.take_choice('p3', 'veto')

      expect(subject.choice_names['p1']).to match_array(%w(accept reject))
    end

    it 'moves on if president accepts' do
      expect(subject.winning_party).to be_nil

      subject.take_choice('p1', 'chancellor', 'p3')
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice('p1', 'discard1')
      subject.take_choice('p3', 'veto')
      expect { subject.take_choice('p1', 'accept') }.to change { subject.discards_size }.by(2)

      expect(subject.choice_names['p2']).to include('chancellor')
    end

    it 'triggers frustrated populace if president accepts thrice' do
      expect(subject.winning_party).to be_nil

      3.times { |i|
        pres = subject.next_presidential_candidate.user

        subject.take_choice(pres, 'chancellor', 'p5')
        subject.users.each { |u| subject.take_choice(u, 'ja') }
        subject.take_choice(pres, 'discard1')
        subject.take_choice('p5', 'veto')

        if i == 2
          subject.subscribe(observer)
          expect(observer).to receive(:president_accepts_veto)
          expect(observer).to receive(:frustrated_populace)
          # new round if liberal, fascist win if fascist
          allow(observer).to receive(:new_round)
          allow(observer).to receive(:new_presidential_candidate)
          allow(observer).to receive(:fascist_policy_win)
        end

        subject.take_choice(pres, 'accept')
      }
    end

    it 'forces policy if president rejects' do
      expect(subject.winning_party).to be_nil

      subject.take_choice('p1', 'chancellor', 'p3')
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice('p1', 'discard1')
      subject.take_choice('p3', 'veto')
      subject.take_choice('p1', 'reject')

      expect(subject.choice_names['p3']).to match_array(%w(discard1 discard2))
    end
  end

  context 'executing fascist leader' do
    # Ensure non-leader is president (can't kill self) and chancellor.
    subject { SecretFascists::Game.new(
      'testgame',
      example_players(5),
      rigged_roles: [:liberal, :fascist_leader, :fascist, :liberal, :liberal],
      rigged_policy_deck: [:fascist] * 13,
      shuffle_players: false,
      fascist_policies_enacted: 4
    )}

    it 'causes liberal victory' do
      expect(subject.winning_party).to be_nil

      subject.take_choice('p1', 'chancellor', 'p3')
      subject.users.each { |u| subject.take_choice(u, 'ja') }
      subject.take_choice('p1', 'discard1')
      subject.take_choice('p3', 'discard1')

      result = subject.take_choice('p1', 'kill', 'p2')
      expect(result).to be_successful

      expect(subject.winning_party).to be == :liberal
    end
  end
end
