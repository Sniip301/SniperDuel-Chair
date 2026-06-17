--[[
    DORA // SniperDuel-Chair v5

    v5 Fixes:
      - Team detection rewrite + "Force All Enemy" override toggle
      - Render distance cap for ESP/chams (no long-range lag)
      - Proper full cleanup when disabling chams/ESP
      - Heavy perf: distance culling, no weapon descendant scans
      - Device spoof (Misc tab)
      - Reduced CPU across the board

    Toggle menu: INSERT
]]

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local GuiService        = game:GetService("GuiService")
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
local C = {
    AimbotEnabled     = true,
    AlwaysOnAimbot    = false,
    Smoothness        = 5,
    AimbotKeyName     = "MouseButton2",
    WallCheck         = false,
    AimPart           = "Head",

    AimAssistEnabled  = false,
    AimAssistSmooth   = 10,
    AimAssistFOV      = 120,

    HeadLockEnabled   = false,
    HeadLockKeyName   = "Q",

    TriggerbotEnabled = false,

    SilentAimEnabled  = false,
    SilentAimFOV      = 150,
    SilentAimChance   = 85,

    FOVEnabled        = true,
    MaxFOV            = 250,
    RainbowFOV        = false,

    VisualsEnabled    = true,
    BoxesEnabled      = false,
    TracersEnabled    = false,
    NamesEnabled      = true,
    HealthBarEnabled  = false,
    TracerOrigin      = "Bottom",

    ChamsEnabled      = true,
    RainbowChams      = false,
    ChamsTransparency = 0.3,
    TeamChams         = "Blue", -- "Blue" or "None"

    -- Render distance (studs) — only show ESP/chams within this range
    RenderDistance     = 200,

    -- Force all players as enemies (overrides team detection)
    ForceAllEnemy      = false,

    ThirdPersonEnabled = false,
    ThirdPersonDist    = 12,
    ThirdPersonKey     = "T",

    SpeedEnabled       = false,
    SpeedValue         = 16,

    BhopEnabled        = false,

    -- Device spoof
    SpoofDevice        = "None", -- "None", "Phone", "Tablet", "Console"

    MenuOpen           = false,
}

--------------------------------------------------------------------
-- KEY MAP
--------------------------------------------------------------------
local KeyMap = {
    ["MouseButton1"] = Enum.UserInputType.MouseButton1,
    ["MouseButton2"] = Enum.UserInputType.MouseButton2,
    ["Q"]=Enum.KeyCode.Q, ["E"]=Enum.KeyCode.E, ["R"]=Enum.KeyCode.R,
    ["F"]=Enum.KeyCode.F, ["T"]=Enum.KeyCode.T, ["X"]=Enum.KeyCode.X,
    ["C"]=Enum.KeyCode.C, ["V"]=Enum.KeyCode.V,
    ["CapsLock"]=Enum.KeyCode.CapsLock, ["LeftAlt"]=Enum.KeyCode.LeftAlt,
    ["LeftShift"]=Enum.KeyCode.LeftShift,
}
local KeyIsMouse = {["MouseButton1"]=true, ["MouseButton2"]=true}
local AimPartOpts = {"Head","HumanoidRootPart","UpperTorso"}
local TracerOpts = {"Bottom","Center","Top"}
local KeyOpts = {"MouseButton2","MouseButton1","Q","E","R","F","T","X","C","V","CapsLock","LeftAlt","LeftShift"}
local TeamChamsOpts = {"Blue","None"}
local DeviceOpts = {"None","Phone","Tablet","Console"}

--------------------------------------------------------------------
-- TEAM DETECTION (v5 — rewritten)
--------------------------------------------------------------------
local function isTeammate(player)
    if not player or player == LocalPlayer then return true end

    -- override: treat everyone as enemy
    if C.ForceAllEnemy then return false end

    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team

    -- Case 1: both have no team → FFA → enemy
    if not myTeam and not theirTeam then return false end

    -- Case 2: one has team, other doesn't → enemy
    if not myTeam or not theirTeam then return false end

    -- Case 3: both neutral → FFA → enemy
    if LocalPlayer.Neutral and player.Neutral then return false end

    -- Case 4: one neutral, one not → enemy
    if LocalPlayer.Neutral ~= player.Neutral then return false end

    -- Case 5: same team object → teammate
    if myTeam == theirTeam then return true end

    -- Case 6: different team objects but same TeamColor → teammate
    -- (some games create duplicate team objects with same color)
    if myTeam.TeamColor == theirTeam.TeamColor then return true end

    -- Case 7: different teams → enemy
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
    local h = char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function isKeyDown(kn)
    if KeyIsMouse[kn] then return UserInputService:IsMouseButtonPressed(KeyMap[kn])
    else return UserInputService:IsKeyDown(KeyMap[kn]) end
end

local function distToLocal(char)
    local lc = LocalPlayer.Character
    if not lc or not char then return 9999 end
    local lhrp = lc:FindFirstChild("HumanoidRootPart")
    local thrp = char:FindFirstChild("HumanoidRootPart")
    if not lhrp or not thrp then return 9999 end
    return (lhrp.Position - thrp.Position).Magnitude
end

local function isVisible(part)
    if not C.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {LocalPlayer.Character}
    local tc = part:FindFirstAncestorOfClass("Model")
    if tc then table.insert(ignore, tc) end
    params.FilterDescendantsInstances = ignore
    return workspace:Raycast(origin, dir, params) == nil
