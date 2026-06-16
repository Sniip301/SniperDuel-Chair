--[[
    BYTE // SniperDuel-Chair
    Target: Sniper Duels (LOCKED IN NETWORK) — Roblox
    
    Features:
      - Aimbot (smooth, adjustable FOV + rainbow FOV circle)
      - Chams (neon red, through walls)
      - 3rd Person Camera
      - Bunnyhop (auto-jump while W held)
    
    Toggle menu: INSERT
    Aimbot lock: Hold RMB
]]

-- Services
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer

-------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------
local Config = {
    -- Aimbot
    AimbotEnabled    = true,
    AimbotKey        = Enum.UserInputType.MouseButton2,
    Smoothness       = 5,
    MaxFOV           = 250,
    TargetPart       = "Head",

    -- FOV Circle
    RainbowFOV       = false,
    FOVVisible       = true,

    -- Chams
    ChamsEnabled     = true,
    ChamsColor       = Color3.fromRGB(255, 20, 20),
    ChamsTransparency = 0.3,

    -- 3rd Person
    ThirdPersonEnabled = false,
    ThirdPersonDist    = 12,

    -- Bunnyhop
    BhopEnabled      = false,

    -- Menu
    MenuOpen         = false,
}

-------------------------------------------------------------------
-- ANTI RE-RUN CLEANUP
-------------------------------------------------------------------
if getgenv and getgenv().ByteCleanup then
    pcall(getgenv().ByteCleanup)
end

-------------------------------------------------------------------
-- UI
-------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ByteUI_SniperDuels"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- main frame
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 300, 0, 480)
Frame.Position = UDim2.new(0.5, -150, 0.5, -240)
Frame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
Frame.BorderSizePixel = 0
Frame.Visible = false
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 30, 30)
stroke.Thickness = 1.5
stroke.Parent = Frame

-- title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Frame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ BYTE  //  SNIPER DUELS"
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = TitleBar

-- scroll frame for controls
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -48)
Scroll.Position = UDim2.new(0, 8, 0, 44)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 40, 40)
Scroll.BorderSizePixel = 0
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Frame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = Scroll

local layoutOrder = 0

-------------------------------------------------------------------
-- UI COMPONENTS
-------------------------------------------------------------------
local function nextOrder()
    layoutOrder = layoutOrder + 1
    return layoutOrder
end

local function addSeparator(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = "— " .. text .. " —"
    lbl.TextColor3 = Color3.fromRGB(255, 60, 60)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.LayoutOrder = nextOrder()
    lbl.Parent = Scroll
end

local function addToggle(name, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = default and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(40, 40, 52)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = name .. (default and "  [ON]" or "  [OFF]")
    btn.BorderSizePixel = 0
    btn.LayoutOrder = nextOrder()
    btn.Parent = Scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = name .. (state and "  [ON]" or "  [OFF]")
        btn.BackgroundColor3 = state and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(40, 40, 52)
        callback(state)
    end)
    return btn
end

local function addSlider(name, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 44)
    container.BackgroundTransparency = 1
    container.LayoutOrder = nextOrder()
    container.Parent = Scroll

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(190, 190, 190)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "  " .. name .. ": " .. tostring(default)
    label.Parent = container

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -16, 0, 10)
    track.Position = UDim2.new(0, 8, 0, 22)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    track.BorderSizePixel = 0
    track.Parent = container
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 5)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    local dragging = false

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp(
                (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1
            )
            local val = math.floor(min + rel * (max - min) + 0.5)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = "  " .. name .. ": " .. tostring(val)
            callback(val)
        end
    end)
end

-------------------------------------------------------------------
-- BUILD MENU
-------------------------------------------------------------------
addSeparator("AIMBOT")
addToggle("Aimbot", Config.AimbotEnabled, function(v) Config.AimbotEnabled = v end)
addSlider("Smoothness", 1, 20, Config.Smoothness, function(v) Config.Smoothness = v end)
addSlider("FOV Radius", 30, 800, Config.MaxFOV, function(v) Config.MaxFOV = v end)
addToggle("Show FOV Circle", Config.FOVVisible, function(v) Config.FOVVisible = v end)
addToggle("Rainbow FOV", Config.RainbowFOV, function(v) Config.RainbowFOV = v end)

