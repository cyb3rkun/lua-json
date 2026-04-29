---@type LuxManifest
return {

	name = "json",
	namespace = "luxa.json",
	license = {
		spdx = "MIT",
		files = { "LICENSE" },
	},
	lua_modules = {
		{
			name = "json",
			sources = { "init.lua" },
		},
	},
}
-- NOTE:
-- still many things to work out and refine regarding the package
-- manifest standard, this is only a prototype and there will
-- be breaking changes!
