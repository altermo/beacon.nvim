if not vim then
    error('Requires running with `nvim`')
end

if not pcall(vim.treesitter.language.inspect, 'lua') then
    error('lua treesitter-parser not found')
end

local LINE_LENGTH = 78
local MAX_LINE_LENGTH = LINE_LENGTH + 30
local LINE = ('='):rep(LINE_LENGTH)
local FUNCTION_DOC_INDENT = '  '
local CONFIG_DOC_INDENT = '    '

---@param name string
---@param tagstr string?
local function tag(name, tagstr)
    tagstr = tagstr or name
    return name .. (' '):rep(LINE_LENGTH - #name - #tagstr - 2) .. '*' .. tagstr .. '*'
end

---@param file string
---@return string[]
local function extract_function_docs(file)
    local name = vim.fn.fnamemodify(file, ':t:r')
    local out = {}
    local lines = vim.fn.readfile(file)
    local source = table.concat(lines, '\n')

    local query = vim.treesitter.query.parse('lua', [[
    (function_declaration name:(_) @name)
    ]])
    local parser = vim.treesitter.get_string_parser(source, 'lua')
    local root = parser:parse()[1]:root()

    for _, node in query:iter_captures(root, source) do
        local comments = {}
        local annotations = {}
        local row = node:range()
        local node_name = vim.treesitter.get_node_text(node, source)

        while row > 0 and lines[row]:match('^%-%-%-[@ ]') do
            if lines[row]:match('^%-%-%-%s*@') then
                table.insert(annotations, 1, lines[row])
            else
                table.insert(comments, 1, lines[row])
            end
            row = row - 1
        end

        if not next(comments) then
            if node_name == 'M.setup' then
                comments = { '--- Start the plugin' }
            else
                goto continue
            end
        end

        local args = {}
        for _, annotation in ipairs(annotations) do
            local arg = annotation:match('^%-%-%-%s*@param ([^ ]+)')
            if arg then
                table.insert(args, '{' .. arg .. '}')
            end
        end

        local function_name = node_name:gsub('^M%.', 'beacon.' .. name .. '.')
        local function_args = '(' .. table.concat(args, ', ') .. ')'
        table.insert(out, tag(function_name .. function_args, function_name .. '()'))

        for _, comment in ipairs(comments) do
            table.insert(out, (comment:gsub('^%-%-%- ', FUNCTION_DOC_INDENT)))
        end

        table.insert(out, '')
        ::continue::
    end

    return out
end

---@param config_spec beacon.spec
---@return string[]
local function config_spec_to_vimdoc(config_spec, _indent)
    _indent = _indent or 0
    local pre = CONFIG_DOC_INDENT:rep(_indent) .. '• '
    local spec = require 'lua.beacon.utils.spec'
    local out = {}

    for k, v in vim.spairs(config_spec) do
        if spec.spec_special_keys[k] then
        elseif v._t then
            table.insert(out, (pre .. '{%s} %s:'):format(k, v._d))
            vim.list_extend(out, config_spec_to_vimdoc(v, _indent + 1))
        else
            table.insert(out,
                (pre .. '{%s}%s (default: `%s`)'):format(k, v[2] ~= '' and ' ' .. v[2] or '', vim.inspect(v[1])))
        end
    end

    return out
end

---@param file string
local function generate_vimdoc_file(file)
    local plugin = assert(loadfile(file))()
    local name = 'beacon'
    local doc_file = 'doc/' .. name .. '.txt'
    local docs = {}

    if not plugin.docs_spec then return end

    table.insert(docs, LINE)
    table.insert(docs, tag(name:upper(), name))
    table.insert(docs, '')

    local plugin_docs = vim.split(plugin.docs_spec, '\n', { trimempty = true })
    vim.list_extend(docs, plugin_docs)
    table.insert(docs, '')

    local function_docs = extract_function_docs(file)
    if function_docs and not vim.tbl_isempty(function_docs) then
        table.insert(docs, LINE)
        table.insert(docs, tag('FUNCTIONS', name .. '.functions'))
        table.insert(docs, '')
        vim.list_extend(docs, function_docs)
    end

    if plugin.config_spec then
        local config_docs = config_spec_to_vimdoc(plugin.config_spec)
        if config_docs and not vim.tbl_isempty(config_docs) then
            table.insert(docs, LINE)
            table.insert(docs, tag('CONFIG', name .. '.config'))
            table.insert(docs, '')
            table.insert(docs, 'This is the config:')
            vim.list_extend(docs, config_docs)
            table.insert(docs, '')
        end
    end

    table.insert(docs, 'vim:ft=help:')

    for _, line in ipairs(docs) do
        assert(vim.api.nvim_strwidth(line) <= MAX_LINE_LENGTH, 'This line is to long: ' .. line)
    end

    vim.fn.writefile(docs, doc_file)
end

local function main()
    vim.opt.runtimepath:append(vim.fn.getcwd())

    generate_vimdoc_file('lua/beacon/init.lua')
end

main()
