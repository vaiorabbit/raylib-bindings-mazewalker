require_relative 'util/setup_dll'
require_relative 'lib/aabb'
require_relative 'lib/cell'
require_relative 'lib/maze'
require_relative 'lib/pathfinding'
require_relative 'game/item'

class Application

  STATE_READY = 0
  STATE_PLAYING = 1
  STATE_SUCCEEDED = 2
  STATE_FAILED = 3

  def initialize(maze_width: 5, maze_height: 5, maze_seed: 12345)
    reset(maze_width: maze_width, maze_height: maze_height, maze_seed: maze_seed)
  end

  def reset(maze_width:, maze_height:, maze_seed:)
    @block_w = 1.0
    @block_h = 1.0

    @maze = Maze.new(maze_width, maze_height)
    @maze.seed = maze_seed

    @orb_positions = [Vector3.create(@maze.grid_map_w * @block_w - @block_w * 2.0, 0.0, @block_h * 1.0), # Upper right
                      Vector3.create(@block_w * 1.0, 0.0, @maze.grid_map_h * @block_h - @block_h * 2.0), # Bottom left
                      Vector3.create(@maze.grid_map_w / 2 * @block_w - @block_w * (@maze.w.even? ? 1.0 : 0.0), 0.0, @maze.grid_map_h / 2 * @block_h - @block_h * (@maze.h.even? ? 1.0 : 0.0))] # Center
    @goal_position = Vector3.create(@maze.grid_map_w * @block_w - @block_w * 2.0, 0.0, @maze.grid_map_h * @block_h - @block_h * 2.0) # Bottom left

    @item_radius = 0.2

    @orbs = [Orb.new(@orb_positions[0][:x], @orb_positions[0][:z], @item_radius),
             Orb.new(@orb_positions[1][:x], @orb_positions[1][:z], @item_radius),
             Orb.new(@orb_positions[2][:x], @orb_positions[2][:z], @item_radius)]
    @collected_orbs = 0

    @goal = Goal.new(@goal_position[:x], @goal_position[:z], @item_radius)

    @items = [*@orbs, @goal]

    until try_generate() == true
      @maze.reset
      @maze.seed += 1
    end

    @pathfinder = DijkstraAlgorithm.new

    @maze.grid_map_h.times do |h|
      @maze.grid_map_w.times do |w|
        grid = @maze.grid_map[h][w]
        next if grid.obstacle?

        node_id_current = @maze.wh_to_id(w, h)
        @pathfinder.add_node(node_id_current, @block_positions[h][w])

        grid_e = @maze.get_node(w + 1, h)
        node_id_e = if grid_e.nil? || grid_e.obstacle?
                      -1
                    else
                      @maze.wh_to_id(w + 1, h)
                    end

        grid_s = @maze.get_node(w, h + 1)
        node_id_s = if grid_s.nil? || grid_s.obstacle?
                      -1
                    else
                      @maze.wh_to_id(w, h + 1)
                    end

        if node_id_e >= 0
          @pathfinder.add_edge(@block_w, node_id_current, node_id_e)
        end
        if node_id_s >= 0
          @pathfinder.add_edge(@block_h, node_id_current, node_id_s)
        end
      end
    end

    @pathfinder.setup_graph

    @game_state = STATE_READY

    @player_radius = 0.025

    @minimap_camera = Camera.new
    @minimap_camera[:position] = Vector3.create(@maze.grid_map_w * @block_w * 0.5, 10.0, @maze.grid_map_h * @block_h * 0.5)
    @minimap_camera[:target] = Vector3.create(@maze.grid_map_w * @block_w * 0.5, 0.0, @maze.grid_map_h * @block_h * 0.5)
    @minimap_camera[:up] = Vector3.create(0.0, 0.0, -1.0)
    @minimap_camera[:fovy] = 15.0
    @minimap_camera[:projection] = CAMERA_ORTHOGRAPHIC

    @player_camera = Camera.new
    @player_camera[:position] = Vector3.create(1.0 * @block_w + @player_radius, 0.0, 1.0 * @block_h + @player_radius)
    @player_camera[:target] = Vector3.create(1.5 * @block_w, 0.0, 1.5 * @block_h)
    @player_camera[:up] = Vector3.create(0.0, 1.0, 0.0)
    @player_camera[:fovy] = 80.0
    @player_camera[:projection] = CAMERA_PERSPECTIVE

    @minimap_mode = false

    @velocity = Vector3.create(0, 0, 0)
    @forward = Vector3Normalize(Vector3Subtract(@player_camera[:target], @player_camera[:position]))
    @right = Vector3Normalize(Vector3CrossProduct(@forward, @player_camera[:up]))

    @time = 3.0
    @delta_time = 0.0
    @clear_time = 0.0

    # pathfinding test
    grid_id_start = @maze.position_to_id(@player_camera[:position][:x], @player_camera[:position][:z], @block_w, @block_h)
    grid_id_goal = @maze.position_to_id(@goal_position[:x], @goal_position[:z], @block_w, @block_h)
    @pathfinder.reset(grid_id_start, grid_id_goal)
    @pathfinder.search
    if @pathfinder.found
      @pathfinder.get_path.each do |grid_id|
        print grid_id
        print grid_id == @pathfinder.goal_id ? "\n" : " -> "
      end
    end

  end

  def update
    @delta_time = GetFrameTime()

    case @game_state

    when STATE_READY
      @time -= @delta_time
      if @time < 0
        @time = 60.0
        @game_state = STATE_PLAYING
      end

    when STATE_PLAYING
      @time -= @delta_time * (@minimap_mode ? 4.0 : 1.0)

      @items.each { |item| item.update(@delta_time) }

      move_player
      @orbs.each do |orb|
        orb.collected = orb.overlap?(@player_camera[:position][:x], @player_camera[:position][:z], @player_radius * 10) unless orb.collected
      end
      cleared = if @orbs.all?(&:collected)
                  @goal.use_fade = true
                  @goal.overlap?(@player_camera[:position][:x], @player_camera[:position][:z], @player_radius * 10)
                else
                  false
                end

      @collected_orbs = @orbs.count { |orb| orb.collected }

      if @time < 0
        @time = 5.0
        @game_state = STATE_FAILED
      elsif cleared
        @clear_time = 60.0 - @time
        @time = 5.0
        @game_state = STATE_SUCCEEDED
      end

    when STATE_SUCCEEDED, STATE_FAILED
      @time -= @delta_time
      reset(maze_width: @maze.w, maze_height: @maze.h, maze_seed: @maze.seed) if @time < 0
    end
  end

  def render_scene
    ClearBackground(RAYWHITE)

    BeginMode3D(@minimap_mode ? @minimap_camera : @player_camera)
      # Redner ground
      DrawPlane(Vector3.create(@maze.grid_map_w * @block_w * 0.5 - 0.5 * @block_w, -0.5 * @block_h, @maze.grid_map_h * @block_h * 0.5 - 0.5 * @block_h),
                Vector2.create(@maze.grid_map_w * @block_w, @maze.grid_map_h * @block_h),
                LIGHTGRAY)

      render_maze

      @items.each(&:render)

      if @minimap_mode
        DrawSphere(@player_camera[:position], 10 * @player_radius, BLUE)
        render_eyesight
      end

      if @pathfinder.found
        path = @pathfinder.get_path
        path.length.times do |i|
          break if i + 1 == path.length
          grid_from = @pathfinder.get_node(path[i])
          grid_to = @pathfinder.get_node(path[i + 1])
          render_direction(grid_from.data, grid_to.data, ORANGE)# Fade(ORANGE, 0.75))
        end
      end

    EndMode3D()
  end

  def render_hud
    DrawRectangle(10, 10, 220, 70, Fade(SKYBLUE, 0.5))
    DrawRectangleLines( 10, 10, 220, 70, BLUE)

    case @game_state
    when STATE_READY
      show = (@time * 10).round % 2 == 1
      DrawText("R E A D Y ?", 90, 40, 10, DARKGRAY) if show
    when STATE_PLAYING
      DrawText("Collect all orbs and get to goal", 40, 20, 10, DARKGRAY)
      DrawText("- Move: W, A, S, D", 40, 30, 10, DARKGRAY)
      DrawText("- Yaw: Q/E or Arrow Left/Right", 40, 40, 10, DARKGRAY)
      DrawText("ORBS : #{@collected_orbs}/#{@orbs.size}", 70, 50, 10, RED)
      DrawText("TIME : %06.3f" % @time, 70, 60, 10, RED)
    when STATE_SUCCEEDED
      show = (@time * 10).round % 2 == 1
      DrawText("F I N I S H !", 85, 40, 10, DARKGRAY) if show
      DrawText("Clear Time: %2.3f" %  @clear_time, 70, 60, 10, DARKGRAY)
    when STATE_FAILED
      DrawText("G A M E  O V E R", 75, 40, 10, DARKGRAY)
    end
  end

  private

  def try_generate
    @maze.generate

    @block_positions = Array.new (@maze.grid_map_h) { Array.new (@maze.grid_map_w) }
    @block_colors = Array.new (@maze.grid_map_h) { Array.new (@maze.grid_map_w) }
    @maze.grid_map_h.times do |h|
      @maze.grid_map_w.times do |w|
        @block_positions[h][w] = Vector3.create(w * @block_w, 0.0, h * @block_h)
        @block_colors[h][w] = Color.from_u8(30, GetRandomValue(100, 250), 30, 255)
      end
    end

    @aabb_tree = AABBTree.new
    @maze.grid_map_h.times do |h|
      @maze.grid_map_w.times do |w|
        @aabb_tree.add_aabb(
          @block_positions[h][w][:x] - @block_w * 0.5,
          @block_positions[h][w][:z] - @block_h * 0.5,
          @block_positions[h][w][:x] + @block_w * 0.5,
          @block_positions[h][w][:z] + @block_h * 0.5,
          @maze.grid_map[h][w])
      end
    end

    generated = !@aabb_tree.overlap?(@orb_positions[0], @item_radius) &&
                !@aabb_tree.overlap?(@orb_positions[1], @item_radius) &&
                !@aabb_tree.overlap?(@orb_positions[2], @item_radius) &&
                !@aabb_tree.overlap?(@goal_position, @item_radius)

    return generated
  end

  def render_maze
    @maze.grid_map_h.times do |h|
      @maze.grid_map_w.times do |w|
        next if @maze.grid_map[h][w].walkable?
        DrawCube(@block_positions[h][w], @block_w, @block_h, @block_w, @block_colors[h][w])
      end
    end
  end

  def render_eyesight
    v1 = Vector3Add(@player_camera[:position], Vector3Add(Vector3Scale(@forward, @block_w * 1.5), Vector3Scale(@right, @block_w * 1.5)))
    v2 = Vector3Add(@player_camera[:position], Vector3Subtract(Vector3Scale(@forward, @block_w * 1.5), Vector3Scale(@right, @block_w * 1.5)))
    DrawTriangle3D(@player_camera[:position], v1, v2, Fade(SKYBLUE, 0.5))
  end

  def render_direction(pos_from, pos_to, color, width_scale = 0.1, y_offset = -0.45)
    up = Vector3.create(0, 1, 0)
    forward = Vector3Normalize(Vector3Subtract(pos_to, pos_from))
    dir = Vector3Normalize(forward)
    left = Vector3CrossProduct(up, dir)
    right = Vector3Scale(left, -1.0)
    length = Vector3Length(forward)
    half_width = width_scale * length

    v1 = Vector3Add(pos_from, Vector3Scale(left, half_width))
    v2 = Vector3Add(pos_from, Vector3Scale(right, half_width))

    offset = Vector3.create(0, y_offset, 0)

    DrawTriangle3D(Vector3Add(pos_to, offset), Vector3Add(v1, offset), Vector3Add(v2, offset), color)
  end

  def move_player
    forward = Vector3Normalize(Vector3Subtract(@player_camera[:target], @player_camera[:position]))

    # Yaw
    mouse_delta = GetMouseDelta()
    if mouse_delta[:x].abs > 1.0
      sgn = mouse_delta[:x] <=> 0
      amp = mouse_delta[:x].abs.clamp(0.0, 10.0)
      rad = -1.0 * sgn * amp * Math::PI / 180.0
      rot = QuaternionFromAxisAngle(Vector3.create(0, 1, 0), rad)
      forward = Vector3RotateByQuaternion(forward, rot)
      @player_camera[:target] = Vector3Add(@player_camera[:position], forward)
    elsif IsKeyDown(KEY_E) || IsKeyDown(KEY_RIGHT)
      sgn = 1.0
      amp = 5.0
      rad = -1.0 * sgn * amp * Math::PI / 180.0
      rot = QuaternionFromAxisAngle(Vector3.create(0, 1, 0), rad)
      forward = Vector3RotateByQuaternion(forward, rot)
      @player_camera[:target] = Vector3Add(@player_camera[:position], forward)
    elsif IsKeyDown(KEY_Q) || IsKeyDown(KEY_LEFT)
      sgn = -1.0
      amp = 5.0
      rad = -1.0 * sgn * amp * Math::PI / 180.0
      rot = QuaternionFromAxisAngle(Vector3.create(0, 1, 0), rad)
      forward = Vector3RotateByQuaternion(forward, rot)
      @player_camera[:target] = Vector3Add(@player_camera[:position], forward)
    end

    # Move posiiton
    velocity = if IsKeyDown(KEY_A) #|| IsKeyDown(KEY_LEFT) # Left
                 left = Vector3CrossProduct(Vector3.create(0, 1, 0), forward)
                 Vector3Scale(left, 0.025)
               elsif IsKeyDown(KEY_D) #|| IsKeyDown(KEY_RIGHT) # Right
                 left = Vector3CrossProduct(Vector3.create(0, 1, 0), forward)
                 Vector3Scale(left, -0.025)
               elsif IsKeyDown(KEY_W) || IsMouseButtonDown(MOUSE_BUTTON_LEFT) # Forward # || IsKeyDown(KEY_UP)
                 Vector3Scale(forward, 0.05)
               elsif IsKeyDown(KEY_S) || IsMouseButtonDown(MOUSE_BUTTON_RIGHT) # Backward # || IsKeyDown(KEY_DOWN)
                 Vector3Scale(forward, -0.05)
               else
                 Vector3.create(0, 0, 0)
               end

    # Overlap test with walls
    unless @aabb_tree.overlap?(@player_camera[:position], @player_radius, velocity)
      @player_camera[:position] = Vector3Add(@player_camera[:position], velocity)
      @player_camera[:target] = Vector3Add(@player_camera[:target], velocity)
    end

    @player_camera[:target][:y] = @player_camera[:position][:y]

    @minimap_mode = IsKeyDown(KEY_M)

    @velocity = velocity
    @forward = forward
    @right = Vector3Normalize(Vector3CrossProduct(@forward, @player_camera[:up]))
  end

end

if __FILE__ == $PROGRAM_NAME
  screenWidth = 1280
  screenHeight = 720
  InitWindow(screenWidth, screenHeight, "Yet Another Ruby-raylib bindings - Maze walker")
  SetTargetFPS(60)

  maze_width = ARGV[0].nil? ? 5 : ARGV[0].to_i
  maze_height = ARGV[1].nil? ? 5 : ARGV[1].to_i
  maze_seed = ARGV[2].nil? ? 12345 : ARGV[2].to_i
  app = Application.new(maze_width: maze_width, maze_height: maze_height, maze_seed: maze_seed)
  until WindowShouldClose()
    app.update
    BeginDrawing()
      app.render_scene
      app.render_hud
    EndDrawing()
  end

  CloseWindow()
end
