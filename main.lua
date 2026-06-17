--[[
    DORA // SniperDuel-Chair v4
    Target: Roblox FPS games (Sniper Duels, BloxStrike, etc.)

    v4 Changes:
      - Robust team detection (Team + TeamColor + Name fallback)
      - Reliable chams (event-driven, self-healing)
      - Major performance optimization (no per-frame full iterations)
      - Wall check toggle for aimbot
      - Speed hack (editable)
      - Silent aim rework (multiple hook strategies)
      - Reduced CPU usage across the board

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
    task.wait(0.3)
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
    WallCheck         = false, -- if true, won't lock through walls

    -- Aim Assist
    AimAssistEnabled  = false,
    AimAssistSmooth   = 10,
    AimAssistFOV      = 120,

    -- Head Lock
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

    -- FOV
    FOVEnabled        = true,
    MaxFOV            = 250,
    RainbowFOV        = false,

    -- Visuals
    VisualsEnabled    = true,
    BoxesEnabled      = false,
    TracersEnabled    = false,
    NamesEnabled      = true,
    HealthBarEnabled  = false,
    TracerOrigin      = "Bottom",

    -- Chams
    ChamsEnabled      = true,
    RainbowChams      = false,
    ChamsTransparency = 0.3,
    TeamChams         = "Blue",

    -- Weapon Chams
    WeaponChamsTransparency = 0.5,

    -- 3rd Person
    ThirdPersonEnabled = false,
    ThirdPersonDist    = 12,
    ThirdPersonKey     = "T",

    -- Speed
    SpeedEnabled       = false,
    SpeedValue         = 16, -- default roblox is 16

    -- Bunnyhop
    BhopEnabled       = false,

    -- Menu
    MenuOpen          = false,
}

--------------------------------------------------------------------
-- KEY MAP
--------------------------------------------------------------------
local KeyMap = {
    ["MouseButton1"] = Enum.UserInputType.MouseButton1,
    ["MouseButton2"] = Enum.UserInputType.MouseButton2,
    ["Q"] = Enum.KeyCode.Q, ["E"] = Enum.KeyCode.E,
    ["R"] = Enum.KeyCode.R, ["F"] = Enum.KeyCode.F,
    ["T"] = Enum.KeyCode.T, ["X"] = Enum.KeyCode.X,
    ["C"] = Enum.KeyCode.C, ["V"] = Enum.KeyCode.V,
    ["CapsLock"] = Enum.KeyCode.CapsLock,
    ["LeftAlt"] = Enum.KeyCode.LeftAlt,
    ["LeftShift"] = Enum.KeyCode.LeftShift,
}
local KeyIsMouse = { ["MouseButton1"] = true, ["MouseButton2"] = true }
local AimPartOptions = { "Head", "HumanoidRootPart", "UpperTorso" }
local TracerOriginOptions = { "Bottom", "Center", "Top" }
local KeyOptions = { "MouseButton2", "MouseButton1", "Q", "E", "R", "F", "T", "X", "C", "V", "CapsLock", "LeftAlt", "LeftShift" }
local TeamChamsOptions = { "Blue", "None" }

--------------------------------------------------------------------
-- ROBUST TEAM DETECTION
--------------------------------------------------------------------
local function isTeammate(player)
    if not player or player == LocalPlayer then return true end

    -- Method 1: Team object
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team

    if myTeam and theirTeam then
        if myTeam == theirTeam then return true end
        -- Method 2: TeamColor (some games use this instead)
        if LocalPlayer.TeamColor == player.TeamColor then return true end
        -- Method 3: Team name
        if myTeam.Name == theirTeam.Name then return true end
        return false
    end

    -- Method 4: Neutral / no team — check TeamColor directly
    if LocalPlayer.TeamColor == player.TeamColor and LocalPlayer.Neutral == player.Neutral then
        -- both neutral or both same color with no Team object
        if LocalPlayer.Neutral and player.Neutral then return false end -- both neutral = FFA
        return true
    end

    return false
end

local function isEnemy(player)
    return player ~= LocalPlayer and not isTeammate(player)
end

--------------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------------
local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isKeyDown(keyName)
    if KeyIsMouse[keyName] then
        return UserInputService:IsMouseButtonPressed(KeyMap[keyName])
    else
        return UserInputService:IsKeyDown(KeyMap[keyName])
    end
end

-- Wall check: returns true if target part is VISIBLE (no wall between camera and part)
local function isVisible(part)
    if not Config.WallCheck then return true end -- wall check disabled = always visible
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { LocalPlayer.Character }
    -- also ignore the target's character to see if anything blocks between
    local targetChar = part:FindFirstAncestorOfClass("Model")
    if targetChar then table.insert(ignore, targetChar) end
    params.FilterDescendantsInstances = ignore

    local result = workspace:Raycast(origin, dir, params)
    return result == nil -- nil means nothing blocked it
end

--------------------------------------------------------------------
-- CHAMS (event-driven, self-healing)
--------------------------------------------------------------------
local chamsCache = {} -- [Player] = Highlight
local chamsConnections = {} -- [Player] = {connections}

local function getChamsColors(player)
    if isTeammate(player) then
        if Config.TeamChams == "None" then return nil, nil end
        return Color3.fromRGB(50, 130, 255), Color3.fromRGB(80, 160, 255)
    end
    return Color3.fromRGB(255, 20, 20), Color3.fromRGB(255, 60, 60)
end

local function ensureChams(player)
    if player == LocalPlayer then return end
    if not Config.VisualsEnabled or not Config.ChamsEnabled then return end

    local char = player.Character
    if not char then return end
    if not isAlive(char) then return end

    -- skip teammates if None
    if isTeammate(player) and Config.TeamChams == "None" then
        local hl = chamsCache[player]
        if hl then pcall(function() hl:Destroy() end); chamsCache[player] = nil end
        return
    end

    local fillColor, outlineColor = getChamsColors(player)
    if not fillColor then return end

    local hl = chamsCache[player]

    -- self-healing: check if highlight still exists and is parented
    if hl and hl.Parent then
        hl.FillColor = fillColor
        hl.OutlineColor = outlineColor
        hl.FillTransparency = Config.ChamsTransparency
        hl.Adornee = char
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

    -- self-healing: if game removes our highlight, reapply
    local conn = hl.AncestryChanged:Connect(function(_, newParent)
        if not newParent then
            chamsCache[player] = nil
            task.wait(0.2)
            if Config.VisualsEnabled and Config.ChamsEnabled then
                ensureChams(player)
            end
        end
    end)

    if not chamsConnections[player] then chamsConnections[player] = {} end
    table.insert(chamsConnections[player], conn)
end

local function removeChams(player)
    local hl = chamsCache[player]
    if hl then pcall(function() hl:Destroy() end) end
    chamsCache[player] = nil
    if chamsConnections[player] then
        for _, c in ipairs(chamsConnections[player]) do pcall(function() c:Disconnect() end) end
        chamsConnections[player] = nil
    end
end

--------------------------------------------------------------------
-- ESP DRAWING (Drawing API)
--------------------------------------------------------------------
local DrawingCache = {}

local function createESP(player)
    if DrawingCache[player] then return end
    local cache = {}
    local ok = pcall(function()
        cache.boxLines = {}
        for i = 1, 4 do
            local l = Drawing.new("Line"); l.Visible = false
            l.Color = Color3.fromRGB(255, 40, 40); l.Thickness = 1.2; l.Transparency = 1
            cache.boxLines[i] = l
        end
        cache.tracer = Drawing.new("Line"); cache.tracer.Visible = false
        cache.tracer.Color = Color3.fromRGB(255, 40, 40); cache.tracer.Thickness = 1.2
        cache.name = Drawing.new("Text"); cache.name.Visible = false
        cache.name.Color = Color3.fromRGB(255,255,255); cache.name.Size = 14
        cache.name.Center = true; cache.name.Outline = true
        cache.name.OutlineColor = Color3.fromRGB(0,0,0)
        cache.name.Text = player.DisplayName or player.Name
        cache.healthBg = Drawing.new("Line"); cache.healthBg.Visible = false
        cache.healthBg.Color = Color3.fromRGB(40,40,40); cache.healthBg.Thickness = 3
        cache.healthBar = Drawing.new("Line"); cache.healthBar.Visible = false
        cache.healthBar.Color = Color3.fromRGB(0,255,0); cache.healthBar.Thickness = 2
    end)
    if ok then DrawingCache[player] = cache end
end

local function removeESP(player)
    local c = DrawingCache[player]
    if not c then return end
    pcall(function()
        if c.boxLines then for _, l in ipairs(c.boxLines) do l:Remove() end end
        if c.tracer then c.tracer:Remove() end
        if c.name then c.name:Remove() end
        if c.healthBg then c.healthBg:Remove() end
        if c.healthBar then c.healthBar:Remove() end
    end)
    DrawingCache[player] = nil
end

local function hideESP(c)
    pcall(function()
        if c.boxLines then for _, l in ipairs(c.boxLines) do l.Visible = false end end
        if c.tracer then c.tracer.Visible = false end
        if c.name then c.name.Visible = false end
        if c.healthBg then c.healthBg.Visible = false end
        if c.healthBar then c.healthBar.Visible = false end
    end)
end

local function updateESP(player, cache)
    if not Config.VisualsEnabled then hideESP(cache); return end
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
    local tl = Vector2.new(rootPos.X - boxW/2, headPos.Y)
    local tr = Vector2.new(rootPos.X + boxW/2, headPos.Y)
    local bl = Vector2.new(rootPos.X - boxW/2, footPos.Y)
    local br = Vector2.new(rootPos.X + boxW/2, footPos.Y)
    local clr = isTeammate(player) and Color3.fromRGB(80, 150, 255) or Color3.fromRGB(255, 40, 40)

    pcall(function()
        local sb = Config.BoxesEnabled
        if cache.boxLines then
            cache.boxLines[1].From=tl; cache.boxLines[1].To=tr; cache.boxLines[1].Visible=sb; cache.boxLines[1].Color=clr
            cache.boxLines[2].From=tr; cache.boxLines[2].To=br; cache.boxLines[2].Visible=sb; cache.boxLines[2].Color=clr
            cache.boxLines[3].From=br; cache.boxLines[3].To=bl; cache.boxLines[3].Visible=sb; cache.boxLines[3].Color=clr
            cache.boxLines[4].From=bl; cache.boxLines[4].To=tl; cache.boxLines[4].Visible=sb; cache.boxLines[4].Color=clr
        end
        local st = Config.TracersEnabled
        if cache.tracer then
            cache.tracer.Visible = st; cache.tracer.Color = clr
            if st then
                local vp = Camera.ViewportSize
                local o
                if Config.TracerOrigin == "Top" then o = Vector2.new(vp.X/2, 0)
                elseif Config.TracerOrigin == "Center" then o = Vector2.new(vp.X/2, vp.Y/2)
                else o = Vector2.new(vp.X/2, vp.Y) end
                cache.tracer.From = o; cache.tracer.To = Vector2.new(rootPos.X, footPos.Y)
            end
        end
        local sn = Config.NamesEnabled
        if cache.name then
            cache.name.Visible = sn; cache.name.Color = clr
            if sn then cache.name.Position = Vector2.new(rootPos.X, headPos.Y - 18)
            cache.name.Text = player.DisplayName or player.Name end
        end
        local sh = Config.HealthBarEnabled
        if cache.healthBg and cache.healthBar then
            cache.healthBg.Visible = sh; cache.healthBar.Visible = sh
            if sh then
                local bx = tl.X - 5
                cache.healthBg.From = Vector2.new(bx, footPos.Y); cache.healthBg.To = Vector2.new(bx, headPos.Y)
                local r = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                cache.healthBar.From = Vector2.new(bx, footPos.Y)
                cache.healthBar.To = Vector2.new(bx, footPos.Y + (headPos.Y - footPos.Y) * r)
                cache.healthBar.Color = Color3.new(math.clamp(2*(1-r),0,1), math.clamp(2*r,0,1), 0)
            end
        end
    end)
end

--------------------------------------------------------------------
-- FOV CIRCLES
--------------------------------------------------------------------
local FOVCircle, SilentFOVCircle, AAFOVCircle
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = true; FOVCircle.Thickness = 1.4
    FOVCircle.Color = Color3.fromRGB(255,50,120); FOVCircle.Transparency = 0.5
    FOVCircle.Filled = false; FOVCircle.NumSides = 64; FOVCircle.Radius = Config.MaxFOV

    SilentFOVCircle = Drawing.new("Circle")
    SilentFOVCircle.Visible = false; SilentFOVCircle.Thickness = 1.2
    SilentFOVCircle.Color = Color3.fromRGB(255,0,255); SilentFOVCircle.Transparency = 0.6
    SilentFOVCircle.Filled = false; SilentFOVCircle.NumSides = 48; SilentFOVCircle.Radius = Config.SilentAimFOV

    AAFOVCircle = Drawing.new("Circle")
    AAFOVCircle.Visible = false; AAFOVCircle.Thickness = 1.0
    AAFOVCircle.Color = Color3.fromRGB(100,255,100); AAFOVCircle.Transparency = 0.7
    AAFOVCircle.Filled = false; AAFOVCircle.NumSides = 48; AAFOVCircle.Radius = Config.AimAssistFOV
end)

