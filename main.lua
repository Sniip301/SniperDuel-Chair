--[[
    DORA // SniperDuel-Chair v2
    Target: Sniper Duels (LOCKED IN NETWORK) — Roblox

    Features:
      AIMBOT
        - Enable aimbot / Always-on aimbot
        - Aimbot smoothing + key selector
        - Triggerbot (auto-fire on crosshair)
        - Silent aim + FOV + hit chance
        - Aim part selector
        - FOV circle (adjustable, rainbow option)

      VISUALS
        - ESP Boxes (2D)
        - Tracers (top / center / bottom)
        - Chams (highlight, rainbow mode)
        - Names
        - Health bars
        - Weapon chams transparency
        - Tracer type selector

      MOVEMENT
        - 3rd person camera
        - Bunnyhop

    Toggle menu: INSERT
]]

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

--------------------------------------------------------------------
-- CLEANUP PREVIOUS INSTANCE
--------------------------------------------------------------------
if getgenv and getgenv().ByteCleanup then
    pcall(getgenv().ByteCleanup)
    task.wait(0.2)
end

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local Config = {
    -- Aimbot
    AimbotEnabled     = true,
    AlwaysOnAimbot    = false,
    Smoothness        = 5,
    AimbotKeyName     = "MouseButton2",
    AimbotKey         = Enum.UserInputType.MouseButton2,

    -- Triggerbot
    TriggerbotEnabled = false,
    TriggerbotDelay   = 80, -- ms

    -- Silent Aim
    SilentAimEnabled  = false,
    SilentAimFOV      = 150,
    SilentAimChance   = 85, -- percent

    -- Aim Part
    AimPart           = "Head", -- Head, HumanoidRootPart, UpperTorso

    -- FOV Circle
    FOVEnabled        = true,
    MaxFOV            = 250,
    RainbowFOV        = false,

    -- Visuals master
    VisualsEnabled    = true,

    -- ESP
    BoxesEnabled      = false,
    TracersEnabled    = false,
    NamesEnabled      = true,
    HealthBarEnabled  = false,
    TracerOrigin      = "Bottom", -- Top, Center, Bottom

    -- Chams
    ChamsEnabled      = true,
    RainbowChams      = false,
    ChamsTransparency = 0.3,

    -- Weapon Chams
    WeaponChamsTransparency = 0.5,

    -- 3rd Person
    ThirdPersonEnabled = false,
    ThirdPersonDist    = 12,

    -- Bunnyhop
    BhopEnabled       = false,

    -- Menu
    MenuOpen          = false,
}

-- Key mapping table
local KeyMap = {
    ["MouseButton1"] = Enum.UserInputType.MouseButton1,
    ["MouseButton2"] = Enum.UserInputType.MouseButton2,
    ["Q"] = Enum.KeyCode.Q,
    ["E"] = Enum.KeyCode.E,
    ["R"] = Enum.KeyCode.R,
    ["F"] = Enum.KeyCode.F,
    ["X"] = Enum.KeyCode.X,
    ["C"] = Enum.KeyCode.C,
    ["V"] = Enum.KeyCode.V,
    ["CapsLock"] = Enum.KeyCode.CapsLock,
    ["LeftAlt"] = Enum.KeyCode.LeftAlt,
    ["LeftShift"] = Enum.KeyCode.LeftShift,
}

local KeyIsMouseButton = {
    ["MouseButton1"] = true,
    ["MouseButton2"] = true,
}

local AimPartOptions = { "Head", "HumanoidRootPart", "UpperTorso" }
local TracerOriginOptions = { "Bottom", "Center", "Top" }
local KeyOptions = { "MouseButton2", "MouseButton1", "Q", "E", "R", "F", "X", "C", "V", "CapsLock", "LeftAlt", "LeftShift" }

--------------------------------------------------------------------
-- DRAWING CACHE
--------------------------------------------------------------------
local DrawingCache = {} -- [Player] = { box, tracer, name, healthBg, healthBar }
local FOVCircle = nil
local SilentFOVCircle = nil

pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible     = true
    FOVCircle.Thickness   = 1.4
    FOVCircle.Color       = Color3.fromRGB(255, 40, 40)
    FOVCircle.Transparency = 0.5
    FOVCircle.Filled      = false
    FOVCircle.NumSides    = 80
    FOVCircle.Radius      = Config.MaxFOV

    SilentFOVCircle = Drawing.new("Circle")
    SilentFOVCircle.Visible     = false
    SilentFOVCircle.Thickness   = 1.2
    SilentFOVCircle.Color       = Color3.fromRGB(255, 0, 255)
    SilentFOVCircle.Transparency = 0.6
    SilentFOVCircle.Filled      = false
    SilentFOVCircle.NumSides    = 60
    SilentFOVCircle.Radius      = Config.SilentAimFOV
end)

--------------------------------------------------------------------
-- ESP DRAWING HELPERS
--------------------------------------------------------------------
local function createESPDrawings(player)
    if DrawingCache[player] then return end

    local cache = {}

    pcall(function()
        -- Box (4 lines)
        cache.boxLines = {}
        for i = 1, 4 do
            local l = Drawing.new("Line")
            l.Visible = false
            l.Color = Color3.fromRGB(255, 40, 40)
            l.Thickness = 1.2
            l.Transparency = 1
            cache.boxLines[i] = l
        end

        -- Tracer
        cache.tracer = Drawing.new("Line")
        cache.tracer.Visible = false
        cache.tracer.Color = Color3.fromRGB(255, 40, 40)
        cache.tracer.Thickness = 1.2
        cache.tracer.Transparency = 1

        -- Name
        cache.name = Drawing.new("Text")
        cache.name.Visible = false
        cache.name.Color = Color3.fromRGB(255, 255, 255)
        cache.name.Size = 14
        cache.name.Center = true
        cache.name.Outline = true
        cache.name.OutlineColor = Color3.fromRGB(0, 0, 0)
        cache.name.Text = player.DisplayName or player.Name

        -- Health bar background
        cache.healthBg = Drawing.new("Line")
        cache.healthBg.Visible = false
        cache.healthBg.Color = Color3.fromRGB(40, 40, 40)
        cache.healthBg.Thickness = 3
        cache.healthBg.Transparency = 1

        -- Health bar fill
        cache.healthBar = Drawing.new("Line")
        cache.healthBar.Visible = false
        cache.healthBar.Color = Color3.fromRGB(0, 255, 0)
        cache.healthBar.Thickness = 2
        cache.healthBar.Transparency = 1
    end)

    DrawingCache[player] = cache
end

local function removeESPDrawings(player)
    local cache = DrawingCache[player]
    if not cache then return end
    pcall(function()
        if cache.boxLines then
            for _, l in ipairs(cache.boxLines) do l:Remove() end
        end
        if cache.tracer then cache.tracer:Remove() end
        if cache.name then cache.name:Remove() end
        if cache.healthBg then cache.healthBg:Remove() end
        if cache.healthBar then cache.healthBar:Remove() end
    end)
    DrawingCache[player] = nil
end

