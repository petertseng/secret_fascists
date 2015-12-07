# secret_fascists

This is a Ruby implementation of "Secret Fascists" by Max Temkin.

https://boardgamegeek.com/boardgame/188834/

The astute will note that this is not the actual name of the game.
Fortunately, that does not really matter, as this code only implements the backend of the game.
The frontend may present the game in whatever manner it pleases.
This includes choosing arbitrary names for the name of the game and the eponymous character around which the game revolves.
The eponymous character is referred to internally as `fascist_leader` as the code was designed for genericity and not hard-coded around any one particular Fascist leader.

# Basic Usage

Call `SecretFascists::Game.new(channel_name: String, users: Array[User])` to create a game.
`User` can be any type that is convenient, such as a string or any other form of user identifier.

## Decisions

Any time a decision is required of a player, the game presents a `Game#decision_type -> DecisionType` and `Game#choice_names -> Hash[User => String]` naming the choices each player can take.
Calling `Game#choice_explanations(User) -> Hash[String => Hash]` gives an explanation of each choice for that `User`, where each string is a choice name.
Each inner Hash is of the form: `{description: String?, requires_args: Boolean}`

`DecisionType` is an array where the first element is a symbol indicating what kind of decision it is, and any extra elements are extra information about the symbol.
Possible decision symbols are as follows.
All symbols have no extra elements unless otherwise stated.

* `:pick_chancellor`
* `:vote`: Extra elements indicate the President and Chancellor in that order.
* `:president_cards`
* `:chancellor_cards`
* `:veto`
* `:investigate`
* `:special_election`
* `:execute`

When a player makes a choice, use `Game#take_choice(User, String(choice), *args) -> [Boolean(success), String(error)]`.
If failed, the `error` will describe why.
If successful, the game state will be updated, `error` will be an empty string, and a new decision will be available.

## Subscribing

To receive output events from the game, have an observer subscribe to the game with `Game#subscribe -> SubscriberId`.
Unsubscribe with `Game#unsubscribe(SubscriberId)`.
An example observer is provided in `lib/secret_fascists/observer/console.rb` that simply logs everything to the console.
To implement an observer, either extend the text observer of `lib/secret_fascists/observer/text.rb` (it would be best to just override `private_message` and `public_message` in this case) or create a new observer that has all of the same methods.

## Game end

When the game is won, all three of the following will be true:

* `Game#winning_side -> :fascist|:liberal|nil` returns non-nil.
* `Game#winning_players -> Array[User]?` returns non-nil.
* `Game#decision_type`, `Game#choice_names`, `Game#choice_explanations` all return empty arrays.

If the game is not won, all three of the above are false.
It will never be the case that some of the above three conditions are true while others are false.
This is because it would not be sensible to have half-won games.

# Tests

The automated tests are run with `rspec`.
Running automatically generates a coverage report (made with [simplecov](https://github.com/colszowka/simplecov)).

If a bug is found in the game logic, write a test that fails with the broken logic, then fix the game logic.

If a new feature is added, a test should be added.
Coverage should remain high.
Any added lines that don't have coverage should have a very good reason for not being covered.