--------------------------------------------------------------------
-- PLAYER MANAGEMENT (event-driven)
--------------------------------------------------------------------
local function onCharacterAdded(player)
    task.wait(0.8) -- wait for character to fully load
    chamsCache[player] = nil -- force fresh
    ensureChams(player)
end

local function hookPlayer(player)
    if player == LocalPlayer then return end
    createESP(player)
    player.CharacterAdded:Connect(function() onCharacterAdded(player) end)
    if player.Character then
        task.spawn(function() ensureChams(player) end)
    end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p) removeChams(p); removeESP(p) end)

--------------------------------------------------------------------
-- TARGET ACQUISITION (cached per frame, shared by all aim systems)
--------------------------------------------------------------------
local frameTarget = nil -- cached target for this frame
local frameTargetFOV = nil
local frameTargetAA = nil

local function acquireTarget(fovRadius, partName, requireVisible)
    local closest, shortDist = nil, fovRadius
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local center = Vector2.new(cx, cy)

    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local char = player.Character
            if char and isAlive(char) then
                local part = char:FindFirstChild(partName or "Head") or char:FindFirstChild("Head")
                if part then
                    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if dist < shortDist then
                            if not requireVisible or isVisible(part) then
                                shortDist = dist
                                closest = part
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DoraUI_v4"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 320, 0, 580)
Frame.Position = UDim2.new(0.5, -160, 0.5, -290)
Frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Frame.BorderSizePixel = 0; Frame.Visible = false
Frame.Active = true; Frame.Draggable = false
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)
local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(255,50,120); ms.Thickness = 1.5; ms.Parent = Frame

