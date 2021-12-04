const giraffe_graph = @import("graph.zig");
const std = @import("std");
const alloc = std.testing.allocator;
pub fn main() !void {  
    //Type of node/edge id, type of weight, is directed
    var thing = giraffe_graph.Graph(u32,u32,true).init(alloc);
    //Add node with ID
    try thing.AddNode(1);
    try thing.AddNode(2);
    //EdgeID, Node1_ID, Node2_ID, Weight
    try thing.AddEdge(1,2,1,3);
    try thing.AddEdge(2,2,1,4);
    try thing.AddEdge(5,1,2,4);
    try thing.AddNode(3);
    try thing.AddEdge(4,1,3,3);
    _ = try thing.RemoveEdgesBetween(1,3);
    try thing.Print();
}