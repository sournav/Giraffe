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
        pub fn AddNode(self: *Self, id: index_type) !void {
            return self.graph.AddNode(id);  
        }
        pub fn AddEdge(self: *Self, id: index_type, n1_id: index_type, n2_id: index_type, w: weight_type) !void {
            try self.graph.AddEdge(id,n1_id,n2_id);
            try self.edge_weights.put(id,w);

        }
        pub fn RemoveNode(self: *Self, id: index_type) !ArrayList(index_type) {
           var removed_edges = try self.graph.RemoveNode(id);
            for (removed_edges.items) |edge| {
                _ = self.edge_weights.swapRemove(edge);
            }
            return removed_edges;
        }
        pub fn RemoveEdgesBetween(self: *Self, n1_id: index_type, n2_id: index_type) !ArrayList(index_type) {
            var edges_removed = try self.graph.RemoveEdgesBetween(n1_id,n2_id);
            for (edges_removed.items) |index| {
                _ = self.edge_weights.swapRemove(index);
            }  
            return edges_removed;
        }
        pub fn RemoveEdgeById(self: *Self, id: index_type) !void {
            try self.graph.RemoveEdgeById(id);
            _ = self.edge_weights.swapRemove(id);
        }
        pub fn GetEdgeWeight(self: *Self, id: index_type) !weight_type {
            if (!self.edge_weights.contains(id)) {
                return graph_err.EdgesDoNotExist;
            }
            return self.edge_weights.get(id).?;
        }
    };
}


test "nominal-AddNode" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try testing.expect(weighted_graph.graph.graph.count() == 1);
    try weighted_graph.deinit();
}
test "nominal-AddEdge" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try weighted_graph.AddNode(4);
    try weighted_graph.AddEdge(1,3,4,6);
    try testing.expect(weighted_graph.edge_weights.get(1).? == 6);
    try weighted_graph.deinit();
}
test "offnominal-AddNode" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try testing.expect(if (weighted_graph.AddNode(3)) |_| unreachable else |err| err == graph_err.NodeAlreadyExists);
    try weighted_graph.deinit();
}
test "nominal-RemoveNode" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try weighted_graph.AddNode(4);
    try weighted_graph.AddEdge(1,3,4,6);
    var edges = try weighted_graph.RemoveNode(3);
    try testing.expect(weighted_graph.graph.graph.count() == 1);
    try testing.expect(weighted_graph.edge_weights.count()==0);
    try testing.expect(edges.items.len == 1);
    edges.deinit();
    try weighted_graph.deinit();
}
test "offnominal-RemoveNode" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try testing.expect(if (weighted_graph.RemoveNode(2)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try weighted_graph.deinit();
}
test "nominal-RemoveEdgeById" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try weighted_graph.AddNode(4);
    try weighted_graph.AddEdge(1,3,4,6);
    try weighted_graph.RemoveEdgeById(1);
    try testing.expect(weighted_graph.edge_weights.count()==0);
    try weighted_graph.deinit();
}
test "offnominal-RemoveEdgeById" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try weighted_graph.AddNode(4);
    try weighted_graph.AddEdge(1,3,4,6);
    try testing.expect(if (weighted_graph.RemoveEdgeById(2)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
    try weighted_graph.deinit();
}
test "nominal-RemoveEdgesBetween" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try weighted_graph.AddNode(4);
    try weighted_graph.AddEdge(1,3,4,6);
    try weighted_graph.AddEdge(2,3,4,6);
    var edges =  try weighted_graph.RemoveEdgesBetween(3,4);
    try testing.expect(weighted_graph.edge_weights.count()==0);
    try testing.expect(edges.items.len==2);
    edges.deinit();
    try weighted_graph.deinit();
}
test "offnominal-RemoveEdgesBetween" {
    var weighted_graph = WeightedGraph(u32, u64, true).init(testing_alloc);
    try weighted_graph.AddNode(3);
    try weighted_graph.AddNode(4);
    try weighted_graph.AddEdge(1,3,4,6);
    try weighted_graph.AddEdge(2,3,4,6);
    try testing.expect(if (weighted_graph.RemoveEdgesBetween(4,5)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try weighted_graph.deinit();
}
