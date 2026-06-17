--[[
    DORA // SniperDuel-Chair v3
    Target: Sniper Duels (LOCKED IN NETWORK) — Roblox

    Fixes in v3:
      - Drag only from title bar (sliders no longer move window)
      - Team-aware chams (blue teammates / none / red enemies)
      - Optimized chams (no per-frame recreate)
      - Aimbot rework: head lock + aim assist (always-on, no keybind)
      - Forced 3rd person works in locked-FP games + keybind (T)
      - Pink neon injection notification

    Toggle menu: INSERT
]]

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

--------------------------------------------------------------------
-- CLEANUP PREVIOUS
--------------------------------------------------------------------
if getgenv and getgenv().DoraCleanup then
    pcall(getgenv().DoraCleanup)
    task.wait(0.2)
end

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local Config = {
    -- Aimbot (keybind mode)
    AimbotEnabled     = true,
    AlwaysOnAimbot    = false,
    Smoothness        = 5,
    AimbotKeyName     = "MouseButton2",

    -- Aim Assist (always-on, automatic)
    AimAssistEnabled  = false,
    AimAssistSmooth   = 10,
    AimAssistFOV      = 120,

    -- Head Lock (instant snap to head on key)
    HeadLockEnabled   = false,
    HeadLockKeyName   = "Q",

    -- Triggerbot
    TriggerbotEnabled = false,

    -- Silent Aim
    SilentAimEnabled  = false,
    SilentAimFOV      = 150,
    SilentAimChance   = 85,

    -- Aim Part
    AimPart           = "Head",

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
    TracerOrigin      = "Bottom",

    -- Chams
    ChamsEnabled      = true,
    RainbowChams      = false,
    ChamsTransparency = 0.3,
    TeamChams         = "Blue", -- "Blue" or "None"

    -- Weapon Chams
    WeaponChamsTransparency = 0.5,

    -- 3rd Person
    ThirdPersonEnabled = false,
    ThirdPersonDist    = 12,
    ThirdPersonKey     = "T",

    -- Bunnyhop
    BhopEnabled       = false,

    -- Menu
    MenuOpen          = false,
}

--------------------------------------------------------------------
-- KEY MAPPING
--------------------------------------------------------------------
local KeyMap = {
    ["MouseButton1"] = Enum.UserInputType.MouseButton1,
    ["MouseButton2"] = Enum.UserInputType.MouseButton2,
    ["Q"] = Enum.KeyCode.Q,
    ["E"] = Enum.KeyCode.E,
    ["R"] = Enum.KeyCode.R,
    ["F"] = Enum.KeyCode.F,
    ["T"] = Enum.KeyCode.T,
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
local KeyOptions = { "MouseButton2", "MouseButton1", "Q", "E", "R", "F", "T", "X", "C", "V", "CapsLock", "LeftAlt", "LeftShift" }
local TeamChamsOptions = { "Blue", "None" }

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local function isKeyDown(keyName)
    if KeyIsMouseButton[keyName] then
        return UserInputService:IsMouseButtonPressed(KeyMap[keyName])
    else
        return UserInputService:IsKeyDown(KeyMap[keyName])
    end
end

local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isTeammate(player)
    if not player or player == LocalPlayer then return false end
    if LocalPlayer.Team and player.Team then
        return player.Team == LocalPlayer.Team
    end
    return false
end

local function isEnemy(player)
    return player ~= LocalPlayer and not isTeammate(player)
end

--------------------------------------------------------------------
-- DRAWING CACHE
--------------------------------------------------------------------
local DrawingCache = {}
local FOVCircle = nil
local SilentFOVCircle = nil
local AimAssistFOVCircle = nil

pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible     = true
    FOVCircle.Thickness   = 1.4
    FOVCircle.Color       = Color3.fromRGB(255, 50, 120)
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

    AimAssistFOVCircle = Drawing.new("Circle")
    AimAssistFOVCircle.Visible     = false
    AimAssistFOVCircle.Thickness   = 1.0
    AimAssistFOVCircle.Color       = Color3.fromRGB(100, 255, 100)
    AimAssistFOVCircle.Transparency = 0.7
    AimAssistFOVCircle.Filled      = false
    AimAssistFOVCircle.NumSides    = 60
    AimAssistFOVCircle.Radius      = Config.AimAssistFOV
end)

