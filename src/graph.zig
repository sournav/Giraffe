const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const alloc = std.heap.page_allocator;


pub const GraphError = error{
    NodeAlreadyExists,
    EdgeAlreadyExists,
    NodesDoNotExist,
    EdgesDoNotExist
};


pub fn Graph (comptime index_type: type, comptime weight_type: type, dir: bool) type{
    return struct {
        const Self = @This();
        directed:bool = dir,
        graph: AutoArrayHashMap(index_type, AutoArrayHashMap(index_type, index_type)),
        edges: AutoArrayHashMap(index_type, weight_type),
        edge_list: AutoArrayHashMap(index_type, [2]index_type),
        allocator: *mem.Allocator,
        pub fn init(alloc_in: *mem.Allocator) Self {
            return Self {
                .graph = AutoArrayHashMap(index_type, AutoArrayHashMap(index_type, index_type)).init(alloc),
                .edges = AutoArrayHashMap(index_type, weight_type).init(alloc),
                .edge_list = AutoArrayHashMap(index_type, [2]index_type).init(alloc),
                .allocator = alloc_in
            };

        }
        pub fn deinit(self: *Self) !void {
            self.graph.deinit();
            self.edges.deinit();
            self.edge_list.deinit();
        }
        pub fn AddNode(self: *Self, id: index_type) !void {
            if (!self.graph.contains(id)) {
                try self.graph.put(id, AutoArrayHashMap(index_type, index_type).init(self.allocator));
            }
            else {
                return GraphError.NodeAlreadyExists;
            }   
        }
        pub fn AddEdge(self: *Self, id: index_type, n1_id: index_type, n2_id: index_type, w: weight_type) !void {
            if (self.edges.contains(id)) {
                return GraphError.EdgeAlreadyExists;
            }
            if (!self.graph.contains(n1_id) or !self.graph.contains(n2_id)) {
                return GraphError.NodesDoNotExist;
            }
            try self.edges.put(id,w);
            var node1_map = self.graph.get(n1_id);
            try node1_map.?.put(id,n2_id);
            try self.graph.put(n1_id,node1_map.?);
            if (!self.directed) {
                var node2_map = self.graph.get(n2_id);
                try node2_map.?.put(id,n1_id);
                try self.graph.put(n2_id,node2_map.?);
            }
            
            try self.edge_list.put(id,[2]index_type{n1_id,n2_id});
        }
        pub fn RemoveNode(self: *Self, id: index_type) !ArrayList(index_type) {
           if (!self.graph.contains(id)) {
               return GraphError.NodesDoNotExist;
           }
           if (self.directed) {
               return self.RemoveNodeDirected(id);
           }
           else {
               return self.RemoveNodeUndirected(id);
           }
        }
        fn RemoveNodeUndirected(self: *Self, id: index_type) !ArrayList(index_type) {
            var n1_remove = self.graph.get(id);
            var iterator_n1 = n1_remove.?.iterator();
            var edges_removed = ArrayList(index_type).init(self.allocator);
            while (iterator_n1.next()) |entry| {
                var edge = entry.key_ptr.*;
                try edges_removed.append(edge);
            }
            for (edges_removed.items) |index| {
                try self.RemoveEdgeById(index);
            }
            _ = self.graph.orderedRemove(id);
            return edges_removed;
        }
        fn RemoveNodeDirected(self: *Self, id: index_type) !ArrayList(index_type) {
            var iterator = self.graph.iterator();
            var edges_removed = ArrayList(index_type).init(self.allocator);
            while (iterator.next()) |entry| {
                var node = entry.key_ptr.*;
                var removal = try self.RemoveEdgesBetween(node,id);
                try edges_removed.appendSlice(removal.items);
                removal.deinit();
            }
            var node_list = self.graph.get(id);
            var node_iterator = node_list.?.iterator();
            while (node_iterator.next()) |entry| {
                var edge = entry.key_ptr.*;
                var node = entry.value_ptr.*;
                try self.RemoveEdgeById(edge);
                try edges_removed.append(edge);
            }
            _ = self.graph.orderedRemove(id);
            return edges_removed;
        }
        pub fn RemoveEdgesBetween(self: *Self, n1_id: index_type, n2_id: index_type) !ArrayList(index_type) {
            
            if (!self.graph.contains(n1_id) or !self.graph.contains(n2_id)) {
                return GraphError.NodesDoNotExist;
            }
            var edges_removed = ArrayList(index_type).init(self.allocator);
            var iterator_n1 = self.graph.get(n1_id).?.iterator();
            while (iterator_n1.next()) |entry| {
                var node = entry.value_ptr.*;
                var edge = entry.key_ptr.*;
                if (node == n2_id) {
                    try edges_removed.append(edge);
                }
            }
            for (edges_removed.items) |index| {
                try self.RemoveEdgeById(index);
            }  
            return edges_removed;
        }
        pub fn RemoveEdgeById(self: *Self, id: index_type) !void {
            if (!self.edges.contains(id)) {
                return GraphError.EdgesDoNotExist;
            }
            var node_data = self.edge_list.get(id);
            var node1_list = self.graph.get(node_data.?[0]);
            _ = node1_list.?.orderedRemove(id);
            try self.graph.put(node_data.?[0],node1_list.?);
            if (!self.directed) {
                var node2_list = self.graph.get(node_data.?[1]);
                _ = node2_list.?.orderedRemove(id);
                try self.graph.put(node_data.?[1],node2_list.?);
            }
            _ = self.edges.orderedRemove(id);
            _ = self.edge_list.orderedRemove(id);

        }
        pub fn Print(self: *Self) !void {
            var iterator = self.graph.iterator();
            while (iterator.next()) |entry| {
                std.debug.print("Node: {}\n", .{entry.key_ptr.*});
                var node_itr = entry.value_ptr.iterator();
                while (node_itr.next()) |value| {
                    std.debug.print("\t->Edge To: {}", .{value.value_ptr.*});
                    std.debug.print(" With ID: {}", .{value.key_ptr.*});
                    std.debug.print(" And Weight: {}\n", .{self.edges.get(value.key_ptr.*)});
                }
            }
        }
        pub fn GetNeighbors(self: *Self, id: index_type) !AutoArrayHashMap(index_type,index_type) {
            if (!self.graph.contains(id)) {
                return GraphError.NodesDoNotExist;
            }
            return self.graph.get(id).?;
        }
        pub fn GetEdgeWeight(self: *Self, id: index_type) !weight_type {
            if (!self.edges.contains(id)) {
                return GraphError.EdgesDoNotExist;
            }
            return self.edges.get(id).?;
        }
    };
}


