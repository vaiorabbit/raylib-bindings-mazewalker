class Cell
  attr_accessor :sym

  WALKABLE = ' '
  OBSTACLE = '#'

  def initialize(sym = ' ')
    @sym = sym
  end

  def obstacle? = @sym == OBSTACLE;
  def walkable? = @sym == WALKABLE;

end
