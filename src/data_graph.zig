const graph = @import("graph.zig").Graph;
const std = @import("std");
const ArrayList = std.ArrayList;
const graph_err = @import("graph.zig").GraphError;
const testing = std.testing;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const pg_alloc = std.heap.page_allocator;


pub fn DataGraph(comptime index_type: type, comptime weight_type: type, comptime node_type: type, comptime edge_type: type, directed: bool) type {
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
            self.graph.deinit();
            self.node_data.deinit();
            self.edge_data.deinit();
        }
        pub fn AddNode(self: *Self, node_index: index_type, node_data: node_type) !void {
            try self.graph.AddNode(node_index);
            try self.node_data.put(node_index, node_data);
        }
        pub fn AddEdge(self: *Self, id:index_type, n1:index_type, n2: index_type, weight: weight_type, edge_data: edge_type) !void {
            try self.graph.AddEdge(id, n1, n2, weight);
            try self.edge_data.put(id, edge_data);
        }
        pub fn RemoveEdgeById(self: *Self, id:index_type) !void{
            try self.graph.RemoveEdgeById(id);
            _ = self.edge_data.remove(id);
        }
        pub fn RemoveEdgesBetween(self: *Self, n1:index_type, n2:index_type) !ArrayList(index_type) {
            var removed_edges = try self.graph.RemoveEdgesBetween(n1,n2);
            for (removed_edges.items) |edge| {
                _ = self.edge_data.remove(edge);
            }
            return removed_edges;
        }
        pub fn RemoveNode(self: *Self, id: index_type) !ArrayList(index_type) {
            var removed_edges = try self.graph.RemoveNode(id);
            for (removed_edges.items) |edge| {
                _ = self.edge_data.remove(edge);
            }
            _ = self.node_data.remove(id);
            return removed_edges;
        }
        pub fn GetNodesData(self: *Self, ids: ArrayList(index_type)) !ArrayList(node_type) {
            var data = ArrayList(node_type).init(self.allocator);
            for (ids.items) |id| {
                if (!self.node_data.contains(id)) {
                    return graph_err.NodesDoNotExist;
                }
                try data.append(self.node_data.get(id).?);
            }
            return data;
        }
        pub fn GetEdgesData(self: *Self, ids: ArrayList(index_type)) !ArrayList(edge_type) {
            var data = ArrayList(edge_type).init(self.allocator);
            for (ids.items) |id| {
                if (!self.edge_data.contains(id)) {
                    return graph_err.EdgesDoNotExist;
                }
                try data.append(self.edge_data.get(id).?);
            }
            return data;
        }
    };
}

test "nominal-AddNode" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    testing.expect(data_graph.graph.graph.count() == 1);
    testing.expect(data_graph.node_data.count()==1);
    testing.expect(data_graph.node_data.get(3).? == 4);
    try graph.deinit();
}
test "nominal-AddEdge" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,5);
    try data_graph.AddEdge(1,3,4,5,6);
    testing.expect(data_graph.edge_data.get(1).? == 6);
}
test "offnominal-AddNode" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    testing.expect(if (data_graph.AddNode(3,4)) |_| unreachable else |err| err == graph_err.NodeAlreadyExists);
}
test "nominal-RemoveNode" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,4);
    try data_graph.AddEdge(1,3,4,5,6);
    var edges = try data_graph.RemoveNode(3);
    testing.expect(data_graph.graph.graph.count() == 1);
    testing.expect(data_graph.node_data.count()==1);
    testing.expect(data_graph.edge_data.count()==0);
    testing.expect(edges.items.len == 1);
}
test "offnominal-RemoveNode" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    testing.expect(if (data_graph.RemoveNode(2)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
}
test "nominal-RemoveEdgeById" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,4);
    try data_graph.AddEdge(1,3,4,5,6);
    try data_graph.RemoveEdgeById(1);
    testing.expect(data_graph.edge_data.count()==0);
}
test "offnominal-RemoveEdgeById" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,4);
    try data_graph.AddEdge(1,3,4,5,6);
    testing.expect(if (data_graph.RemoveEdgeById(2)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
}
test "nominal-RemoveEdgesBetween" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,4);
    try data_graph.AddEdge(1,3,4,5,6);
    try data_graph.AddEdge(2,3,4,5,6);
    var edges =  try data_graph.RemoveEdgesBetween(3,4);
    testing.expect(data_graph.edge_data.count()==0);
    testing.expect(edges.items.len==2);
}
test "offnominal-RemoveEdgesBetween" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,4);
    try data_graph.AddEdge(1,3,4,5,6);
    try data_graph.AddEdge(2,3,4,5,6);
    testing.expect(if (data_graph.RemoveEdgesBetween(4,5)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
}
test "nominal-GetNodesData" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,5);
    var arr = ArrayList(u32).init(pg_alloc);
    try arr.append(3);
    try arr.append(4);
    var node_data = try data_graph.GetNodesData(arr);
    testing.expect(node_data.items[0] == 4);
    testing.expect(node_data.items[1] == 5);
}
test "offnominal-GetNodesData" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,5);
    var arr = ArrayList(u32).init(pg_alloc);
    try arr.append(1);
    try arr.append(7);
    testing.expect(if (data_graph.GetNodesData(arr)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
}
test "nominal-GetEdgesData" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,5);
    try data_graph.AddEdge(1,3,4,5,6);
    try data_graph.AddEdge(2,3,4,5,7);
    var arr = ArrayList(u32).init(pg_alloc);
    try arr.append(1);
    try arr.append(2);
    var node_data = try data_graph.GetEdgesData(arr);
    testing.expect(node_data.items[0] == 6);
    testing.expect(node_data.items[1] == 7);
}
test "offnominal-GetEdgesData" {
    var data_graph = DataGraph(u32, u32, u64, u64, true).init(pg_alloc);
    try data_graph.AddNode(3,4);
    try data_graph.AddNode(4,5);
    try data_graph.AddEdge(1,3,4,5,6);
    try data_graph.AddEdge(2,3,4,5,7);
    var arr = ArrayList(u32).init(pg_alloc);
    try arr.append(1);
    try arr.append(7);
    testing.expect(if (data_graph.GetEdgesData(arr)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
}