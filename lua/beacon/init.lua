local utils = require('beacon.utils')

local M = {}

-- `docs_spec` and `config_spec` are used to autogenerate meta files and documentation

M.docs_spec = 'Simple beacon with window local highlighting'

M.config_spec = {
    _t = true,
    interval = { 150, 'how long to flash' },
    count = { 2, 'how many times to flash' },
    color = { 'LightGoldenRodYellow', 'the color of flash, can be color name or #RRGGBB' },
    on_line_change = {
        _d = 'flash on line change',
        _t = true,
        enable = { true, '' },
        minimal_change = { 10, 'minimal amount of line change to trigger flash' },
    },
    on_window_change = {
        _d = 'flash on window change',
        _t = true,
        enable = { true, '' },
    },
}

M.ns = vim.api.nvim_create_namespace 'beacon.beacon'

---@type table<beacon.id, table>
M.flashes = {}

---@param conf beacon.conf.beacon
---@return beacon.id
function M.flash(conf)
    local id = utils.new_id()
    local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
    local winid = vim.api.nvim_get_current_win()

    M.flashes[id] = {
        row = cursor_y,
        winid = winid,
    }
    M.redraw_screen()

    if conf.count == 0 then return id end
    local count = conf.count

    local function loop()
        if M.flashes[id] == nil then return end

        count = count - 1
        if count <= 0 then
            M.clear(id)
            return
        end

        M.flashes[id].winid = nil
        M.redraw_screen()

        vim.defer_fn(function()
            if M.flashes[id] == nil then return end

            M.flashes[id].winid = winid
            M.redraw_screen()

            vim.defer_fn(loop, conf.interval)
        end, conf.interval)
    end
    vim.defer_fn(loop, conf.interval)

    return id
end

function M.redraw_screen()
    vim.schedule_wrap(vim.cmd.redraw) { bang = true }
end

---@param id beacon.id? if nil, clear all
function M.clear(id)
    if id == nil then
        M.flashes = {}
    else
        M.flashes[id] = nil
    end
    M.redraw_screen()
end

---@param conf beacon.conf.beacon
function M.create_autocmd(conf)
    local last_cursor_y = vim.api.nvim_win_get_cursor(0)[1]
    local last_win = vim.api.nvim_get_current_win()

    return vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
        callback = function()
            local cusror_y = vim.api.nvim_win_get_cursor(0)[1]
            local win = vim.api.nvim_get_current_win()

            if (conf.on_window_change.enable and win ~= last_win)
                or
                (conf.on_line_change.enable and
                    math.abs(last_cursor_y - cusror_y) >= conf.on_line_change.minimal_change)
            then
                if M.id then M.clear(M.id) end
                M.id = M.flash(conf)
            end

            last_cursor_y = cusror_y
            last_win = win
        end,
        group = vim.api.nvim_create_augroup('beaconBeacon', {})
    })
end

---@param winid integer
---@param bufnr integer
function M._on_win(_, winid, bufnr, _)
    for _, v in pairs(M.flashes) do
        if winid == v.winid then
            vim.api.nvim_buf_set_extmark(bufnr, M.ns, v.row - 1, 0, {
                hl_group = 'beaconBeacon',
                end_col = #vim.fn.getline(v.row),
                ephemeral = true,
            })
        end
    end
end

---@param conf table|nil
function M.setup(conf)
    conf = utils.spec.merge_conf(M.config_spec, conf, 'beacon.beacon')

    if conf.color ~= '' then
        vim.api.nvim_set_hl(0, 'beaconBeacon', { bg = utils.color_to_number(conf.color) })
    end

    M.create_autocmd(conf)

    vim.api.nvim_set_decoration_provider(M.ns, { on_win = M._on_win })
end

return M