--------------------------------------------------------------------
-- ESP DRAWINGS
--------------------------------------------------------------------
local function createESPDrawings(player)
    if DrawingCache[player] then return end
    local cache = {}
    pcall(function()
        cache.boxLines = {}
        for i = 1, 4 do
            local l = Drawing.new("Line")
            l.Visible = false
            l.Color = Color3.fromRGB(255, 40, 40)
            l.Thickness = 1.2
            l.Transparency = 1
            cache.boxLines[i] = l
        end

        cache.tracer = Drawing.new("Line")
        cache.tracer.Visible = false
        cache.tracer.Color = Color3.fromRGB(255, 40, 40)
        cache.tracer.Thickness = 1.2
        cache.tracer.Transparency = 1

        cache.name = Drawing.new("Text")
        cache.name.Visible = false
        cache.name.Color = Color3.fromRGB(255, 255, 255)
        cache.name.Size = 14
        cache.name.Center = true
        cache.name.Outline = true
        cache.name.OutlineColor = Color3.fromRGB(0, 0, 0)
        cache.name.Text = player.DisplayName or player.Name

        cache.healthBg = Drawing.new("Line")
        cache.healthBg.Visible = false
        cache.healthBg.Color = Color3.fromRGB(40, 40, 40)
        cache.healthBg.Thickness = 3
        cache.healthBg.Transparency = 1

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
        if cache.boxLines then for _, l in ipairs(cache.boxLines) do l:Remove() end end
        if cache.tracer then cache.tracer:Remove() end
        if cache.name then cache.name:Remove() end
        if cache.healthBg then cache.healthBg:Remove() end
        if cache.healthBar then cache.healthBar:Remove() end
    end)
    DrawingCache[player] = nil
end

local function hideESP(cache)
    pcall(function()
        if cache.boxLines then for _, l in ipairs(cache.boxLines) do l.Visible = false end end
        if cache.tracer then cache.tracer.Visible = false end
        if cache.name then cache.name.Visible = false end
        if cache.healthBg then cache.healthBg.Visible = false end
        if cache.healthBar then cache.healthBar.Visible = false end
    end)
end

local function updateESP(player, cache)
    local char = player.Character
    if not char or player == LocalPlayer then hideESP(cache); return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hum or not hrp or not head or hum.Health <= 0 then hideESP(cache); return end

    local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    if not onScreen then hideESP(cache); return end

    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
    local footPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

    local boxH = math.abs(headPos.Y - footPos.Y)
    local boxW = boxH * 0.55
    local topLeft = Vector2.new(rootPos.X - boxW / 2, headPos.Y)
    local topRight = Vector2.new(rootPos.X + boxW / 2, headPos.Y)
    local bottomLeft = Vector2.new(rootPos.X - boxW / 2, footPos.Y)
    local bottomRight = Vector2.new(rootPos.X + boxW / 2, footPos.Y)

    -- color based on team
    local espColor = isTeammate(player) and Color3.fromRGB(80, 150, 255) or Color3.fromRGB(255, 40, 40)

    pcall(function()
        local showBoxes = Config.VisualsEnabled and Config.BoxesEnabled
        if cache.boxLines then
            cache.boxLines[1].From = topLeft; cache.boxLines[1].To = topRight
            cache.boxLines[2].From = topRight; cache.boxLines[2].To = bottomRight
            cache.boxLines[3].From = bottomRight; cache.boxLines[3].To = bottomLeft
            cache.boxLines[4].From = bottomLeft; cache.boxLines[4].To = topLeft
            for _, l in ipairs(cache.boxLines) do l.Visible = showBoxes; l.Color = espColor end
        end

        local showTracers = Config.VisualsEnabled and Config.TracersEnabled
        if cache.tracer then
            cache.tracer.Visible = showTracers
            cache.tracer.Color = espColor
            if showTracers then
                local vp = Camera.ViewportSize
                local origin
                if Config.TracerOrigin == "Top" then origin = Vector2.new(vp.X / 2, 0)
                elseif Config.TracerOrigin == "Center" then origin = Vector2.new(vp.X / 2, vp.Y / 2)
                else origin = Vector2.new(vp.X / 2, vp.Y) end
                cache.tracer.From = origin
                cache.tracer.To = Vector2.new(rootPos.X, footPos.Y)
            end
        end

        local showNames = Config.VisualsEnabled and Config.NamesEnabled
        if cache.name then
            cache.name.Visible = showNames
            cache.name.Color = espColor
            if showNames then
                cache.name.Position = Vector2.new(rootPos.X, headPos.Y - 18)
                cache.name.Text = player.DisplayName or player.Name
            end
        end

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
                cache.healthBar.Color = Color3.new(math.clamp(2 * (1 - ratio), 0, 1), math.clamp(2 * ratio, 0, 1), 0)
            end
        end
    end)