local function updateESP(player, cache)
    local char = player.Character
    if not char or player == LocalPlayer then
        -- hide all
        pcall(function()
            if cache.boxLines then for _, l in ipairs(cache.boxLines) do l.Visible = false end end
            if cache.tracer then cache.tracer.Visible = false end
            if cache.name then cache.name.Visible = false end
            if cache.healthBg then cache.healthBg.Visible = false end
            if cache.healthBar then cache.healthBar.Visible = false end
        end)
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hum or not hrp or not head or hum.Health <= 0 then
        pcall(function()
            if cache.boxLines then for _, l in ipairs(cache.boxLines) do l.Visible = false end end
            if cache.tracer then cache.tracer.Visible = false end
            if cache.name then cache.name.Visible = false end
            if cache.healthBg then cache.healthBg.Visible = false end
            if cache.healthBar then cache.healthBar.Visible = false end
        end)
        return
    end

    local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
    local footPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

    if not onScreen then
        pcall(function()
            if cache.boxLines then for _, l in ipairs(cache.boxLines) do l.Visible = false end end
            if cache.tracer then cache.tracer.Visible = false end
            if cache.name then cache.name.Visible = false end
            if cache.healthBg then cache.healthBg.Visible = false end
            if cache.healthBar then cache.healthBar.Visible = false end
        end)
        return
    end

    local boxH = math.abs(headPos.Y - footPos.Y)
    local boxW = boxH * 0.55

    local topLeft = Vector2.new(rootPos.X - boxW / 2, headPos.Y)
    local topRight = Vector2.new(rootPos.X + boxW / 2, headPos.Y)
    local bottomLeft = Vector2.new(rootPos.X - boxW / 2, footPos.Y)
    local bottomRight = Vector2.new(rootPos.X + boxW / 2, footPos.Y)

    pcall(function()
        -- Boxes
        local showBoxes = Config.VisualsEnabled and Config.BoxesEnabled
        if cache.boxLines then
            cache.boxLines[1].From = topLeft
            cache.boxLines[1].To = topRight
            cache.boxLines[1].Visible = showBoxes

            cache.boxLines[2].From = topRight
            cache.boxLines[2].To = bottomRight
            cache.boxLines[2].Visible = showBoxes

            cache.boxLines[3].From = bottomRight
            cache.boxLines[3].To = bottomLeft
            cache.boxLines[3].Visible = showBoxes

            cache.boxLines[4].From = bottomLeft
            cache.boxLines[4].To = topLeft
            cache.boxLines[4].Visible = showBoxes
        end

        -- Tracers
        local showTracers = Config.VisualsEnabled and Config.TracersEnabled
        if cache.tracer then
            cache.tracer.Visible = showTracers
            if showTracers then
                local vp = Camera.ViewportSize
                local origin
                if Config.TracerOrigin == "Top" then
                    origin = Vector2.new(vp.X / 2, 0)
                elseif Config.TracerOrigin == "Center" then
                    origin = Vector2.new(vp.X / 2, vp.Y / 2)
                else
                    origin = Vector2.new(vp.X / 2, vp.Y)
                end
                cache.tracer.From = origin
                cache.tracer.To = Vector2.new(rootPos.X, footPos.Y)
            end
        end

        -- Names
        local showNames = Config.VisualsEnabled and Config.NamesEnabled
        if cache.name then
            cache.name.Visible = showNames
            if showNames then
                cache.name.Position = Vector2.new(rootPos.X, headPos.Y - 18)
                cache.name.Text = player.DisplayName or player.Name
            end
        end

        -- Health bar
        local showHealth = Config.VisualsEnabled and Config.HealthBarEnabled
        if cache.healthBg and cache.healthBar then
            cache.healthBg.Visible = showHealth
            cache.healthBar.Visible = showHealth
            if showHealth then
                local barX = topLeft.X - 5
                cache.healthBg.From = Vector2.new(barX, footPos.Y)
                cache.healthBg.To = Vector2.new(barX, headPos.Y)

                local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local barTop = footPos.Y + (headPos.Y - footPos.Y) * ratio
                cache.healthBar.From = Vector2.new(barX, footPos.Y)
                cache.healthBar.To = Vector2.new(barX, barTop)

                -- color gradient: green > yellow > red
                local r = math.clamp(2 * (1 - ratio), 0, 1)
                local g = math.clamp(2 * ratio, 0, 1)
                cache.healthBar.Color = Color3.new(r, g, 0)
            end
        end
    end)
end

--------------------------------------------------------------------
-- CHAMS
--------------------------------------------------------------------
local chamsCache = {} -- [Player] = Highlight

local function applyChams(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if chamsCache[player] then return end

    local hl = Instance.new("Highlight")
    hl.Name = "DoraChams"
    hl.FillColor = Color3.fromRGB(255, 20, 20)
    hl.FillTransparency = Config.ChamsTransparency
    hl.OutlineColor = Color3.fromRGB(255, 60, 60)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char
    chamsCache[player] = hl
end

local function removeChams(player)
    local hl = chamsCache[player]
    if hl then pcall(function() hl:Destroy() end) end
    chamsCache[player] = nil
end

local function refreshChams(rainbowColor)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if Config.VisualsEnabled and Config.ChamsEnabled then
                applyChams(p)
                local hl = chamsCache[p]
                if hl then
                    hl.FillTransparency = Config.ChamsTransparency
                    if Config.RainbowChams and rainbowColor then
                        hl.FillColor = rainbowColor
                        hl.OutlineColor = rainbowColor
                    else
                        hl.FillColor = Color3.fromRGB(255, 20, 20)
                        hl.OutlineColor = Color3.fromRGB(255, 60, 60)
                    end
                end
            else
                removeChams(p)
            end
        end
    end
end

--------------------------------------------------------------------
-- WEAPON CHAMS (tool transparency)
--------------------------------------------------------------------
local function updateWeaponChams()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            for _, obj in ipairs(p.Character:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Tool") then
                    pcall(function()
                        obj.Transparency = Config.VisualsEnabled and Config.WeaponChamsTransparency or 0
                    end)
                end
            end
        end
    end
end

--------------------------------------------------------------------
-- PLAYER HOOKS
--------------------------------------------------------------------
local function hookPlayer(player)
    if player == LocalPlayer then return end
    createESPDrawings(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        chamsCache[player] = nil
        if Config.VisualsEnabled and Config.ChamsEnabled then applyChams(player) end
    end)
    if player.Character and Config.VisualsEnabled and Config.ChamsEnabled then
        applyChams(player)
    end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p)
    removeChams(p)
    removeESPDrawings(p)
end)

