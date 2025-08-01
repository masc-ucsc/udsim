#!/usr/bin/env ruby

require 'rgl/adjacency'
require 'matrix'

class MetisBalancedPartitioner
  def initialize(graph_input)
    if File.exist?(graph_input)
      # File path input
      @graph_data = File.read(graph_input)
    else
      # String input (METIS format data)
      @graph_data = graph_input
    end

    @graph, @weights = parse_metis_format
    @vertices = @graph.vertices.to_a.sort
  end

  # Main partitioning method
  def partition(k, algorithm: :multilevel, balance_factor: 1.05)
    case algorithm
    when :multilevel
      multilevel_partition(k, balance_factor)
    when :spectral
      spectral_partition(k, balance_factor)
    when :kernighan_lin
      kernighan_lin_partition(k, balance_factor)
    when :greedy_growth
      greedy_growth_partition(k, balance_factor)
    else
      raise "Unknown algorithm: #{algorithm}"
    end
  end

  # Multilevel partitioning (similar to METIS approach)
  def multilevel_partition(k, balance_factor = 1.05)
    return simple_partition(k) if @vertices.length < k * 10

    # Phase 1: Coarsening
    coarse_graphs = coarsen_graph

    # Phase 2: Initial partitioning on coarsest graph
    coarsest_graph, _coarsest_weights, _vertex_mapping = coarse_graphs.last
    initial_partitions = initial_partition(coarsest_graph.vertices.to_a, k)

    # Phase 3: Uncoarsening and refinement
    partitions = initial_partitions
    coarse_graphs.reverse.each_with_index do |(graph, weights, mapping), idx|
      next if idx == 0  # Skip the coarsest level

      # Project partitions back
      partitions = project_partitions(partitions, mapping)

      # Refine using Kernighan-Lin style moves
      partitions = refine_partitions(graph, weights, partitions, k, balance_factor)
    end

    format_result(partitions, k)
  end

  # Spectral partitioning using graph Laplacian
  def spectral_partition(k, balance_factor = 1.05)
    return simple_partition(k) if @vertices.length < k

    # Build Laplacian matrix
    laplacian = build_laplacian_matrix

    # Find k-1 smallest non-zero eigenvalues and eigenvectors
    _eigenvalues, eigenvectors = compute_eigenvectors(laplacian, k)

    # Use k-means clustering on eigenvector coordinates
    partitions = kmeans_cluster(eigenvectors, k)

    # Balance the partitions
    partitions = balance_partitions(partitions, k, balance_factor)

    format_result(partitions, k)
  end

  # Kernighan-Lin style partitioning
  def kernighan_lin_partition(k, balance_factor = 1.05)
    # Start with random assignment
    partitions = Array.new(k) { [] }
    @vertices.each_with_index { |v, i| partitions[i % k] << v }

    max_iterations = 10
    max_iterations.times do
      improved = false

      # Try swapping vertices between partitions
      k.times do |i|
        k.times do |j|
          next if i >= j

          best_swap = find_best_swap(partitions, i, j)
          if best_swap[:gain] > 0
            perform_swap(partitions, best_swap)
            improved = true
          end
        end
      end

      break unless improved
    end

    partitions = balance_partitions(partitions, k, balance_factor)
    format_result(partitions, k)
  end

  # Greedy graph growing partitioning
  def greedy_growth_partition(k, balance_factor = 1.05)
    target_size = (@vertices.length.to_f / k).ceil
    partitions = Array.new(k) { [] }
    used = Set.new

    k.times do |partition_idx|
      break if used.length >= @vertices.length

      # Start with highest degree unused vertex
      remaining = @vertices - used.to_a
      break if remaining.empty?

      seed = remaining.max_by { |v| vertex_degree(v) }
      current_partition = [seed]
      used.add(seed)

      # Grow partition greedily
      while current_partition.length < target_size && used.length < @vertices.length
        candidates = []

        current_partition.each do |v|
          @graph.adjacent_vertices(v).each do |neighbor|
            next if used.include?(neighbor)

            weight = edge_weight(v, neighbor)
            candidates << { vertex: neighbor, weight: weight }
          end
        end

        break if candidates.empty?

        # Choose vertex with highest connection weight to current partition
        best_candidate = candidates.group_by { |c| c[:vertex] }
          .map { |vertex, connections|
            { vertex: vertex, total_weight: connections.sum { |c| c[:weight] } }
          }
          .max_by { |c| c[:total_weight] }

        if best_candidate
          current_partition << best_candidate[:vertex]
          used.add(best_candidate[:vertex])
        else
          break
        end
      end

      partitions[partition_idx] = current_partition
    end

    # Assign remaining vertices
    remaining = @vertices - used.to_a
    remaining.each_with_index do |v, idx|
      partitions[idx % k] << v
    end

    partitions = balance_partitions(partitions, k, balance_factor)
    format_result(partitions, k)
  end

  # Calculate partition quality metrics
  def evaluate_partitioning(partitions)
    total_cut_weight = 0
    total_vertices = partitions.sum(&:length)

    # Calculate cut weight
    partitions.each_with_index do |partition1, i|
      partitions.each_with_index do |partition2, j|
        next if i >= j

        partition1.each do |u|
          partition2.each do |v|
            if @graph.has_edge?(u, v)
              total_cut_weight += edge_weight(u, v)
            end
          end
        end
      end
    end

    # Calculate balance
    sizes = partitions.map(&:length)
    avg_size = total_vertices.to_f / partitions.length
    max_imbalance = sizes.map { |s| (s - avg_size).abs / avg_size }.max

    {
      cut_weight: total_cut_weight,
      partition_sizes: sizes,
      imbalance: max_imbalance,
      quality_score: total_cut_weight * (1 + max_imbalance)  # Lower is better
    }
  end

  private

  def parse_metis_format
    lines = @graph_data.strip.split("\n")
    header = lines[0].split.map(&:to_i)
    num_vertices = header[0]

    graph = RGL::AdjacencyGraph.new
    weights = {}

    (1..num_vertices).each { |v| graph.add_vertex(v) }

    lines[1..-1].each_with_index do |line, idx|
      vertex = idx + 1
      break if vertex > num_vertices
      next if line.strip.empty?

      parts = line.split.map(&:to_i)

      i = 0
      while i < parts.length - 1
        weight = parts[i]
        neighbor = parts[i + 1]

        if neighbor > 0 && neighbor <= num_vertices && neighbor != vertex
          graph.add_edge(vertex, neighbor)
          weights[[vertex, neighbor]] = weight
          weights[[neighbor, vertex]] = weight
        end
        i += 2
      end
    end

    [graph, weights]
  end

  def edge_weight(u, v)
    return 0 if u == v
    @weights[[u, v]] || @weights[[v, u]] || 1
  end

  def vertex_degree(v)
    @graph.adjacent_vertices(v).sum { |neighbor| edge_weight(v, neighbor) }
  end

  def simple_partition(k)
    partitions = Array.new(k) { [] }
    @vertices.each_with_index { |v, i| partitions[i % k] << v }
    format_result(partitions, k)
  end

  def coarsen_graph
    current_graph = @graph
    current_weights = @weights
    graphs = [[current_graph, current_weights, nil]]

    while current_graph.vertices.length > 100
      coarse_graph, coarse_weights, mapping = coarsen_step(current_graph, current_weights)
      break if coarse_graph.vertices.length >= current_graph.vertices.length * 0.8

      graphs << [coarse_graph, coarse_weights, mapping]
      current_graph = coarse_graph
      current_weights = coarse_weights
    end

    graphs
  end

  def coarsen_step(graph, weights)
    matched = Set.new
    mapping = {}
    new_vertex_id = 0

    coarse_graph = RGL::AdjacencyGraph.new
    coarse_weights = {}

    graph.vertices.each do |v|
      next if matched.include?(v)

      # Find best neighbor to match with
      best_neighbor = nil
      best_weight = 0

      graph.adjacent_vertices(v).each do |neighbor|
        next if matched.include?(neighbor)

        weight = edge_weight(v, neighbor)
        if weight > best_weight
          best_weight = weight
          best_neighbor = neighbor
        end
      end

      new_vertex_id += 1
      coarse_graph.add_vertex(new_vertex_id)

      if best_neighbor
        mapping[v] = new_vertex_id
        mapping[best_neighbor] = new_vertex_id
        matched.add(v)
        matched.add(best_neighbor)
      else
        mapping[v] = new_vertex_id
        matched.add(v)
      end
    end

    # Build coarse graph edges
    coarse_graph.vertices.each do |u|
      coarse_graph.vertices.each do |v|
        next if u >= v

        total_weight = 0

        # Find all original vertices mapped to u and v
        orig_u = mapping.select { |_, new_v| new_v == u }.keys
        orig_v = mapping.select { |_, new_v| new_v == v }.keys

        orig_u.each do |ou|
          orig_v.each do |ov|
            if graph.has_edge?(ou, ov)
              total_weight += edge_weight(ou, ov)
            end
          end
        end

        if total_weight > 0
          coarse_graph.add_edge(u, v)
          coarse_weights[[u, v]] = total_weight
          coarse_weights[[v, u]] = total_weight
        end
      end
    end

    [coarse_graph, coarse_weights, mapping.invert]
  end

  def initial_partition(vertices, k)
    partitions = Array.new(k) { [] }
    vertices.each_with_index { |v, i| partitions[i % k] << v }
    partitions
  end

  def project_partitions(partitions, mapping)
    new_partitions = Array.new(partitions.length) { [] }

    mapping.each do |coarse_vertex, original_vertices|
      # Find which partition the coarse vertex belongs to
      partition_idx = partitions.find_index { |p| p.include?(coarse_vertex) }

      if partition_idx
        Array(original_vertices).each do |orig_v|
          new_partitions[partition_idx] << orig_v
        end
      end
    end

    new_partitions
  end

  def refine_partitions(graph, weights, partitions, k, balance_factor)
    # Simple refinement - could be enhanced with more sophisticated methods
    max_iterations = 5

    max_iterations.times do
      improved = false

      k.times do |i|
        k.times do |j|
          next if i >= j

          swap = find_best_swap(partitions, i, j)
          if swap[:gain] > 0
            perform_swap(partitions, swap)
            improved = true
          end
        end
      end

      break unless improved
    end

    partitions
  end

  def find_best_swap(partitions, i, j)
    best_gain = 0
    best_swap = { vertex_i: nil, vertex_j: nil, gain: 0 }

    partitions[i].each do |vi|
      partitions[j].each do |vj|
        gain = calculate_swap_gain(partitions, vi, vj, i, j)
        if gain > best_gain
          best_gain = gain
          best_swap = { vertex_i: vi, vertex_j: vj, partition_i: i, partition_j: j, gain: gain }
        end
      end
    end

    best_swap
  end

  def calculate_swap_gain(partitions, vi, vj, i, j)
    # Calculate reduction in cut weight from swapping vi and vj
    current_cut = 0
    new_cut = 0

    # Current cut involving vi
    @graph.adjacent_vertices(vi).each do |neighbor|
      next if neighbor == vj

      neighbor_partition = partitions.find_index { |p| p.include?(neighbor) }
      weight = edge_weight(vi, neighbor)

      current_cut += weight if neighbor_partition != i
      new_cut += weight if neighbor_partition != j
    end

    # Current cut involving vj
    @graph.adjacent_vertices(vj).each do |neighbor|
      next if neighbor == vi

      neighbor_partition = partitions.find_index { |p| p.include?(neighbor) }
      weight = edge_weight(vj, neighbor)

      current_cut += weight if neighbor_partition != j
      new_cut += weight if neighbor_partition != i
    end

    # Edge between vi and vj
    if @graph.has_edge?(vi, vj)
      edge_weight_ij = edge_weight(vi, vj)
      current_cut += edge_weight_ij  # They're in different partitions
      # new_cut += 0  # They'll be in different partitions after swap
    end

    current_cut - new_cut
  end

  def perform_swap(partitions, swap)
    i, j = swap[:partition_i], swap[:partition_j]
    vi, vj = swap[:vertex_i], swap[:vertex_j]

    partitions[i].delete(vi)
    partitions[j].delete(vj)
    partitions[i] << vj
    partitions[j] << vi
  end

  def balance_partitions(partitions, k, balance_factor)
    target_size = @vertices.length.to_f / k
    max_allowed_size = (target_size * balance_factor).floor

    # Move vertices from oversized partitions to undersized ones
    loop do
      oversized = partitions.each_with_index.select { |p, _| p.length > max_allowed_size }
      undersized = partitions.each_with_index.select { |p, _| p.length < target_size }

      break if oversized.empty? || undersized.empty?

      oversized_partition, _oversized_idx = oversized.first
      undersized_partition, _undersized_idx = undersized.first

      # Move a vertex with minimal cut increase
      best_vertex = oversized_partition.min_by do |v|
        # Count connections to the target partition vs source partition
        target_connections = @graph.adjacent_vertices(v).count { |n| undersized_partition.include?(n) }
        source_connections = @graph.adjacent_vertices(v).count { |n| oversized_partition.include?(n) && n != v }
        source_connections - target_connections
      end

      oversized_partition.delete(best_vertex)
      undersized_partition << best_vertex
    end

    partitions
  end

  def build_laplacian_matrix
    n = @vertices.length
    _vertex_to_idx = @vertices.each_with_index.to_h

    # Build adjacency matrix
    adj_matrix = Matrix.zero(n)
    degree_matrix = Matrix.zero(n)

    @vertices.each_with_index do |u, i|
      degree = 0
      @vertices.each_with_index do |v, j|
        if @graph.has_edge?(u, v)
          weight = edge_weight(u, v)
          adj_matrix = adj_matrix.set_element(i, j, weight)
          degree += weight
        end
      end
      degree_matrix = degree_matrix.set_element(i, i, degree)
    end

    # Laplacian = Degree - Adjacency
    degree_matrix - adj_matrix
  end

  def compute_eigenvectors(laplacian, k)
    # Simplified eigenvalue computation - in practice, you'd use a numerical library
    # This is a placeholder that returns random vectors for demonstration
    n = laplacian.row_count
    eigenvectors = Array.new(k-1) { Array.new(n) { rand - 0.5 } }
    eigenvalues = Array.new(k-1) { rand }

    [eigenvalues, eigenvectors]
  end

  def kmeans_cluster(eigenvectors, k)
    return simple_partition(k) if eigenvectors.empty?

    n = eigenvectors.first.length
    partitions = Array.new(k) { [] }

    # Simple clustering based on first eigenvector
    first_eigenvector = eigenvectors.first
    sorted_vertices = @vertices.zip(first_eigenvector).sort_by(&:last)

    chunk_size = (n.to_f / k).ceil
    sorted_vertices.each_slice(chunk_size).each_with_index do |chunk, idx|
      chunk.each { |vertex, _| partitions[idx] << vertex }
    end

    partitions.reject(&:empty?)
  end

  def format_result(partitions, k)
    metrics = evaluate_partitioning(partitions)

    {
      partitions: partitions,
      num_partitions: partitions.length,
      metrics: metrics,
      partition_sizes: partitions.map(&:length)
    }
  end