end

--------------------------------------------------------------------
-- CHAMS (optimized — no per-frame recreate)
--------------------------------------------------------------------
local chamsCache = {} -- [Player] = Highlight

local function getChamsColor(player)
    if isTeammate(player) then
        if Config.TeamChams == "None" then return nil end
        return Color3.fromRGB(50, 130, 255), Color3.fromRGB(80, 160, 255)
    end
    return Color3.fromRGB(255, 20, 20), Color3.fromRGB(255, 60, 60)
end

local function applyChams(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end

    -- skip teammates if set to None
    if isTeammate(player) and Config.TeamChams == "None" then
        if chamsCache[player] then
            pcall(function() chamsCache[player]:Destroy() end)
            chamsCache[player] = nil
        end
        return
    end

    local fillColor, outlineColor = getChamsColor(player)
    if not fillColor then return end

    local hl = chamsCache[player]
    if hl and hl.Parent then
        -- update existing
        hl.FillColor = fillColor
        hl.OutlineColor = outlineColor
        hl.FillTransparency = Config.ChamsTransparency
        return
    end

    -- create new
    hl = Instance.new("Highlight")
    hl.Name = "DoraChams"
    hl.FillColor = fillColor
    hl.FillTransparency = Config.ChamsTransparency
    hl.OutlineColor = outlineColor
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

-- throttled chams refresh (not every frame)
local lastChamsRefresh = 0
local CHAMS_REFRESH_INTERVAL = 0.25

local function refreshChams(rainbowColor)
    local now = tick()
    if now - lastChamsRefresh < CHAMS_REFRESH_INTERVAL then return end
    lastChamsRefresh = now

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if Config.VisualsEnabled and Config.ChamsEnabled then
                applyChams(p)
                if Config.RainbowChams and rainbowColor and isEnemy(p) then
                    local hl = chamsCache[p]
                    if hl and hl.Parent then
                        hl.FillColor = rainbowColor
                        hl.OutlineColor = rainbowColor
                    end
                end
            else
                removeChams(p)
            end
        end
    end
end

--------------------------------------------------------------------
-- WEAPON CHAMS (throttled)
--------------------------------------------------------------------
local lastWeaponRefresh = 0
local function updateWeaponChams()
    local now = tick()
    if now - lastWeaponRefresh < 0.5 then return end
    lastWeaponRefresh = now

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
ScreenGui.Name = "DoraUI_v3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Main Frame — NOT draggable (we handle drag via title bar only)
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 320, 0, 580)
Frame.Position = UDim2.new(0.5, -160, 0.5, -290)
Frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Frame.BorderSizePixel = 0
Frame.Visible = false
Frame.Active = true
Frame.Draggable = false -- DISABLED: sliders were conflicting
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 50, 120)
mainStroke.Thickness = 1.5
mainStroke.Parent = Frame

-- Title bar — THIS is the drag handle
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
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

-- Manual drag logic on title bar only
do
    local dragging = false
    local dragStart, startPos

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Frame

