const std = @import("std");
const Map = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const TypeInfo = std.builtin.TypeInfo;
const StructField = TypeInfo.StructField;
const Declaration = TypeInfo.Declaration;
const List = @import("list.zig").List;

const Entity = usize;

fn Component(comptime T: type) type {
    return struct {
        data: List(T),
        entity_to_data: Map(Entity, usize),
        entities: List(Entity),

        const Self = @This();

        fn init(allocator: *Allocator) Self {
            return .{
                .data = List(T).init(allocator),
                .entity_to_data = Map(Entity, usize).init(allocator),
                .entities = List(Entity).init(allocator),
            };
        }

        fn write(self: *Self, entity: Entity) !*T {
            const result = try self.data.addOne();
            try self.entity_to_data.putNoClobber(entity, result.index);
            _ = try self.entities.insert(entity);
            return result.ptr;
        }
    };
}

fn Wrap(comptime types: []const type, with: fn (comptime type) type) type {
    var fields: [types.len]StructField = undefined;
    for (types) |T, i| {
        fields[i] = StructField{
            .name = @typeName(T),
            .field_type = with(T),
            .default_value = null,
            .is_comptime = false,
            .alignment = 8,
        };
    }
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &[_]Declaration{},
            .is_tuple = false,
        },
    });
}

const Config = struct {
    components: []const type,
};

fn ConstPtr(comptime T: type) type {
    return *const T;
}

fn Ptr(comptime T: type) type {
    return *T;
}

fn ReadGroup(comptime types: []const type) type {
    return Wrap(types, ConstPtr);
}

fn WriteGroup(comptime types: []const type) type {
    return Wrap(types, Ptr);
}

fn ReadIterator(comptime T: type) type {
    const Entry = struct {
        data: *const T,
        entity: Entity,
    };

    return struct {
        data: []const T,
        entities: []const Entity,
        i: usize,

        const Self = @This();

        pub fn next(self: *Self) ?Entry {
            const i = self.i;
            if (i >= self.data.len)
                return null;
            self.i += 1;
            return Entry{
                .data = &self.data[i],
                .entity = self.entities[i],
            };
        }
    };
}

pub fn Database(comptime config: Config) type {
    const Components = Wrap(config.components, Component);

    return struct {
        parent_allocator: *Allocator,
        arena: *Arena,
        components: Components,
        next_entity: usize,

        const Self = @This();

        pub fn init(allocator: *Allocator) !Self {
            const arena = try allocator.create(Arena);
            arena.* = Arena.init(allocator);
            var components: Components = undefined;
            inline for (config.components) |T, i| {
                @field(components, @typeName(T)) = Component(T).init(&arena.allocator);
            }
            return Self{
                .parent_allocator = allocator,
                .arena = arena,
                .components = components,
                .next_entity = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
            self.parent_allocator.destroy(self.arena);
        }

        pub fn createEntity(self: *Self) Entity {
            const index = self.next_entity;
            self.next_entity += 1;
            return index;
        }

        pub fn read(self: Self, entity: Entity, comptime T: type) *const T {
            const component = &@field(self.components, @typeName(T));
            const index = component.entity_to_data.get(entity).?;
            return &component.data.items[index];
        }

        pub fn write(self: *Self, entity: Entity, comptime T: type) !*T {
            return try @field(self.components, @typeName(T)).write(entity);
        }

        pub fn readGroup(self: Self, entity: Entity, comptime types: []const type) ReadGroup(types) {
            var group: ReadGroup(types) = undefined;
            inline for (types) |T|
                @field(group, @typeName(T)) = self.read(entity, T);
            return group;
        }

        pub fn writeGroup(self: *Self, entity: Entity, comptime types: []const type) !WriteGroup(types) {
            var group: WriteGroup(types) = undefined;
            inline for (types) |T|
                @field(group, @typeName(T)) = try self.write(entity, T);
            return group;
        }

        pub fn readIterator(self: Self, comptime T: type) ReadIterator(T) {
            const component = &@field(self.components, @typeName(T));
            return ReadIterator(T){
                .data = component.data.slice(),
                .entities = component.entities.slice(),
                .i = 0,
            };
        }
    };
}