-- Title bar (drag handle)
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
TitleBar.BorderSizePixel = 0; TitleBar.Active = true; TitleBar.Parent = Frame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,0,1,0); Title.BackgroundTransparency = 1
Title.Text = "🌸 DORA  //  SNIPER DUELS"
Title.TextColor3 = Color3.fromRGB(255,100,180)
Title.Font = Enum.Font.GothamBold; Title.TextSize = 15; Title.Parent = TitleBar

-- Drag logic
do
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Tabs
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1,-16,0,30); TabBar.Position = UDim2.new(0,8,0,46)
TabBar.BackgroundTransparency = 1; TabBar.Parent = Frame

local pages, tabBtns = {}, {}
local tabNames = {"Aimbot", "Visuals", "Movement"}
local activeTab = "Aimbot"

local function createPage(name)
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1,-16,1,-86); s.Position = UDim2.new(0,8,0,82)
    s.BackgroundTransparency = 1; s.ScrollBarThickness = 3
    s.ScrollBarImageColor3 = Color3.fromRGB(255,100,180)
    s.BorderSizePixel = 0; s.CanvasSize = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Visible = (name == activeTab); s.Parent = Frame
    local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0,5); l.Parent = s
    pages[name] = s; return s
end

for i, name in ipairs(tabNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1/#tabNames,-4,1,0); b.Position = UDim2.new((i-1)/#tabNames,2,0,0)
    b.BackgroundColor3 = (name==activeTab) and Color3.fromRGB(255,50,120) or Color3.fromRGB(35,35,48)
    b.TextColor3 = Color3.fromRGB(230,230,230); b.Font = Enum.Font.GothamBold
    b.TextSize = 12; b.Text = name; b.BorderSizePixel = 0; b.Parent = TabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    tabBtns[name] = b
    b.MouseButton1Click:Connect(function()
        activeTab = name
        for n, pg in pairs(pages) do pg.Visible = (n==name) end
        for n, tb in pairs(tabBtns) do tb.BackgroundColor3 = (n==name) and Color3.fromRGB(255,50,120) or Color3.fromRGB(35,35,48) end
    end)
end

local aimbotPage = createPage("Aimbot")
local visualsPage = createPage("Visuals")
local movementPage = createPage("Movement")

-- UI Components
local oc = {}
local function no(p) oc[p]=(oc[p] or 0)+1; return oc[p] end

local function addSep(p, t)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,0,0,22)
    l.BackgroundTransparency = 1; l.Text = "— "..t.." —"
    l.TextColor3 = Color3.fromRGB(255,100,180); l.Font = Enum.Font.GothamBold
    l.TextSize = 11; l.LayoutOrder = no(p); l.Parent = p