local pages = {}
local tabBtns = {}
local tabNames = { "Aimbot", "Visuals", "Movement" }
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

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabNames, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabNames, 2, 0, 0)
    btn.BackgroundColor3 = (name == activeTab) and Color3.fromRGB(255, 50, 120) or Color3.fromRGB(35, 35, 48)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = name
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = btn

    btn.MouseButton1Click:Connect(function()
        activeTab = name
        for n, pg in pairs(pages) do pg.Visible = (n == name) end
        for n, tb in pairs(tabBtns) do tb.BackgroundColor3 = (n == name) and Color3.fromRGB(255, 50, 120) or Color3.fromRGB(35, 35, 48) end
    end)
end

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
    track.Active = true -- capture input on track, not parent
    track.Parent = container
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 5)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 80, 150)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    local dragging = false

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            -- immediate update on click
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + rel * (max - min) + 0.5)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = "  " .. name .. ": " .. tostring(val)
            callback(val)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
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
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.TextColor3 = Color3.fromRGB(210, 210, 210)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Text = name .. ": " .. tostring(default) .. "  ▼"
    btn.BorderSizePixel = 0
    btn.LayoutOrder = nextOrder(page)
    btn.Parent = page
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local idx = 1
    for i, v in ipairs(options) do
        if v == default then idx = i; break end
    end

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        local val = options[idx]
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
addDropdown(aimbotPage, "Aimbot Key", KeyOptions, Config.AimbotKeyName, function(v) Config.AimbotKeyName = v end)
addDropdown(aimbotPage, "Aim Part", AimPartOptions, Config.AimPart, function(v) Config.AimPart = v end)

addSeparator(aimbotPage, "HEAD LOCK")
addToggle(aimbotPage, "Enable Head Lock", Config.HeadLockEnabled, function(v) Config.HeadLockEnabled = v end)
addDropdown(aimbotPage, "Head Lock Key", KeyOptions, Config.HeadLockKeyName, function(v) Config.HeadLockKeyName = v end)

addSeparator(aimbotPage, "AIM ASSIST (auto)")
addToggle(aimbotPage, "Enable Aim Assist", Config.AimAssistEnabled, function(v) Config.AimAssistEnabled = v end)
addSlider(aimbotPage, "AA Smoothness", 1, 30, Config.AimAssistSmooth, function(v) Config.AimAssistSmooth = v end)
addSlider(aimbotPage, "AA FOV", 30, 400, Config.AimAssistFOV, function(v) Config.AimAssistFOV = v end)

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
addDropdown(visualsPage, "Teammate Chams", TeamChamsOptions, Config.TeamChams, function(v) Config.TeamChams = v end)
addSlider(visualsPage, "Weapon Chams Transp.", 0, 100, math.floor(Config.WeaponChamsTransparency * 100), function(v) Config.WeaponChamsTransparency = v / 100 end)

--------------------------------------------------------------------
-- BUILD MOVEMENT PAGE
--------------------------------------------------------------------
addSeparator(movementPage, "3RD PERSON")
addToggle(movementPage, "3rd Person", Config.ThirdPersonEnabled, function(v)
    Config.ThirdPersonEnabled = v
    if v then
        pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
            LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
        end)
    else
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = 0.5
            LocalPlayer.CameraMinZoomDistance = 0.5
        end)
    end
end)
addSlider(movementPage, "3P Distance", 4, 30, Config.ThirdPersonDist, function(v)
    Config.ThirdPersonDist = v
    if Config.ThirdPersonEnabled then
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = v
            LocalPlayer.CameraMinZoomDistance = v
        end)
    end
