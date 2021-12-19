const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const alloc = std.testing.allocator;

pub const GraphError = error{ NodeAlreadyExists, EdgeAlreadyExists, NodesDoNotExist, EdgesDoNotExist };

pub fn Graph(comptime index_type: type, dir: bool) type {
    return struct {
        const Self = @This();
        directed: bool = dir,
        graph: AutoArrayHashMap(index_type, AutoArrayHashMap(index_type, index_type)),
        edge_list: AutoArrayHashMap(index_type, [2]index_type),
        allocator: *mem.Allocator,
        pub fn init(alloc_in: *mem.Allocator) Self {
            return Self{ .graph = AutoArrayHashMap(index_type, AutoArrayHashMap(index_type, index_type)).init(alloc_in), .edge_list = AutoArrayHashMap(index_type, [2]index_type).init(alloc_in), .allocator = alloc_in };
        }
        pub fn deinit(self: *Self) !void {
            var itr = self.graph.iterator();
            while (itr.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.graph.deinit();
            self.edge_list.deinit();
        }

        //Adding a node to the graph via index of node
        pub fn addNode(self: *Self, id: index_type) !void {
            if (!self.graph.contains(id)) {
                try self.graph.put(id, AutoArrayHashMap(index_type, index_type).init(self.allocator));
            } else {
                return GraphError.NodeAlreadyExists;
            }
        }

        //Adding an edge to a graph between nodes n1_id, and n2_id (note that order matters for a directed graph)
        pub fn addEdge(self: *Self, id: index_type, n1_id: index_type, n2_id: index_type) !void {
            if (self.edge_list.contains(id)) {
                return GraphError.EdgeAlreadyExists;
            }
            if (!self.graph.contains(n1_id) or !self.graph.contains(n2_id)) {
                return GraphError.NodesDoNotExist;
            }
            var node1_map = self.graph.get(n1_id);
            try node1_map.?.put(id, n2_id);
            try self.graph.put(n1_id, node1_map.?);
            if (!self.directed) {
                var node2_map = self.graph.get(n2_id);
                try node2_map.?.put(id, n1_id);
                try self.graph.put(n2_id, node2_map.?);
            }
            try self.edge_list.put(id, [2]index_type{ n1_id, n2_id });
        }

        //Remove just the node from the graph hashmap, the edges pointing to it will still be there,
        //graph is thust invalid
        pub fn removeNodeWithoutEdges(self: *Self, id: index_type) !void {
            _ = try self.graph.swapRemove(id);
        }

        //Removes node with all edges going to/fro it
        pub fn removeNodeWithEdges(self: *Self, id: index_type) !ArrayList(index_type) {
            if (!self.graph.contains(id)) {
                return GraphError.NodesDoNotExist;
            }
            if (self.directed) {
                return self.removeNodeWithEdgesDirected(id);
            } else {
                return self.removeNodeWithEdgesUndirected(id);
            }
        }

        //Removes node with all edges for an undirected graph (is faster than removeNodeWithEdgesDirected)
        //Use removeNode, do not call this directly
        fn removeNodeWithEdgesUndirected(self: *Self, id: index_type) !ArrayList(index_type) {
            var n1_remove = self.graph.get(id);
            var iterator_n1 = n1_remove.?.iterator();
            var edges_removed = ArrayList(index_type).init(self.allocator);
            while (iterator_n1.next()) |entry| {
                var edge = entry.key_ptr.*;
                try edges_removed.append(edge);
            }
            for (edges_removed.items) |index| {
                try self.removeEdgeByID(index);
            }
            n1_remove.?.deinit();

            //swap remove chosen because its faster than orderedRemove
            _ = self.graph.swapRemove(id);
            return edges_removed;
        }

        //Removes node with all edges for a directed graph
        //Use removeNode, do not call this directly
        fn removeNodeWithEdgesDirected(self: *Self, id: index_type) !ArrayList(index_type) {
            var iterator = self.graph.iterator();
            var edges_removed = ArrayList(index_type).init(self.allocator);

            //removal of all edges going to the given node
            while (iterator.next()) |entry| {
                var node = entry.key_ptr.*;
                var removal = try self.removeEdgesBetween(node, id);
                try edges_removed.appendSlice(removal.items);
                removal.deinit();
            }

            //removal of all edges going from the given node
            var node_list = self.graph.get(id);
            var node_iterator = node_list.?.iterator();
            while (node_iterator.next()) |entry| {
                var edge = entry.key_ptr.*;
                try self.removeEdgeByID(edge);
                try edges_removed.append(edge);
            }
            node_list.?.deinit();
            _ = self.graph.swapRemove(id);
            return edges_removed;
        }

        //Remove the edges between n1 and n2 (order matters for a directed graph)
        pub fn removeEdgesBetween(self: *Self, n1_id: index_type, n2_id: index_type) !ArrayList(index_type) {
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
                try self.removeEdgeByID(index);
            }
            return edges_removed;
        }

        //Remove the edge with the given ID
        pub fn removeEdgeByID(self: *Self, id: index_type) !void {
            if (!self.edge_list.contains(id)) {
                return GraphError.EdgesDoNotExist;
            }
            var node_data = self.edge_list.get(id);
            var node1_list = self.graph.get(node_data.?[0]);
            _ = node1_list.?.swapRemove(id);
            try self.graph.put(node_data.?[0], node1_list.?);
            if (!self.directed) {
                var node2_list = self.graph.get(node_data.?[1]);
                _ = node2_list.?.swapRemove(id);
                try self.graph.put(node_data.?[1], node2_list.?);
            }
            _ = self.edge_list.swapRemove(id);
        }

        //Print the graph
        pub fn print(self: *Self) !void {
            var iterator = self.graph.iterator();
            while (iterator.next()) |entry| {
                std.debug.print("Node: {}\n", .{entry.key_ptr.*});
                var node_itr = entry.value_ptr.iterator();
                while (node_itr.next()) |value| {
                    std.debug.print("\t->Edge To: {}", .{value.value_ptr.*});
                    std.debug.print(" With ID: {}", .{value.key_ptr.*});
                }
            }
        }

        //Get the neighbors of a given node (returns the hashmap in graph hashmap)
        pub fn GetNeighbors(self: *Self, id: index_type) !AutoArrayHashMap(index_type, index_type) {
            if (!self.graph.contains(id)) {
                return GraphError.NodesDoNotExist;
            }
            return self.graph.get(id).?;
        }

        //Returns 1 as default edge weight
        pub fn getEdgeWeight(self: *Self, id: index_type) !u32 {
            if (!self.edge_list.contains(id)) {
                return GraphError.EdgesDoNotExist;
            }
            return 1;
        }
    };
}