end

local function addToggle(p, name, def, cb)
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,30)
    b.BackgroundColor3 = def and Color3.fromRGB(255,50,120) or Color3.fromRGB(38,38,50)
    b.TextColor3 = Color3.fromRGB(225,225,225); b.Font = Enum.Font.Gotham
    b.TextSize = 13; b.Text = name..(def and "  [ON]" or "  [OFF]")
    b.BorderSizePixel = 0; b.LayoutOrder = no(p); b.Parent = p
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    local s = def
    b.MouseButton1Click:Connect(function()
        s = not s; b.Text = name..(s and "  [ON]" or "  [OFF]")
        b.BackgroundColor3 = s and Color3.fromRGB(255,50,120) or Color3.fromRGB(38,38,50)
        cb(s)
    end)
end

local function addSlider(p, name, mn, mx, def, cb)
    local ct = Instance.new("Frame"); ct.Size = UDim2.new(1,0,0,42)
    ct.BackgroundTransparency = 1; ct.LayoutOrder = no(p); ct.Parent = p
    local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,0,0,16)
    lb.BackgroundTransparency = 1; lb.TextColor3 = Color3.fromRGB(185,185,185)
    lb.Font = Enum.Font.Gotham; lb.TextSize = 12; lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Text = "  "..name..": "..tostring(def); lb.Parent = ct
    local tk = Instance.new("Frame"); tk.Size = UDim2.new(1,-16,0,10)
    tk.Position = UDim2.new(0,8,0,20); tk.BackgroundColor3 = Color3.fromRGB(30,30,42)
    tk.BorderSizePixel = 0; tk.Active = true; tk.Parent = ct
    Instance.new("UICorner", tk).CornerRadius = UDim.new(0,5)
    local fl = Instance.new("Frame")
    fl.Size = UDim2.new(math.clamp((def-mn)/(mx-mn),0,1),0,1,0)
    fl.BackgroundColor3 = Color3.fromRGB(255,80,150); fl.BorderSizePixel = 0; fl.Parent = tk
    Instance.new("UICorner", fl).CornerRadius = UDim.new(0,5)
    local dr = false
    local function upd(input)
        local r = math.clamp((input.Position.X - tk.AbsolutePosition.X)/tk.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + r*(mx-mn) + 0.5)
        fl.Size = UDim2.new(r,0,1,0); lb.Text = "  "..name..": "..tostring(v); cb(v)
    end
    tk.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dr = true; upd(i)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
    end)
