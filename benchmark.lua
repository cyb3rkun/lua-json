local json = require("js")
local clock = os.clock

local f, err = io.open("b.json", "r")
if err then
	print("Error Reading file: " .. err)
	return
end
if not f then
	print("Couldn't Read File")
	return
end

local big = f:read("*a")
f:close()
print(_VERSION)
local times = {}
for i = 1, 10 do
	collectgarbage("collect")
	local t = clock()
	for _ = 1, 100 do
		json.decode(big)
	end
	times[i] = clock() - t
end
local sum = 0
for _, v in ipairs(times) do
	sum = sum + v
end
local avg = sum / #times
print(avg)
