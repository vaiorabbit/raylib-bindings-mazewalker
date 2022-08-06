module Pathfinding

  class Node
    attr_reader :id, :edges
    attr_accessor :data

    def initialize(node_id, data = nil)
      @id = node_id
      @edges = []
      @data = data
    end

    def connect_edge(edge) = @edges << edge;
    def disconnect_edge(edge) = @edges.delete(edge);
  end

  class Edge
    attr_accessor :cost, :node_ids

    def initialize(cost, node_id0, node_id1)
      @cost = cost
      @node_ids = [node_id0, node_id1]
    end

    def has_node_id?(node_id) = return @node_ids[0] == node_id || @node_ids[1] == node_id;
    def opposite_id(node_id) = return node_id == @node_ids[0] ? @node_ids[1] : @node_ids[0];
  end

  class Route
    attr_accessor :found, :parents, :start_id, :goal_id

    def initialize
      @parents = Hash.new # child id -> parent id
      @costs = Hash.new # node id -> way cost
      reset()
    end

    def reset
      @parents.clear
      @costs.clear
      @found = false
      @start_id = nil
      @goal_id = nil
    end

    def record(child:, parent:, cost:)
      @parents[child] = parent
      @costs[child] = cost
    end

    def cost_to(node_id)
      return @costs.include?(node_id) ? @costs[node_id] : Float::MAX
    end

    def get_path(goal_id)
      path = []
      if @found
        parent = goal_id
        while parent != nil
          path << parent
          parent = @parents[parent]
        end
      end
      return path.reverse!
    end
  end

  class AlgorithmBase
    def initialize
      @edges = []
      @nodes = Hash.new
      @route = Route.new
    end

    def add_node(id, data = nil)
      @nodes[id] = Node.new(id, data)
    end

    def add_edge(cost, node0_id, node1_id)
      @edges << Edge.new(cost, node0_id, node1_id)
    end

    def get_node(id)
      @nodes.has_key?(id) ? @nodes[id] : nil
    end

    def get_edge(node_id0, node_id1)
      @edges.find {|edge| edge.has_node_id?(node_id0) && edge.has_node_id?(node_id1) }
    end

    def remove_node(id)
      @nodes.delete(id)
    end

    def remove_edge(node_id0, node_id1)
      @edges.delete_if {|edge| edge.node_ids.include?(node_id0) && edge.node_ids.include?(node_id1) }
    end

    def setup_graph
      @edges.each do |edge|
        @nodes[edge.node_ids[0]].connect_edge(edge)
        @nodes[edge.node_ids[1]].connect_edge(edge)
      end
    end

    def found = return @route.found;

    def get_path = return @route.get_path(@route.goal_id);

    def goal_id = return @route.goal_id;

    def reset(start_id, goal_id)
      @route.reset
      @route.start_id = start_id
      @route.goal_id = goal_id
      @route.record(child: @nodes[start_id].id, parent: nil, cost: 0.0)
    end

    def search; end
  end

end

####################################################################################################

class DijkstraAlgorithm < Pathfinding::AlgorithmBase
  def search
    open_list  = [@nodes[@route.start_id]]
    close_list = []

    until open_list.empty?
      minimum_cost_nodes = []
      open_list.each do |node|
        minimum_cost_nodes << [@route.cost_to(node.id), node] # pair : [cost, node]
      end
      minimum_cost_nodes.sort_by! {|pair| pair[0]}

      n = minimum_cost_nodes.first[1]
      if n.id == @route.goal_id
        @route.found = true
        break
      end

      n.edges.each do |edge|
        m = @nodes[edge.opposite_id(n.id)]
        cost_current = @route.cost_to(n.id) + edge.cost
        if open_list.include?(m)
          if cost_current < @route.cost_to(m.id)
            @route.record(child: m.id, parent: n.id, cost: cost_current)
          end
        elsif close_list.include?(m)
          if cost_current < @route.cost_to(m.id)
            @route.record(child: m.id, parent: n.id, cost: cost_current)
            close_list.delete(m)
            open_list.push(m)
          end
        else
          @route.record(child: m.id, parent: n.id, cost: cost_current)
          open_list.push(m)
        end
      end

      open_list.delete(n)
      close_list.push(n)
    end
  end
end

####################################################################################################

if __FILE__ == $PROGRAM_NAME

  algo = DijkstraAlgorithm.new

  # 0 - 1 - 2
  # |       |
  # 3 - 4 - 5
  # |   |
  # 6   7 - 8

  9.times do |id|
    algo.add_node(id)
  end

  algo.add_edge(1.0, 0, 1)
  algo.add_edge(1.0, 1, 2)
  algo.add_edge(1.0, 0, 3)
  algo.add_edge(1.0, 2, 5)
  algo.add_edge(1.0, 3, 4)
  algo.add_edge(1.0, 4, 5)
  algo.add_edge(1.0, 3, 6)
  algo.add_edge(1.0, 4, 7)
  algo.add_edge(1.0, 7, 8)
  algo.setup_graph

  pp algo.get_node(0)
  pp algo.get_node(8)
  pp algo.get_node(9)     # should return nil
  pp algo.get_edge(0, 1)
  pp algo.get_edge(1, 0)
  pp algo.get_edge(8, 10) # should return nil
  pp algo.get_edge(9, 10) # should return nil

  algo.reset(0, 8)
  algo.search

  if algo.found
    # 0 -> 3 -> 4 -> 7 -> 8
    algo.get_path.each do |node_id|
      print node_id
      print node_id == algo.goal_id ? "\n" : " -> "
    end
  end

  # replace path 3 to 4 with high-cost edge and calculate path
  # 0 - 1 - 2
  # |       |
  # 3 ~ 4 - 5
  # |   |
  # 6   7 - 8

  edge = algo.get_edge(3, 4)
  algo.get_node(3).disconnect_edge(edge)
  algo.get_node(4).disconnect_edge(edge)
  algo.remove_edge(3, 4)
  algo.add_edge(1000.0, 3, 4)
  algo.setup_graph

  algo.reset(0, 8)
  algo.search

  if algo.found
    # 0 -> 1 -> 2 -> 5 -> 4 -> 7 -> 8
    algo.get_path.each do |node_id|
      print node_id
      print node_id == algo.goal_id ? "\n" : " -> "
    end
  end


end