end

local function addDrop(p, name, opts, def, cb)
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,30)
    b.BackgroundColor3 = Color3.fromRGB(30,30,42); b.TextColor3 = Color3.fromRGB(210,210,210)
    b.Font = Enum.Font.Gotham; b.TextSize = 12
    b.Text = name..": "..tostring(def).."  ▼"; b.BorderSizePixel = 0
    b.LayoutOrder = no(p); b.Parent = p
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    local idx = 1
    for i,v in ipairs(opts) do if v == def then idx = i end end
    b.MouseButton1Click:Connect(function()
        idx = idx % #opts + 1; local v = opts[idx]
        b.Text = name..": "..tostring(v).."  ▼"; cb(v)
    end)
end

--------------------------------------------------------------------
-- BUILD PAGES
--------------------------------------------------------------------
-- AIMBOT PAGE
addSep(aimbotPage, "AIMBOT")
addToggle(aimbotPage, "Enable Aimbot", Config.AimbotEnabled, function(v) Config.AimbotEnabled = v end)
addToggle(aimbotPage, "Always-On Aimbot", Config.AlwaysOnAimbot, function(v) Config.AlwaysOnAimbot = v end)
addToggle(aimbotPage, "Wall Check", Config.WallCheck, function(v) Config.WallCheck = v end)
addSlider(aimbotPage, "Smoothness", 1, 20, Config.Smoothness, function(v) Config.Smoothness = v end)
addDrop(aimbotPage, "Aimbot Key", KeyOptions, Config.AimbotKeyName, function(v) Config.AimbotKeyName = v end)
addDrop(aimbotPage, "Aim Part", AimPartOptions, Config.AimPart, function(v) Config.AimPart = v end)

addSep(aimbotPage, "HEAD LOCK")
addToggle(aimbotPage, "Enable Head Lock", Config.HeadLockEnabled, function(v) Config.HeadLockEnabled = v end)
addDrop(aimbotPage, "Head Lock Key", KeyOptions, Config.HeadLockKeyName, function(v) Config.HeadLockKeyName = v end)

addSep(aimbotPage, "AIM ASSIST (auto)")
addToggle(aimbotPage, "Enable Aim Assist", Config.AimAssistEnabled, function(v) Config.AimAssistEnabled = v end)
addSlider(aimbotPage, "AA Smoothness", 1, 30, Config.AimAssistSmooth, function(v) Config.AimAssistSmooth = v end)
addSlider(aimbotPage, "AA FOV", 30, 400, Config.AimAssistFOV, function(v) Config.AimAssistFOV = v end)

addSep(aimbotPage, "FOV")
addSlider(aimbotPage, "FOV Radius", 30, 800, Config.MaxFOV, function(v) Config.MaxFOV = v end)
addToggle(aimbotPage, "Show FOV Circle", Config.FOVEnabled, function(v) Config.FOVEnabled = v end)
addToggle(aimbotPage, "Rainbow FOV", Config.RainbowFOV, function(v) Config.RainbowFOV = v end)

addSep(aimbotPage, "TRIGGERBOT")
addToggle(aimbotPage, "Enable Triggerbot", Config.TriggerbotEnabled, function(v) Config.TriggerbotEnabled = v end)

addSep(aimbotPage, "SILENT AIM")
addToggle(aimbotPage, "Enable Silent Aim", Config.SilentAimEnabled, function(v) Config.SilentAimEnabled = v end)
addSlider(aimbotPage, "Silent Aim FOV", 30, 500, Config.SilentAimFOV, function(v) Config.SilentAimFOV = v end)
addSlider(aimbotPage, "Hit Chance (%)", 1, 100, Config.SilentAimChance, function(v) Config.SilentAimChance = v end)

-- VISUALS PAGE
addSep(visualsPage, "MASTER")
addToggle(visualsPage, "Enable Visuals", Config.VisualsEnabled, function(v) Config.VisualsEnabled = v end)

