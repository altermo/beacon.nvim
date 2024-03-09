---@class beacon.id

local M = {}

M.spec = require('beacon.utils.spec')

---@param color string
---@return integer
function M.color_to_number(color)
    if vim.startswith(color, '#') then
        return tonumber(color:sub(2), 16)
    end
    return vim.api.nvim_get_color_by_name(color)
end

---@return beacon.id
function M.new_id()
    local id = {}
    local name = ('anonymous id: %s'):format(tostring(id):gsub('^table: ', ''))
    return setmetatable(id, { __tostring = function() return name end, name = name })
end

return M
