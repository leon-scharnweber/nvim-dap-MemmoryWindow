local M = {}

local levels = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 }
M.level = levels.INFO

local logfile = vim.fn.stdpath("log") .. "/memoryWatchWindow.log"

local function write(level_name, ...)
	if levels[level_name] < M.level then
		return
	end
	local parts = {}
	for _, v in ipairs({ ... }) do
		table.insert(parts, type(v) == "table" and vim.inspect(v) or tostring(v))
	end
	local line = string.format("[%s] %-5s %s\n", os.date("%Y-%m-%d %H:%M:%S"), level_name, table.concat(parts, " "))
	local f = io.open(logfile, "a")
	if f then
		f:write(line)
		f:close()
	end
end

M.trace = function(...)
	write("TRACE", ...)
end
M.debug = function(...)
	write("DEBUG", ...)
end
M.info = function(...)
	write("INFO", ...)
end
M.warn = function(...)
	write("WARN", ...)
end
M.error = function(...)
	write("ERROR", ...)
end

M.set_level = function(name)
	M.level = levels[name:upper()] or levels.INFO
end

return M
