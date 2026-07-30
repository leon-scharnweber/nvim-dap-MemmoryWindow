local M = {}

M.hex_to_char = {}
for idx = 0, 255 do
	M.hex_to_char[("%02X"):format(idx)] = string.char(idx)
	M.hex_to_char[("%02x"):format(idx)] = string.char(idx)
end

M.hex_regex =
	"^0x[0-9a-f][0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?[0-9a-f]?$"

M.hexAddition = function(hexNum, x)
	return string.format("0x%016x", tonumber(hexNum) + x)
end

M.byte_to_hex = function(byte)
	return string.format("%02x", byte)
end
return M
