local M = {}

local dap = require("dap")

local mem_buf = {
	nr = -1,
}

local addr_prefix = "addr"

local memory = {}

local function b64_decode(data)
	return vim.base64.decode(data)
end

M.config = {
	dap_view_register = true,
	dapview = {
		keymap = "M",
		label = "Memory",
		short_label = "M",
	},
	window = {
		heigth = 20,
		width = 16,
		unknown_sign = "??",
	},
	start_addr = "0x00007fffffffd380",
}
local function is_available(session)
	if not session then
		print("Derzeitg keine Session")
		return false
	end
	print("Es ist eine Sesssion vorhanden")
	return true
end

mem_buf.create = function()
	local buf = mem_buf.nr

	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].modifiable = false
	vim.api.nvim_buf_set_name(buf, "DAP Memory")
	mem_buf.nr = buf

	return buf
end

local function make_Table_to_Array(table)
	local array = {}
	local count = 1

	for _, value in pairs(table) do
		array[count] = value
		count = count + 1
	end

	return array
end

M.refresh = function()
	local buf = mem_buf.nr

	if not buf or not vim.api.nvim_buf_is_loaded(buf) then
		return
	end

	local memoryArray = make_Table_to_Array(memory)

	vim.api.nvim_buf_set_lines(buf, -2, -1, false, memoryArray)
	vim.bo[buf].modifiable = false
end

function M.setup()
	if M.config.dap_view_register and package.loaded["dap-view"] then
		vim.notify("Werde registrieren")

		require("dap-view").register_view("memory", {
			action = M.refresh,
			buffer = mem_buf.create,
			keymap = M.config.dapview.keymap,
			label = M.config.dapview.label,
			short_label = M.config.dapview.short_label,
		})
		vim.notify("Habe registriert")
	else
		vim.notify("Package not loaded")
	end
end

local function printAddres(bytes, count)
	local hex_bytes = ""
	for i = 1, count do
		local byte = bytes:byte(i)
		hex_bytes = hex_bytes .. string.format("%02x", byte)
	end

	vim.notify("Das lesen an der Stelle ist " .. hex_bytes)
end

function M.readMemoryAddr(mem_ref, count)
	local session = dap.session()
	if not is_available(session) then
		return
	end

	vim.notify("mem_ref: " .. mem_ref)
	vim.notify("count: " .. count)

	session:request("readMemory", {
		memoryReference = mem_ref,
		count = count,
	}, function(err, res)
		if err then
			vim.notify("Beim Call gab es einen Fehler: " .. err.message)
		else
			local bytes = b64_decode(res.data)
			printAddres(bytes, count)
			memory[mem_ref] = bytes
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