addSep(visualsPage, "ESP")
addToggle(visualsPage, "Boxes", Config.BoxesEnabled, function(v) Config.BoxesEnabled = v end)
addToggle(visualsPage, "Tracers", Config.TracersEnabled, function(v) Config.TracersEnabled = v end)
addToggle(visualsPage, "Names", Config.NamesEnabled, function(v) Config.NamesEnabled = v end)
addToggle(visualsPage, "Health Bar", Config.HealthBarEnabled, function(v) Config.HealthBarEnabled = v end)
addDrop(visualsPage, "Tracer Origin", TracerOriginOptions, Config.TracerOrigin, function(v) Config.TracerOrigin = v end)

addSep(visualsPage, "CHAMS")
addToggle(visualsPage, "Chams", Config.ChamsEnabled, function(v)
    Config.ChamsEnabled = v
    if not v then
        for p in pairs(chamsCache) do removeChams(p) end
    else
        for _, p in ipairs(Players:GetPlayers()) do ensureChams(p) end
    end
end)
addToggle(visualsPage, "Rainbow Chams", Config.RainbowChams, function(v) Config.RainbowChams = v end)
addSlider(visualsPage, "Chams Transparency", 0, 100, math.floor(Config.ChamsTransparency*100), function(v) Config.ChamsTransparency = v/100 end)
addDrop(visualsPage, "Teammate Chams", TeamChamsOptions, Config.TeamChams, function(v)
    Config.TeamChams = v
    -- force refresh
    for p in pairs(chamsCache) do removeChams(p) end
    for _, p in ipairs(Players:GetPlayers()) do ensureChams(p) end
end)
addSlider(visualsPage, "Weapon Chams Transp.", 0, 100, math.floor(Config.WeaponChamsTransparency*100), function(v) Config.WeaponChamsTransparency = v/100 end)

-- MOVEMENT PAGE
addSep(movementPage, "3RD PERSON")
addToggle(movementPage, "3rd Person", Config.ThirdPersonEnabled, function(v)
    Config.ThirdPersonEnabled = v
    pcall(function()
        if v then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
            LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
        else
            LocalPlayer.CameraMaxZoomDistance = 0.5; LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end)
end)
addSlider(movementPage, "3P Distance", 4, 30, Config.ThirdPersonDist, function(v)
    Config.ThirdPersonDist = v
    if Config.ThirdPersonEnabled then
        pcall(function() LocalPlayer.CameraMaxZoomDistance = v; LocalPlayer.CameraMinZoomDistance = v end)
    end
end)
addDrop(movementPage, "3P Toggle Key", KeyOptions, Config.ThirdPersonKey, function(v) Config.ThirdPersonKey = v end)

addSep(movementPage, "SPEED")
addToggle(movementPage, "Speed Hack", Config.SpeedEnabled, function(v)
    Config.SpeedEnabled = v
    if not v then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end)
    end
end)
addSlider(movementPage, "Walk Speed", 16, 150, Config.SpeedValue, function(v) Config.SpeedValue = v end)

addSep(movementPage, "MOVEMENT")
addToggle(movementPage, "Bunnyhop", Config.BhopEnabled, function(v) Config.BhopEnabled = v end)

--------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- Menu toggle
    if input.KeyCode == Enum.KeyCode.Insert then
        Config.MenuOpen = not Config.MenuOpen; Frame.Visible = Config.MenuOpen
        return
    end

    -- 3rd person keybind
    if Config.ThirdPersonKey and KeyMap[Config.ThirdPersonKey] then
        local match = KeyIsMouse[Config.ThirdPersonKey]
            and (input.UserInputType == KeyMap[Config.ThirdPersonKey])
            or (input.KeyCode == KeyMap[Config.ThirdPersonKey])
        if match then
            Config.ThirdPersonEnabled = not Config.ThirdPersonEnabled
            pcall(function()
                if Config.ThirdPersonEnabled then
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                    LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
                    LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
                else
                    LocalPlayer.CameraMaxZoomDistance = 0.5; LocalPlayer.CameraMinZoomDistance = 0.5
                end
            end)
        end
    end

    -- Head lock (instant snap)
    if Config.HeadLockEnabled and Config.HeadLockKeyName and KeyMap[Config.HeadLockKeyName] then
        local match = KeyIsMouse[Config.HeadLockKeyName]
            and (input.UserInputType == KeyMap[Config.HeadLockKeyName])
            or (input.KeyCode == KeyMap[Config.HeadLockKeyName])
        if match then
            local target = acquireTarget(Config.MaxFOV, "Head", Config.WallCheck)
            if target then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
            end
        end
    end
end)

--------------------------------------------------------------------
-- SILENT AIM (multi-strategy hook)
--------------------------------------------------------------------
local silentAimTarget = nil -- updated per frame

