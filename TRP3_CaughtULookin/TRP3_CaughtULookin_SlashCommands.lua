local _, addon = ...

-- SlashCommands is a small helper for registering table-driven slash commands.
--
-- Usage:
--   addon.SlashCommands.Register("/culookin", {"/culookin", "/culook"}, {
--       all = {
--           desc = "toggle all addon windows",
--           func = ToggleAllWindows,
--       },
--       show = {
--           desc = "show a specific window",
--           main = {
--               desc = "show the main window",
--               func = ShowMainWindow,
--           },
--           history = {
--               desc = "show the history window",
--               func = function() addon:OpenHistoryWindow() end,
--           },
--       },
--       hide = {
--           desc = "hide a specific window",
--           main = {
--               desc = "hide the main window",
--               func = HideMainWindow,
--           },
--           history = {
--               desc = "hide the history window",
--               func = HideHistoryWindow,
--           },
--       },
--   })
--
-- Command table rules:
--   * A command node is a table with a `func` field.
--   * A group node is a table with nested command tables.
--   * `desc` is optional and used for help output.
--   * `help` is automatically supported as the first argument.

local SlashCommands = {}
local RESERVED_KEYS = {
    desc = true,
    func = true,
}

-- WoW chat color sequences use the format |cAARRGGBB ... |r.
-- Here we keep the alpha byte fully opaque and only vary RGB.
local COMMAND_COLOR = "|cff00ff00"
local ARG_COLOR = "|cff80c0ff"
local GROUP_COLOR = "|cffffff00"
local RESET_COLOR = "|r"

local function NormalizeToken(token)
    return type(token) == "string" and token:lower() or ""
end

local function SplitArgs(msg)
    local args = {}
    if type(msg) ~= "string" then
        return args
    end
    for token in msg:gmatch("%S+") do
        table.insert(args, token)
    end
    return args
end

local function IsCommandNode(node)
    return type(node) == "table" and type(node.func) == "function"
end

local function TraverseCommandTree(node, args, index)
    if index > #args then
        return node, index
    end
    local token = NormalizeToken(args[index])
    local child = type(node) == "table" and node[token]
    if not child then
        return node, index
    end
    if IsCommandNode(child) then
        return child, index + 1
    end
    if type(child) == "table" then
        return TraverseCommandTree(child, args, index + 1)
    end
    return node, index
end

local COMMAND_COLOR = "|cff00ff00"
local ARG_COLOR = "|cff80c0ff"
local GROUP_COLOR = "|cffffff00"
local RESET_COLOR = "|r"

local function PrintHelpSeparator()
    print("-----")
end

local function ColorizeCommandLine(prefix, key, isGroup)
    local pieces = {}
    if prefix and prefix ~= "" then
        for token in prefix:gmatch("%S+") do
            if #pieces == 0 then
                table.insert(pieces, COMMAND_COLOR .. token .. RESET_COLOR)
            else
                table.insert(pieces, GROUP_COLOR .. token .. RESET_COLOR)
            end
        end
    end
    local lastColor = isGroup and GROUP_COLOR or ARG_COLOR
    table.insert(pieces, lastColor .. key .. RESET_COLOR)
    return table.concat(pieces, " ")
end

local function PrintCommandHelp(prefix, node)
    for key, value in pairs(node) do
        if not RESERVED_KEYS[key] and type(value) == "table" then
            local commandLine = ColorizeCommandLine(prefix, key, not IsCommandNode(value))
            local description = value.desc or ""
            print(commandLine .. (description ~= "" and " - " .. description or ""))
            if not IsCommandNode(value) then
                PrintCommandHelp((prefix ~= "" and prefix .. " " or "") .. key, value)
            end
        end
    end
end

local function PrintGroupHelp(commandPath, node)
    PrintHelpSeparator()
    print(GROUP_COLOR .. commandPath .. " commands:" .. RESET_COLOR)
    PrintCommandHelp(commandPath, node)
    PrintHelpSeparator()
end

function SlashCommands.PrintHelp(rootName, aliases, commands, nodeToPrint, commandPath)
    if nodeToPrint then
        PrintGroupHelp(commandPath or (aliases[1] or rootName), nodeToPrint)
        return
    end

    PrintHelpSeparator()
    print(COMMAND_COLOR .. rootName .. " commands:" .. RESET_COLOR)
    for _, alias in ipairs(aliases or {}) do
        print("  " .. COMMAND_COLOR .. alias .. RESET_COLOR .. " <command>")
    end
    PrintCommandHelp(aliases[1] or rootName, commands)
    PrintHelpSeparator()
end

function SlashCommands.Register(rootName, aliases, commands)
    local normalizedRoot = rootName:gsub("^/", "")
    local slashName = normalizedRoot:upper()
    aliases = type(aliases) == "table" and aliases or { aliases }

    for index, alias in ipairs(aliases) do
        alias = alias:gsub("^/", ""):lower()
        _G["SLASH_" .. slashName .. index] = "/" .. alias
    end

    SlashCmdList[slashName] = function(msg)
        local args = SplitArgs(msg)
        if #args == 0 or NormalizeToken(args[1]) == "help" then
            SlashCommands.PrintHelp(rootName, aliases, commands)
            return
        end

        local node, nextIndex = TraverseCommandTree(commands, args, 1)
        if IsCommandNode(node) then
            node.func(args, nextIndex)
        elseif type(node) == "table" and nextIndex > 1 then
            local matchedArgs = {}
            for i = 1, nextIndex - 1 do
                table.insert(matchedArgs, args[i])
            end
            local commandPath = (aliases[1] or rootName) .. " " .. table.concat(matchedArgs, " ")
            SlashCommands.PrintHelp(rootName, aliases, commands, node, commandPath)
        else
            SlashCommands.PrintHelp(rootName, aliases, commands)
        end
    end
end

addon.SlashCommands = SlashCommands
