const std = @import("std");
const lang = @import("lang");
const list = lang.list;

test "int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = "123 475 923";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(int 123)
        \\(int 475)
        \\(int 923)
    );
}

test "symbol" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = "foo bar baz";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(symbol foo)
        \\(symbol bar)
        \\(symbol baz)
    );
}

test "keyword" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = ":foo :bar :baz";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(keyword :foo)
        \\(keyword :bar)
        \\(keyword :baz)
    );
}

test "parens" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = "(+ 3 7 (* 9 5))";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(parens
        \\  (symbol +)
        \\  (int 3)
        \\  (int 7)
        \\  (parens
        \\    (symbol *)
        \\    (int 9)
        \\    (int 5)))
    );
}

test "brackets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = "[[1 2] [3 4]]";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(brackets
        \\  (brackets
        \\    (int 1)
        \\    (int 2))
        \\  (brackets
        \\    (int 3)
        \\    (int 4)))
    );
}

test "entry point" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = "(fn main :args [] :ret i64 :body 0)";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(parens
        \\  (symbol fn)
        \\  (symbol main)
        \\  (keyword :args)
        \\  (brackets)
        \\  (keyword :ret)
        \\  (symbol i64)
        \\  (keyword :body)
        \\  (int 0))
    );
}