-- Strategy 1: __namecall hook (Raycast / FindPartOnRay)
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        if Config.SilentAimEnabled and silentAimTarget then
            if method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                if math.random(1, 100) <= Config.SilentAimChance then
                    local origin = Camera.CFrame.Position
                    local dir = (silentAimTarget.Position - origin).Unit * 5000

                    if method == "Raycast" then
                        local args = {...}
                        local rayOrigin = args[1]
                        local rayDir = args[2]
                        -- only redirect if it's a player-fired ray (from near camera)
                        if typeof(rayOrigin) == "Vector3" and (rayOrigin - origin).Magnitude < 20 then
                            args[2] = dir
                            return oldNamecall(self, args[1], dir, select(3, ...))
                        end
                    else
                        local args = {...}
                        local ray = args[1]
                        if typeof(ray) == "Ray" and (ray.Origin - origin).Magnitude < 20 then
                            local newRay = Ray.new(ray.Origin, dir)
                            return oldNamecall(self, newRay, select(2, ...))
                        end
                    end
                end
            end

            -- Strategy 2: FireServer hook for remote-based hit registration
            if method == "FireServer" or method == "InvokeServer" then
                -- some games pass mouse hit position as an argument
                local args = {...}
                if Config.SilentAimEnabled and silentAimTarget and math.random(1,100) <= Config.SilentAimChance then
                    for i, arg in ipairs(args) do
                        if typeof(arg) == "Vector3" then
                            -- check if this vector is near where the mouse is pointing (likely a hit pos)
                            local mousePos = Mouse.Hit and Mouse.Hit.Position
                            if mousePos and (arg - mousePos).Magnitude < 10 then
                                args[i] = silentAimTarget.Position
                            end
                        elseif typeof(arg) == "CFrame" then
                            local mousePos = Mouse.Hit and Mouse.Hit.Position
                            if mousePos and (arg.Position - mousePos).Magnitude < 10 then
                                args[i] = CFrame.new(silentAimTarget.Position)
                            end
                        end
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end)
end)

-- Strategy 3: __index hook to redirect Mouse.Hit / Mouse.Target
pcall(function()
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if Config.SilentAimEnabled and silentAimTarget and math.random(1,100) <= Config.SilentAimChance then
            if self == Mouse then
                if key == "Hit" then
                    return CFrame.new(silentAimTarget.Position)
                elseif key == "Target" then
                    return silentAimTarget
                elseif key == "X" then
                    local sp = Camera:WorldToViewportPoint(silentAimTarget.Position)
                    return sp.X
                elseif key == "Y" then
                    local sp = Camera:WorldToViewportPoint(silentAimTarget.Position)
                    return sp.Y
                elseif key == "UnitRay" then
                    local origin = Camera.CFrame.Position
                    local dir = (silentAimTarget.Position - origin).Unit
                    return Ray.new(origin, dir)
                end
            end
        end
        return oldIndex(self, key)
    end)
end)

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
                    lastTrigger = now; pcall(mouse1click)
                end
            end
        end
    end
end

--------------------------------------------------------------------
-- BUNNYHOP
--------------------------------------------------------------------
local function doBhop()
    if not Config.BhopEnabled then return end
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
    or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
        if hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

--------------------------------------------------------------------
-- MAIN LOOP (optimized — minimal work per frame)
--------------------------------------------------------------------
local rainbowHue = 0
local chamsTickCounter = 0
local CHAMS_TICK_INTERVAL = 15 -- every 15 frames (~0.25s at 60fps)
local weaponTickCounter = 0
local WEAPON_TICK_INTERVAL = 30