test "nominal-AddNode" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try testing.expect(graph.graph.count() == 1);
    try testing.expect(graph.graph.contains(2));
    try graph.deinit();
}
test "offnominal-AddNode" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try testing.expect(if (graph.AddNode(2)) |_| unreachable else |err| err == GraphError.NodeAlreadyExists);
    try graph.deinit();
}
test "nominal-AddEdgeDirected" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try testing.expect(graph.edges.count() == 2);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 1);
    try testing.expect(graph.edges.get(1).? == 4);
    try testing.expect(graph.edges.get(2).? == 5);
    try testing.expect(graph.edge_list.count() == 2);
    try graph.deinit();
}
test "offnominal-AddEdge" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try testing.expect(if (graph.AddEdge(1,2,3,5)) |_| unreachable else |err| err == GraphError.EdgeAlreadyExists);
    try testing.expect(if (graph.AddEdge(1,6,3,5)) |_| unreachable else |err| err == GraphError.EdgeAlreadyExists);
    try graph.deinit();
}
test "nominal-AddEdgeUndirected" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try testing.expect(graph.edges.count() == 2);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 2);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 2);
    try testing.expect(graph.edges.get(1).? == 4);
    try testing.expect(graph.edges.get(2).? == 5);
    try testing.expect(graph.edge_list.count() == 2);
    try graph.deinit();
}
test "nominal-RemoveNodeDirected" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    _= try graph.RemoveNode(2);
    
    try testing.expect(graph.edges.count() == 0);
    try testing.expect(graph.graph.count() == 1);
    try testing.expect(graph.graph.get(3).?.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "nominal-RemoveNodeUndirected" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    var edges = try graph.RemoveNode(2);
    try testing.expect(edges.items.len == 2);
    try testing.expect(graph.edges.count() == 0);
    try testing.expect(graph.graph.count() == 1);
    try testing.expect(graph.graph.get(3).?.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "offnominal-RemoveNode" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try testing.expect(if (graph.RemoveNode(5)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
}
test "nominal-RemoveEdgeByIdDirected" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveEdgeById(2);
    try testing.expect(graph.edges.count() == 1);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 0);
    try testing.expect(graph.edge_list.count() == 1);
    try graph.deinit();
}
test "nominal-RemoveEdgeByIdUndirected" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveEdgeById(2);
    try graph.RemoveEdgeById(1);
    try testing.expect(graph.edges.count() == 0);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 0);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "offnominal-RemoveEdgeById" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try testing.expect(if (graph.RemoveEdgeById(5)) |_| unreachable else |err| err == GraphError.EdgesDoNotExist);
    try graph.deinit();
}
test "nominal-RemoveEdgesBetween" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    _ = try graph.RemoveEdgesBetween(2,3);
    //try testing.expect(graph.edges.count() == 0);
    var edge_list = graph.graph.get(2).?;
    //try testing.expect(edge_list.count() == 0);
    edge_list = graph.graph.get(3).?;
    //try testing.expect(edge_list.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
    
}
test "offnominal-RemoveEdgesBetween" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try testing.expect(if (graph.RemoveEdgesBetween(5,4)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
    
}
test "nominal-GetNeighbors" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddNode(4);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,2,4,5);
    var neighbors = try graph.GetNeighbors(2);
    try testing.expect(neighbors.get(1).? == 3);
    try testing.expect(neighbors.get(2).? == 4);
    try graph.deinit();
}
test "offnominal-GetNeighbors" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddNode(4);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,2,4,5);
    try testing.expect(if (graph.GetNeighbors(6)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
}
test "nominal-GetEdgeWeight" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddNode(4);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,2,4,5);
    var weight = try graph.GetEdgeWeight(2);
    try testing.expect(weight == 5);
    try graph.deinit();
}
test "offnominal-GetEdgeWeight" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddNode(4);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,2,4,5);
    try testing.expect(if (graph.GetEdgeWeight(4)) |_| unreachable else |err| err == GraphError.EdgesDoNotExist);
    try graph.deinit();
}