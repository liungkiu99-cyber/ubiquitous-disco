--[[
    HS HUB · ScriptDumper  —  the "NO static deobf" runtime extractor
    discord.gg/5rpP6faZSJ

    WHY: an obfuscated VM (Luraph/Kannonix), once it RUNS, builds real Lua closures whose
    string CONSTANTS (remote names, feature text, urls) are already DECRYPTED in memory.
    The executor's debug lib can read them directly -> no need to reverse the VM at all.

    HOW: enumerate every Lua closure with getgc(), then debug.getconstants / getupvalues /
    getprotos on each -> collect every readable string. Filter by a keyword to focus on one
    hub. Export JSON (+ clipboard). Remote/feature names fall out for free.

    USE: 1) load the target hub (let it fully load).  2) load THIS.  3) (optional) type a
    filter keyword.  4) SCAN.  5) send me HSHub_ScriptDumper.json.
    Reusable on ANY game/obfuscator — that's the point.
]]

if shared.__HSHub_ScriptDumper then pcall(function() shared.__HSHub_ScriptDumper:Destroy() end) end

local Players, HttpService = game:GetService('Players'), game:GetService('HttpService')
local LP = Players.LocalPlayer
local PG = LP:WaitForChild('PlayerGui')
local FILE = 'HSHub_ScriptDumper.json'

-- ── resolve executor debug APIs (names vary across executors) ──
local _getgc      = rawget(getfenv(), 'getgc') or getgc
local _getconsts  = (debug and (debug.getconstants or debug.getconsts)) or getconstants
local _getupvals  = (debug and debug.getupvalues) or getupvalues
local _getprotos  = (debug and debug.getprotos) or getprotos
local _islclosure = islclosure or is_l_closure or function() return true end

local API_OK = (_getgc and _getconsts) and true or false

local function printable(s)
    if type(s) ~= 'string' then return false end
    local n = #s; if n < 3 or n > 400 then return false end
    local p = 0; for i = 1, n do local b = string.byte(s, i); if b >= 32 and b < 127 then p = p + 1 end end
    return p >= n * 0.9
end

