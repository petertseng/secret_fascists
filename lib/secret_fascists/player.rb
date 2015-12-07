# Represents a player in the game, tracking their role.
# Can be exposed to clients.
# Is read-only unless using the GameEditor refinement.
module SecretFascists; class Player
  attr_reader :user, :role, :investigated
  alias :investigated? :investigated

  def initialize(user)
    @user = user
    @role = nil
    @investigated = false
  end

  def to_s
    @user.respond_to?(:name) ? @user.name : @user
  end
end; end

module SecretFascists; module GameEditor; refine Player do
  attr_writer :user

  def role=(new_role)
    raise "#{self} already has role #{@role}, can't become #{new_role}" if @role
    @role = new_role
  end

  def investigate!
    raise "Can't investigate #{self}, already been investigated" if @investigated
    @investigated = true
    @role == :liberal ? :liberal : :fascist
  end
end; end; end
