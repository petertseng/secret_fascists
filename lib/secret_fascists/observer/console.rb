module SecretFascists; module Observer; class Console < Text
  def public_message(msg)
    puts msg
  end

  def private_message(player, msg)
    # Obviously this is not really private if everything is dumped to console.
    # Other descendants of Observer::Text may have something to say about this.
    puts "[PRIVATE #{player}]: #{msg}"
  end
end; end; end
