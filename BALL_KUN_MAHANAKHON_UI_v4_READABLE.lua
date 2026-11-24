--[[
BALL KUN HUB • MAHANAKHON v4.0 (อ่านง่าย + สวิตช์เปิด/ปิด)
Client-side companion UI for PlaceId 104549080643413
Designed for Roblox Studio / an experience you own or are authorized to test.
This script does NOT invoke game remotes, bypass server checks, automate rewards,
or spoof job/race completion. Native game actions remain in the game's own UI.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local PLACE_ID = 104549080643413
-- พื้นหลัง: มีภาพฝังมาในไฟล์แล้ว (ใช้ได้เลยถ้า executor รองรับ writefile + getcustomasset)
-- อยากใช้ภาพอื่น: ใส่ Asset ID ของ Roblox หรือลิงก์ raw ของภาพ (.png/.jpg) ด้านล่าง
local BACKGROUND_ASSET_ID = 0      -- เช่น 123456789 (ถ้า > 0 จะใช้ก่อน)
local BACKGROUND_URL = ""          -- เช่น "https://raw.githubusercontent.com/user/repo/main/bg.jpg"
local BG_DATA                      -- ภาพฝัง (base64) อยู่ท้ายไฟล์
local BACKGROUND_IMAGE = BACKGROUND_ASSET_ID > 0 and ("rbxassetid://" .. BACKGROUND_ASSET_ID) or ""
if game.PlaceId ~= PLACE_ID then
    warn("[MAHANAKHON HUB] PlaceId mismatch. Expected:", PLACE_ID, "Got:", game.PlaceId)
end

local old = PlayerGui:FindFirstChild("MahanakhonHubV2")
if old then old:Destroy() end

local Theme = {
    bg = Color3.fromRGB(3, 12, 5),
    panel = Color3.fromRGB(5, 22, 10),
    panel2 = Color3.fromRGB(10, 42, 18),
    line = Color3.fromRGB(25, 210, 55),
    text = Color3.fromRGB(246, 249, 252),
    muted = Color3.fromRGB(195, 208, 222),
    accent = Color3.fromRGB(35, 255, 30),
    accent2 = Color3.fromRGB(0, 220, 150),
    danger = Color3.fromRGB(238, 86, 100),
    good = Color3.fromRGB(85, 205, 145),
}
local FONT = Enum.Font.Gotham
local State = {
    tab = "Overview",
    promptESP = false,
    vehicleESP = false,
    jobESP = false,
    miniStatus = true,
    scanBusy = false,
    highlights = {},
    waypoint = nil,
    lastScan = 0,
    autoNearest = false,
    nearestPart = nil,
    bgOn = true,
    boost = 1,
}
local Connections = {}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

-- Themed objects: a property value like "@accent" is bound to Theme.accent
-- and is recolored by applyTheme() when the user picks a new palette.
local Themed = {}
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        if type(v) == "string" and v:sub(1, 1) == "@" and Theme[v:sub(2)] then
            table.insert(Themed, {obj, k, v:sub(2)})
            obj[k] = Theme[v:sub(2)]
        else
            obj[k] = v
        end
    end
    obj.Parent = parent
    return obj
end

local function applyTheme()
    local alive = {}
    for _, e in ipairs(Themed) do
        local obj = e[1]
        if obj.Parent ~= nil then
            pcall(function() obj[e[2]] = Theme[e[3]] end)
            table.insert(alive, e)
        end
    end
    Themed = alive
end

local loadingGui = make("ScreenGui", {
    Name = "BallKunLoading",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
}, PlayerGui)
local loading = make("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(2, 8, 3),
    BorderSizePixel = 0,
}, loadingGui)
local loadingTitle = make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
    Size = UDim2.new(0.9, 0, 0, 58), BackgroundTransparency = 1,
    Text = "BALL KUN HUB", TextColor3 = Color3.fromRGB(35,255,30),
    Font = Enum.Font.GothamBlack, TextSize = 34,
}, loading)
make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
    Size = UDim2.new(0.9, 0, 0, 34), BackgroundTransparency = 1,
    Text = "รอก่อนไอสลัด", TextColor3 = Color3.fromRGB(245,245,245),
    Font = Enum.Font.GothamBold, TextSize = 20,
}, loading)

-- Build the main interface under xpcall so an initialization error is visible
-- instead of leaving the loading screen stuck forever.
local loadingDetail
local loadingBar = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.69),
    Size = UDim2.new(0.5, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(15, 45, 20),
    BorderSizePixel = 0,
}, loading)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, loadingBar)
local loadingFill = make("Frame", {
    Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = Color3.fromRGB(35, 255, 30),
    BorderSizePixel = 0,
}, loadingBar)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, loadingFill)

-- Hard fallback: whatever happens, the overlay never stays longer than 20s.
task.delay(20, function()
    if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
end)

task.delay(15, function()
    if loadingGui and loadingGui.Parent then
        warn("[BALL KUN HUB] Loading watchdog: UI did not finish within 15 seconds.")
        loadingTitle.Text = "BALL KUN HUB - TIMEOUT"
        if loadingDetail then
            loadingDetail.Text = "ระบบเริ่มต้นนานเกินไป กรุณาตรวจสอบ Output ใน Roblox Studio"
        end
        task.delay(8, function()
            if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
        end)
    end
end)

loadingDetail = make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.60),
    Size = UDim2.new(0.9, 0, 0, 54), BackgroundTransparency = 1,
    Text = "กำลังเริ่มต้นระบบ...", TextColor3 = Color3.fromRGB(180, 220, 180),
    Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true,
}, loading)

