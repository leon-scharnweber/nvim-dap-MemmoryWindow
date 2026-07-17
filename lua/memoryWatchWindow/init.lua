local M = {}

local dap = require("dap")

local function b64_decode(data)
	return vim.base64.decode(data)
end

local function is_available(session)
	if not session then
		print("Derzeitg keine Session")
		return false
	end
	print("Es ist eine Sesssion vorhanden")
	return true
end

function M.setup()
	is_available()
end

M.config = {}

local function printAddres(res, count)
	local data = b64_decode(res.data)
	local hex_bytes = ""
	for i = 1, count do
		local byte = data:byte(i)
		hex_bytes = hex_bytes .. string.format("%02x", byte)
	end

	vim.notify("Das lesen an der Stelle ist " .. hex_bytes)
end

function M.readMemoryAddr(mem_ref, count)
	local session = dap.session()
	if not is_available(session) then
		return
	end

	session:request("readMemory", {
		memoryReference = mem_ref,
		count = count,
	}, function(err, res)
		if err then
			vim.notify("Beim Call gab es einen Fehler: " .. err.message)
		else
			printAddres(res, count)
		end
	end)
end

function M.readMemoryVar(var)
	local session = dap.session()
	if not is_available(session) then
		return
	end

	local varValues = {}
	local pending = 2

	local function ready()
		pending = pending - 1
		if pending == 0 and varValues.addr and varValues.size then
			M.readMemoryAddr(varValues.addr, varValues.size)
		end
	end

	session:request("evaluate", {
		expression = "?/nat sizeof(" .. var .. ")",
		frameId = session.current_frame and session.current_frame.id,
		context = "repl",
	}, function(err, res)
		if err then
			vim.notify("Fehler beim bekomen der Größe der Variablen " .. err.message)
		else
			varValues.size = tonumber(res.result)
			ready()
		end
	end)

	session:request("evaluate", {
		expression = "?/nat (void*)&" .. var,
		frameId = session.current_frame and session.current_frame.id,
		context = "repl",
	}, function(err, res)
		if err then
			vim.notify("Fehler beim bekomen der Addresse der Variablen " .. err.message)
		else
			varValues.addr = res.result
			ready()
		end
	end)
end

function M.readMemory(location)
	if string.match(location, "^0x") then
		M.readMemoryAddr(location, 8)
	else
		M.readMemoryVar(location)
	end
end

return M
