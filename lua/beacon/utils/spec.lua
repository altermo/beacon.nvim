---@class beacon.spec.table
---@field _t true
---@field _d? string
---@field [string] beacon.spec

---@class beacon.spec.value
---@field [1] any
---@field [2] string

---@class beacon.config
---@field merge? boolean merge table with default config (default: true)


---@alias beacon.spec beacon.spec.table | beacon.spec.value

local M = {}

M.spec_special_keys = vim.tbl_add_reverse_lookup({ '_t', '_d' })

---@param config_spec beacon.spec
---@return table
function M.to_config(config_spec)
    if not config_spec._t then
        return config_spec[1]
    end

    local config = {}
    for k, v in pairs(config_spec) do
        if not M.spec_special_keys[k] then
            config[k] = M.to_config(v)
        end
    end

    return config
end

---@param value any
---@param type_ string
---@param opt_name string
---@param plugin_name string
function M.assert_type(value, type_, opt_name, plugin_name)
    if type(value) ~= type_ then
        error(('\n\n\n' .. [[
        Configuration for the plugin '%s' is incorrect.
        The option `%s` has the value `%s`, which has the type `%s`.
        However, that option should have the type `%s`.
        ]] .. '\n'):format(plugin_name, opt_name, vim.inspect(value), type(value), type_))
    end
end

---@param config_spec beacon.spec
---@param value table?
---@param name string
---@param plugin_name string
function M.merge(config_spec, value, name, plugin_name)
    if value == nil then
        return M.to_config(config_spec)
    end

    if not config_spec._t then
        M.assert_type(value, type(config_spec[1]), name, plugin_name)
        return value
    end


    M.assert_type(value, 'table', name, plugin_name)

    for k, _ in pairs(value) do
        if not config_spec[k] then
            error(('\n\n\n' .. [[
        Configuration for the plugin '%s' is incorrect.
        The option '%s' is set, but it should not be set.
        ]] .. '\n'):format(plugin_name, name == '' and k or name .. '.' .. k))
        end
    end

    local new = {}

    for k, v in pairs(config_spec) do
        if M.spec_special_keys[k] then
        else
            local setting = M.merge(v, value[k], name == '' and k or name .. '.' .. k, plugin_name)
            if value.merge == false then
                new[k] = value[k]
            else
                new[k] = setting
            end
        end
    end

    return new
end

---@param config_spec beacon.spec.table
---@param config? beacon.config
---@param plugin_name string
function M.merge_conf(config_spec, config, plugin_name)
    if type(config) == nil then
        return M.to_config(config_spec)
    end

    if type(config) ~= 'table' then
        error(('\n\n\n' .. [[
        Configuration for the plugin '%s' is incorrect.
        The configuration is `%s`, which has the type `%s`.
        However, the configuration should be a table.
        ]] .. '\n'):format(plugin_name, vim.inspect(config), type(config)))
    end

    return M.merge(config_spec, config, '', plugin_name)
end

return M