--------------------------------------------------------------------
-- UI FRAMEWORK
--------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DoraUI_SniperDuels"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 320, 0, 580)
Frame.Position = UDim2.new(0.5, -160, 0.5, -290)
Frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Frame.BorderSizePixel = 0
Frame.Visible = false
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 50, 120)
mainStroke.Thickness = 1.5
mainStroke.Parent = Frame

-- Title
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Frame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "🌸 DORA  //  SNIPER DUELS"
Title.TextColor3 = Color3.fromRGB(255, 100, 180)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = TitleBar

-- Tab buttons
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Frame

-- Tab pages (ScrollingFrames)
local pages = {}
local tabs = { "Aimbot", "Visuals", "Movement" }
local activeTab = "Aimbot"

local function createPage(name)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -86)
    scroll.Position = UDim2.new(0, 8, 0, 82)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 180)
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = (name == activeTab)
    scroll.Parent = Frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scroll

    pages[name] = scroll
    return scroll
end

local tabButtons = {}
for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#tabs, -4, 1, 0)
    btn.Position = UDim2.new((i-1)/#tabs, 2, 0, 0)
    btn.BackgroundColor3 = (name == activeTab) and Color3.fromRGB(255, 50, 120) or Color3.fromRGB(35, 35, 48)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = name
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabButtons[name] = btn

    btn.MouseButton1Click:Connect(function()
        activeTab = name
        for n, pg in pairs(pages) do pg.Visible = (n == name) end
        for n, tb in pairs(tabButtons) do
            tb.BackgroundColor3 = (n == name) and Color3.fromRGB(255, 50, 120) or Color3.fromRGB(35, 35, 48)
        end
    end)
end

-- Create pages
local aimbotPage = createPage("Aimbot")
local visualsPage = createPage("Visuals")
local movementPage = createPage("Movement")

--------------------------------------------------------------------
-- UI COMPONENTS
--------------------------------------------------------------------
local orderCounters = {}
local function nextOrder(page)
    orderCounters[page] = (orderCounters[page] or 0) + 1
    return orderCounters[page]
end

local function addSeparator(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "— " .. text .. " —"
    lbl.TextColor3 = Color3.fromRGB(255, 100, 180)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.LayoutOrder = nextOrder(page)
    lbl.Parent = page
end

local function addToggle(page, name, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = default and Color3.fromRGB(255, 50, 120) or Color3.fromRGB(38, 38, 50)
    btn.TextColor3 = Color3.fromRGB(225, 225, 225)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = name .. (default and "  [ON]" or "  [OFF]")
    btn.BorderSizePixel = 0
    btn.LayoutOrder = nextOrder(page)
    btn.Parent = page
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = name .. (state and "  [ON]" or "  [OFF]")
        btn.BackgroundColor3 = state and Color3.fromRGB(255, 50, 120) or Color3.fromRGB(38, 38, 50)
        callback(state)
    end)
    return btn
end

local function addSlider(page, name, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundTransparency = 1
    container.LayoutOrder = nextOrder(page)
    container.Parent = page

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(185, 185, 185)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "  " .. name .. ": " .. tostring(default)
    label.Parent = container

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -16, 0, 10)
    track.Position = UDim2.new(0, 8, 0, 20)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    track.BorderSizePixel = 0
    track.Parent = container
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 5)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 80, 150)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    local dragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + rel * (max - min) + 0.5)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = "  " .. name .. ": " .. tostring(val)
            callback(val)
        end
    end)
end