local buildOK, buildError = xpcall(function()
local gui = make("ScreenGui", {
    Name = "MahanakhonHubV2",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local root = make("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(800, 540),
    BackgroundColor3 = "@bg",
    BorderSizePixel = 0,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, root)
make("UIStroke", {Color = "@line", Thickness = 1}, root)
local backgroundArt = make("ImageLabel", {
    Name = "BALLKUN_Background",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = BACKGROUND_IMAGE,
    ImageTransparency = 0.78,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, backgroundArt)
local scale = make("UIScale", {Scale = 1}, root)
local side, content, brand, subtitle, mini, showTab

local function updateScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local v = cam.ViewportSize
    if v.X < 650 then
        root.Size = UDim2.new(0.96, 0, 0.86, 0)
        scale.Scale = 1
        if side then side.Position = UDim2.fromOffset(8, 70); side.Size = UDim2.new(0, 126, 1, -80) end
        if content then content.Position = UDim2.fromOffset(142, 70); content.Size = UDim2.new(1, -150, 1, -80) end
        if brand then brand.TextSize = 15 end
        if subtitle then subtitle.TextSize = 11 end
    else
        root.Size = UDim2.fromOffset(800, 540)
        scale.Scale = math.clamp(math.min(v.X / 960, v.Y / 680), 0.72, 1) * (State.boost or 1)
        if side then side.Position = UDim2.fromOffset(12, 72); side.Size = UDim2.new(0, 178, 1, -86) end
        if content then content.Position = UDim2.fromOffset(202, 72); content.Size = UDim2.new(1, -214, 1, -86) end
        if brand then brand.TextSize = 19 end
        if subtitle then subtitle.TextSize = 12 end
    end
end
updateScale()
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    local cam = Workspace.CurrentCamera
    if cam then
        connect(cam:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end
    updateScale()
end)
if Workspace.CurrentCamera then
    connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
end

local top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = "@panel",
    BorderSizePixel = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, top)
make("Frame", {
    Position = UDim2.new(0, 0, 1, -14),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundColor3 = "@panel",
    BorderSizePixel = 0,
}, top)

brand = make("TextLabel", {
    Position = UDim2.fromOffset(20, 6),
    Size = UDim2.fromOffset(360, 27),
    BackgroundTransparency = 1,
    Text = "BALL KUN  /  มหานคร",
    TextColor3 = "@text",
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)
subtitle = make("TextLabel", {
    Position = UDim2.fromOffset(21, 34),
    Size = UDim2.fromOffset(480, 18),
    BackgroundTransparency = 1,
    Text = "บอลคุง ไงหนู  •  รุ่นทดลอง",
    TextColor3 = "@muted",
    Font = FONT,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local close = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(40, 38),
    BackgroundColor3 = Color3.fromRGB(150, 45, 60),
    Text = "×",
    TextColor3 = "@text",
    Font = Enum.Font.GothamBold,
    TextSize = 24,
    AutoButtonColor = true,
}, top)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, close)

side = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 72),
    Size = UDim2.new(0, 178, 1, -86),
    BackgroundColor3 = "@panel",
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BorderSizePixel = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, side)
local sideLayout = make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, side)
make("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 9),
    PaddingRight = UDim.new(0, 9),
}, side)

content = make("Frame", {
    Position = UDim2.fromOffset(202, 72),
    Size = UDim2.new(1, -214, 1, -86),
    BackgroundTransparency = 1,
}, root)

local pageTitle = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundTransparency = 1,
    Text = "ภาพรวม",
    TextColor3 = "@text",
    Font = Enum.Font.GothamBold,
    TextSize = 23,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local pageDesc = make("TextLabel", {
    Position = UDim2.fromOffset(0, 33),
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "สถานะเกมและเครื่องมือหลัก",
    TextColor3 = "@muted",
    Font = FONT,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local pageBody = make("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 64),
    Size = UDim2.new(1, 0, 1, -64),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = "@accent",
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, content)
make("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, pageBody)

local function clearPage()
    for _, child in ipairs(pageBody:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
end

local function card(title, desc, rightWidth)
    rightWidth = rightWidth or 0
    local f = make("Frame", {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "@panel",
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
    }, pageBody)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, f)
    make("UIStroke", {Color = "@line", Thickness = 1, Transparency = 0.4}, f)
    make("UISizeConstraint", {MinSize = Vector2.new(0, 70)}, f)
    local box = make("Frame", {
        Size = UDim2.new(1, rightWidth > 0 and -(rightWidth + 28) or 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, f)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
    }, box)
    make("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, box)
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = "@text",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    }, box)
    if desc and desc ~= "" then
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = "@muted",
            Font = FONT,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
        }, box)
    end
    return f
end

local function sectionLabel(text)
    return make("TextLabel", {
        Size = UDim2.new(1, -8, 0, 28),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = "@accent",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, pageBody)
end

local function button(parent, label, callback, width)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(width or 120, 36),
        BackgroundColor3 = "@panel2",
        Text = label,
        TextColor3 = "@text",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = true,
    }, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
    make("UIStroke", {Color = "@line", Thickness = 1}, b)
    connect(b.Activated, callback)
    return b
end

local function rowCard(title, desc, actionText, callback)
    local f = card(title, desc, 108)
    local b = button(f, actionText, callback, 108)
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -14, 0.5, 0)
    return f, b
end

