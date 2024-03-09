if not vim then
    error('Requires running with `nvim`')
end

if vim.fn.executable('lua-language-server') == 0 then
    error('Requires `lua-language-server` for formatting')
end

---@param files string[]
local function format(files)
    local channel = vim.fn.jobstart({ 'nvim', '--clean', '--headless', '--embed', '-n' }, { rpc = true })

    vim.rpcrequest(channel, 'nvim_exec_lua', [[
    local files=...

    vim.o.shiftwidth=4
    vim.o.expandtab=true
    vim.g.done=false

    local temp_file=vim.fn.tempname()..'.lua'
    vim.cmd.edit(temp_file)
    vim.bo.buftype='nofile'buftype='nofile'buftype='nofile'

    vim.lsp.start({
        name = 'lua_ls',
        cmd = { 'lua-language-server' },
        root_dir = vim.fn.fnamemodify(temp_file,':h'),
    })

    vim.api.nvim_create_autocmd('LspAttach',{once=true,callback=function()
        for _,file in ipairs(files) do
            vim.api.nvim_buf_set_lines(0,0,-1,false,vim.fn.readfile(file))

            if vim.fn.getline('$')=='' then
                vim.cmd.norm'Gdd'
            end

            vim.lsp.buf.format()
            vim.fn.writefile(vim.api.nvim_buf_get_lines(0,0,-1,false),file)
        end
        vim.g.done=true
    end})
    ]], { files })

    if not vim.wait(10000, function()
            return vim.rpcrequest(channel, 'nvim_get_var', 'done') == true
        end) then
        vim.notify('timeout reached', vim.log.levels.WARN)
    end

    vim.fn.jobstop(channel)
end

local function main()
    local limit = 100

    local files = vim.fs.find(function(file)
        return file:find('%.lua$') and true or false
    end, { limit = limit })

    if #files == limit then
        error('Amount of files exceeded limit ' .. limit)
    end

    format(files)
end

main()