local function addDropdown(page, name, options, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = nextOrder(page)
    container.Parent = page

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.TextColor3 = Color3.fromRGB(210, 210, 210)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Text = name .. ": " .. tostring(default) .. "  ▼"
    btn.BorderSizePixel = 0
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local currentIndex = 1
    for i, v in ipairs(options) do
        if v == default then currentIndex = i; break end
    end

    btn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex % #options + 1
        local val = options[currentIndex]
        btn.Text = name .. ": " .. tostring(val) .. "  ▼"
        callback(val)
    end)
end

--------------------------------------------------------------------
-- BUILD AIMBOT PAGE
--------------------------------------------------------------------
addSeparator(aimbotPage, "AIMBOT")
addToggle(aimbotPage, "Enable Aimbot", Config.AimbotEnabled, function(v) Config.AimbotEnabled = v end)
addToggle(aimbotPage, "Always-On Aimbot", Config.AlwaysOnAimbot, function(v) Config.AlwaysOnAimbot = v end)
addSlider(aimbotPage, "Smoothness", 1, 20, Config.Smoothness, function(v) Config.Smoothness = v end)
addDropdown(aimbotPage, "Aimbot Key", KeyOptions, Config.AimbotKeyName, function(v)
    Config.AimbotKeyName = v
    Config.AimbotKey = KeyMap[v]
end)
addDropdown(aimbotPage, "Aim Part", AimPartOptions, Config.AimPart, function(v) Config.AimPart = v end)

addSeparator(aimbotPage, "FOV")
addSlider(aimbotPage, "FOV Radius", 30, 800, Config.MaxFOV, function(v) Config.MaxFOV = v end)
addToggle(aimbotPage, "Show FOV Circle", Config.FOVEnabled, function(v) Config.FOVEnabled = v end)
addToggle(aimbotPage, "Rainbow FOV", Config.RainbowFOV, function(v) Config.RainbowFOV = v end)

addSeparator(aimbotPage, "TRIGGERBOT")
addToggle(aimbotPage, "Enable Triggerbot", Config.TriggerbotEnabled, function(v) Config.TriggerbotEnabled = v end)

addSeparator(aimbotPage, "SILENT AIM")
addToggle(aimbotPage, "Enable Silent Aim", Config.SilentAimEnabled, function(v) Config.SilentAimEnabled = v end)
addSlider(aimbotPage, "Silent Aim FOV", 30, 500, Config.SilentAimFOV, function(v) Config.SilentAimFOV = v end)
addSlider(aimbotPage, "Hit Chance (%)", 1, 100, Config.SilentAimChance, function(v) Config.SilentAimChance = v end)

--------------------------------------------------------------------
-- BUILD VISUALS PAGE
--------------------------------------------------------------------
addSeparator(visualsPage, "MASTER")
addToggle(visualsPage, "Enable Visuals", Config.VisualsEnabled, function(v) Config.VisualsEnabled = v end)

addSeparator(visualsPage, "ESP")
addToggle(visualsPage, "Boxes", Config.BoxesEnabled, function(v) Config.BoxesEnabled = v end)
addToggle(visualsPage, "Tracers", Config.TracersEnabled, function(v) Config.TracersEnabled = v end)
addToggle(visualsPage, "Names", Config.NamesEnabled, function(v) Config.NamesEnabled = v end)
addToggle(visualsPage, "Health Bar", Config.HealthBarEnabled, function(v) Config.HealthBarEnabled = v end)
addDropdown(visualsPage, "Tracer Origin", TracerOriginOptions, Config.TracerOrigin, function(v) Config.TracerOrigin = v end)

addSeparator(visualsPage, "CHAMS")
addToggle(visualsPage, "Chams", Config.ChamsEnabled, function(v) Config.ChamsEnabled = v end)
addToggle(visualsPage, "Rainbow Chams", Config.RainbowChams, function(v) Config.RainbowChams = v end)
addSlider(visualsPage, "Chams Transparency", 0, 100, math.floor(Config.ChamsTransparency * 100), function(v) Config.ChamsTransparency = v / 100 end)
addSlider(visualsPage, "Weapon Chams Transp.", 0, 100, math.floor(Config.WeaponChamsTransparency * 100), function(v) Config.WeaponChamsTransparency = v / 100 end)