end)
addDropdown(movementPage, "3P Toggle Key", KeyOptions, Config.ThirdPersonKey, function(v) Config.ThirdPersonKey = v end)

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
-- 3RD PERSON KEYBIND + FORCED OVERRIDE
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    -- 3rd person toggle keybind
    if Config.ThirdPersonKey and KeyMap[Config.ThirdPersonKey] then
        local match = false
        if KeyIsMouseButton[Config.ThirdPersonKey] then
            match = (input.UserInputType == KeyMap[Config.ThirdPersonKey])
        else
            match = (input.KeyCode == KeyMap[Config.ThirdPersonKey])
        end
        if match then
            Config.ThirdPersonEnabled = not Config.ThirdPersonEnabled
            if Config.ThirdPersonEnabled then
                pcall(function()
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                    LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
                    LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
                end)
            else
                pcall(function()
                    LocalPlayer.CameraMaxZoomDistance = 0.5
                    LocalPlayer.CameraMinZoomDistance = 0.5
                end)
            end
        end
    end

    -- Head lock keybind (instant snap)
    if Config.HeadLockEnabled and Config.HeadLockKeyName and KeyMap[Config.HeadLockKeyName] then
        local match = false
        if KeyIsMouseButton[Config.HeadLockKeyName] then
            match = (input.UserInputType == KeyMap[Config.HeadLockKeyName])
        else
            match = (input.KeyCode == KeyMap[Config.HeadLockKeyName])
        end
        if match then
            local closest, shortDist = nil, Config.MaxFOV
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            for _, p in ipairs(Players:GetPlayers()) do
                if isEnemy(p) and p.Character and isAlive(p.Character) then
                    local head = p.Character:FindFirstChild("Head")
                    if head then
                        local sp, vis = Camera:WorldToViewportPoint(head.Position)
                        if vis then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if d < shortDist then shortDist = d; closest = head end
                        end
                    end
                end
            end
            if closest then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, closest.Position)
            end
        end
    end
end)

-- Force 3rd person every frame (overrides game scripts that lock FP)
RunService.RenderStepped:Connect(function()
    if Config.ThirdPersonEnabled then
        pcall(function()
            if LocalPlayer.CameraMaxZoomDistance < Config.ThirdPersonDist then
                LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
            end
            if LocalPlayer.CameraMinZoomDistance < Config.ThirdPersonDist * 0.8 then
                LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist * 0.8
            end
            if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
                LocalPlayer.CameraMode = Enum.CameraMode.Classic
            end
        end)
    end
end)

--------------------------------------------------------------------
-- AIMBOT TARGET FINDER
--------------------------------------------------------------------
local function getClosestInFOV(fovRadius, partName)
    local closest, shortDist = nil, fovRadius
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local char = player.Character
            if char and isAlive(char) then
                local part = char:FindFirstChild(partName or Config.AimPart) or char:FindFirstChild("Head")
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

--------------------------------------------------------------------
-- TRIGGERBOT
--------------------------------------------------------------------
local lastTrigger = 0
local function doTriggerbot()
    if not Config.TriggerbotEnabled then return end
    local now = tick()
    if (now - lastTrigger) < 0.08 then return end
    local target = Mouse.Target
    if target then
        local model = target:FindFirstAncestorOfClass("Model")
        if model then
            local player = Players:GetPlayerFromCharacter(model)
            if player and isEnemy(player) then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    lastTrigger = now
                    pcall(mouse1click)
                end
            end
        end
    end
end

--------------------------------------------------------------------
-- SILENT AIM HOOK
--------------------------------------------------------------------
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if Config.SilentAimEnabled and (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "Raycast") then
            if math.random(1, 100) <= Config.SilentAimChance then
                local target = getClosestInFOV(Config.SilentAimFOV, Config.AimPart)
                if target then
                    local origin = Camera.CFrame.Position
                    local dir = (target.Position - origin).Unit * 1000
                    if method == "Raycast" then
                        local params = select(2, ...) or RaycastParams.new()
                        return oldNamecall(self, Ray.new(origin, dir), params)
                    else
                        return oldNamecall(self, Ray.new(origin, dir), select(2, ...))
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end)

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
-- MAIN RENDER LOOP
--------------------------------------------------------------------
local rainbowHue = 0

