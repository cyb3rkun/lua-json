-- -@diagnostic disable: unused-function, unused-local
---@class JSON
---convert lua data to jsong string
---@field encode fun(t: table): string
---parse json string into lua table
---@field decode fun(s: string, pos: number?): table
local M = {}

---@param t table
---@return boolean is_array, number count, number length
local function Is_array(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count == #t, count, #t
end

---@param s string
local function Escape_str(s)
	local map = {
		["\\"] = "\\\\",
		['"'] = '\\"',
		["/"] = "\\/",
		["\b"] = "\\b",
		["\f"] = "\\f",
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
	}
	-- NOTE:
	-- %c matches control characters
	return (
		s:gsub('[%c\\"/]', function(c)
			-- common escape sequences
			if map[c] then return map[c] end
			-- NOTE:
			-- \\u literal backslash followed by u '\u' JSON prefix for
			-- unicode characters.
			-- %04x:
			--	x converts to lowercase hex
			-- 	4 ensures 4 characters wide
			-- 	0 pads with 0 instead of spaces.
			-- byte(c) converts character to it's ascii or ISO numerical
			-- value
			-- this should escape any unicode character
			return string.format("\\u%04x", string.byte(c))
		end)
	)
end
-- NOTE: encode
local encode_value
local function encode_str(s) return '"' .. Escape_str(s) .. '"' end

local function encode_array(t)
	local res = {}
	for _, v in ipairs(t) do
		table.insert(res, encode_value(v))
	end
	return "[" .. table.concat(res, ",") .. "]"
end

local function encode_obj(t)
	local res = {}
	for k, v in pairs(t) do
		local tp = type(k)
		if
			(tp == "boolean")
			or (tp == "nil")
			or (tp == "table")
		then
			error("invalid type as key", 2)
		end

		local key = type(k) == "string" and k or tostring(k)
		table.insert(res, encode_str(key) .. ":" .. encode_value(v))
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
	local map = {
		["\\"] = "\\",
		['"'] = '"',
		["/"] = "/",
		["b"] = "\b",
		["f"] = "\f",
		["n"] = "\n",
		["r"] = "\r",
		["t"] = "\t",
	}
	local res = s:gsub('\\([\\"/bfnrt])', map)

	res = res:gsub(
		"\\u(%x%x%x%x)",
		function(hex) return string.char(tonumber(hex, 16)) end
	)
	return res
end
local parse_val, parse_array, parse_obj, parse_str, parse_num, parse_bool, parse_null
---@param s string
---@param pos number?
parse_str = function(s, pos)
	pos = pos or 1
	local i = pos + 1
	local res = ""

	while i <= #s do
		local char = s:sub(i, i)
		if char == '"' then
			return Unescape_str(res), i + 1
		elseif char == "\\" then
			res = res .. s:sub(i, i + 1)
			i = i + 2
		else
			res = res .. char
			i = i + 1
		end
	end

	error("Expected a closing quote at position " .. i, 2)
	-- return Unescape_str()
end

---@param s string
---@param pos number
parse_null = function(s, pos)
	if s:sub(pos, pos + 3) == "null" then return nil, pos + 4 end
	error("Expected null at " .. pos)
end

---@param s string
---@param pos number?
parse_num = function(s, pos)
	pos = pos or 1
	local res = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
	if not res then error("Expected number at position" .. pos) end
	return tonumber(res), pos + #res
end
---
---@param s string
---@param pos number
parse_bool = function(s, pos)
	if s:sub(pos, pos + 3) == "true" then
		return true, pos + 4
	elseif s:sub(pos, pos + 4) == "false" then
		return false, pos + 5
	end
	error("Expected boolean at " .. pos)
end

local function skip_whitespace(s, pos)
	local start, stop = s:find("^%s*", pos)
	return stop + 1
end

-- local parse_val
---@param s string
---@param pos number
parse_array = function(s, pos)
	local parts = {}
	-- pos = pos or 1
	-- local i = pos + 1
	local i = skip_whitespace(s, pos + 1)

	-- if s:sub(i, i) == "]" then return parts, i + 1 end
	while i <= #s do
		local val, next_pos = parse_val(s, i)
		table.insert(parts, val)

		i = skip_whitespace(s, next_pos)

		local char = s:sub(i, i)

		if char == "]" then return parts, i + 1
		elseif char == "," then i = i + 1 i = skip_whitespace(s, i)
		else error("Expected ',' or ']' at position" .. i) end
	end
	error("Unclosed array at " .. pos)
end

---@param s string
---@param pos number
parse_obj = function(s, pos)
	local obj = {}
	pos = pos or 1
	local i = pos + 1
	i = skip_whitespace(s, i)

	if s:sub(i, i) == "}" then return obj, i + 1 end
	while i <= #s do
		local key, next_i = parse_str(s, i)
		i = skip_whitespace(s, next_i) -- skip whitespace between string key and ':'

		if s:sub(i, i) ~= ":" then
			error("Expected ':' at position " .. i)
		end
		i = i + 1 -- Skip ':'
		i = skip_whitespace(s, i)
		local val, next_val_i = parse_val(s, i)
		obj[key] = val
		i = skip_whitespace(s, next_val_i)

		local char = s:sub(i, i)
		if char == "}" then
			return obj, i + 1
		elseif char == "," then
			i = i + 1 -- skip ','
			i = skip_whitespace(s, i)
		else
			error("expected ',' or '}' at position: " .. i)
		end
	end
	error("Unclosed object starting at " .. pos)
end

parse_val = function(s, pos)
	pos = skip_whitespace(s, pos)
	local char = s:sub(pos, pos)

	if char == '"' then return parse_str(s, pos) end
	if char == "[" then return parse_array(s, pos) end
	if char == "{" then return parse_obj(s, pos) end
	if char == "t" or char == "f" then return parse_bool(s, pos) end
	if char == "n" then return parse_null(s, pos) end
	if char:find("[%d%-]") then return parse_num(s, pos) end

	error("Unexpected character '" .. char .. "' at " .. pos)
end
function M.decode(s, pos)
	pos = pos or 1

	return parse_val(s, 1)
end

---@class JSONPrivate
---@field is_array fun(t: table): boolean
---@field esc_str fun(s: string): string
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