--------------------------------------------------------------------
-- BUILD MOVEMENT PAGE
--------------------------------------------------------------------
addSeparator(movementPage, "CAMERA")
addToggle(movementPage, "3rd Person", Config.ThirdPersonEnabled, function(v)
    Config.ThirdPersonEnabled = v
    if v then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
        LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
    else
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    end
end)
addSlider(movementPage, "3P Distance", 4, 30, Config.ThirdPersonDist, function(v)
    Config.ThirdPersonDist = v
    if Config.ThirdPersonEnabled then
        LocalPlayer.CameraMaxZoomDistance = v
        LocalPlayer.CameraMinZoomDistance = v
    end
end)

addSeparator(movementPage, "MOVEMENT")
addToggle(movementPage, "Bunnyhop", Config.BhopEnabled, function(v) Config.BhopEnabled = v end)

--------------------------------------------------------------------
-- INSERT KEY — MENU TOGGLE
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        Config.MenuOpen = not Config.MenuOpen
        Frame.Visible = Config.MenuOpen
    end
end)

--------------------------------------------------------------------
-- AIMBOT HELPERS
--------------------------------------------------------------------
local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getClosestInFOV(fovRadius)
    local closest, shortDist = nil, fovRadius
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local center = Vector2.new(cx, cy)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and isAlive(char) then
                local part = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("Head")
                if part then
                    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if dist < shortDist then
                            shortDist = dist
                            closest = part
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function isAimKeyDown()
    if Config.AlwaysOnAimbot then return true end
    local key = Config.AimbotKeyName
    if KeyIsMouseButton[key] then
        return UserInputService:IsMouseButtonPressed(Config.AimbotKey)
    else
        return UserInputService:IsKeyDown(Config.AimbotKey)
    end
end

--------------------------------------------------------------------
-- TRIGGERBOT
--------------------------------------------------------------------
local lastTriggerTime = 0
local function doTriggerbot()
    if not Config.TriggerbotEnabled then return end
    local now = tick()
    if (now - lastTriggerTime) * 1000 < Config.TriggerbotDelay then return end

    local target = Mouse.Target
    if target then
        local model = target:FindFirstAncestorOfClass("Model")
        if model then
            local player = Players:GetPlayerFromCharacter(model)
            if player and player ~= LocalPlayer then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    lastTriggerTime = now
                    -- simulate click
                    pcall(function()
                        mouse1click()
                    end)
                end
            end
        end
    end
end

--------------------------------------------------------------------
-- SILENT AIM (namecall hook)
--------------------------------------------------------------------
if Config.SilentAimEnabled or true then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "Raycast") and Config.SilentAimEnabled then
                if math.random(1, 100) <= Config.SilentAimChance then
                    local target = getClosestInFOV(Config.SilentAimFOV)
                    if target then
                        local args = {...}
                        -- redirect ray toward target
                        if method == "Raycast" then
                            local origin = Camera.CFrame.Position
                            local dir = (target.Position - origin).Unit * 1000
                            local params = args[2] or RaycastParams.new()
                            return oldNamecall(self, Ray.new(origin, dir), params)
                        else
                            local origin = Camera.CFrame.Position
                            local dir = (target.Position - origin).Unit * 1000
                            local ray = Ray.new(origin, dir)
                            return oldNamecall(self, ray, select(2, ...))
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
end

--------------------------------------------------------------------
-- BUNNYHOP
--------------------------------------------------------------------
local function doBhop()
    if not Config.BhopEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or
       UserInputService:IsKeyDown(Enum.KeyCode.A) or
       UserInputService:IsKeyDown(Enum.KeyCode.S) or
       UserInputService:IsKeyDown(Enum.KeyCode.D) then
        if hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

--------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------
local rainbowHue = 0

