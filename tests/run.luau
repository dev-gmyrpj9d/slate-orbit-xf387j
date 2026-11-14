-- Offline test suite. Usage: lune run tests/run.luau
local process = require("@lune/process")
local H = require("./harness")

for _, suite in
	{ "./motion.spec", "./factory.spec", "./monetization.spec", "./passes.spec", "./companion.spec", "./feel.spec", "./wayfinding.spec" }
do
	print(suite)
	require(suite)(H)
end

if H.summary() > 0 then
	process.exit(1)
end