end

--------------------------------------------------------------------
-- CHAMS (v5 — proper cleanup, distance-gated)
--------------------------------------------------------------------
local chamsCache = {}
local chamsConns = {}

local function destroyAllChams()
    -- nuke cache
    for p, hl in pairs(chamsCache) do
        pcall(function() hl:Destroy() end)
    end
    chamsCache = {}
    -- disconnect all healing connections
    for p, conns in pairs(chamsConns) do
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
    chamsConns = {}
    -- brute-force: find any leftover DoraChams in workspace
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            for _, obj in ipairs(p.Character:GetChildren()) do
                if obj:IsA("Highlight") and obj.Name == "DoraChams" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end
end

local function ensureChams(player)
    if player == LocalPlayer then return end
    if not C.VisualsEnabled or not C.ChamsEnabled then return end

    local char = player.Character
    if not char or not isAlive(char) then return end

    -- distance check
    if distToLocal(char) > C.RenderDistance then
        -- remove if exists (out of range)
        local hl = chamsCache[player]
        if hl then pcall(function() hl:Destroy() end); chamsCache[player] = nil end
        return
    end

    -- teammate handling
    local teammate = isTeammate(player)
    if teammate and C.TeamChams == "None" then
        local hl = chamsCache[player]
        if hl then pcall(function() hl:Destroy() end); chamsCache[player] = nil end
        return
    end

    local fillC, outC
    if teammate then
        fillC = Color3.fromRGB(50,130,255)
        outC = Color3.fromRGB(80,160,255)
    else
        fillC = Color3.fromRGB(255,20,20)
        outC = Color3.fromRGB(255,60,60)
    end

    local hl = chamsCache[player]
    if hl and hl.Parent then
        hl.FillColor = fillC
        hl.OutlineColor = outC
        hl.FillTransparency = C.ChamsTransparency
        hl.Adornee = char
        return
    end

    -- create
    hl = Instance.new("Highlight")
    hl.Name = "DoraChams"
    hl.FillColor = fillC
    hl.FillTransparency = C.ChamsTransparency
    hl.OutlineColor = outC
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char
    chamsCache[player] = hl

    -- self-heal (only within distance)
    if not chamsConns[player] then chamsConns[player] = {} end
    local conn = hl.AncestryChanged:Connect(function(_, newP)
        if not newP then
            chamsCache[player] = nil
            task.wait(0.3)
            if C.VisualsEnabled and C.ChamsEnabled then ensureChams(player) end
        end
    end)
    table.insert(chamsConns[player], conn)
end

local function removeChamsFor(player)
    local hl = chamsCache[player]
    if hl then pcall(function() hl:Destroy() end); chamsCache[player] = nil end
    if chamsConns[player] then
        for _, c in ipairs(chamsConns[player]) do pcall(function() c:Disconnect() end) end
        chamsConns[player] = nil
    end
    -- also nuke any leftover in character
    if player.Character then
        for _, obj in ipairs(player.Character:GetChildren()) do
            if obj:IsA("Highlight") and obj.Name == "DoraChams" then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

--------------------------------------------------------------------
-- ESP DRAWING
--------------------------------------------------------------------
local DrawCache = {}

local function createESP(player)
    if DrawCache[player] then return end
    local c = {}
    local ok = pcall(function()
        c.box = {}
        for i=1,4 do
            local l = Drawing.new("Line"); l.Visible=false; l.Thickness=1.2; l.Transparency=1
            c.box[i] = l
        end
        c.tracer = Drawing.new("Line"); c.tracer.Visible=false; c.tracer.Thickness=1.2
        c.name = Drawing.new("Text"); c.name.Visible=false; c.name.Size=14
        c.name.Center=true; c.name.Outline=true; c.name.OutlineColor=Color3.fromRGB(0,0,0)
        c.name.Text = player.DisplayName or player.Name
        c.hpBg = Drawing.new("Line"); c.hpBg.Visible=false; c.hpBg.Thickness=3; c.hpBg.Color=Color3.fromRGB(40,40,40)
        c.hpFill = Drawing.new("Line"); c.hpFill.Visible=false; c.hpFill.Thickness=2
    end)
    if ok then DrawCache[player] = c end
end

local function removeESP(player)
    local c = DrawCache[player]
    if not c then return end
    pcall(function()
        for _,l in ipairs(c.box) do l:Remove() end
        c.tracer:Remove(); c.name:Remove(); c.hpBg:Remove(); c.hpFill:Remove()
    end)
    DrawCache[player] = nil
end

local function hideESP(c)
    pcall(function()
        for _,l in ipairs(c.box) do l.Visible=false end
        c.tracer.Visible=false; c.name.Visible=false; c.hpBg.Visible=false; c.hpFill.Visible=false
    end)
end

