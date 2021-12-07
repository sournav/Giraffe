const std = @import("std");
const core = @import("graph.zig");
const graph_type = core.Graph;
const graph_err = core.GraphError;
const print = std.debug.print;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const testing_alloc = std.testing.allocator;


pub fn WeightedGraph (comptime index_type: type, comptime weight_type: type, dir: bool) type{
    return struct {
        const Self = @This();
        directed:bool = dir,
        graph: graph_type(index_type, dir),
        edge_weights: AutoArrayHashMap(index_type, weight_type),
        allocator: *mem.Allocator,

        pub fn init(alloc_in: *mem.Allocator) Self {
            return Self {
                .graph = graph_type(index_type, dir).init(alloc_in),
                .edge_weights = AutoArrayHashMap(index_type, weight_type).init(alloc_in),
                .allocator = alloc_in
            };

        }
        pub fn deinit(self: *Self) !void {
            try self.graph.deinit();
            self.edge_weights.deinit();
        }

        //Adds a node to the graph struct given an index of a node
        pub fn addNode(self: *Self, id: index_type) !void {
            return self.graph.addNode(id);  
        }

        //Adds an edge given the nodes to connect between, and a weight. (Note: for directed graphs, the order of the nodes matter)
        pub fn addEdge(self: *Self, id: index_type, n1_id: index_type, n2_id: index_type, w: weight_type) !void {
            try self.graph.addEdge(id,n1_id,n2_id);
            try self.edge_weights.put(id,w);

        }

        //Given an node ID, removes all nodes, an automatically removes all edges connected to it
        pub fn removeNodeWithEdges(self: *Self, id: index_type) !ArrayList(index_type) {
           var removed_edges = try self.graph.removeNodeWithEdges(id);
            for (removed_edges.items) |edge| {
                _ = self.edge_weights.swapRemove(edge);
            }
            return removed_edges;
        }

        //Removes the edges between two nodes (Note: for directed graphs the order of nodes matter, only edges from n1_id to n2_id will be removed )
        pub fn removeEdgesBetween(self: *Self, n1_id: index_type, n2_id: index_type) !ArrayList(index_type) {
            var edges_removed = try self.graph.removeEdgesBetween(n1_id,n2_id);
            for (edges_removed.items) |index| {
                _ = self.edge_weights.swapRemove(index);
            }  
            return edges_removed;
        }

        //Removes the edge by its ID using swapRemove
        pub fn removeEdgeByID(self: *Self, id: index_type) !void {
            try self.graph.removeEdgeByID(id);
            _ = self.edge_weights.swapRemove(id);
        }

        //Gets the weight of an edge if it exists given the index of the edge
        pub fn getEdgeWeight(self: *Self, id: index_type) !weight_type {
            if (!self.edge_weights.contains(id)) {
                return graph_err.EdgesDoNotExist;
            }
            return self.edge_weights.get(id).?;
        }
    };
}


test "nominal-addNode" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try testing.expect(weighted_graph.graph.graph.count() == 1);
    try weighted_graph.deinit();
}
test "nominal-addEdge" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try weighted_graph.addNode(4);
    try weighted_graph.addEdge(1,3,4,6);
    try testing.expect(weighted_graph.edge_weights.get(1).? == 6);
    try weighted_graph.deinit();
}
test "offnominal-addNode" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try testing.expect(if (weighted_graph.addNode(3)) |_| unreachable else |err| err == graph_err.NodeAlreadyExists);
    try weighted_graph.deinit();
}
test "nominal-removeNodeWithEdges" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try weighted_graph.addNode(4);
    try weighted_graph.addEdge(1,3,4,6);
    var edges = try weighted_graph.removeNodeWithEdges(3);
    try testing.expect(weighted_graph.graph.graph.count() == 1);
    try testing.expect(weighted_graph.edge_weights.count()==0);
    try testing.expect(edges.items.len == 1);
    edges.deinit();
    try weighted_graph.deinit();
}
test "offnominal-removeNodeWithEdges" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try testing.expect(if (weighted_graph.removeNodeWithEdges(2)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try weighted_graph.deinit();
}
test "nominal-removeEdgeByID" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try weighted_graph.addNode(4);
    try weighted_graph.addEdge(1,3,4,6);
    try weighted_graph.removeEdgeByID(1);
    try testing.expect(weighted_graph.edge_weights.count()==0);
    try weighted_graph.deinit();
}
test "offnominal-removeEdgeByID" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try weighted_graph.addNode(4);
    try weighted_graph.addEdge(1,3,4,6);
    try testing.expect(if (weighted_graph.removeEdgeByID(2)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
    try weighted_graph.deinit();
}
test "nominal-removeEdgesBetween" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try weighted_graph.addNode(4);
    try weighted_graph.addEdge(1,3,4,6);
    try weighted_graph.addEdge(2,3,4,6);
    var edges =  try weighted_graph.removeEdgesBetween(3,4);
    try testing.expect(weighted_graph.edge_weights.count()==0);
    try testing.expect(edges.items.len==2);
    edges.deinit();
    try weighted_graph.deinit();
}
test "offnominal-removeEdgesBetween" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.addNode(3);
    try weighted_graph.addNode(4);
    try weighted_graph.addEdge(1,3,4,6);
    try weighted_graph.addEdge(2,3,4,6);
    try testing.expect(if (weighted_graph.removeEdgesBetween(4,5)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try weighted_graph.deinit();
}