test "nominal-addNode" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try testing.expect(graph.graph.count() == 1);
    try testing.expect(graph.graph.contains(2));
    try graph.deinit();
}
test "offnominal-addNode" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try testing.expect(if (graph.addNode(2)) |_| unreachable else |err| err == GraphError.NodeAlreadyExists);
    try graph.deinit();
}
test "nominal-addEdgeDirected" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    try testing.expect(graph.edge_list.count() == 2);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 1);
    try testing.expect(graph.edge_list.count() == 2);
    try graph.deinit();
}
test "offnominal-addEdge" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try testing.expect(if (graph.addEdge(1, 2, 3)) |_| unreachable else |err| err == GraphError.EdgeAlreadyExists);
    try graph.deinit();
}
test "nominal-addEdgeUndirected" {
    var graph = Graph(u32, false).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    try testing.expect(graph.edge_list.count() == 2);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 2);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 2);
    try graph.deinit();
}
test "nominal-removeNodeWithEdgesDirected" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    var edge_list = try graph.removeNodeWithEdges(2);
    edge_list.deinit();
    try testing.expect(graph.edge_list.count() == 0);
    try testing.expect(graph.graph.count() == 1);
    try testing.expect(graph.graph.get(3).?.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "nominal-removeNodeWithEdgesUndirected" {
    var graph = Graph(u32, false).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    var edges = try graph.removeNodeWithEdges(2);
    try testing.expect(edges.items.len == 2);
    try testing.expect(graph.edge_list.count() == 0);
    try testing.expect(graph.graph.count() == 1);
    try testing.expect(graph.graph.get(3).?.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
    edges.deinit();
}
test "offnominal-removeNodeWithEdges" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try testing.expect(if (graph.removeNodeWithEdges(5)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
}
test "nominal-removeEdgeByIDDirected" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    try graph.removeEdgeByID(2);
    try testing.expect(graph.edge_list.count() == 1);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 1);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 0);
    try testing.expect(graph.edge_list.count() == 1);
    try graph.deinit();
}
test "nominal-removeEdgeByIDUndirected" {
    var graph = Graph(u32, false).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    try graph.removeEdgeByID(2);
    try graph.removeEdgeByID(1);
    try testing.expect(graph.edge_list.count() == 0);
    var edge_list = graph.graph.get(2).?;
    try testing.expect(edge_list.count() == 0);
    edge_list = graph.graph.get(3).?;
    try testing.expect(edge_list.count() == 0);
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "offnominal-removeEdgeByID" {
    var graph = Graph(u32, false).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    try testing.expect(if (graph.removeEdgeByID(5)) |_| unreachable else |err| err == GraphError.EdgesDoNotExist);
    try graph.deinit();
}
test "nominal-removeEdgesBetween" {
    var graph = Graph(u32, false).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    var edges = try graph.removeEdgesBetween(2, 3);
    edges.deinit();
    var edge_list = graph.graph.get(2).?;
    edge_list = graph.graph.get(3).?;
    try testing.expect(graph.edge_list.count() == 0);
    try graph.deinit();
}
test "offnominal-removeEdgesBetween" {
    var graph = Graph(u32, false).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 3, 2);
    try testing.expect(if (graph.removeEdgesBetween(5, 4)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
}
test "nominal-GetNeighbors" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addNode(4);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 2, 4);
    var neighbors = try graph.GetNeighbors(2);
    try testing.expect(neighbors.get(1).? == 3);
    try testing.expect(neighbors.get(2).? == 4);
    try graph.deinit();
}
test "offnominal-GetNeighbors" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addNode(4);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 2, 4);
    try testing.expect(if (graph.GetNeighbors(6)) |_| unreachable else |err| err == GraphError.NodesDoNotExist);
    try graph.deinit();
}
test "nominal-getEdgeWeight" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addNode(4);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 2, 4);
    var weight = try graph.getEdgeWeight(2);
    try testing.expect(weight == 1);
    try graph.deinit();
}
test "offnominal-getEdgeWeight" {
    var graph = Graph(u32, true).init(alloc);
    try graph.addNode(2);
    try graph.addNode(3);
    try graph.addNode(4);
    try graph.addEdge(1, 2, 3);
    try graph.addEdge(2, 2, 4);
    try testing.expect(if (graph.getEdgeWeight(4)) |_| unreachable else |err| err == GraphError.EdgesDoNotExist);
    try graph.deinit();
}
