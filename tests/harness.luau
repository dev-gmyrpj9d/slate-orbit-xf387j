-- Minimal test harness for the offline Lune suite.
local Harness = {}

local failures = 0
local passes = 0

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passes += 1
		print("  ok   " .. name)
	else
		failures += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function Harness.check(condition: any, message: string)
	if not condition then
		error(message, 2)
	end
end

function Harness.near(a: number, b: number, eps: number, message: string)
	if math.abs(a - b) > eps then
		error(string.format("%s (%.4f vs %.4f)", message, a, b), 2)
	end
end

function Harness.summary(): number
	print(string.format("\n%d passed, %d failed", passes, failures))
	return failures
end

return Harness
