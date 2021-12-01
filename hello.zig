const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const test_allocator = std.testing.allocator;
pub fn Graph (comptime index_type: type, comptime weight_type: type, dir: bool) type{
    return struct {
        const Self = @This();
        directed:bool = dir,
        graph: AutoArrayHashMap(index_type, AutoArrayHashMap(index_type, index_type)),
        edges: AutoArrayHashMap(index_type, weight_type),
        edge_list: AutoArrayHashMap(index_type, [2]index_type),
        pub fn init() Self {
            return Self {
                .graph = AutoArrayHashMap(index_type, AutoArrayHashMap(index_type, index_type)).init(test_allocator),
                .edges = AutoArrayHashMap(index_type, weight_type).init(test_allocator),
                .edge_list = AutoArrayHashMap(index_type, [2]index_type).init(test_allocator)
            };

        }
        pub fn AddNode(self: *Self, id: index_type) !void {
            try self.graph.put(id, AutoArrayHashMap(index_type, index_type).init(test_allocator));
        }
        pub fn AddEdge(self: *Self, id: index_type, n1_id: index_type, n2_id: index_type, w: weight_type) !void {
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
                if (node == id) {
                    try self.RemoveEdgeById(edge);
                }
                
            }
            _ = self.graph.remove(id);
        }
        pub fn RemoveEdgesBetween(self: *Self, n1_id: index_type, n2_id: index_type) !void {
            var n1_remove = self.graph.get(n1_id);
            var iterator_n1 = n1_remove.?.iterator();
            var replacement = n1_remove;
            while (iterator_n1.next()) |entry| {
                var node = entry.value;
                var edge = entry.key;
                try self.RemoveEdgeById(edge);
            }  
        }
        pub fn RemoveEdgeById(self: *Self, id: index_type) !void {
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
                    try stdout.print(" With Edge: {}", .{value.key});
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


pub fn main() !void {
    var thing = Graph(u32,u32,true).init();
    try thing.AddNode(1);
    try thing.AddNode(2);
    try thing.AddEdge(1,2,1,3);
    try thing.AddEdge(2,2,1,4);
    try thing.AddEdge(5,1,2,4);
    try thing.RemoveNode(2);
    try thing.AddNode(3);
    try thing.AddEdge(4,1,3,3);
    try thing.RemoveEdgesBetween(1,3);
    try thing.AddEdge(4,1,3,3);
    try thing.Print();
}