-- Slide switch: green + "เปิด" when on, grey + "ปิด" when off.
local function makeSwitch(parent, initial, onChange)
    local on = initial and true or false
    local OFF = Color3.fromRGB(80, 88, 100)
    local sw = make("TextButton", {
        Size = UDim2.fromOffset(80, 36),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        BackgroundColor3 = OFF,
    }, parent)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, sw)
    local label = make("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 14, Text = "",
    }, sw)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
    }, sw)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    local function render(animate)
        sw.BackgroundColor3 = on and Theme.accent or OFF
        label.Text = on and "เปิด" or "ปิด"
        label.TextColor3 = on and Theme.bg or Color3.fromRGB(240, 243, 248)
        label.Position = on and UDim2.fromOffset(0, 0) or UDim2.fromOffset(40, 0)
        local goal = on and UDim2.new(1, -32, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
        if animate then
            knob:TweenPosition(goal, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.12, true)
        else
            knob.Position = goal
        end
    end
    render(false)
    connect(sw.Activated, function()
        on = not on
        render(true)
        onChange(on)
    end)
    return sw
end

local function setStatus(text)
    subtitle.Text = "บอลคุง ไงหนู  •  " .. tostring(text)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRootPart()
    local ch = getCharacter()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function countDescendants(rootObj, predicate)
    local n = 0
    for _, obj in ipairs(rootObj:GetDescendants()) do
        if predicate(obj) then n += 1 end
    end
    return n
end

local function removeHighlights(prefix)
    for obj, h in pairs(State.highlights) do
        if h and h.Parent and (not prefix or h.Name:sub(1, #prefix) == prefix) then
            h:Destroy()
            State.highlights[obj] = nil
        end
    end
end

local function addHighlight(obj, name, color)
    if not obj or not obj.Parent or State.highlights[obj] then return end
    if obj:IsA("Attachment") then obj = obj.Parent end
    if not obj or not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
    local h = Instance.new("Highlight")
    h.Name = name
    h.Adornee = obj
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = 0.78
    h.OutlineTransparency = 0.08
    h.DepthMode = Enum.HighlightDepthMode.Occluded
    h.Parent = gui
    State.highlights[obj] = h
end

local function clearWaypoint()
    if State.waypoint then State.waypoint:Destroy() State.waypoint = nil end
end

local function markWaypoint(part, label)
    clearWaypoint()
    if not part then return end
    local a = Instance.new("BillboardGui")
    a.Name = "LocalWaypoint"
    a.Size = UDim2.fromOffset(150, 36)
    a.StudsOffset = Vector3.new(0, 3, 0)
    a.AlwaysOnTop = true
    a.Adornee = part
    a.Parent = gui
    local t = make("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = "@bg",
        BackgroundTransparency = 0.12,
        Text = "◆  " .. label,
        TextColor3 = "@accent",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    }, a)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, t)
    State.waypoint = a
end

local function scanWorld()
    if State.scanBusy then return nil end
    State.scanBusy = true
    local result = {prompts = {}, vehicles = {}, jobs = {}, landmarks = {}}
    local ok, err = pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                table.insert(result.prompts, obj)
                local p = obj.Parent
                local path = p and p:GetFullName() or ""
                local low = string.lower(path .. " " .. obj.Name)
                if string.find(low, "job") or string.find(low, "delivery") or string.find(low, "rider") then
                    table.insert(result.jobs, obj)
                end
            elseif obj:IsA("VehicleSeat") or obj:IsA("Seat") then
                local p = obj.Parent
                if p and (string.find(string.lower(p:GetFullName()), "vehicle") or string.find(string.lower(p.Name), "car") or string.find(string.lower(p.Name), "bike")) then
                    table.insert(result.vehicles, p)
                end
            end
        end
    end)
    State.scanBusy = false
    if not ok then warn("[MAHANAKHON HUB] scan error:", err) end
    State.lastScan = os.clock()
    return result
end

local function nearestPrompt()
    local hrp = getRootPart()
    if not hrp then return nil end
    local best, bestDist
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local part = obj.Parent
            if part and part:IsA("Attachment") then part = part.Parent end
            if part and part:IsA("BasePart") then
                local d = (hrp.Position - part.Position).Magnitude
                if not bestDist or d < bestDist then best, bestDist = obj, d end
            end
        end
    end
    return best, bestDist
end

local function makeToggle(parent, title, desc, initial, changed)
    local f = card(title, desc, 80)
    makeSwitch(f, initial, changed)
    return f
end

-- ===== Feature setters (shared by every page) =====
local function highlightWhere(prefix, color, finder)
    removeHighlights(prefix)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local target = finder(obj)
        if target then addHighlight(target, prefix, color) end
    end
end

local function setPromptESP(on)
    State.promptESP = on
    removeHighlights("PromptESP")
    if on then
        highlightWhere("PromptESP", Theme.accent, function(o)
            return o:IsA("ProximityPrompt") and o.Parent or nil
        end)
    end
end

local function setVehicleESP(on)
    State.vehicleESP = on
    removeHighlights("VehicleESP")
    if on then
        highlightWhere("VehicleESP", Theme.accent2, function(o)
            return o:IsA("VehicleSeat") and o or nil
        end)
    end
end

local function setJobESP(on)
    State.jobESP = on
    removeHighlights("JobESP")
    if on then
        highlightWhere("JobESP", Theme.good, function(o)
            if o:IsA("ProximityPrompt") then
                local path = string.lower(o:GetFullName())
                if string.find(path, "job") or string.find(path, "farm") or string.find(path, "delivery") or string.find(path, "cargo") then
                    return o.Parent
                end
            end
            return nil
        end)
    end
end

local function refreshNearest()
    local p = nearestPrompt()
    if not p then return end
    local part = p.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if part and part:IsA("BasePart") and part ~= State.nearestPart then
        State.nearestPart = part
        markWaypoint(part, p.ActionText ~= "" and p.ActionText or p.Name)
    end
end

local function setAutoNearest(on)
    State.autoNearest = on
    State.nearestPart = nil
    if on then refreshNearest() else clearWaypoint() end
end

local function setMini(on)
    State.miniStatus = on
    if mini then mini.Visible = on end
end

local function setBackground(on)
    State.bgOn = on
    backgroundArt.Visible = on
end

local function setBoost(on)
    State.boost = on and 1.15 or 1
    updateScale()
end