-- ── scan ──
local result = { strings = {}, remotes = {}, urls = {}, count_fn = 0, api = {} }
local seen = {}
local function add(v)
    if not printable(v) then return end
    if seen[v] then return end
    seen[v] = true
    result.strings[#result.strings + 1] = v
    local lv = v:lower()
    if lv:find('http') then result.urls[#result.urls + 1] = v end
    -- remote-ish: CamelCase word, or contains remote/event/service/fire/invoke + no spaces
    if (#v <= 64 and not v:find('%s')) and
       (v:find('Remote') or v:find('Event') or v:find('Service') or v:find('Function')
        or lv:find('fire') or lv:find('invoke') or v:match('^[A-Z][A-Za-z0-9]+$')) then
        result.remotes[#result.remotes + 1] = v
    end
end
local function dumpFn(fn, depth)
    local ok = pcall(_islclosure, fn); if ok and _islclosure(fn) == false then return end
    pcall(function() for _, c in ipairs(_getconsts(fn)) do add(c) end end)
    if _getupvals then pcall(function() for _, u in ipairs(_getupvals(fn)) do add(u) end end) end
    if _getprotos and depth < 3 then
        pcall(function() for _, p in ipairs(_getprotos(fn)) do result.count_fn = result.count_fn + 1; dumpFn(p, depth + 1) end end)
    end
end
local function runScan(filter)
    result = { strings = {}, remotes = {}, urls = {}, count_fn = 0, place = game.PlaceId }
    seen = {}
    if not API_OK then result.error = 'executor missing getgc/getconstants'; return 'NO API', 0 end
    local gc = _getgc()
    for _, o in ipairs(gc) do
        if type(o) == 'function' then result.count_fn = result.count_fn + 1; pcall(dumpFn, o, 0) end
    end
    if filter and filter ~= '' then
        local f = filter:lower()
        local keep = {}
        for _, s in ipairs(result.strings) do if s:lower():find(f, 1, true) then keep[#keep + 1] = s end end
        result.filtered = keep
    end
    local json = '{}'; pcall(function() json = HttpService:JSONEncode(result) end)
    pcall(function() if writefile then writefile(FILE, json) end end)
    pcall(function() if setclipboard then setclipboard(json) end end)
    return ('fns:%d  strings:%d  remote-ish:%d'):format(result.count_fn, #result.strings, #result.remotes), #json
end

-- ── UI ──
local gui = Instance.new('ScreenGui'); gui.Name = 'HSHub_ScriptDumper_' .. math.random(1e5, 1e6)
gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = (gethui and gethui()) or PG
shared.__HSHub_ScriptDumper = gui
local frame = Instance.new('Frame', gui); frame.Size = UDim2.new(0, 360, 0, 178); frame.Position = UDim2.new(0, 20, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28); frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true
Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 10); Instance.new('UIStroke', frame).Color = Color3.fromRGB(120, 200, 140)
local hdr = Instance.new('Frame', frame); hdr.Size = UDim2.new(1, 0, 0, 34); hdr.BackgroundColor3 = Color3.fromRGB(60, 165, 105); hdr.BorderSizePixel = 0
Instance.new('UICorner', hdr).CornerRadius = UDim.new(0, 10)
local ttl = Instance.new('TextLabel', hdr); ttl.BackgroundTransparency = 1; ttl.Size = UDim2.new(1, -40, 1, 0); ttl.Position = UDim2.new(0, 12, 0, 0)
ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 13; ttl.TextColor3 = Color3.fromRGB(245, 245, 250); ttl.TextXAlignment = Enum.TextXAlignment.Left; ttl.Text = 'HS HUB · ScriptDumper'
local xB = Instance.new('TextButton', hdr); xB.BackgroundTransparency = 1; xB.Size = UDim2.new(0, 34, 0, 34); xB.Position = UDim2.new(1, -36, 0, 0)
xB.Font = Enum.Font.GothamBold; xB.TextSize = 20; xB.TextColor3 = Color3.fromRGB(255, 255, 255); xB.Text = '×'
xB.MouseButton1Click:Connect(function() gui:Destroy(); shared.__HSHub_ScriptDumper = nil end)
local fbox = Instance.new('TextBox', frame); fbox.Size = UDim2.new(1, -24, 0, 28); fbox.Position = UDim2.new(0, 12, 0, 42)
fbox.BackgroundColor3 = Color3.fromRGB(30, 34, 44); fbox.BorderSizePixel = 0; fbox.Font = Enum.Font.Code; fbox.TextSize = 13
fbox.TextColor3 = Color3.fromRGB(230, 240, 230); fbox.PlaceholderText = 'filter keyword (blank = all)'; fbox.Text = ''; fbox.ClearTextOnFocus = false
Instance.new('UICorner', fbox).CornerRadius = UDim.new(0, 6)
local info = Instance.new('TextLabel', frame); info.BackgroundTransparency = 1; info.Size = UDim2.new(1, -20, 0, 56); info.Position = UDim2.new(0, 12, 0, 76)
info.Font = Enum.Font.Code; info.TextSize = 12; info.TextColor3 = Color3.fromRGB(190, 215, 235); info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left; info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = API_OK and 'Load target hub FIRST, then SCAN. (getgc+getconstants OK)' or 'WARNING: executor missing getgc/getconstants debug API.'
local function mkBtn(lbl, col, x, w)
    local b = Instance.new('TextButton', frame); b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 1, -40)
    b.BackgroundColor3 = col; b.BorderSizePixel = 0; b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.fromRGB(245, 245, 250); b.Text = lbl
    Instance.new('UICorner', b).CornerRadius = UDim.new(0, 6); return b
end
local scanB = mkBtn('🔍 SCAN (dump all)', Color3.fromRGB(60, 165, 105), 12, 200)
local copyB = mkBtn('📋 COPY', Color3.fromRGB(60, 130, 180), 220, 128)
scanB.MouseButton1Click:Connect(function() task.spawn(function()
    info.Text = 'scanning memory (getgc)...'; local s, len = runScan(fbox.Text)
    info.Text = ('done: %s\nsaved %s (%d chars) + clipboard. send me the file.'):format(s, FILE, len)
end) end)
copyB.MouseButton1Click:Connect(function()
    local json = '{}'; pcall(function() json = HttpService:JSONEncode(result) end)
    pcall(function() if setclipboard then setclipboard(json) end end); info.Text = 'copied JSON to clipboard.'
end)
