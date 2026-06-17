-- -@diagnostic disable: unused-function, unused-local
---@class JSON
---convert lua data to json string
---@field encode fun(t: table): string
---parse json string into lua table
---@field decode fun(s: string, pos: number?): table
local M = {}

-- Define maps once as upvalues to avoid recreation overhead
local escape_map = {
	["\\"] = "\\\\",
	['"'] = '\\"',
	["/"] = "\\/",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local unescape_map = {
	["\\"] = "\\",
	['"'] = '"',
	["/"] = "/",
	["b"] = "\b",
	["f"] = "\f",
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "\t",
}

---@param t table
---@return boolean is_array, number count, number length
local function Is_array(t)
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false, i, #t end
	end
	return true, i, #t
end

---@param s string
local function Escape_str(s)
	return (
		s:gsub('[%c\\"/]', function(c)
			if escape_map[c] then return escape_map[c] end
			return string.format("\\u%04x", string.byte(c))
		end)
	)
end

-- Encode implementation
local encode_value
local function encode_str(s) return '"' .. Escape_str(s) .. '"' end

local function encode_array(t)
	local res = {}
	local n = 0
	for _, v in ipairs(t) do
		n = n + 1
		res[n] = encode_value(v)
	end
	return "[" .. table.concat(res, ",") .. "]"
end

local function encode_obj(t)
	local res = {}
	local n = 0
	for k, v in pairs(t) do
		local tp = type(k)
		if (tp == "boolean") or (tp == "nil") or (tp == "table") then
			error("invalid type as key", 2)
		end

		local key = type(k) == "string" and k or tostring(k)
		n = n + 1
		res[n] = encode_str(key) .. ":" .. encode_value(v)
	end
	return "{" .. table.concat(res, ",") .. "}"
end

encode_value = function(v)
	local t = type(v)
	if t == "string" then return encode_str(v) end
	if t == "number" then return tostring(v) end
	if t == "boolean" then return tostring(v) end
	if t == "nil" then return "null" end
	if t == "table" then
		if Is_array(v) then
			return encode_array(v)
		else
			return encode_obj(v)
		end
	end
	error("Cannot encode type: " .. t)
end

function M.encode(v) return encode_value(v) end

---@param s string
local function Unescape_str(s)
	local res = s:gsub('\\([\\"/bfnrt])', unescape_map)
	res = res:gsub(
		"\\u(%x%x%x%x)",
		function(hex) return string.char(tonumber(hex, 16)) end
	)
	return res
end

local parse_val, parse_array, parse_obj, parse_str, parse_num, parse_bool, parse_null

-- Capture index directly via matching capture '()'
local function skip_whitespace(s, pos)
	return s:match("^%s*()", pos)
end

---@param s string
---@param pos number?
parse_str = function(s, pos)
	pos = pos or 1
	local start_pos = pos + 1
	local i = start_pos
	local has_escape = false

	while true do
		-- Jump directly to the next quote or backslash
		local next_i = s:find('["\\]', i)
		if not next_i then
			error("Expected a closing quote at position " .. i, 2)
		end

		local b = s:byte(next_i)
		if b == 34 then -- Quote '"'
			local substring = s:sub(start_pos, next_i - 1)
			if has_escape then
				return Unescape_str(substring), next_i + 1
			else
				return substring, next_i + 1
			end
		else -- Backslash '\\'
			has_escape = true
			i = next_i + 2 -- Skip the escaped character
		end
	end
end

---@param s string
---@param pos number
parse_null = function(s, pos)
	if s:sub(pos + 1, pos + 3) == "ull" then return nil, pos + 4 end
	error("Expected null at " .. pos)
end

---@param s string
---@param pos number?
parse_num = function(s, pos)
	-- Capture both value and the next position inside match
	local val, next_pos = s:match("^(-?%d+%.?%d*[eE]?[+-]?%d*)()", pos)
	if not val then error("Expected number at position " .. pos) end
	return tonumber(val), next_pos
end

---@param s string
---@param pos number
---@param b number First character byte
parse_bool = function(s, pos, b)
	if b == 116 then -- 't'
		if s:sub(pos + 1, pos + 3) == "rue" then return true, pos + 4 end
	else -- 'f'
		if s:sub(pos + 1, pos + 4) == "alse" then return false, pos + 5 end
	end
	error("Expected boolean at " .. pos)
end

---@param s string
---@param pos number
parse_array = function(s, pos)
	local parts = {}
	local i = skip_whitespace(s, pos + 1)

	-- Handle empty array
	if s:byte(i) == 93 then return parts, i + 1 end

	local len = #s
	local n = 0
	while i <= len do
		local val, next_pos = parse_val(s, i)
		n = n + 1
		parts[n] = val

		i = skip_whitespace(s, next_pos)
		local b = s:byte(i)

		if b == 93 then -- ']'
			return parts, i + 1
		elseif b == 44 then -- ','
			i = skip_whitespace(s, i + 1)
		else
			error("Expected ',' or ']' at position " .. i)
		end
	end
	error("Unclosed array at " .. pos)
end

---@param s string
---@param pos number
parse_obj = function(s, pos)
	local obj = {}
	local i = skip_whitespace(s, pos + 1)

	-- Handle empty object
	if s:byte(i) == 125 then return obj, i + 1 end

	local len = #s
	while i <= len do
		local key, next_i = parse_str(s, i)
		i = skip_whitespace(s, next_i)

		if s:byte(i) ~= 58 then error("Expected ':' at position " .. i) end -- 58 = ':'

		i = skip_whitespace(s, i + 1)
		local val, next_val_i = parse_val(s, i)
		obj[key] = val
		i = skip_whitespace(s, next_val_i)

		local b = s:byte(i)
		if b == 125 then -- 125 = "}"
			return obj, i + 1
		elseif b == 44 then -- 44 = ","
			i = skip_whitespace(s, i + 1)
		else
			error("Expected ',' or '}' at position " .. i)
		end
	end
	error("Unclosed object starting at " .. pos)
end

parse_val = function(s, pos)
	pos = skip_whitespace(s, pos)
	local b = s:byte(pos)
	if not b then error("Unexpected end of input") end

	if b == 34 then return parse_str(s, pos) end -- '"'
	if b == 123 then return parse_obj(s, pos) end -- '{'
	if b == 91 then return parse_array(s, pos) end -- '['
	if b == 116 or b == 102 then return parse_bool(s, pos, b) end -- 't' or 'f'
	if b == 110 then return parse_null(s, pos) end -- 'n'
	if (b >= 48 and b <= 57) or b == 45 then return parse_num(s, pos) end -- '0'-'9' or '-'

	error("Unexpected character '" .. string.char(b) .. "' at " .. pos)
end

function M.decode(s, pos)
	pos = pos or 1
	return parse_val(s, pos)
end

local extras = {
	is_array = Is_array,
	esc_str = Escape_str,
	unescape_str = Unescape_str,
	parse_str = parse_str,
	parse_num = parse_num,
	parse_obj = parse_obj,
	parse_null = parse_null,
	parse_bool = parse_bool,
}
return M, extras

