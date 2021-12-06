const graph = @import("weighted_graph.zig").WeightedGraph;
const std = @import("std");
const ArrayList = std.ArrayList;
const graph_err = @import("graph.zig").GraphError;
const testing = std.testing;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const testing_alloc = std.testing.allocator;


pub fn WeightedDataGraph(comptime index_type: type, comptime weight_type: type, comptime node_type: type, comptime edge_type: type, directed: bool) type {
    return struct {
        const Self = @This();
        graph: graph(index_type, weight_type, directed),
        node_data: AutoArrayHashMap(index_type, node_type),
        edge_data: AutoArrayHashMap(index_type, edge_type),
        allocator: *mem.Allocator,
        pub fn init(alloc: *mem.Allocator) Self {
            return Self {
                .graph = graph(index_type, weight_type, directed).init(alloc),
                .node_data = AutoArrayHashMap(index_type, node_type).init(alloc),
                .edge_data = AutoArrayHashMap(index_type, edge_type).init(alloc),
                .allocator = alloc
            };
        }
        pub fn deinit(self: *Self) !void {
            try self.graph.deinit();
            self.node_data.deinit();
            self.edge_data.deinit();
        }
        pub fn AddNode(self: *Self, node_index: index_type, node_data: node_type) !void {
            try self.graph.AddNode(node_index);
            try self.node_data.put(node_index, node_data);
        }
        pub fn AddEdge(self: *Self, id:index_type, n1:index_type, n2: index_type, w: weight_type, edge_data: edge_type) !void {
            try self.graph.AddEdge(id, n1, n2, w);
            try self.edge_data.put(id, edge_data);
        }
        pub fn RemoveEdgeById(self: *Self, id:index_type) !void{
            try self.graph.RemoveEdgeById(id);
            _ = self.edge_data.orderedRemove(id);
        }
        pub fn RemoveEdgesBetween(self: *Self, n1:index_type, n2:index_type) !ArrayList(index_type) {
            var removed_edges = try self.graph.RemoveEdgesBetween(n1,n2);
            for (removed_edges.items) |edge| {
                _ = self.edge_data.orderedRemove(edge);
            }
            return removed_edges;
        }
        pub fn RemoveNode(self: *Self, id: index_type) !ArrayList(index_type) {
            var removed_edges = try self.graph.RemoveNode(id);
            for (removed_edges.items) |edge| {
                _ = self.edge_data.orderedRemove(edge);
            }
            _ = self.node_data.orderedRemove(id);
            return removed_edges;
        }
        pub fn GetNodesData(self: *Self, ids: ArrayList(index_type)) !ArrayList(node_type) {
            var data = ArrayList(node_type).init(self.allocator);
            data.deinit();
            for (ids.items) |id| {
                if (!self.node_data.contains(id)) {
                    data.deinit();
                    return graph_err.NodesDoNotExist;
                }
                try data.append(self.node_data.get(id).?);
            }
            return data;
        }
        pub fn GetEdgesData(self: *Self, ids: ArrayList(index_type)) !ArrayList(edge_type) {
            var data = ArrayList(edge_type).init(self.allocator);
            data.deinit();
            for (ids.items) |id| {
                if (!self.edge_data.contains(id)) {
                    data.deinit();
                    return graph_err.EdgesDoNotExist;
                }
                try data.append(self.edge_data.get(id).?);
            }
            return data;
        }
    };
}

test "nominal-AddNode" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try testing.expect(weighted_data_graph.graph.graph.graph.count() == 1);
    try testing.expect(weighted_data_graph.node_data.count()==1);
    try testing.expect(weighted_data_graph.node_data.get(3).? == 4);
    try weighted_data_graph.deinit();
}
test "nominal-AddEdge" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,5);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try testing.expect(weighted_data_graph.edge_data.get(1).? == 6);
    try weighted_data_graph.deinit();
}
test "offnominal-AddNode" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try testing.expect(if (weighted_data_graph.AddNode(3,4)) |_| unreachable else |err| err == graph_err.NodeAlreadyExists);
    try weighted_data_graph.deinit();
}
test "nominal-RemoveNode" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,4);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    var edges = try weighted_data_graph.RemoveNode(3);
    try testing.expect(weighted_data_graph.graph.graph.graph.count() == 1);
    try testing.expect(weighted_data_graph.node_data.count()==1);
    try testing.expect(weighted_data_graph.edge_data.count()==0);
    try testing.expect(edges.items.len == 1);
    edges.deinit();
    try weighted_data_graph.deinit();
}
test "offnominal-RemoveNode" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try testing.expect(if (weighted_data_graph.RemoveNode(2)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try weighted_data_graph.deinit();
}
test "nominal-RemoveEdgeById" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,4);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try weighted_data_graph.RemoveEdgeById(1);
    try testing.expect(weighted_data_graph.edge_data.count()==0);
    try weighted_data_graph.deinit();
}
test "offnominal-RemoveEdgeById" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,4);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try testing.expect(if (weighted_data_graph.RemoveEdgeById(2)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
    try weighted_data_graph.deinit();
}
test "nominal-RemoveEdgesBetween" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,4);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try weighted_data_graph.AddEdge(2,3,4,7,6);
    var edges =  try weighted_data_graph.RemoveEdgesBetween(3,4);
    try testing.expect(weighted_data_graph.edge_data.count()==0);
    try testing.expect(edges.items.len==2);
    edges.deinit();
    try weighted_data_graph.deinit();
}
test "offnominal-RemoveEdgesBetween" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,4);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try weighted_data_graph.AddEdge(2,3,4,7,6);
    try testing.expect(if (weighted_data_graph.RemoveEdgesBetween(4,5)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try weighted_data_graph.deinit();
}
test "nominal-GetNodesData" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,5);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(3);
    try arr.append(4);
    var node_data = try weighted_data_graph.GetNodesData(arr);
    try testing.expect(node_data.items[0] == 4);
    try testing.expect(node_data.items[1] == 5);
    node_data.deinit();
    arr.deinit();
    try weighted_data_graph.deinit();
}
test "offnominal-GetNodesData" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,5);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(1);
    try arr.append(7);
    try testing.expect(if (weighted_data_graph.GetNodesData(arr)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    arr.deinit();
    try weighted_data_graph.deinit();
}
test "nominal-GetEdgesData" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,5);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try weighted_data_graph.AddEdge(2,3,4,7,7);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(1);
    try arr.append(2);
    var node_data = try weighted_data_graph.GetEdgesData(arr);
    try testing.expect(node_data.items[0] == 6);
    try testing.expect(node_data.items[1] == 7);
    node_data.deinit();
    arr.deinit();
    try weighted_data_graph.deinit();
}
test "offnominal-GetEdgesData" {
    var weighted_data_graph = WeightedDataGraph(u32, u64, u64, u64, true).init(testing_alloc);
    try weighted_data_graph.AddNode(3,4);
    try weighted_data_graph.AddNode(4,5);
    try weighted_data_graph.AddEdge(1,3,4,5,6);
    try weighted_data_graph.AddEdge(2,3,4,7,7);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(1);
    try arr.append(7);
    try testing.expect(if (weighted_data_graph.GetEdgesData(arr)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
    arr.deinit();
    try weighted_data_graph.deinit();
}