local function updateESP(player, c)
    if not C.VisualsEnabled then hideESP(c); return end
    local char = player.Character
    if not char or player == LocalPlayer then hideESP(c); return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hum or not hrp or not head or hum.Health <= 0 then hideESP(c); return end

    -- distance cull
    if distToLocal(char) > C.RenderDistance then hideESP(c); return end

    local rp, onScr = Camera:WorldToViewportPoint(hrp.Position)
    if not onScr then hideESP(c); return end

    local hp = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,1.5,0))
    local fp = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))
    local bH = math.abs(hp.Y - fp.Y)
    local bW = bH * 0.55
    local tl=Vector2.new(rp.X-bW/2,hp.Y); local tr=Vector2.new(rp.X+bW/2,hp.Y)
    local bl=Vector2.new(rp.X-bW/2,fp.Y); local br=Vector2.new(rp.X+bW/2,fp.Y)
    local clr = isTeammate(player) and Color3.fromRGB(80,150,255) or Color3.fromRGB(255,40,40)

    pcall(function()
        local sb = C.BoxesEnabled
        c.box[1].From=tl;c.box[1].To=tr;c.box[1].Visible=sb;c.box[1].Color=clr
        c.box[2].From=tr;c.box[2].To=br;c.box[2].Visible=sb;c.box[2].Color=clr
        c.box[3].From=br;c.box[3].To=bl;c.box[3].Visible=sb;c.box[3].Color=clr
        c.box[4].From=bl;c.box[4].To=tl;c.box[4].Visible=sb;c.box[4].Color=clr

        local st = C.TracersEnabled
        c.tracer.Visible=st; c.tracer.Color=clr
        if st then
            local vp=Camera.ViewportSize
            local o
            if C.TracerOrigin=="Top" then o=Vector2.new(vp.X/2,0)
            elseif C.TracerOrigin=="Center" then o=Vector2.new(vp.X/2,vp.Y/2)
            else o=Vector2.new(vp.X/2,vp.Y) end
            c.tracer.From=o; c.tracer.To=Vector2.new(rp.X,fp.Y)
        end

        local sn = C.NamesEnabled
        c.name.Visible=sn; c.name.Color=clr
        if sn then c.name.Position=Vector2.new(rp.X,hp.Y-18); c.name.Text=player.DisplayName or player.Name end

        local sh = C.HealthBarEnabled
        c.hpBg.Visible=sh; c.hpFill.Visible=sh
        if sh then
            local bx=tl.X-5
            c.hpBg.From=Vector2.new(bx,fp.Y); c.hpBg.To=Vector2.new(bx,hp.Y)
            local r=math.clamp(hum.Health/hum.MaxHealth,0,1)
            c.hpFill.From=Vector2.new(bx,fp.Y)
            c.hpFill.To=Vector2.new(bx, fp.Y+(hp.Y-fp.Y)*r)
            c.hpFill.Color=Color3.new(math.clamp(2*(1-r),0,1), math.clamp(2*r,0,1), 0)
        end
    end)
end

--------------------------------------------------------------------
-- FOV CIRCLES
--------------------------------------------------------------------
local FOVCircle, SilentFOV, AAFOV
pcall(function()
    FOVCircle = Drawing.new("Circle"); FOVCircle.Visible=true; FOVCircle.Thickness=1.4
    FOVCircle.Color=Color3.fromRGB(255,50,120); FOVCircle.Transparency=0.5
    FOVCircle.Filled=false; FOVCircle.NumSides=64; FOVCircle.Radius=C.MaxFOV
    SilentFOV = Drawing.new("Circle"); SilentFOV.Visible=false; SilentFOV.Thickness=1.2
    SilentFOV.Color=Color3.fromRGB(255,0,255); SilentFOV.Transparency=0.6
    SilentFOV.Filled=false; SilentFOV.NumSides=48
    AAFOV = Drawing.new("Circle"); AAFOV.Visible=false; AAFOV.Thickness=1.0
    AAFOV.Color=Color3.fromRGB(100,255,100); AAFOV.Transparency=0.7
    AAFOV.Filled=false; AAFOV.NumSides=48
end)

--------------------------------------------------------------------
-- PLAYER HOOKS
--------------------------------------------------------------------
local function hookPlayer(p)
    if p == LocalPlayer then return end
    createESP(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.8)
        chamsCache[p] = nil
        ensureChams(p)
    end)
    if p.Character then task.spawn(function() ensureChams(p) end) end
end
for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p) removeChamsFor(p); removeESP(p) end)

--------------------------------------------------------------------
-- TARGET ACQUISITION
--------------------------------------------------------------------
local function acquireTarget(fov, partName, wallCheck)
    local best, bestDist = nil, fov
    local cx,cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
    local center = Vector2.new(cx,cy)
    for _,p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local ch = p.Character
            if ch and isAlive(ch) then
                local part = ch:FindFirstChild(partName or "Head") or ch:FindFirstChild("Head")
                if part then
                    local sp, vis = Camera:WorldToViewportPoint(part.Position)
                    if vis then
                        local d = (Vector2.new(sp.X,sp.Y)-center).Magnitude
                        if d < bestDist then
                            if not wallCheck or isVisible(part) then
                                bestDist=d; best=part
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