local function setAllOff()
    setPromptESP(false)
    setVehicleESP(false)
    setJobESP(false)
    setAutoNearest(false)
    clearWaypoint()
end

local function switchPanel()
    sectionLabel("⚡ สวิตช์เปิด / ปิดฟังก์ชัน")
    makeToggle(pageBody, "✨ ไฮไลต์จุดกด", "ขอบเรืองบนจุดกดทุกจุดที่โหลดอยู่ในแผนที่", State.promptESP, setPromptESP)
    makeToggle(pageBody, "🏍️ ไฮไลต์เบาะรถ", "ขอบเรืองบนเบาะรถและมอเตอร์ไซค์", State.vehicleESP, setVehicleESP)
    makeToggle(pageBody, "🌾 ไฮไลต์จุดงาน / ฟาร์ม", "ขอบเรืองบนจุดงาน ส่งของ ฟาร์ม และสินค้า", State.jobESP, setJobESP)
    makeToggle(pageBody, "📍 หมุดจุดกดใกล้สุด (อัตโนมัติ)", "ปักหมุดจุดกดที่ใกล้ที่สุดและอัปเดตให้ทุก 2 วินาที", State.autoNearest, setAutoNearest)
    makeToggle(pageBody, "📊 แผงสถานะย่อ", "แสดงพลังชีวิต ความเร็ว และพิกัดที่มุมขวาบน", State.miniStatus, setMini)
    rowCard("⏻ ปิดทุกสวิตช์", "ปิดไฮไลต์และหมุดทั้งหมดในครั้งเดียว", "ปิดทั้งหมด", function()
        setAllOff()
        setStatus("ปิดทุกสวิตช์แล้ว")
        showTab(State.tab)
    end)
end

