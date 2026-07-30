vim.api.nvim_create_user_command("ChangeAddr", function(opts)
	require("memoryWatchWindow").changeCurrAddr(opts.fargs[1])
end, { nargs = 1 })

require("dap").listeners.before.event_terminated["dap-memory"] = function(_, _)
	require("memoryWatchWindow").close()
end
require("dap").listeners.before.event_exited["dap-memory"] = function(_, _)
	require("memoryWatchWindow").close()
end

require("dap").listeners.after.event_stopped["dap-memory"] = function(_, _)
	require("memoryWatchWindow").update()
end