--------------------------------------------------------------------
-- DEVICE SPOOF
--------------------------------------------------------------------
local spoofActive = false
local function applySpoofHooks()
    if spoofActive then return end
    pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if C.SpoofDevice ~= "None" then
                if self == UserInputService then
                    if C.SpoofDevice == "Phone" or C.SpoofDevice == "Tablet" then
                        if key == "TouchEnabled" then return true end
                        if key == "KeyboardEnabled" then return false end
                        if key == "MouseEnabled" then return false end
                        if key == "GamepadEnabled" then return false end
                        if key == "GyroscopeEnabled" then return C.SpoofDevice == "Phone" end
                        if key == "AccelerometerEnabled" then return C.SpoofDevice == "Phone" end
                    elseif C.SpoofDevice == "Console" then
                        if key == "TouchEnabled" then return false end
                        if key == "KeyboardEnabled" then return false end
                        if key == "MouseEnabled" then return false end
                        if key == "GamepadEnabled" then return true end
                    end
                end
                if self == GuiService then
                    if key == "IsTenFootInterface" and C.SpoofDevice == "Console" then
                        return true
                    end
                end
            end

            -- silent aim hooks (combined here to avoid double hookmetamethod)
            if C.SilentAimEnabled and silentAimTarget then
                if self == Mouse and math.random(1,100) <= C.SilentAimChance then
                    if key == "Hit" then return CFrame.new(silentAimTarget.Position) end
                    if key == "Target" then return silentAimTarget end
                    if key == "UnitRay" then
                        local o = Camera.CFrame.Position
                        return Ray.new(o, (silentAimTarget.Position-o).Unit)
                    end
                    if key == "X" then
                        return (Camera:WorldToViewportPoint(silentAimTarget.Position)).X
                    end
                    if key == "Y" then
                        return (Camera:WorldToViewportPoint(silentAimTarget.Position)).Y
                    end
                end
            end

            return oldIndex(self, key)
        end)
        spoofActive = true
    end)
end

-- also hook GetPlatform
pcall(function()
    local oldGetPlatform = UserInputService.GetPlatform
    hookfunction(UserInputService.GetPlatform, function(self)
        if C.SpoofDevice == "Phone" then return Enum.Platform.IOS end
        if C.SpoofDevice == "Tablet" then return Enum.Platform.IOS end
        if C.SpoofDevice == "Console" then return Enum.Platform.XBoxOne end
        return oldGetPlatform(self)
    end)
end)

-- also hook GetLastInputType for device detection
pcall(function()
    local oldGetLast = UserInputService.GetLastInputType
    hookfunction(UserInputService.GetLastInputType, function(self)
        if C.SpoofDevice == "Phone" or C.SpoofDevice == "Tablet" then
            return Enum.UserInputType.Touch
        end
        if C.SpoofDevice == "Console" then
            return Enum.UserInputType.Gamepad1
        end
        return oldGetLast(self)
    end)
end)

applySpoofHooks()

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local SG = Instance.new("ScreenGui"); SG.Name="DoraUI_v5"
SG.ResetOnSpawn=false; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local F = Instance.new("Frame"); F.Size=UDim2.new(0,320,0,580)
F.Position=UDim2.new(0.5,-160,0.5,-290); F.BackgroundColor3=Color3.fromRGB(12,12,18)
F.BorderSizePixel=0; F.Visible=false; F.Active=true; F.Draggable=false; F.Parent=SG
Instance.new("UICorner",F).CornerRadius=UDim.new(0,10)
local fStroke=Instance.new("UIStroke"); fStroke.Color=Color3.fromRGB(255,50,120); fStroke.Thickness=1.5; fStroke.Parent=F

-- Title (drag handle)
local TB=Instance.new("Frame"); TB.Size=UDim2.new(1,0,0,42)
TB.BackgroundColor3=Color3.fromRGB(18,18,26); TB.BorderSizePixel=0; TB.Active=true; TB.Parent=F
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,10)
local TL=Instance.new("TextLabel"); TL.Size=UDim2.new(1,0,1,0); TL.BackgroundTransparency=1
TL.Text="🌸 DORA  //  CHAIR v5"; TL.TextColor3=Color3.fromRGB(255,100,180)
TL.Font=Enum.Font.GothamBold; TL.TextSize=15; TL.Parent=TB

do -- drag
    local dg,ds,sp = false,nil,nil
    TB.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dg=true; ds=i.Position; sp=F.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dg=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dg and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-ds
            F.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X, sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- Tabs
local TBR=Instance.new("Frame"); TBR.Size=UDim2.new(1,-16,0,30); TBR.Position=UDim2.new(0,8,0,46)
TBR.BackgroundTransparency=1; TBR.Parent=F

local pages,tabBtns = {},{}
local tabNames = {"Aimbot","Visuals","Movement","Misc"}
local activeTab = "Aimbot"

local function mkPage(n)
    local s=Instance.new("ScrollingFrame"); s.Size=UDim2.new(1,-16,1,-86); s.Position=UDim2.new(0,8,0,82)
    s.BackgroundTransparency=1; s.ScrollBarThickness=3; s.ScrollBarImageColor3=Color3.fromRGB(255,100,180)
    s.BorderSizePixel=0; s.CanvasSize=UDim2.new(0,0,0,0); s.AutomaticCanvasSize=Enum.AutomaticSize.Y
    s.Visible=(n==activeTab); s.Parent=F
    local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,5); l.Parent=s
    pages[n]=s; return s
end