local function renderOverview()
    clearPage()
    local avatarCard = make("Frame", {
        Size = UDim2.new(1, -8, 0, 160),
        BackgroundColor3 = "@panel",
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
    }, pageBody)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, avatarCard)
    make("UIStroke", {Color = "@accent", Thickness = 1}, avatarCard)
    make("TextLabel", {
        Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22),
        BackgroundTransparency = 1, Text = "👤 ตัวละครผู้เล่น 3 มิติ",
        TextColor3 = "@text", Font = Enum.Font.GothamBold, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, avatarCard)
    local viewport = make("ViewportFrame", {
        Position = UDim2.new(0.5, -53, 0, 38), Size = UDim2.fromOffset(106, 114),
        BackgroundColor3 = "@panel2", BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, avatarCard)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, viewport)
    local avatar = getCharacter()
    if avatar then
        -- Character models may be non-Archivable; clone defensively so a preview
        -- failure never aborts the entire UI initialization.
        local wasArchivable = avatar.Archivable
        avatar.Archivable = true
        local cloneOK, clone = pcall(function() return avatar:Clone() end)
        avatar.Archivable = wasArchivable
        if cloneOK and clone then
            for _, item in ipairs(clone:GetDescendants()) do
                if item:IsA("Script") or item:IsA("LocalScript") then item:Destroy() end
            end
            local world = Instance.new("WorldModel")
            world.Parent = viewport
            clone.Parent = world
            local rootPart = clone:FindFirstChild("HumanoidRootPart")
            if rootPart then
                clone:PivotTo(CFrame.new(0, 0, 0))
                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(Vector3.new(0, 2.2, 6), Vector3.new(0, 1.5, 0))
                cam.Parent = viewport
                viewport.CurrentCamera = cam
            else
                clone:Destroy()
            end
        else
            warn("[BALL KUN HUB] Avatar preview skipped:", tostring(clone))
            make("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = "ไม่สามารถแสดงตัวละครตัวอย่างได้", TextColor3 = "@muted",
                Font = FONT, TextSize = 10, TextWrapped = true,
            }, viewport)
        end
    end
    local ch = getCharacter()
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hrp = getRootPart()
    local pos = hrp and hrp.Position
    card("👤 สถานะผู้เล่น", string.format(
        "ผู้เล่น: %s   |   พลังชีวิต: %s   |   ความเร็ว: %s\nพิกัด: %s",
        LocalPlayer.Name,
        hum and math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) or "N/A",
        hum and math.floor(hum.WalkSpeed) or "N/A",
        pos and string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z) or "N/A"
    ))
    switchPanel()
    sectionLabel("🛠️ เครื่องมือ")
    rowCard("🔎 สำรวจโลก", "ตรวจหาจุดกด งาน และเบาะยานพาหนะที่มองเห็นได้", "สแกน", function()
        local r = scanWorld()
        if r then
            setStatus(string.format("สแกนแล้ว: จุดกด %d / เบาะรถ %d", #r.prompts, #r.vehicles))
            renderOverview()
        end
    end)
    rowCard("📍 จุดกดที่ใกล้ที่สุด", "ปักหมุดจุดกดที่อยู่ใกล้ที่สุด โดยไม่กดใช้งานแทนผู้เล่น", "ปักหมุด", function()
        local p, d = nearestPrompt()
        if p then
            local part = p.Parent
            if part and part:IsA("Attachment") then part = part.Parent end
            if part and part:IsA("BasePart") then markWaypoint(part, p.ActionText ~= "" and p.ActionText or p.Name) end
            setStatus("จุดกดใกล้สุดห่าง " .. math.floor(d or 0) .. " studs")
        else
            setStatus("ไม่พบจุดกด")
        end
    end)
    rowCard("🧹 ล้างหมุด", "ลบหมุดที่สร้างไว้บนหน้าจอ", "ล้าง", function()
        clearWaypoint()
        setStatus("ล้างหมุดแล้ว")
    end)
    card("🧩 ระบบที่ตรวจพบ", "ตรวจพบหมวดงานส่งของ งานทั่วไป แข่งขัน โรงรถ แต่งรถ ECU ดูแลรถ สินค้า ลูกสูบ ป้าย หมวก ไดโน แผนที่ ภารกิจ และรางวัล ฮับนี้อ่านข้อมูลที่เครื่องมองเห็นเท่านั้น")
end

local function renderJobs()
    clearPage()
    card("📦 งานและส่งของ", "ไฟล์สำรวจเกมพบระบบส่งของและงานต่าง ๆ การเริ่ม รับ หรือส่งงานให้ดำเนินการผ่านหน้าจอเกมตามปกติ")
    rowCard("📱 แอปส่งของ", "ตรวจหาแอปส่งของจากหน้าจอโทรศัพท์ในเกม", "ค้นหาแอป", function()
        local phone = PlayerGui:FindFirstChild("Phone")
        local app = phone and phone:FindFirstChild("Dock", true)
        local delivery = app and app:FindFirstChild("delivery", true)
        if delivery and delivery:IsA("GuiButton") then
            setStatus("พบแอปส่งของ - กดในโทรศัพท์ได้เลย")
        else
            setStatus("กรุณาเปิดโทรศัพท์ในเกมก่อน")
        end
    end)
    rowCard("📦 ตู้รับงาน", "ค้นหาและปักหมุดตำแหน่งตู้รับงานเมื่อโหลดเข้ามาแล้ว", "ค้นหาตู้", function()
        local root = Workspace:FindFirstChild("Map")
        local locker = root and root:FindFirstChild("JobLockers", true)
        local prompt = locker and locker:FindFirstChild("LockerPrompt", true)
        local part = prompt and prompt.Parent
        if part and part:IsA("Attachment") then part = part.Parent end
        if part and part:IsA("BasePart") then
            markWaypoint(part, "ตู้รับงาน")
            setStatus("พบตู้รับงาน")
        else
            setStatus("ตู้ยังไม่โหลดในแผนที่")
        end
    end)
    rowCard("📋 สถานะงานส่งของ", "อ่านข้อมูลสถานะงานที่เครื่องมองเห็นได้", "รีเฟรช", function()
        local found = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "DeliveryState" or obj.Name == "DeliveryJob" or obj.Name == "DeliveryArrived" then
                table.insert(found, obj:GetFullName() .. " = " .. tostring(obj.Value or obj:GetAttribute("Value") or "present"))
            end
        end
        setStatus(#found > 0 and ("พบข้อมูลสถานะ " .. #found .. " รายการ") or "ไม่พบข้อมูลสถานะในเครื่อง")
        if #found > 0 then print("[MAHANAKHON HUB] Delivery state:\n" .. table.concat(found, "\n")) end
    end)
    card("🛡️ ข้อจำกัดการทำงาน", "ไม่สร้างยอดงานปลอม ไม่เรียกคำสั่งเซิร์ฟเวอร์ และไม่กดรับรางวัลอัตโนมัติ")
end

local function renderVehicles()
    clearPage()
    card("🏍️ ระบบยานพาหนะ", "พบระบบรถยนต์ PCX160 โรงรถ ร้านแต่งรถ ECU ดูแลรถ รายละเอียดรถ และไดโน การเปลี่ยนค่าที่บันทึกกับเซิร์ฟเวอร์ให้ใช้เมนูในเกม")
    makeToggle(pageBody, "💡 ไฮไลต์เบาะรถ", "ไฮไลต์เบาะรถที่มองเห็นได้บนหน้าจอ", State.vehicleESP, setVehicleESP)
    rowCard("🚘 หน้าต่างโรงรถ", "ตรวจสอบว่าหน้าต่างโรงรถของเกมเปิดอยู่หรือไม่", "ตรวจสอบ", function()
        local g = PlayerGui:FindFirstChild("GarageWindow")
        setStatus(g and "พบหน้าต่างโรงรถ" or "กรุณาเปิดโรงรถในเกมก่อน")
    end)
    rowCard("🧽 หน้าต่างดูแลรถ", "ตรวจสอบหน้าต่างดูแลรถของเกม", "ตรวจสอบ", function()
        local v = PlayerGui:FindFirstChild("VehicleCare")
        setStatus(v and "พบหน้าต่างดูแลรถ" or "ยังไม่ได้เปิดหน้าต่างดูแลรถ")
    end)
    rowCard("🧹 ล้างไฮไลต์รถ", "ลบไฮไลต์ที่สร้างไว้บนหน้าจอ", "ล้าง", function()
        setVehicleESP(false)
        setStatus("ล้างไฮไลต์รถแล้ว")
        showTab(State.tab)
    end)
end

local function renderRace()
    clearPage()
    card("🏁 แข่งขันและสนาม", "พบระบบแข่งขัน ตัวนับถอยหลัง และคิวดวล การเข้าร่วมและผลการแข่งขันยังควบคุมโดยระบบเกม")
    rowCard("🔎 ตรวจหน้าต่างแข่ง", "ตรวจหาหน้าต่างการแข่งขันที่มองเห็นได้", "สแกน", function()
        local hits = {}
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            local n = string.lower(obj.Name)
            if string.find(n, "race") or string.find(n, "countdown") or string.find(n, "duel") then
                table.insert(hits, obj:GetFullName())
            end
        end
        setStatus(#hits > 0 and ("พบหน้าต่างแข่ง " .. #hits .. " รายการ") or "ยังไม่เปิดหน้าต่างแข่ง")
        for _, v in ipairs(hits) do print("[RACE UI]", v) end
    end)
    rowCard("📍 ตำแหน่งผู้เล่น", "แสดงตำแหน่งปัจจุบันในคอนโซล", "บันทึก", function()
        local p = getRootPart()
        if p then print("[MAHANAKHON HUB] Position:", p.Position) setStatus("บันทึกพิกัดแล้ว") else setStatus("ตัวละครยังไม่พร้อม") end
    end)
end

local function renderFarm()
    clearPage()
    card("🌾 ฟาร์มและสินค้า", "พบระบบตรวจฟาร์ม เก็บสินค้า ลูกสูบ และโฟลเดอร์ที่เกี่ยวข้อง หน้านี้ใช้ค้นหาและปักหมุดข้อมูลที่มองเห็นได้เท่านั้น")
    makeToggle(pageBody, "🌾 ไฮไลต์จุดงาน / ฟาร์ม", "ไฮไลต์จุดกดที่เกี่ยวข้องกับงาน ฟาร์ม ส่งของ หรือสินค้า", State.jobESP, setJobESP)
    rowCard("📦 สแกนสินค้า", "ค้นหาโมเดลและจุดกดที่เกี่ยวข้องกับสินค้า", "สแกน", function()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local s = string.lower(obj.Name .. " " .. obj:GetFullName())
            if string.find(s, "cargo") or string.find(s, "piston") then
                n += 1
            end
        end
        setStatus("พบสินค้า / ลูกสูบ " .. n .. " รายการ")
    end)
    rowCard("🧹 ล้างหมุดฟาร์ม", "ลบไฮไลต์งานและฟาร์ม", "ล้าง", function()
        setJobESP(false)
        setStatus("ล้างหมุดฟาร์มแล้ว")
        showTab(State.tab)
    end)
end

local function renderMap()
    clearPage()
    card("🗺️ แผนที่อัจฉริยะ", "แผนที่ใช้ Workspace/Map และอาจโหลดวัตถุบางส่วนเมื่อเข้าใกล้พื้นที่เท่านั้น")
    makeToggle(pageBody, "✨ ไฮไลต์จุดกด", "ไฮไลต์จุดกดทั้งหมดที่โหลดอยู่ในขณะนี้", State.promptESP, setPromptESP)
    makeToggle(pageBody, "📍 หมุดจุดกดใกล้สุด (อัตโนมัติ)", "ปักหมุดจุดกดที่ใกล้ที่สุดและอัปเดตทุก 2 วินาที", State.autoNearest, setAutoNearest)
    rowCard("🗺️ สแกนแผนที่", "นับจุดกด เบาะรถ และวัตถุในแผนที่ที่โหลดอยู่", "สแกน", function()
        local r = scanWorld()
        if r then
            local map = Workspace:FindFirstChild("Map")
            local descendants = map and #map:GetDescendants() or 0
            setStatus(string.format("แผนที่ %d วัตถุ / จุดกด %d / เบาะรถ %d", descendants, #r.prompts, #r.vehicles))
        end
    end)
    rowCard("🧹 ล้างหมุดแผนที่", "ลบไฮไลต์จุดกดและหมุดนำทาง", "ล้าง", function()
        setPromptESP(false)
        setAutoNearest(false)
        clearWaypoint()
        setStatus("ล้างหมุดแผนที่แล้ว")
        showTab(State.tab)
    end)
end

local navButtons = {}

local function renderTools()
    clearPage()
    card("🧰 เครื่องมือในเครื่อง", "เครื่องมือด้านล่างทำงานเฉพาะหน้าจอผู้เล่น ไม่แก้ไขค่าการเล่นที่เซิร์ฟเวอร์ควบคุม")
    sectionLabel("🎨 การแสดงผล")
    makeToggle(pageBody, "🖼️ ภาพพื้นหลัง", "เปิดภาพพื้นหลังของหน้าต่าง ปิดไว้ตัวหนังสือจะชัดขึ้น", State.bgOn, setBackground)
    makeToggle(pageBody, "🔍 ขยาย UI 15%", "ทำให้หน้าต่างและตัวหนังสือใหญ่ขึ้น (เฉพาะหน้าจอใหญ่)", State.boost > 1, setBoost)
    sectionLabel("🛠️ เครื่องมือ")
    rowCard("👤 รีเฟรชตัวละคร", "อ่านข้อมูลตัวละครและพลังชีวิตอีกครั้ง", "รีเฟรช", function()
        local ch = getCharacter()
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        setStatus(h and ("พลังชีวิต " .. math.floor(h.Health)) or "ตัวละครยังไม่พร้อม")
    end)
    rowCard("🧹 ล้างข้อมูลชั่วคราว", "ลบหมุดและไฮไลต์ทั้งหมดที่ฮับนี้สร้างไว้", "ล้างทั้งหมด", function()
        setAllOff()
        removeHighlights()
        setStatus("ล้างหมุดทั้งหมดแล้ว")
        showTab(State.tab)
    end)
    rowCard("⏻ ปิดฮับ", "ยกเลิกการเชื่อมต่อและปิดหน้าต่างฮับ", "ปิดฮับ", function()
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        removeHighlights()
        clearWaypoint()
        gui:Destroy()
    end)
end

local function renderSettings()
    clearPage()
    card("⚙️ ตั้งค่าหน้าตา", "เลือกสีหลักของ UI ได้ทันที และลากแถบด้านบนเพื่อย้ายตำแหน่งหน้าต่าง")
    local themeCard = card("🌈 สีธีม", "เลือกสีที่ต้องการ")
    local palettes = {
        {"เขียวนีออน", {bg=Color3.fromRGB(3,12,5),   panel=Color3.fromRGB(5,22,10),  panel2=Color3.fromRGB(10,42,18), line=Color3.fromRGB(25,210,55),  accent=Color3.fromRGB(35,255,30),  accent2=Color3.fromRGB(0,220,150)}},
        {"ฟ้าน้ำทะเล", {bg=Color3.fromRGB(3,8,14),   panel=Color3.fromRGB(6,18,30),  panel2=Color3.fromRGB(10,36,58), line=Color3.fromRGB(0,170,230),  accent=Color3.fromRGB(0,210,255),  accent2=Color3.fromRGB(40,120,255)}},
        {"ม่วง",       {bg=Color3.fromRGB(8,4,14),   panel=Color3.fromRGB(18,9,30),  panel2=Color3.fromRGB(36,18,60), line=Color3.fromRGB(150,70,230), accent=Color3.fromRGB(180,80,255), accent2=Color3.fromRGB(100,70,220)}},
        {"แดง",        {bg=Color3.fromRGB(14,4,5),   panel=Color3.fromRGB(28,8,10),  panel2=Color3.fromRGB(56,14,18), line=Color3.fromRGB(230,55,65),  accent=Color3.fromRGB(255,65,75),  accent2=Color3.fromRGB(255,130,30)}},
        {"ทอง",        {bg=Color3.fromRGB(14,10,3),  panel=Color3.fromRGB(28,20,6),  panel2=Color3.fromRGB(56,40,10), line=Color3.fromRGB(230,165,25), accent=Color3.fromRGB(255,190,35), accent2=Color3.fromRGB(255,115,20)}},
    }
    for i, palette in ipairs(palettes) do
        local b = button(themeCard, palette[1], function()
            for k, v in pairs(palette[2]) do Theme[k] = v end
            applyTheme()
            showTab(State.tab)
            setStatus("เปลี่ยนสีธีมแล้ว")
        end, 100)
        b.Position = UDim2.fromOffset(14 + ((i-1)%3)*108, 64 + math.floor((i-1)/3)*44)
        b.BackgroundColor3 = palette[2].accent
        b.TextColor3 = Color3.fromRGB(8, 12, 8)
    end
    themeCard.AutomaticSize = Enum.AutomaticSize.None
    themeCard.Size = UDim2.new(1, -8, 0, 156)
    rowCard("รีเซ็ตหน้าต่าง", "ย้ายหน้าต่างกลับมากึ่งกลางหน้าจอ", "จัดกลาง", function()
        root.Position = UDim2.fromScale(0.5, 0.5)
        setStatus("จัดหน้าต่างกลางจอแล้ว")
    end)
    rowCard("👁️ ซ่อน / แสดง UI", "กด RightControl เพื่อซ่อนหรือแสดงหน้าต่าง", "เข้าใจแล้ว", function()
        setStatus("กด RightControl เพื่อซ่อน/แสดง")
    end)
    card("👑 เกี่ยวกับฮับ", "BALL KUN HUB • MAHANAKHON v3.0  |  PlaceId 104549080643413\nClient-side companion. No remote invocation or server-side bypass.")
end

local pages = {
    Overview = {renderOverview, "Live player status and quick tools"},
    Jobs = {renderJobs, "Delivery, work and job discovery"},
    Vehicles = {renderVehicles, "Garage, bike, car and tuning"},
    Race = {renderRace, "Race interface and track utilities"},
    Farm = {renderFarm, "Farm checks, cargo and piston discovery"},
    Map = {renderMap, "Adaptive map and local markers"},
    Tools = {renderTools, "Local utilities and cleanup"},
    Settings = {renderSettings, "Interface and hub settings"},
}
local tabThai = {
    Overview = "🏠 ภาพรวม", Jobs = "📦 งาน / ส่งของ", Vehicles = "🏍️ รถและแต่งรถ",
    Race = "🏁 แข่งขัน", Farm = "🌾 ฟาร์ม", Map = "🗺️ แผนที่",
    Tools = "🧰 เครื่องมือ", Settings = "⚙️ ตั้งค่า"
}
local descThai = {
    Overview = "สถานะผู้เล่นและเครื่องมือหลัก",
    Jobs = "ระบบงานและการส่งของ",
    Vehicles = "โรงรถ รถยนต์ มอเตอร์ไซค์ และการแต่งรถ",
    Race = "ข้อมูลการแข่งขันและสนาม",
    Farm = "ตรวจสอบฟาร์ม สินค้า และจุดทำงาน",
    Map = "แผนที่และจุดที่ตรวจพบ",
    Tools = "เครื่องมือใช้งานเฉพาะเครื่อง",
    Settings = "ปรับแต่งหน้าตาและการใช้งาน"
}
function showTab(name)
    if not pages[name] then return end
    State.tab = name
    pageTitle.Text = tabThai[name] or name
    pageDesc.Text = descThai[name] or pages[name][2]
    for n, b in pairs(navButtons) do
        b.BackgroundColor3 = n == name and Theme.accent or Theme.panel2
        b.TextColor3 = n == name and Theme.bg or Theme.text
    end
    local ok, err = xpcall(pages[name][1], function(e)
        return debug.traceback(tostring(e), 2)
    end)
    if not ok then
        warn("[BALL KUN HUB] Tab render failed (" .. tostring(name) .. "):\n" .. tostring(err))
        clearPage()
        card("⚠️ โหลดหมวดหมู่ไม่สำเร็จ", "หมวดนี้เกิดข้อผิดพลาด แต่หน้าหลักยังใช้งานได้ กรุณาตรวจ Output ใน Roblox Studio")
        setStatus("พบข้อผิดพลาดในหมวด " .. tostring(name))
    end
end

local tabNames = {"Overview", "Jobs", "Vehicles", "Race", "Farm", "Map", "Tools", "Settings"}
for i, name in ipairs(tabNames) do
    local b = make("TextButton", {
        Name = name,
        Size = UDim2.new(1, -2, 0, 44),
        BackgroundColor3 = "@panel2",
        Text = tabThai[name] or name,
        TextColor3 = "@text",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = true,
        LayoutOrder = i,
    }, side)
    make("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
    make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, b)
    navButtons[name] = b
    connect(b.Activated, function() showTab(name) end)
end

mini = make("Frame", {
    Name = "MiniStatus",
    Position = UDim2.new(1, -276, 0, 14),
    Size = UDim2.fromOffset(262, 66),
    BackgroundColor3 = "@panel",
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Visible = State.miniStatus,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, mini)
make("UIStroke", {Color = "@line", Thickness = 1}, mini)
local miniText = make("TextLabel", {
    Position = UDim2.fromOffset(10, 7),
    Size = UDim2.new(1, -20, 1, -14),
    BackgroundTransparency = 1,
    Text = "BALL KUN HUB  •  พร้อมใช้งาน",
    TextColor3 = "@accent",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, mini)

-- Drag window from top bar.
local dragging, dragStart, startPos
connect(top.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = root.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightControl then
        root.Visible = not root.Visible
    end
end)
connect(close.Activated, function() root.Visible = false end)

-- Floating open/close button (mobile has no RightControl key)
local fab = make("TextButton", {
    Name = "ToggleHub",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.fromOffset(48, 48),
    BackgroundColor3 = "@panel",
    Text = "BK",
    TextColor3 = "@accent",
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
    ZIndex = 50,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, fab)
make("UIStroke", {Color = "@accent", Thickness = 1.5}, fab)
connect(fab.Activated, function() root.Visible = not root.Visible end)

-- Lightweight status refresh; no repeated Workspace scans.
local tickAccum = 0
connect(RunService.Heartbeat, function(dt)
    tickAccum += dt
    if tickAccum < 0.5 then return end
    tickAccum = 0
    local ch = getCharacter()
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hrp = getRootPart()
    if hum and hrp then
        miniText.Text = string.format("BALL KUN HUB  •  พร้อมใช้งาน\nHP %d/%d  |  เร็ว %d\nพิกัด %.0f, %.0f, %.0f",
            math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(hum.WalkSpeed),
            hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
    else
        miniText.Text = "กำลังรอตัวละคร..."
    end
end)

local nearAccum = 0
connect(RunService.Heartbeat, function(dt)
    if not State.autoNearest then return end
    nearAccum += dt
    if nearAccum < 2 then return end
    nearAccum = 0
    refreshNearest()
end)

connect(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    setStatus("ตัวละครพร้อมแล้ว")
end)

showTab("Overview")
setStatus("พร้อมใช้งาน")
-- Reveal the main UI immediately after its shell is built; do not leave the
-- loading overlay covering a usable interface while optional content loads.
print("[BALL KUN HUB] Loaded v3.0 for PlaceId", PLACE_ID)

-- Finish the loading overlay (short progress animation, then remove).
-- Wrapped so an animation error can never keep the overlay on screen.
task.spawn(function()
    pcall(function()
        loadingDetail.Text = "พร้อมแล้ว"
        loadingFill:TweenSize(UDim2.fromScale(1, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.9, true)
        task.wait(1.0)
    end)
    if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
end)

-- Background image: runs after the file finished loading (BG_DATA is set at the end),
-- and never blocks the UI. Any failure just leaves the plain dark background.
task.defer(function()
    local function setBg(image)
        if image and image ~= "" then
            backgroundArt.Image = image
        end
    end
    if BACKGROUND_IMAGE ~= "" then setBg(BACKGROUND_IMAGE) return end
    local getAsset = getcustomasset or getsynasset or (getgenv and getgenv().getcustomasset)
    if not (getAsset and writefile) then
        warn("[BALL KUN HUB] Executor has no writefile/getcustomasset - background skipped")
        return
    end
    local function fromBytes(bytes, name)
        local ok, asset = pcall(function()
            writefile(name, bytes)
            return getAsset(name)
        end)
        if ok then setBg(asset) else warn("[BALL KUN HUB] background failed:", tostring(asset)) end
        return ok
    end
    if BACKGROUND_URL ~= "" then
        local ok, bytes = pcall(function() return game:HttpGet(BACKGROUND_URL) end)
        if ok and bytes and #bytes > 100 and fromBytes(bytes, "ballkun_bg_custom.jpg") then return end
    end
    if BG_DATA and BG_DATA ~= "" then
        local ok, bytes = pcall(function()
            local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local lookup = {}
            for i = 1, #chars do lookup[chars:byte(i)] = i - 1 end
            local out, n = {}, 0
            local data = BG_DATA:gsub("%s", "")
            for i = 1, #data, 4 do
                local a, b, c, d = data:byte(i, i + 3)
                local v = lookup[a] * 262144 + lookup[b] * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
                n += 1
                out[n] = string.char(math.floor(v / 65536) % 256)
                if c ~= 61 then n += 1; out[n] = string.char(math.floor(v / 256) % 256) end
                if d ~= 61 then n += 1; out[n] = string.char(v % 256) end
            end
            return table.concat(out)
        end)
        if ok and bytes then fromBytes(bytes, "ballkun_bg.jpg") end
    end
end)

end, function(err)
    return debug.traceback(tostring(err), 2)
end)

if not buildOK then
    warn("[BALL KUN HUB] UI initialization failed:\n" .. tostring(buildError))
    loadingTitle.Text = "BALL KUN HUB - ERROR"
    loadingTitle.TextColor3 = Color3.fromRGB(255, 90, 90)
    loadingDetail.Text = "เกิดข้อผิดพลาดตอนสร้าง UI\nดูรายละเอียดใน Output ของ Roblox Studio"
    loadingDetail.TextColor3 = Color3.fromRGB(255, 170, 170)
    task.delay(12, function()
        if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
    end)
end

-- ภาพพื้นหลังฝังในไฟล์ (JPEG base64) - ไม่ต้องแก้
BG_DATA = [[
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
ycRRWFml2ZlAUE+WKybiwFhjmPsRRf/Z
]]
