local M = {}

local dap = require("dap")

local mem_buf = {
	nr = -1,
}

local curr_addr = "0x0"

local augroup = vim.api.nvim_create_augroup("DapMemory", { clear = true })

local memory = {}

local save_statuscolumn = ""

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

local wished_new_addr = { M.config.start_addr }

local new_memory = false

local function is_available(session)
	if not session then
		print("Derzeitg keine Session")
		return false
	end
	print("Es ist eine Sesssion vorhanden")
	return true
end

local function updateMemory()
	M.readMemoryAddr(curr_addr, M.config.window.heigth * M.config.window.width)
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

	vim.api.nvim_create_autocmd("BufEnter", {
		buf = buf,
		group = augroup,
		callback = function(opts)
			save_statuscolumn = vim.wo.statuscolumn
			vim.wo.statuscolumn = "%{%v:lua.ChangeNumColoum()%}"
		end,
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = augroup,
		buf = buf,
		callback = function(opts)
			memory = {}
			mem_buf.nr = -1
			vim.wo.statuscolumn = save_statuscolumn
			vim.api.nvim_del_augroup_by_id(augroup)
		end,
	})

	return buf
end

function ChangeNumColoum()
	local linenum = vim.v.lnum
	return string.format("0x%016x", tonumber(curr_addr) + (linenum - 1) * M.config.window.width)
end

local function make_memory_printable()
	local printable_memory = {}
	local count = 1
	local curr_addr_count = curr_addr

	vim.notify("Curr addr: " .. curr_addr_count)

	for i = 1, M.config.window.heigth do
		local lines = " "
		local byte = ""
		for j = 1, M.config.window.width do
			local raw_byte = memory[curr_addr_count]
			if raw_byte then
				byte = string.format("%02x", raw_byte)
				lines = lines .. byte .. " "
			else
				lines = lines .. M.config.window.unknown_sign .. " "
			end
			curr_addr_count = string.format("0x%016x", tonumber(curr_addr_count) + 1)
		end
		printable_memory[i] = lines
	end

	return printable_memory
end

M.refresh = function()
	local buf = mem_buf.nr

	if not buf or not vim.api.nvim_buf_is_loaded(buf) then
		return
	end

	if #wished_new_addr > 0 then
		curr_addr = wished_new_addr[#wished_new_addr]
		vim.notify("Es gibt eine addr Änderung: " .. curr_addr)
		updateMemory()
		wished_new_addr = {}
		return
	elseif new_memory then
		local printable_memory = make_memory_printable()
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, M.config.window.heigth, false, printable_memory)
		vim.bo[buf].modifiable = false
		new_memory = false
	end
end

M.changeCurrAddr = function(new_addr)
	wished_new_addr[#wished_new_addr + 1] = new_addr
	M.refresh()
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

local function putByteIntoMemoryTable(bytes, first_addr)
	for i = 1, string.len(bytes) do
		memory[first_addr] = string.byte(bytes, i)
		first_addr = string.format("0x%016x", tonumber(first_addr) + 1)
	end

	vim.notify("Es wurde neue bytes geladen und gespeichert")
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
			putByteIntoMemoryTable(bytes, mem_ref)
			new_memory = true
			M.refresh()
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