for i,n in ipairs(tabNames) do
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1/#tabNames,-4,1,0)
    b.Position=UDim2.new((i-1)/#tabNames,2,0,0)
    b.BackgroundColor3=(n==activeTab) and Color3.fromRGB(255,50,120) or Color3.fromRGB(35,35,48)
    b.TextColor3=Color3.fromRGB(230,230,230); b.Font=Enum.Font.GothamBold
    b.TextSize=11; b.Text=n; b.BorderSizePixel=0; b.Parent=TBR
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    tabBtns[n]=b
    b.MouseButton1Click:Connect(function()
        activeTab=n
        for nn,pg in pairs(pages) do pg.Visible=(nn==n) end
        for nn,tb in pairs(tabBtns) do tb.BackgroundColor3=(nn==n) and Color3.fromRGB(255,50,120) or Color3.fromRGB(35,35,48) end
    end)
end

local pgAim=mkPage("Aimbot"); local pgVis=mkPage("Visuals")
local pgMov=mkPage("Movement"); local pgMisc=mkPage("Misc")

-- UI builders
local oc={}
local function no(p) oc[p]=(oc[p] or 0)+1; return oc[p] end

local function sep(p,t)
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1
    l.Text="— "..t.." —"; l.TextColor3=Color3.fromRGB(255,100,180)
    l.Font=Enum.Font.GothamBold; l.TextSize=11; l.LayoutOrder=no(p); l.Parent=p
end

local function tog(p,name,def,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=def and Color3.fromRGB(255,50,120) or Color3.fromRGB(38,38,50)
    b.TextColor3=Color3.fromRGB(225,225,225); b.Font=Enum.Font.Gotham; b.TextSize=13
    b.Text=name..(def and "  [ON]" or "  [OFF]"); b.BorderSizePixel=0
    b.LayoutOrder=no(p); b.Parent=p
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    local s=def
    b.MouseButton1Click:Connect(function()
        s=not s; b.Text=name..(s and "  [ON]" or "  [OFF]")
        b.BackgroundColor3=s and Color3.fromRGB(255,50,120) or Color3.fromRGB(38,38,50)
        cb(s)
    end)
end

local function sld(p,name,mn,mx,def,cb)
    local ct=Instance.new("Frame"); ct.Size=UDim2.new(1,0,0,42); ct.BackgroundTransparency=1
    ct.LayoutOrder=no(p); ct.Parent=p
    local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,0,0,16); lb.BackgroundTransparency=1
    lb.TextColor3=Color3.fromRGB(185,185,185); lb.Font=Enum.Font.Gotham; lb.TextSize=12
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Text="  "..name..": "..tostring(def); lb.Parent=ct
    local tk=Instance.new("Frame"); tk.Size=UDim2.new(1,-16,0,10); tk.Position=UDim2.new(0,8,0,20)
    tk.BackgroundColor3=Color3.fromRGB(30,30,42); tk.BorderSizePixel=0; tk.Active=true; tk.Parent=ct
    Instance.new("UICorner",tk).CornerRadius=UDim.new(0,5)
    local fl=Instance.new("Frame"); fl.Size=UDim2.new(math.clamp((def-mn)/(mx-mn),0,1),0,1,0)
    fl.BackgroundColor3=Color3.fromRGB(255,80,150); fl.BorderSizePixel=0; fl.Parent=tk
    Instance.new("UICorner",fl).CornerRadius=UDim.new(0,5)
    local dr=false
    local function upd(i)
        local r=math.clamp((i.Position.X-tk.AbsolutePosition.X)/tk.AbsoluteSize.X,0,1)
        local v=math.floor(mn+r*(mx-mn)+0.5)
        fl.Size=UDim2.new(r,0,1,0); lb.Text="  "..name..": "..tostring(v); cb(v)
    end
    tk.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=true; upd(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dr and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i) end
    end)
end