RunService.RenderStepped:Connect(function(dt)
    rainbowHue = (rainbowHue + dt * 0.5) % 1
    local rainbowColor = Color3.fromHSV(rainbowHue, 1, 1)
    local vp = Camera.ViewportSize
    local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)

    -- FOV circles
    if FOVCircle then
        FOVCircle.Position = screenCenter
        FOVCircle.Radius = Config.MaxFOV
        FOVCircle.Visible = Config.AimbotEnabled and Config.FOVEnabled
        FOVCircle.Color = Config.RainbowFOV and rainbowColor or Color3.fromRGB(255, 50, 120)
    end
    if SilentFOVCircle then
        SilentFOVCircle.Position = screenCenter
        SilentFOVCircle.Radius = Config.SilentAimFOV
        SilentFOVCircle.Visible = Config.SilentAimEnabled and Config.FOVEnabled
    end
    if AimAssistFOVCircle then
        AimAssistFOVCircle.Position = screenCenter
        AimAssistFOVCircle.Radius = Config.AimAssistFOV
        AimAssistFOVCircle.Visible = Config.AimAssistEnabled and Config.FOVEnabled
    end

    -- ESP
    for player, cache in pairs(DrawingCache) do
        updateESP(player, cache)
    end

    -- Chams (throttled)
    refreshChams(Config.RainbowChams and rainbowColor or nil)

    -- Weapon chams (throttled)
    updateWeaponChams()

    -- Aimbot (keybind)
    if Config.AimbotEnabled then
        local keyDown = Config.AlwaysOnAimbot or isKeyDown(Config.AimbotKeyName)
        if keyDown then
            local target = getClosestInFOV(Config.MaxFOV, Config.AimPart)
            if target then
                local targetCF = CFrame.new(Camera.CFrame.Position, target.Position)
                local alpha = 1 / math.clamp(Config.Smoothness, 1, 20)
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
            end
        end
    end

    -- Aim Assist (always-on, automatic, no keybind)
    if Config.AimAssistEnabled then
        local target = getClosestInFOV(Config.AimAssistFOV, Config.AimPart)
        if target then
            local targetCF = CFrame.new(Camera.CFrame.Position, target.Position)
            local alpha = 1 / math.clamp(Config.AimAssistSmooth, 1, 30)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
        end
    end

    -- Triggerbot
    doTriggerbot()

    -- Bunnyhop
    doBhop()
end)

--------------------------------------------------------------------
-- INJECTION NOTIFICATION (pink neon, bottom-right)
--------------------------------------------------------------------
local NotifGui = Instance.new("ScreenGui")
NotifGui.Name = "DoraNotif"
NotifGui.ResetOnSpawn = false
pcall(function() NotifGui.Parent = game:GetService("CoreGui") end)
if not NotifGui.Parent then NotifGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local NotifFrame = Instance.new("Frame")
NotifFrame.Size = UDim2.new(0, 260, 0, 60)
NotifFrame.Position = UDim2.new(1, 280, 1, -80)
NotifFrame.AnchorPoint = Vector2.new(1, 0)
NotifFrame.BackgroundColor3 = Color3.fromRGB(20, 8, 20)
NotifFrame.BorderSizePixel = 0
NotifFrame.Parent = NotifGui
Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 10)

local nStroke = Instance.new("UIStroke")
nStroke.Color = Color3.fromRGB(255, 50, 180)
nStroke.Thickness = 2
nStroke.Parent = NotifFrame

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

task.spawn(function()
    task.wait(0.3)
    NotifFrame:TweenPosition(UDim2.new(1, -20, 1, -80), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.6, true)
    task.spawn(function()
        local t = 0
        for _ = 1, 80 do
            t = t + 0.05
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            nStroke.Color = Color3.fromRGB(255, math.floor(50 + 130 * pulse), math.floor(180 + 75 * pulse))
            task.wait(0.03)
        end
    end)
    task.wait(4)
    NotifFrame:TweenPosition(UDim2.new(1, 280, 1, -80), Enum.EasingDirection.In, Enum.EasingStyle.Quint, 0.5, true)
    task.wait(0.6)
    NotifGui:Destroy()
end)

--------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------
local function cleanup()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
    pcall(function() if SilentFOVCircle then SilentFOVCircle:Remove() end end)
    pcall(function() if AimAssistFOVCircle then AimAssistFOVCircle:Remove() end end)
    for p in pairs(DrawingCache) do removeESPDrawings(p) end
    for p in pairs(chamsCache) do removeChams(p) end
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() NotifGui:Destroy() end)
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
    end)
end

if getgenv then getgenv().DoraCleanup = cleanup end

print("[DORA] SniperDuel-Chair v3 loaded — press INSERT")