RunService.RenderStepped:Connect(function(dt)
    rainbowHue = (rainbowHue + dt * 0.5) % 1
    local rc = Color3.fromHSV(rainbowHue, 1, 1)
    local vp = Camera.ViewportSize
    local sc = Vector2.new(vp.X / 2, vp.Y / 2)

    -- FOV circles (cheap)
    if FOVCircle then
        FOVCircle.Position = sc; FOVCircle.Radius = Config.MaxFOV
        FOVCircle.Visible = Config.AimbotEnabled and Config.FOVEnabled
        FOVCircle.Color = Config.RainbowFOV and rc or Color3.fromRGB(255,50,120)
    end
    if SilentFOVCircle then
        SilentFOVCircle.Position = sc; SilentFOVCircle.Radius = Config.SilentAimFOV
        SilentFOVCircle.Visible = Config.SilentAimEnabled and Config.FOVEnabled
    end
    if AAFOVCircle then
        AAFOVCircle.Position = sc; AAFOVCircle.Radius = Config.AimAssistFOV
        AAFOVCircle.Visible = Config.AimAssistEnabled and Config.FOVEnabled
    end

    -- ESP (per frame — Drawing API requires it)
    for player, cache in pairs(DrawingCache) do
        updateESP(player, cache)
    end

    -- Chams (throttled — every N frames)
    chamsTickCounter = chamsTickCounter + 1
    if chamsTickCounter >= CHAMS_TICK_INTERVAL then
        chamsTickCounter = 0
        if Config.VisualsEnabled and Config.ChamsEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                ensureChams(p)
                if Config.RainbowChams and isEnemy(p) then
                    local hl = chamsCache[p]
                    if hl and hl.Parent then hl.FillColor = rc; hl.OutlineColor = rc end
                end
            end
        end
    end

    -- Weapon chams (very throttled)
    weaponTickCounter = weaponTickCounter + 1
    if weaponTickCounter >= WEAPON_TICK_INTERVAL then
        weaponTickCounter = 0
        if Config.VisualsEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    for _, obj in ipairs(p.Character:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Tool") then
                            pcall(function() obj.Transparency = Config.WeaponChamsTransparency end)
                        end
                    end
                end
            end
        end
    end

    -- 3rd person force (every frame to fight game overrides)
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

    -- Speed hack
    if Config.SpeedEnabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = Config.SpeedValue end
        end)
    end

    -- Silent aim target (acquire once, reuse in hooks)
    if Config.SilentAimEnabled then
        silentAimTarget = acquireTarget(Config.SilentAimFOV, Config.AimPart, false)
    else
        silentAimTarget = nil
    end

    -- Aimbot (keybind)
    if Config.AimbotEnabled then
        local keyDown = Config.AlwaysOnAimbot or isKeyDown(Config.AimbotKeyName)
        if keyDown then
            local target = acquireTarget(Config.MaxFOV, Config.AimPart, Config.WallCheck)
            if target then
                local a = 1 / math.clamp(Config.Smoothness, 1, 20)
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), a)
            end
        end
    end

    -- Aim Assist (always-on, no keybind)
    if Config.AimAssistEnabled and not (Config.AimbotEnabled and (Config.AlwaysOnAimbot or isKeyDown(Config.AimbotKeyName))) then
        local target = acquireTarget(Config.AimAssistFOV, Config.AimPart, Config.WallCheck)
        if target then
            local a = 1 / math.clamp(Config.AimAssistSmooth, 1, 30)
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), a)
        end
    end

    -- Triggerbot
    doTriggerbot()

    -- Bunnyhop
    doBhop()
end)

--------------------------------------------------------------------
-- NOTIFICATION
--------------------------------------------------------------------
local NotifGui = Instance.new("ScreenGui"); NotifGui.Name = "DoraNotif"
NotifGui.ResetOnSpawn = false
pcall(function() NotifGui.Parent = game:GetService("CoreGui") end)
if not NotifGui.Parent then NotifGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local NF = Instance.new("Frame")
NF.Size = UDim2.new(0,260,0,60); NF.Position = UDim2.new(1,280,1,-80)
NF.AnchorPoint = Vector2.new(1,0); NF.BackgroundColor3 = Color3.fromRGB(20,8,20)
NF.BorderSizePixel = 0; NF.Parent = NotifGui
Instance.new("UICorner", NF).CornerRadius = UDim.new(0,10)
local ns = Instance.new("UIStroke"); ns.Color = Color3.fromRGB(255,50,180); ns.Thickness = 2; ns.Parent = NF

local NT = Instance.new("TextLabel"); NT.Size = UDim2.new(1,0,0.55,0)
NT.Position = UDim2.new(0,0,0,4); NT.BackgroundTransparency = 1
NT.Text = "✨ Success!"; NT.TextColor3 = Color3.fromRGB(255,100,200)
NT.Font = Enum.Font.GothamBold; NT.TextSize = 18; NT.Parent = NF

local NS = Instance.new("TextLabel"); NS.Size = UDim2.new(1,0,0.4,0)
NS.Position = UDim2.new(0,0,0.55,0); NS.BackgroundTransparency = 1
NS.Text = "Made by Dora 🌸"; NS.TextColor3 = Color3.fromRGB(200,130,200)
NS.Font = Enum.Font.Gotham; NS.TextSize = 13; NS.Parent = NF

task.spawn(function()
    task.wait(0.3)
    NF:TweenPosition(UDim2.new(1,-20,1,-80), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.6, true)
    task.spawn(function()
        local t = 0
        for _ = 1, 80 do t=t+0.05
            local p = 0.5+0.5*math.sin(t*4)
            ns.Color = Color3.fromRGB(255, math.floor(50+130*p), math.floor(180+75*p))
            task.wait(0.03)
        end
    end)
    task.wait(4)
    NF:TweenPosition(UDim2.new(1,280,1,-80), Enum.EasingDirection.In, Enum.EasingStyle.Quint, 0.5, true)
    task.wait(0.6); NotifGui:Destroy()
end)

--------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------
local function cleanup()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
    pcall(function() if SilentFOVCircle then SilentFOVCircle:Remove() end end)
    pcall(function() if AAFOVCircle then AAFOVCircle:Remove() end end)
    for p in pairs(DrawingCache) do removeESP(p) end
    for p in pairs(chamsCache) do removeChams(p) end
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() NotifGui:Destroy() end)
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5; LocalPlayer.CameraMinZoomDistance = 0.5
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end)
end

if getgenv then getgenv().DoraCleanup = cleanup end
print("[DORA] SniperDuel-Chair v4 loaded — press INSERT")