local function drp(p,name,opts,def,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=Color3.fromRGB(30,30,42); b.TextColor3=Color3.fromRGB(210,210,210)
    b.Font=Enum.Font.Gotham; b.TextSize=12; b.Text=name..": "..tostring(def).."  ▼"
    b.BorderSizePixel=0; b.LayoutOrder=no(p); b.Parent=p
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    local idx=1
    for i,v in ipairs(opts) do if v==def then idx=i end end
    b.MouseButton1Click:Connect(function()
        idx=idx%#opts+1; local v=opts[idx]
        b.Text=name..": "..tostring(v).."  ▼"; cb(v)
    end)
end

--------------------------------------------------------------------
-- BUILD PAGES
--------------------------------------------------------------------
-- AIMBOT
sep(pgAim,"AIMBOT")
tog(pgAim,"Enable Aimbot",C.AimbotEnabled,function(v) C.AimbotEnabled=v end)
tog(pgAim,"Always-On",C.AlwaysOnAimbot,function(v) C.AlwaysOnAimbot=v end)
tog(pgAim,"Wall Check (legit)",C.WallCheck,function(v) C.WallCheck=v end)
tog(pgAim,"Force All Enemy",C.ForceAllEnemy,function(v)
    C.ForceAllEnemy=v
    -- refresh chams with new team info
    destroyAllChams()
    for _,p in ipairs(Players:GetPlayers()) do ensureChams(p) end
end)
sld(pgAim,"Smoothness",1,20,C.Smoothness,function(v) C.Smoothness=v end)
drp(pgAim,"Aimbot Key",KeyOpts,C.AimbotKeyName,function(v) C.AimbotKeyName=v end)
drp(pgAim,"Aim Part",AimPartOpts,C.AimPart,function(v) C.AimPart=v end)

sep(pgAim,"HEAD LOCK")
tog(pgAim,"Enable Head Lock",C.HeadLockEnabled,function(v) C.HeadLockEnabled=v end)
drp(pgAim,"Head Lock Key",KeyOpts,C.HeadLockKeyName,function(v) C.HeadLockKeyName=v end)

sep(pgAim,"AIM ASSIST (auto)")
tog(pgAim,"Enable Aim Assist",C.AimAssistEnabled,function(v) C.AimAssistEnabled=v end)
sld(pgAim,"AA Smoothness",1,30,C.AimAssistSmooth,function(v) C.AimAssistSmooth=v end)
sld(pgAim,"AA FOV",30,400,C.AimAssistFOV,function(v) C.AimAssistFOV=v end)

sep(pgAim,"FOV")
sld(pgAim,"FOV Radius",30,800,C.MaxFOV,function(v) C.MaxFOV=v end)
tog(pgAim,"Show FOV Circle",C.FOVEnabled,function(v) C.FOVEnabled=v end)
tog(pgAim,"Rainbow FOV",C.RainbowFOV,function(v) C.RainbowFOV=v end)

sep(pgAim,"TRIGGERBOT")
tog(pgAim,"Enable Triggerbot",C.TriggerbotEnabled,function(v) C.TriggerbotEnabled=v end)

sep(pgAim,"SILENT AIM")
tog(pgAim,"Enable Silent Aim",C.SilentAimEnabled,function(v) C.SilentAimEnabled=v end)
sld(pgAim,"Silent Aim FOV",30,500,C.SilentAimFOV,function(v) C.SilentAimFOV=v end)
sld(pgAim,"Hit Chance (%)",1,100,C.SilentAimChance,function(v) C.SilentAimChance=v end)

-- VISUALS
sep(pgVis,"MASTER")
tog(pgVis,"Enable Visuals",C.VisualsEnabled,function(v)
    C.VisualsEnabled=v
    if not v then
        destroyAllChams()
        for _,cache in pairs(DrawCache) do hideESP(cache) end
    end
end)

sep(pgVis,"ESP")
tog(pgVis,"Boxes",C.BoxesEnabled,function(v) C.BoxesEnabled=v end)
tog(pgVis,"Tracers",C.TracersEnabled,function(v) C.TracersEnabled=v end)
tog(pgVis,"Names",C.NamesEnabled,function(v) C.NamesEnabled=v end)
tog(pgVis,"Health Bar",C.HealthBarEnabled,function(v) C.HealthBarEnabled=v end)
drp(pgVis,"Tracer Origin",TracerOpts,C.TracerOrigin,function(v) C.TracerOrigin=v end)

sep(pgVis,"CHAMS")
tog(pgVis,"Chams",C.ChamsEnabled,function(v)
    C.ChamsEnabled=v
    if not v then destroyAllChams()
    else for _,p in ipairs(Players:GetPlayers()) do ensureChams(p) end end
end)
tog(pgVis,"Rainbow Chams",C.RainbowChams,function(v) C.RainbowChams=v end)
sld(pgVis,"Chams Transparency",0,100,math.floor(C.ChamsTransparency*100),function(v) C.ChamsTransparency=v/100 end)
drp(pgVis,"Teammate Chams",TeamChamsOpts,C.TeamChams,function(v)
    C.TeamChams=v; destroyAllChams()
    for _,p in ipairs(Players:GetPlayers()) do ensureChams(p) end
end)
sld(pgVis,"Render Distance",50,500,C.RenderDistance,function(v) C.RenderDistance=v end)

-- MOVEMENT
sep(pgMov,"3RD PERSON")
tog(pgMov,"3rd Person",C.ThirdPersonEnabled,function(v)
    C.ThirdPersonEnabled=v
    pcall(function()
        if v then
            LocalPlayer.CameraMode=Enum.CameraMode.Classic
            LocalPlayer.CameraMaxZoomDistance=C.ThirdPersonDist; LocalPlayer.CameraMinZoomDistance=C.ThirdPersonDist
        else LocalPlayer.CameraMaxZoomDistance=0.5; LocalPlayer.CameraMinZoomDistance=0.5 end
    end)
end)
sld(pgMov,"3P Distance",4,30,C.ThirdPersonDist,function(v)
    C.ThirdPersonDist=v
    if C.ThirdPersonEnabled then pcall(function() LocalPlayer.CameraMaxZoomDistance=v; LocalPlayer.CameraMinZoomDistance=v end) end
end)
drp(pgMov,"3P Toggle Key",KeyOpts,C.ThirdPersonKey,function(v) C.ThirdPersonKey=v end)

sep(pgMov,"SPEED")
tog(pgMov,"Speed Hack",C.SpeedEnabled,function(v)
    C.SpeedEnabled=v
    if not v then pcall(function()
        local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed=16 end
    end) end
end)
sld(pgMov,"Walk Speed",16,150,C.SpeedValue,function(v) C.SpeedValue=v end)

sep(pgMov,"MOVEMENT")
tog(pgMov,"Bunnyhop",C.BhopEnabled,function(v) C.BhopEnabled=v end)

-- MISC
sep(pgMisc,"DEVICE SPOOF")
drp(pgMisc,"Spoof As",DeviceOpts,C.SpoofDevice,function(v) C.SpoofDevice=v end)

sep(pgMisc,"INFO")
do
    local info = Instance.new("TextLabel"); info.Size=UDim2.new(1,0,0,60)
    info.BackgroundTransparency=1; info.TextColor3=Color3.fromRGB(150,150,150)
    info.Font=Enum.Font.Gotham; info.TextSize=11; info.TextWrapped=true
    info.Text="Device spoof makes other players see your input device as Phone, Tablet, or Console. Some games show device icons next to names."
    info.LayoutOrder=no(pgMisc); info.Parent=pgMisc
end

--------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, proc)
    if proc then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        C.MenuOpen=not C.MenuOpen; F.Visible=C.MenuOpen; return
    end

    -- 3P keybind
    if C.ThirdPersonKey and KeyMap[C.ThirdPersonKey] then
        local m = KeyIsMouse[C.ThirdPersonKey] and (input.UserInputType==KeyMap[C.ThirdPersonKey])
            or (input.KeyCode==KeyMap[C.ThirdPersonKey])
        if m then
            C.ThirdPersonEnabled=not C.ThirdPersonEnabled
            pcall(function()
                if C.ThirdPersonEnabled then
                    LocalPlayer.CameraMode=Enum.CameraMode.Classic
                    LocalPlayer.CameraMaxZoomDistance=C.ThirdPersonDist; LocalPlayer.CameraMinZoomDistance=C.ThirdPersonDist
                else LocalPlayer.CameraMaxZoomDistance=0.5; LocalPlayer.CameraMinZoomDistance=0.5 end
            end)
        end
    end

    -- Head lock
    if C.HeadLockEnabled and C.HeadLockKeyName and KeyMap[C.HeadLockKeyName] then
        local m = KeyIsMouse[C.HeadLockKeyName] and (input.UserInputType==KeyMap[C.HeadLockKeyName])
            or (input.KeyCode==KeyMap[C.HeadLockKeyName])
        if m then
            local t = acquireTarget(C.MaxFOV,"Head",C.WallCheck)
            if t then Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.Position) end
        end
    end