RunService.RenderStepped:Connect(function(dt)
    rainbowHue = (rainbowHue + dt * 0.5) % 1
    local rainbowColor = Color3.fromHSV(rainbowHue, 1, 1)

    -- FOV circles
    if FOVCircle then
        local vp = Camera.ViewportSize
        FOVCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        FOVCircle.Radius = Config.MaxFOV
        FOVCircle.Visible = Config.AimbotEnabled and Config.FOVEnabled
        FOVCircle.Color = Config.RainbowFOV and rainbowColor or Color3.fromRGB(255, 50, 120)
    end

    if SilentFOVCircle then
        local vp = Camera.ViewportSize
        SilentFOVCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        SilentFOVCircle.Radius = Config.SilentAimFOV
        SilentFOVCircle.Visible = Config.SilentAimEnabled and Config.FOVEnabled
    end

    -- ESP drawings
    for player, cache in pairs(DrawingCache) do
        updateESP(player, cache)
    end

    -- Chams
    refreshChams(Config.RainbowChams and rainbowColor or nil)

    -- Weapon chams
    updateWeaponChams()

    -- Aimbot
    if Config.AimbotEnabled and isAimKeyDown() then
        local target = getClosestInFOV(Config.MaxFOV)
        if target then
            local targetCF = CFrame.new(Camera.CFrame.Position, target.Position)
            local alpha = 1 / math.clamp(Config.Smoothness, 1, 20)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
        end
    end

    -- Triggerbot
    doTriggerbot()

    -- Bunnyhop
    doBhop()
end)

--------------------------------------------------------------------
-- INJECTION SUCCESS NOTIFICATION (bottom-right, pink neon)
--------------------------------------------------------------------
local NotifGui = Instance.new("ScreenGui")
NotifGui.Name = "DoraNotification"
NotifGui.ResetOnSpawn = false
NotifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() NotifGui.Parent = game:GetService("CoreGui") end)
if not NotifGui.Parent then NotifGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local NotifFrame = Instance.new("Frame")
NotifFrame.Size = UDim2.new(0, 260, 0, 60)
NotifFrame.Position = UDim2.new(1, 10, 1, -80) -- start offscreen right
NotifFrame.AnchorPoint = Vector2.new(1, 0)
NotifFrame.BackgroundColor3 = Color3.fromRGB(20, 8, 20)
NotifFrame.BorderSizePixel = 0
NotifFrame.Parent = NotifGui
Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 10)

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(255, 50, 180)
notifStroke.Thickness = 2
notifStroke.Parent = NotifFrame

-- Glow effect via UIGradient on stroke
local notifGradient = Instance.new("UIGradient")
notifGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 180)),
})
notifGradient.Parent = notifStroke

local NotifText = Instance.new("TextLabel")
NotifText.Size = UDim2.new(1, 0, 0.55, 0)
NotifText.Position = UDim2.new(0, 0, 0, 4)
NotifText.BackgroundTransparency = 1
NotifText.Text = "✨ Success!"
NotifText.TextColor3 = Color3.fromRGB(255, 100, 200)
NotifText.Font = Enum.Font.GothamBold
NotifText.TextSize = 18
NotifText.Parent = NotifFrame

local NotifSub = Instance.new("TextLabel")
NotifSub.Size = UDim2.new(1, 0, 0.4, 0)
NotifSub.Position = UDim2.new(0, 0, 0.55, 0)
NotifSub.BackgroundTransparency = 1
NotifSub.Text = "Made by Dora 🌸"
NotifSub.TextColor3 = Color3.fromRGB(200, 130, 200)
NotifSub.Font = Enum.Font.Gotham
NotifSub.TextSize = 13
NotifSub.Parent = NotifFrame

-- Slide-in animation
task.spawn(function()
    task.wait(0.3)
    -- Slide in
    NotifFrame:TweenPosition(
        UDim2.new(1, -20, 1, -80),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quint,
        0.6, true
    )

    -- Neon pulse on stroke
    task.spawn(function()
        local t = 0
        for i = 1, 80 do
            t = t + 0.05
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            notifStroke.Color = Color3.fromRGB(
                255,
                math.floor(50 + 130 * pulse),
                math.floor(180 + 75 * pulse)
            )
            task.wait(0.03)
        end
    end)

    -- Hold for 4 seconds, then slide out
    task.wait(4)
    NotifFrame:TweenPosition(
        UDim2.new(1, 280, 1, -80),
        Enum.EasingDirection.In,
        Enum.EasingStyle.Quint,
        0.5, true
    )
    task.wait(0.6)
    NotifGui:Destroy()
end)

--------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------
local function cleanup()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
    pcall(function() if SilentFOVCircle then SilentFOVCircle:Remove() end end)
    for p, _ in pairs(DrawingCache) do removeESPDrawings(p) end
    for p, _ in pairs(chamsCache) do removeChams(p) end
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() NotifGui:Destroy() end)
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    end)
end

if getgenv then getgenv().ByteCleanup = cleanup end

print("[DORA] SniperDuel-Chair v2 loaded — press INSERT")
