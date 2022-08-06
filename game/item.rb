class Item
  attr_reader :radius
  attr_accessor :collected

  def initialize(x, z, radius)
    @position = Vector3.create(x, 0, z)
    @radius = radius
    @collected = false
  end

  def overlap?(x, z, radius)
    return Math.sqrt((@position[:x] - x) ** 2 + (@position[:z] - z) ** 2) <= @radius + radius
  end

  def update(dt); end
  def render; end
end

class Orb < Item
  def initialize(x, z, radius)
    super(x, z, radius)
    @color = YELLOW
  end

  def render
    DrawSphere(@position, @radius, @collected ? Fade(@color, 0.25) : @color)
  end
end

class Goal < Item
  attr_accessor :use_fade

  def initialize(x, z, radius)
    super(x, z, radius)
    @color = RED
    @use_fade = false
    @fade_time = 0.0
    @fade = 1.0
  end

  def update(dt)
    @fade = if @use_fade
              @fade_time += dt
              0.5 + 0.5 * Math.cos(180.0 * @fade_time * Math::PI / 180.0).abs
            else
              1.0
            end
  end

  def render
    DrawSphere(@position, @radius, Fade(@color, @fade))
  end
end