end)

--------------------------------------------------------------------
-- SILENT AIM (__namecall hook)
--------------------------------------------------------------------
local silentAimTarget = nil

pcall(function()
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if C.SilentAimEnabled and silentAimTarget and math.random(1,100) <= C.SilentAimChance then
            local origin = Camera.CFrame.Position

            if method == "Raycast" then
                local args = {...}
                if typeof(args[1]) == "Vector3" and (args[1]-origin).Magnitude < 20 then
                    local dir = (silentAimTarget.Position - args[1]).Unit * 5000
                    return old(self, args[1], dir, select(3,...))
                end
            elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                local args = {...}
                if typeof(args[1]) == "Ray" and (args[1].Origin-origin).Magnitude < 20 then
                    local dir = (silentAimTarget.Position - args[1].Origin).Unit * 5000
                    return old(self, Ray.new(args[1].Origin, dir), select(2,...))
                end
            elseif method == "FireServer" or method == "InvokeServer" then
                local args = {...}
                local changed = false
                local mousePos = Mouse.Hit and Mouse.Hit.Position
                for i,arg in ipairs(args) do
                    if typeof(arg)=="Vector3" and mousePos and (arg-mousePos).Magnitude < 15 then
                        args[i] = silentAimTarget.Position; changed=true
                    elseif typeof(arg)=="CFrame" and mousePos and (arg.Position-mousePos).Magnitude < 15 then
                        args[i] = CFrame.new(silentAimTarget.Position); changed=true
                    end
                end
                if changed then return old(self, unpack(args)) end
            end
        end
        return old(self, ...)
    end)
end)

--------------------------------------------------------------------
-- TRIGGERBOT
--------------------------------------------------------------------
local lastTrig = 0
local function trigBot()
    if not C.TriggerbotEnabled then return end
    local now=tick(); if now-lastTrig < 0.08 then return end
    local t=Mouse.Target
    if t then
        local m=t:FindFirstAncestorOfClass("Model")
        if m then
            local p=Players:GetPlayerFromCharacter(m)
            if p and isEnemy(p) then
                local h=m:FindFirstChildOfClass("Humanoid")
                if h and h.Health>0 then lastTrig=now; pcall(mouse1click) end
            end
        end
    end
end

--------------------------------------------------------------------
-- BHOP
--------------------------------------------------------------------
local function bhop()
    if not C.BhopEnabled then return end
    local ch=LocalPlayer.Character; if not ch then return end
    local h=ch:FindFirstChildOfClass("Humanoid")
    if not h or h.Health<=0 then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
    or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
        if h.FloorMaterial ~= Enum.Material.Air then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end

--------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------
local hue = 0
local chamsTick, CHAMS_RATE = 0, 20