end

# Usage example
if __FILE__ == $0
  graph_data = """72 53 10 1
    43 17 18 19 20 27 36 37
    72 8 13 15 22 53 63
    9 32 49
    655 44
    109 11
    124 8
    4
    114 10 6 9 2
    4 8
    381 8
    173 5
    84 13
    328 22 15 2 11 12
    71 15
    276 14 2
    41
    14 1
    107 1
    116 1
    44 1
    48 23
    30 2
    209 21 25 24
    38 23
    18 23
    414 29
    44 1
    19 29
    26 26 28
    142 34
    293 34
    248 3
    116 35
    227 30 31 32 38 39
    151 33 40
    44 1
    44 1
    76 34
    66 34
    98 35
    369 42
    168 41
    1
    179 4
    58 46
    227 44 45 47 51
    409 49 48
    56 47
    86 3
    7
    13 46
    1
    93 2
    502 53
    355 61
    623 61
    102 61
    99 61
    163 61
    47 61
    344 54 55 56 59 60 57 58
    1889 63
    1536 68 67 64 65 66 2
    347 63
    155 63
    137 63
    112 63
    30 63
    1
    72
    28
    1"""

  partitioner = MetisBalancedPartitioner.new(graph_data)

  # Test different algorithms
  algorithms = [:multilevel, :greedy_growth, :kernighan_lin]
  k_values = [2, 4, 8]

  algorithms.each do |algorithm|
    puts "\n" + "="*50
    puts "Algorithm: #{algorithm.to_s.upcase}"
    puts "="*50

    k_values.each do |k|
      puts "\n--- Partitioning into #{k} parts ---"

      result = partitioner.partition(k, algorithm: algorithm)

      puts "Partitions created: #{result[:num_partitions]}"
      puts "Partition sizes: #{result[:partition_sizes]}"
      puts "Cut weight: #{result[:metrics][:cut_weight]}"
      puts "Max imbalance: #{(result[:metrics][:imbalance] * 100).round(2)}%"
      puts "Quality score: #{result[:metrics][:quality_score].round(2)}"

      # Show first few vertices of each partition
      result[:partitions].each_with_index do |partition, idx|
        preview = partition.first(5)
        preview_str = preview.join(", ")
        preview_str += ", ..." if partition.length > 5
        puts "  Partition #{idx + 1} (#{partition.length} vertices): [#{preview_str}]"
      end
    end
  end
end