addSeparator("VISUALS")
addToggle("Chams", Config.ChamsEnabled, function(v) Config.ChamsEnabled = v end)

addSeparator("MOVEMENT")
addToggle("3rd Person", Config.ThirdPersonEnabled, function(v)
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
addSlider("3P Distance", 4, 30, Config.ThirdPersonDist, function(v)
    Config.ThirdPersonDist = v
    if Config.ThirdPersonEnabled then
        LocalPlayer.CameraMaxZoomDistance = v
        LocalPlayer.CameraMinZoomDistance = v
    end
end)
addToggle("Bunnyhop", Config.BhopEnabled, function(v) Config.BhopEnabled = v end)

-------------------------------------------------------------------
-- INSERT KEY — MENU TOGGLE
-------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        Config.MenuOpen = not Config.MenuOpen
        Frame.Visible = Config.MenuOpen
    end
end)

-------------------------------------------------------------------
-- FOV CIRCLE (Drawing API)
-------------------------------------------------------------------
local FOVCircle = nil
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible    = Config.FOVVisible
    FOVCircle.Radius     = Config.MaxFOV
    FOVCircle.Thickness  = 1.4
    FOVCircle.Color      = Color3.fromRGB(255, 40, 40)
    FOVCircle.Transparency = 0.5
    FOVCircle.Filled     = false
    FOVCircle.NumSides   = 80
end)

-- rainbow hue tracker
local rainbowHue = 0

-------------------------------------------------------------------
-- CHAMS
-------------------------------------------------------------------
local chamsCache = {}

local function applyChams(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if chamsCache[player] then return end

    local hl = Instance.new("Highlight")
    hl.Name = "ByteChams"
    hl.FillColor = Config.ChamsColor
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

local function refreshChams()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if Config.ChamsEnabled then
                applyChams(p)
            else
                removeChams(p)
            end
        end
    end
end

local function hookPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        chamsCache[player] = nil
        if Config.ChamsEnabled then applyChams(player) end
    end)
    if player.Character and Config.ChamsEnabled then
        applyChams(player)
    end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p) removeChams(p) end)

-------------------------------------------------------------------
-- AIMBOT HELPERS
-------------------------------------------------------------------
local function isAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getClosestTarget()
    local closest, shortDist = nil, Config.MaxFOV
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local center = Vector2.new(cx, cy)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and isAlive(char) then
                local part = char:FindFirstChild(Config.TargetPart) or char:FindFirstChild("Head")
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

-------------------------------------------------------------------
-- BUNNYHOP
-------------------------------------------------------------------
local function doBhop()
    if not Config.BhopEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    -- jump when on ground and W is held
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or
       UserInputService:IsKeyDown(Enum.KeyCode.A) or
       UserInputService:IsKeyDown(Enum.KeyCode.S) or
       UserInputService:IsKeyDown(Enum.KeyCode.D) then
        if hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

-------------------------------------------------------------------
-- MAIN LOOP
-------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
    -- rainbow hue
    rainbowHue = (rainbowHue + dt * 0.5) % 1

    -- FOV circle update
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Config.MaxFOV
        FOVCircle.Visible = Config.AimbotEnabled and Config.FOVVisible

        if Config.RainbowFOV then
            FOVCircle.Color = Color3.fromHSV(rainbowHue, 1, 1)
        else
            FOVCircle.Color = Color3.fromRGB(255, 40, 40)
        end
    end

    -- chams
    refreshChams()

    -- aimbot
    if Config.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = getClosestTarget()
        if target then
            local targetCF = CFrame.new(Camera.CFrame.Position, target.Position)
            local alpha = 1 / math.clamp(Config.Smoothness, 1, 20)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
        end
    end

    -- bunnyhop
    doBhop()
end)

-------------------------------------------------------------------
-- CLEANUP
-------------------------------------------------------------------
local function cleanup()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
    for _, hl in pairs(chamsCache) do pcall(function() hl:Destroy() end) end
    pcall(function() ScreenGui:Destroy() end)
    -- restore camera
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    end)
end

if getgenv then getgenv().ByteCleanup = cleanup end

print("[BYTE] SniperDuel-Chair loaded — press INSERT")
