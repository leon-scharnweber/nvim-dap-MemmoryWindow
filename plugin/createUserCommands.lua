vim.api.nvim_create_user_command("Setup", function()
	require("memoryWatchWindow").setup()
end, {})

vim.api.nvim_create_user_command("ReadMemoryAddr", function(opts)
	require("memoryWatchWindow").readMemoryAddr(opts.fargs[1], tonumber(opts.fargs[2]))
end, { nargs = "+" })

vim.api.nvim_create_user_command("ReadMemoryVar", function(opts)
	require("memoryWatchWindow").readMemoryVar(opts.fargs[1])
end, { nargs = 1 })

vim.api.nvim_create_user_command("ReadMemory", function(opts)
	require("memoryWatchWindow").readMemory(opts.fargs[1])
end, { nargs = 1 })

vim.api.nvim_create_user_command("ChangeAddr", function(opts)
	require("memoryWatchWindow").changeCurrAddr(opts.fargs[1])
end, { nargs = 1 })

require("dap").listeners.before.event_terminated["dap-memory"] = function(_, _)
	require("memoryWatchWindow").close()
end
require("dap").listeners.before.event_exited["dap-memory"] = function(_, _)
	require("memoryWatchWindow").close()
end
