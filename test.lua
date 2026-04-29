local test = require("luxa.test")
-- local lux = require("lux")

---@type TestList
local tests = {
	["test_is_array"] = {
		func = function()
			---@type JSONPrivate
			local is_array = select(2, dofile("init.lua"))["is_array"]
			-- print("is_array= ", lux.inspect(is_array))

			local v1 = (is_array({ "hello", "tata" }))
			-- print(tostring(v1), tostring(c1), tostring(l1))

			local v2 = (is_array({ foo = "foo", bar = "bar" }))
			-- print(tostring(v2), tostring(c2), tostring(l2))

			test.assert_true(v1)
			test.assert_false(v2)
		end,
	},
	["test_esc_str"] = {
		func = function()
			local escstr = select(2, dofile("init.lua"))["esc_str"]
			test.assert_eq(
				escstr("hello/to/you"),
				"hello\\/to\\/you",
				"Failed to escape forward slashes"
			)
			test.assert_eq(
				escstr("tata\n"),
				"tata\\n",
				"Failed to escape newline"
			)
			test.assert_eq(
				escstr('Path: "C:\\Windows"\t\r'),
				'Path: \\"C:\\\\Windows\\"\\t\\r',
				"Failed to escape complex sequence"
			)
			test.assert_eq(
				escstr("\b\f"),
				"\\b\\f",
				"failed to escape controll characters"
			)
			-- Test Null Byte (U+0000)
			test.assert_eq(
				escstr("\0"),
				"\\u0000",
				"Failed to escape Null byte to unicode sequence"
			)

			-- Test Escape character (U+001B)
			test.assert_eq(
				escstr("\27"),
				"\\u001b",
				"Failed to escape ESC character to unicode sequence"
			)

			-- Test multiple control characters in a string
			test.assert_eq(
				escstr("A\1B\2"),
				"A\\u0001B\\u0002",
				"Failed to escape mixed control characters"
			)
		end,
	},

	["test_recursive_descent_encoder"] = {
		func = function()
			---@type JSON
			local m = dofile("init.lua")
			local data = {
				users = {
					{
						id = 1,
						tags = { "lua", "json" },
						online = false,
					},
					{ id = 1, tags = {}, online = true },
				},
				random = nil, -- same as deleting 'random' key
				is_active = 6,
				[5] = "indexed test",
			}
			-- {"is_active":6,"5":"indexed test","users":[{"id":1,"online":false,"tags":["lua","json"]},{"id":1,"online":true,"tags":[]}]}
			local jstr = m.encode(data)
			print(jstr)
			local v1 = jstr:find('"random"')
			test.assert_false(v1)

			test.assert_true(jstr:find('"tags":%["lua","json"%]'))
			test.assert_true(jstr:find('"tags":%[%]'))
			test.assert_true(jstr:find('"id":1'))
			test.assert_true(jstr:find('"online":true'))
			test.assert_true(jstr:find('"is_active":6'))
			test.assert_false(jstr:find('"random":nil'))
			test.assert_false(jstr:find('"5":"indexed_test"'))
			test.assert_eq(jstr:sub(#jstr, #jstr), "}")
		end,
	},

	["test_parse_str"] = {
		func = function()
			---@type JSONPrivate
			local extras = select(2, dofile("init.lua"))
			local parse_str = extras.parse_str

			local s1 = '"Hello world" next'
			local val1, next_pos1 = parse_str(s1, 1)
			test.assert_eq(val1, "Hello world")
			test.assert_eq(next_pos1, 14)

			local s2 = '"say \\"hi\\""'
			local val2 = parse_str(s2, 1)
			test.assert_eq(val2, 'say "hi"')

			local s3 = '"C:\\\\"'
			local val3 = parse_str(s3, 1)
			test.assert_eq(val3, "C:\\")

			local s4 = '"val: \\u001b"'
			local val4 = parse_str(s4, 1)
			test.assert_eq(val4, "val: \27")
		end,
	},
	["unesc_str"] = {
		func = function()
			---@type JSONPrivate
			local extras = select(2, dofile("init.lua"))
			local unesc = extras.unescape_str

			test.assert_eq(unesc("\\nhello"), "\nhello")
			test.assert_eq(unesc("\\t\\rhello"), "\t\rhello")

			test.assert_eq(unesc("\\u0041"), "A")

			test.assert_eq(unesc("Path\\t\\u0042"), "Path\tB")
		end,
	},
	["parse_num"] = {
		func = function()
			---@type JSONPrivate
			local extras = select(2, dofile("init.lua"))
			local parse_num = extras.parse_num

			test.assert_eq(parse_num("452"), 452)
			test.assert_eq(parse_num("-452"), -452)
			test.assert_eq(parse_num("4.52"), 4.52)
			test.assert_eq(parse_num("-45.2"), -45.2)
		end,
	},
	["test_atomic_parsers"] = {
		func = function()
			---@type JSON, JSONPrivate
			local M, extras = dofile("init.lua")

			-- Test Numbers
			local n1, p1 = extras.parse_num("123.45 ", 1)
			test.assert_eq(n1, 123.45)

			-- Test Booleans
			local b1, p2 = M.decode("true")
			local b2, p3 = M.decode("false")
			test.assert_is_true(b1)
			test.assert_is_false(b2)

			-- Test Null
			local nu = M.decode("null")
			test.assert_eq(nu, nil)
		end,
	},
	["test_structural_parsers"] = {
		func = function()
			---@type JSON
			local M = dofile("init.lua")

			-- Test Array
			local arr = M.decode('[1, "two", true]')
			test.assert_eq(arr[1], 1)
			test.assert_eq(arr[2], "two")
			test.assert_true(arr[3])

			-- Test Object
			local obj = M.decode('{"key": "value", "id": 101}')
			test.assert_eq(obj.key, "value")
			test.assert_eq(obj.id, 101)
		end,
	},
	["test_round_trip"] = {
		func = function()
			---@type JSON
			local M = dofile("init.lua")
			local data = {
				name = "Lua JSON",
				version = 1.0,
				features = { "encode", "decode", "unicode" },
				active = true,
				meta = {
					author = "Developer",
					nested_null = nil, -- Should vanish in JSON
				},
			}

			local encoded = M.encode(data)
			local decoded = M.decode(encoded)

			test.assert_eq(decoded.name, data.name)
			test.assert_eq(decoded.version, data.version)
			test.assert_eq(decoded.features[2], "decode")
			test.assert_is_true(decoded.active)
			test.assert_eq(decoded.meta.author, "Developer")
		end,
	},
}

if arg[1] and arg[1] == "--all" then
	test.tests = tests
	test.test_all()
elseif arg[1] then
	test.run_test(arg[1])
end
