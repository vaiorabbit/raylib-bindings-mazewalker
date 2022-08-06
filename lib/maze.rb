# Ref.: Maze Generation: Recursive Backtracking
# http://weblog.jamisbuck.org/2010/12/27/maze-generation-recursive-backtracking

require_relative 'cell'

class Maze

  N, E, S, W = 1, 2, 4, 8
  DIR = { N => [0, -1], E => [1, 0], S => [0, 1], W => [-1, 0] }
  REV = { N => S, E => W, S => N, W => E }

  attr_reader :w, :h, :grid_map_w, :grid_map_h, :grid_map
  attr_accessor :seed

  def initialize(w = 10, h = 10)
    @w = w
    @h = h
    @grid_map_w = 2 * @w + 1
    @grid_map_h = 2 * @h + 1
    @seed = 12345
    reset
  end

  def reset
    @walkable_map = Array.new(@h) { Array.new(@w, 0x00) }
    @grid_map = Array.new(@grid_map_h) { Array.new(@grid_map_w) { Cell.new('#') } }
  end

  def generate()
    @rng = Random.new(@seed)
    dig(0, 0)
    build_grid_map()
  end

  def dump
    @grid_map.length.times do |y|
      @grid_map[0].length.times do |x|
        print @grid_map[y][x].sym
      end
      puts
    end
  end

  def get_node(w, h)
    if w.between?(0, @grid_map_w) && h.between?(0, @grid_map_h)
      @grid_map[h][w]
    else
      nil
    end
  end

  def position_to_wh(pos_x, pos_z, size_w, size_h)
    grid_w = @grid_map_w * size_w
    grid_h = @grid_map_h * size_h
    w = if pos_x.between?(0, grid_w)
          pos_x.div(size_w).to_i
        else
          -1
        end
    h = if pos_z.between?(0, grid_h)
          pos_z.div(size_h).to_i
        else
          -1
        end

    return w, h
  end

  def wh_to_id(w, h)
    unless w.between?(0, @grid_map_w)
      return -1
    end
    unless h.between?(0, @grid_map_h)
      return -1
    end
    return @grid_map_w * h + w
  end

  def position_to_id(pos_x, pos_z, size_w, size_h)
    wh_to_id(*position_to_wh(pos_x, pos_z, size_w, size_h))
  end

  private

  def dig(x, y)
    dir = [N, E, S, W].shuffle(random: @rng)
    dir.each do |d|
      nx, ny = x + DIR[d][0], y + DIR[d][1]
      if (0 <= nx && nx < @w) && (0 <= ny && ny < @h) && @walkable_map[ny][nx] == 0x00
        @walkable_map[y][x] |= d
        @walkable_map[ny][nx] |= REV[d]
        dig(nx, ny)
      end
    end
  end

  WallInfo = Struct.new(:e, :s, keyword_init: true)

  def build_grid_map()
    wall_map = Array.new(@h) { Array.new(@w) { WallInfo.new(e: false, s: false) } }

    @h.times do |y|
      @w.times do |x|
        wall_map[y][x].s = (@walkable_map[y][x] & S != 0)
        wall_map[y][x].e = (@walkable_map[y][x] & E != 0)
      end
    end

    @h.times do |y|
      @w.times do |x|
        wall = wall_map[y][x]
        @grid_map[(2 * y) + 1][(2 * x) + 1].sym = Cell::WALKABLE
        @grid_map[(2 * y) + 1][(2 * x + 1) + 1].sym = wall.e ? Cell::WALKABLE : Cell::OBSTACLE
        @grid_map[(2 * y + 1) + 1][(2 * x) + 1].sym = wall.s ? Cell::WALKABLE : Cell::OBSTACLE
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  maze = Maze.new(ARGV[0].nil? ? 10 : ARGV[0].to_i, ARGV[1].nil? ? 10 : ARGV[1].to_i)
  maze.seed = ARGV[2].nil? ? 12345 : ARGV[2].to_i
  maze.generate()
  maze.dump
end