RunService.RenderStepped:Connect(function(dt)
    hue = (hue + dt*0.5) % 1
    local rc = Color3.fromHSV(hue,1,1)
    local vp = Camera.ViewportSize
    local sc = Vector2.new(vp.X/2, vp.Y/2)

    -- FOV circles
    if FOVCircle then
        FOVCircle.Position=sc; FOVCircle.Radius=C.MaxFOV
        FOVCircle.Visible = C.AimbotEnabled and C.FOVEnabled
        FOVCircle.Color = C.RainbowFOV and rc or Color3.fromRGB(255,50,120)
    end
    if SilentFOV then
        SilentFOV.Position=sc; SilentFOV.Radius=C.SilentAimFOV
        SilentFOV.Visible = C.SilentAimEnabled and C.FOVEnabled
    end
    if AAFOV then
        AAFOV.Position=sc; AAFOV.Radius=C.AimAssistFOV
        AAFOV.Visible = C.AimAssistEnabled and C.FOVEnabled
    end

    -- ESP
    for p, cache in pairs(DrawCache) do updateESP(p, cache) end

    -- Chams (throttled)
    chamsTick = chamsTick + 1
    if chamsTick >= CHAMS_RATE then
        chamsTick = 0
        if C.VisualsEnabled and C.ChamsEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                ensureChams(p)
                if C.RainbowChams and isEnemy(p) then
                    local hl = chamsCache[p]
                    if hl and hl.Parent then hl.FillColor=rc; hl.OutlineColor=rc end
                end
            end
        end
    end

    -- 3P force
    if C.ThirdPersonEnabled then
        pcall(function()
            if LocalPlayer.CameraMaxZoomDistance < C.ThirdPersonDist then LocalPlayer.CameraMaxZoomDistance=C.ThirdPersonDist end
            if LocalPlayer.CameraMinZoomDistance < C.ThirdPersonDist*0.8 then LocalPlayer.CameraMinZoomDistance=C.ThirdPersonDist*0.8 end
            if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then LocalPlayer.CameraMode=Enum.CameraMode.Classic end
        end)
    end

    -- Speed
    if C.SpeedEnabled then
        pcall(function()
            local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed=C.SpeedValue end
        end)
    end

    -- Silent aim target
    silentAimTarget = C.SilentAimEnabled and acquireTarget(C.SilentAimFOV, C.AimPart, false) or nil

    -- Aimbot
    if C.AimbotEnabled then
        local down = C.AlwaysOnAimbot or isKeyDown(C.AimbotKeyName)
        if down then
            local t = acquireTarget(C.MaxFOV, C.AimPart, C.WallCheck)
            if t then
                local a = 1/math.clamp(C.Smoothness,1,20)
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, t.Position), a)
            end
        end
    end

    -- Aim Assist
    if C.AimAssistEnabled and not (C.AimbotEnabled and (C.AlwaysOnAimbot or isKeyDown(C.AimbotKeyName))) then
        local t = acquireTarget(C.AimAssistFOV, C.AimPart, C.WallCheck)
        if t then
            local a = 1/math.clamp(C.AimAssistSmooth,1,30)
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, t.Position), a)
        end
    end

    trigBot()
    bhop()
end)

--------------------------------------------------------------------
-- NOTIFICATION
--------------------------------------------------------------------
local NG=Instance.new("ScreenGui"); NG.Name="DoraNotif"; NG.ResetOnSpawn=false
pcall(function() NG.Parent=game:GetService("CoreGui") end)
if not NG.Parent then NG.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local NF=Instance.new("Frame"); NF.Size=UDim2.new(0,260,0,60)
NF.Position=UDim2.new(1,280,1,-80); NF.AnchorPoint=Vector2.new(1,0)
NF.BackgroundColor3=Color3.fromRGB(20,8,20); NF.BorderSizePixel=0; NF.Parent=NG
Instance.new("UICorner",NF).CornerRadius=UDim.new(0,10)
local ns=Instance.new("UIStroke"); ns.Color=Color3.fromRGB(255,50,180); ns.Thickness=2; ns.Parent=NF
local NT=Instance.new("TextLabel"); NT.Size=UDim2.new(1,0,0.55,0); NT.Position=UDim2.new(0,0,0,4)
NT.BackgroundTransparency=1; NT.Text="✨ Success!"; NT.TextColor3=Color3.fromRGB(255,100,200)
NT.Font=Enum.Font.GothamBold; NT.TextSize=18; NT.Parent=NF
local NS=Instance.new("TextLabel"); NS.Size=UDim2.new(1,0,0.4,0); NS.Position=UDim2.new(0,0,0.55,0)
NS.BackgroundTransparency=1; NS.Text="Made by Dora 🌸"; NS.TextColor3=Color3.fromRGB(200,130,200)
NS.Font=Enum.Font.Gotham; NS.TextSize=13; NS.Parent=NF

task.spawn(function()
    task.wait(0.3)
    NF:TweenPosition(UDim2.new(1,-20,1,-80),Enum.EasingDirection.Out,Enum.EasingStyle.Quint,0.6,true)
    task.spawn(function()
        local t=0
        for _=1,80 do t=t+0.05
            ns.Color=Color3.fromRGB(255,math.floor(50+130*(0.5+0.5*math.sin(t*4))),math.floor(180+75*(0.5+0.5*math.sin(t*4))))
            task.wait(0.03)
        end
    end)
    task.wait(4)
    NF:TweenPosition(UDim2.new(1,280,1,-80),Enum.EasingDirection.In,Enum.EasingStyle.Quint,0.5,true)
    task.wait(0.6); NG:Destroy()
end)

--------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------
local function cleanup()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
    pcall(function() if SilentFOV then SilentFOV:Remove() end end)
    pcall(function() if AAFOV then AAFOV:Remove() end end)
    for p in pairs(DrawCache) do removeESP(p) end
    destroyAllChams()
    pcall(function() SG:Destroy() end)
    pcall(function() NG:Destroy() end)
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance=0.5; LocalPlayer.CameraMinZoomDistance=0.5
        local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed=16 end
    end)
end

if getgenv then getgenv().DoraCleanup = cleanup end
print("[DORA] v5 loaded — press INSERT")
