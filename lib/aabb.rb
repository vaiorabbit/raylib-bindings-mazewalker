require_relative 'cell'

class AABB
  attr_reader :min_x, :min_z, :max_x, :max_z, :cell
  def initialize(min_x, min_z, max_x, max_z, cell)
    @min_x = min_x
    @min_z = min_z
    @max_x = max_x
    @max_z = max_z
    @cell = cell
  end
end

class AABBTree
  attr_reader :aabbs

  def initialize
    @aabbs = []
  end

  def add_aabb(min_x, min_z, max_x, max_z, cell)
    @aabbs << AABB.new(min_x, min_z, max_x, max_z, cell)
  end

  def overlap?(position, radius = 0.0, velocity = Vector3.create(0.0, 0.0, 0.0))
    @aabbs.each do |aabb|
      next if aabb.cell.walkable?
      min_x_test = ((aabb.min_x - radius) <= (position[:x] + velocity[:x]))
      min_z_test = ((aabb.min_z - radius) <= (position[:z] + velocity[:z]))
      max_x_test = ((position[:x] + velocity[:x]) <= (aabb.max_x + radius))
      max_z_test = ((position[:z] + velocity[:z]) <= (aabb.max_z + radius))
      if min_x_test && min_z_test && max_x_test && max_z_test
        return true
      end
    end
    return false
  end
end
