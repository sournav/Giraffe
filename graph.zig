const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const alloc = std.heap.page_allocator;
const GraphError = error{
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
        pub fn RemoveNode(self: *Self, id: index_type) !void {
           if (!self.graph.contains(id)) {
               return GraphError.NodesDoNotExist;
           }
           if (self.directed) {
               try self.RemoveNodeDirected(id);
           }
           else {
               try self.RemoveNodeUndirected(id);
           }
        }
        fn RemoveNodeUndirected(self: *Self, id: index_type) !void {
            var n1_remove = self.graph.get(id);
            var iterator_n1 = n1_remove.?.iterator();
            while (iterator_n1.next()) |entry| {
                var node = entry.value;
                var edge = entry.key;
                try self.RemoveEdgeById(edge);
            }
            _ = self.graph.remove(id);
        }
        fn RemoveNodeDirected(self: *Self, id: index_type) !void {
            var iterator = self.graph.iterator();
            const stdout = std.io.getStdOut().outStream();
            while (iterator.next()) |entry| {
                var node = entry.key;
                try self.RemoveEdgesBetween(node,id);
            }
            var node_list = self.graph.get(id);
            var node_iterator = node_list.?.iterator();
            while (node_iterator.next()) |entry| {
                var edge = entry.key;
                var node = entry.value;
                try self.RemoveEdgeById(edge);
            }
            _ = self.graph.remove(id);
        }
        pub fn RemoveEdgesBetween(self: *Self, n1_id: index_type, n2_id: index_type) !void {
            if (!self.graph.contains(n1_id) or !self.graph.contains(n2_id)) {
                return GraphError.NodesDoNotExist;
            }
            var n1_remove = self.graph.get(n1_id);
            var iterator_n1 = n1_remove.?.iterator();
            var replacement = n1_remove;
            while (iterator_n1.next()) |entry| {
                var node = entry.value;
                var edge = entry.key;
                if (node == n2_id) {
                    try self.RemoveEdgeById(edge);
                }
            }  
        }
        pub fn RemoveEdgeById(self: *Self, id: index_type) !void {
            if (!self.edges.contains(id)) {
                return GraphError.EdgesDoNotExist;
            }
            var node_data = self.edge_list.get(id);
            var node1_list = self.graph.get(node_data.?[0]);
            _ = node1_list.?.remove(id);
            try self.graph.put(node_data.?[0],node1_list.?);
            if (!self.directed) {
                var node2_list = self.graph.get(node_data.?[1]);
                _ = node2_list.?.remove(id);
                try self.graph.put(node_data.?[1],node2_list.?);
            }
            _ = self.edges.remove(id);
            _ = self.edge_list.remove(id);
        }
        pub fn Print(self: *Self) !void {
            var iterator = self.graph.iterator();
            const stdout = std.io.getStdOut().outStream();
            while (iterator.next()) |entry| {
                try stdout.print("Node: {}\n", .{entry.key});
                var node_itr = entry.value.iterator();
                while (node_itr.next()) |value| {
                    try stdout.print("\t->Edge To: {}", .{value.value});
                    try stdout.print(" With ID: {}", .{value.key});
                    try stdout.print(" And Weight: {}\n", .{self.edges.get(value.key)});
                }
            }
        }
        pub fn GetNeighbors(self: *Self, id: index_type) AutoArrayHashMap(index_type,index_type) {
            return self.graph.get(id).?;
        }
        pub fn GetEdgeWeight(self: *Self, id: index_type) weight_type {
            return edges.get(id).?;
        }
    };
}

test "nominal-AddNode" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    testing.expect(graph.graph.count() == 1);
    testing.expect(graph.graph.contains(2));
    try graph.deinit();
}
test "offnominal-AddNode" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    testing.expect(if (graph.AddNode(2)) |_| unreachable else |err| err == GraphError.NodeAlreadyExists);
    try graph.deinit();
}
test "nominal-AddEdgeDirected" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    testing.expect(graph.edges.count() == 2);
    var edge_list = graph.graph.get(2).?;
    testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    testing.expect(edge_list.count() == 1);
    testing.expect(graph.edges.get(1).? == 4);
    testing.expect(graph.edges.get(2).? == 5);
    testing.expect(graph.edge_list.count() == 2);
    try graph.deinit();
}
test "offnominal-AddEdge" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    testing.expect(if (graph.AddEdge(1,2,3,5)) |_| unreachable else |err| err == GraphError.EdgeAlreadyExists);
    testing.expect(if (graph.AddEdge(1,6,3,5)) |_| unreachable else |err| err == GraphError.EdgeAlreadyExists);
    try graph.deinit();
}
test "nominal-AddEdgeUndirected" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    testing.expect(graph.edges.count() == 2);
    var edge_list = graph.graph.get(2).?;
    testing.expect(edge_list.count() == 2);
    edge_list = graph.graph.get(3).?;
    testing.expect(edge_list.count() == 2);
    testing.expect(graph.edges.get(1).? == 4);
    testing.expect(graph.edges.get(2).? == 5);
    testing.expect(graph.edge_list.count() == 2);
    try graph.deinit();
}
test "nominal-RemoveNodeDirected" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveNode(2);
    
    testing.expect(graph.edges.count() == 0);
    testing.expect(graph.graph.count() == 1);
    testing.expect(graph.graph.get(3).?.count() == 0);
    testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "nominal-RemoveNodeUndirected" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveNode(2);
    testing.expect(graph.edges.count() == 0);
    testing.expect(graph.graph.count() == 1);
    testing.expect(graph.graph.get(3).?.count() == 0);
    testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "offnominal-RemoveNode" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    testing.expect(if (graph.RemoveNode(5)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
}
test "nominal-RemoveEdgeByIdDirected" {
    var graph = Graph(u32, u32, true).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveEdgeById(2);
    testing.expect(graph.edges.count() == 1);
    var edge_list = graph.graph.get(2).?;
    testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    testing.expect(edge_list.count() == 0);
    testing.expect(graph.edge_list.count() == 1);
    try graph.deinit();
}
test "nominal-RemoveEdgeByIdUndirected" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveEdgeById(2);
    testing.expect(graph.edges.count() == 1);
    var edge_list = graph.graph.get(2).?;
    testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    testing.expect(edge_list.count() == 1);
    testing.expect(graph.edge_list.count() == 1);
    try graph.deinit();
}
test "offnominal-RemoveEdgeById" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    testing.expect(if (graph.RemoveEdgeById(5)) |_| unreachable else |err| err == GraphError.EdgesDoNotExist);
    try graph.deinit();
}
test "nominal-RemoveEdgesBetween" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    try graph.RemoveEdgesBetween(2,3);
    testing.expect(graph.edges.count() == 0);
    var edge_list = graph.graph.get(2).?;
    testing.expect(edge_list.count() == 0);
    edge_list = graph.graph.get(3).?;
    testing.expect(edge_list.count() == 0);
    testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
    
}
test "offnominal-RemoveEdgesBetween" {
    var graph = Graph(u32, u32, false).init(alloc);
    try graph.AddNode(2);
    try graph.AddNode(3);
    try graph.AddEdge(1,2,3,4);
    try graph.AddEdge(2,3,2,5);
    testing.expect(if (graph.RemoveEdgesBetween(5,4)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
    
}