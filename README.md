# json

A pure Lua JSON encoder and decoder built on a recursive descent parser. No dependencies.

## Installation

Install with [lux](https://github.com/LuaLuxa):

```lua
{
    "cyb3rkun/lua-json",
    opts = { scope = "local" },
}
```

> **Note:** lux and the LuaLuxa ecosystem are not yet publicly released. Manual installation is available in the meantime — just drop `init.lua` into your project.

## Usage

```lua
local json = require("luxa.json")

-- Encode
local encoded = json.encode({ name = "lua", version = 5, active = true })
-- {"name":"lua","version":5,"active":true}

-- Decode
local decoded = json.decode('{"name":"lua","version":5,"active":true}')
-- { name = "lua", version = 5, active = true }

-- Arrays
local arr = json.encode({ 1, 2, 3 })
-- [1,2,3]

-- Round-trip
local data = { features = { "encode", "decode" }, version = 1.0 }
local result = json.decode(json.encode(data))
```

## API

### `json.encode(value)`

Encodes a Lua value as a JSON string. Supports strings, numbers, booleans, `nil` (encoded as `null`), and tables (encoded as arrays or objects based on structure).

Throws an error if a table key is a boolean, nil, or table.

### `json.decode(s, pos?)`

Parses a JSON string into a Lua value. `pos` is an optional starting position (defaults to 1).

Supports all JSON types: objects, arrays, strings, numbers, booleans, and null. JSON `null` is decoded as Lua `nil`.

## Type Mapping

| Lua | JSON |
|---|---|
| `string` | `string` |
| `number` | `number` |
| `boolean` | `boolean` |
| `nil` | `null` |
| sequential table | `array` |
| mixed/keyed table | `object` |

## Known Limitations

- **Unicode above U+00FF**: `\uXXXX` escape sequences are decoded via `string.char`, which is limited to single-byte values in standard Lua. Characters above U+00FF will not decode correctly. Basic unicode escape sequences (e.g. `\u001b`) work fine and are covered by the test suite.
- **NaN / Infinity**: Not valid JSON. `math.huge` and `0/0` will not encode correctly.
- **nil table keys**: Table keys that are `nil`, boolean, or table will throw on encode. `nil` values in tables are silently dropped, matching standard JSON behaviour.
- **Number keys**: Numeric table keys are encoded as strings (e.g. `[5] = "val"` becomes `"5": "val"`).

## License

MIT
