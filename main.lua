--[[
    DORA // SniperDuel-Chair v6

    v6:
      - Performance overhaul: work split across frames, cached player list
      - FPS Boost (reduce graphics quality)
      - Real dropdown menus (expand/collapse)
      - FPS Counter widget (draggable)
      - Custom pink cursor + white trail on menu
      - Pop sound on menu clicks
      - Device spoof rework
      - Unlock All stub (Sniper Duels)

    Toggle menu: INSERT
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local GuiService        = game:GetService("GuiService")
local SoundService      = game:GetService("SoundService")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

if getgenv and getgenv().DoraCleanup then pcall(getgenv().DoraCleanup); task.wait(0.3) end

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local C = {
    AimbotEnabled=true, AlwaysOnAimbot=false, Smoothness=5,
    AimbotKeyName="MouseButton2", WallCheck=false, AimPart="Head",
    AimAssistEnabled=false, AimAssistSmooth=10, AimAssistFOV=120,
    HeadLockEnabled=false, HeadLockKeyName="Q",
    TriggerbotEnabled=false,
    SilentAimEnabled=false, SilentAimFOV=150, SilentAimChance=85,
    FOVEnabled=true, MaxFOV=250, RainbowFOV=false,
    VisualsEnabled=true, BoxesEnabled=false, TracersEnabled=false,
    NamesEnabled=true, HealthBarEnabled=false, TracerOrigin="Bottom",
    ChamsEnabled=true, RainbowChams=false, ChamsTransparency=0.3,
    TeamChams="Blue", RenderDistance=200, ForceAllEnemy=false,
    ThirdPersonEnabled=false, ThirdPersonDist=12, ThirdPersonKey="T",
    SpeedEnabled=false, SpeedValue=16, BhopEnabled=false,
    FPSBoostEnabled=false,
    SpoofDevice="None",
    ShowFPS=true,
    MenuOpen=false,
}

--------------------------------------------------------------------
-- KEY MAP
--------------------------------------------------------------------
local KM={["MouseButton1"]=Enum.UserInputType.MouseButton1,["MouseButton2"]=Enum.UserInputType.MouseButton2,
["Q"]=Enum.KeyCode.Q,["E"]=Enum.KeyCode.E,["R"]=Enum.KeyCode.R,["F"]=Enum.KeyCode.F,
["T"]=Enum.KeyCode.T,["X"]=Enum.KeyCode.X,["C"]=Enum.KeyCode.C,["V"]=Enum.KeyCode.V,
["CapsLock"]=Enum.KeyCode.CapsLock,["LeftAlt"]=Enum.KeyCode.LeftAlt,["LeftShift"]=Enum.KeyCode.LeftShift}
local KMouse={["MouseButton1"]=1,["MouseButton2"]=1}
local AimParts={"Head","HumanoidRootPart","UpperTorso"}
local TracerOps={"Bottom","Center","Top"}
local KeyOps={"MouseButton2","MouseButton1","Q","E","R","F","T","X","C","V","CapsLock","LeftAlt","LeftShift"}
local TeamOps={"Blue","None"}
local DeviceOps={"None","Phone","Tablet","Console"}

local function keyDown(kn)
    if KMouse[kn] then return UserInputService:IsMouseButtonPressed(KM[kn])
    else return UserInputService:IsKeyDown(KM[kn]) end
end

--------------------------------------------------------------------
-- TEAM / UTILITY
--------------------------------------------------------------------
local function isTeammate(p)
    if not p or p==LocalPlayer then return true end
    if C.ForceAllEnemy then return false end
    local mt,tt=LocalPlayer.Team,p.Team
    if not mt and not tt then return false end
    if not mt or not tt then return false end
    if LocalPlayer.Neutral and p.Neutral then return false end
    if LocalPlayer.Neutral~=p.Neutral then return false end
    if mt==tt then return true end
    if mt.TeamColor==tt.TeamColor then return true end
    return false
end
local function isEnemy(p) return p~=LocalPlayer and not isTeammate(p) end
local function isAlive(ch) if not ch then return false end; local h=ch:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end

local cachedLocalHRP = nil
local function getLocalHRP()
    local ch = LocalPlayer.Character
    if ch then cachedLocalHRP = ch:FindFirstChild("HumanoidRootPart") end
    return cachedLocalHRP
end

local function distTo(ch)
    local lh = getLocalHRP()
    if not lh or not ch then return 9999 end
    local th = ch:FindFirstChild("HumanoidRootPart")
    if not th then return 9999 end
    return (lh.Position-th.Position).Magnitude
end

local function isVisible(part)
    if not C.WallCheck then return true end
    local o=Camera.CFrame.Position; local d=part.Position-o
    local pr=RaycastParams.new(); pr.FilterType=Enum.RaycastFilterType.Exclude
    local ig={LocalPlayer.Character}
    local tc=part:FindFirstAncestorOfClass("Model"); if tc then table.insert(ig,tc) end
    pr.FilterDescendantsInstances=ig
    return workspace:Raycast(o,d,pr)==nil
end

--------------------------------------------------------------------
-- CACHED PLAYER LIST (refresh every 60 frames)
--------------------------------------------------------------------
local playerCache = {}
local playerCacheTick = 0
local function refreshPlayerCache()
    playerCache = Players:GetPlayers()
end
refreshPlayerCache()
Players.PlayerAdded:Connect(function() refreshPlayerCache() end)
Players.PlayerRemoving:Connect(function() task.defer(refreshPlayerCache) end)

--------------------------------------------------------------------
-- POP SOUND
--------------------------------------------------------------------
local popSound = Instance.new("Sound")
popSound.SoundId = "rbxassetid://6895079853" -- soft pop
popSound.Volume = 0.3
popSound.PlaybackSpeed = 1.3
popSound.Parent = SoundService

local function playPop()
    pcall(function() popSound:Play() end)
end

--------------------------------------------------------------------
-- UI FRAMEWORK
--------------------------------------------------------------------
local SG=Instance.new("ScreenGui"); SG.Name="DoraUI_v6"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent=game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local Fr=Instance.new("Frame"); Fr.Size=UDim2.new(0,320,0,580)
Fr.Position=UDim2.new(0.5,-160,0.5,-290); Fr.BackgroundColor3=Color3.fromRGB(12,12,18)
Fr.BorderSizePixel=0; Fr.Visible=false; Fr.Active=true; Fr.Draggable=false; Fr.Parent=SG
Instance.new("UICorner",Fr).CornerRadius=UDim.new(0,10)
local fStr=Instance.new("UIStroke"); fStr.Color=Color3.fromRGB(255,50,120); fStr.Thickness=1.5; fStr.Parent=Fr

-- Title drag
local TB=Instance.new("Frame"); TB.Size=UDim2.new(1,0,0,42)
TB.BackgroundColor3=Color3.fromRGB(18,18,26); TB.BorderSizePixel=0; TB.Active=true; TB.Parent=Fr
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,10)
local TL=Instance.new("TextLabel"); TL.Size=UDim2.new(1,0,1,0); TL.BackgroundTransparency=1
TL.Text="🌸 DORA  //  CHAIR v6"; TL.TextColor3=Color3.fromRGB(255,100,180)
TL.Font=Enum.Font.GothamBold; TL.TextSize=15; TL.Parent=TB

do local dg,ds,sp=false,nil,nil
    TB.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dg=true;ds=i.Position;sp=Fr.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dg=false end end)
    end end)
    UserInputService.InputChanged:Connect(function(i)
        if dg and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds; Fr.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- Tabs
local TBR=Instance.new("Frame"); TBR.Size=UDim2.new(1,-16,0,28); TBR.Position=UDim2.new(0,8,0,46)
TBR.BackgroundTransparency=1; TBR.Parent=Fr
local pages,tabBtns={},{}
local tabNames={"Aimbot","Visuals","Move","Misc"}
local activeTab="Aimbot"

local function mkPage(n)
    local s=Instance.new("ScrollingFrame"); s.Size=UDim2.new(1,-16,1,-82); s.Position=UDim2.new(0,8,0,78)
    s.BackgroundTransparency=1; s.ScrollBarThickness=3; s.ScrollBarImageColor3=Color3.fromRGB(255,100,180)
    s.BorderSizePixel=0; s.CanvasSize=UDim2.new(0,0,0,0); s.AutomaticCanvasSize=Enum.AutomaticSize.Y
    s.Visible=(n==activeTab); s.Parent=Fr
    Instance.new("UIListLayout",s).Padding=UDim.new(0,4)
    s:FindFirstChild("UIListLayout").SortOrder=Enum.SortOrder.LayoutOrder
    pages[n]=s; return s
end

for i,n in ipairs(tabNames) do
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1/#tabNames,-3,1,0)
    b.Position=UDim2.new((i-1)/#tabNames,1,0,0)
    b.BackgroundColor3=(n==activeTab) and Color3.fromRGB(255,50,120) or Color3.fromRGB(35,35,48)
    b.TextColor3=Color3.fromRGB(230,230,230); b.Font=Enum.Font.GothamBold; b.TextSize=11
    b.Text=n; b.BorderSizePixel=0; b.Parent=TBR
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    tabBtns[n]=b
    b.MouseButton1Click:Connect(function()
        playPop(); activeTab=n
        for nn,pg in pairs(pages) do pg.Visible=(nn==n) end
        for nn,tb in pairs(tabBtns) do tb.BackgroundColor3=(nn==n) and Color3.fromRGB(255,50,120) or Color3.fromRGB(35,35,48) end
    end)
end

local pgA=mkPage("Aimbot"); local pgV=mkPage("Visuals")
local pgM=mkPage("Move"); local pgX=mkPage("Misc")

-- UI builders
local oc={}
local function no(p) oc[p]=(oc[p] or 0)+1; return oc[p] end

local function sep(p,t)
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,20); l.BackgroundTransparency=1
    l.Text="— "..t.." —"; l.TextColor3=Color3.fromRGB(255,100,180)
    l.Font=Enum.Font.GothamBold; l.TextSize=11; l.LayoutOrder=no(p); l.Parent=p
end

local function tog(p,name,def,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,28)
    b.BackgroundColor3=def and Color3.fromRGB(255,50,120) or Color3.fromRGB(38,38,50)
    b.TextColor3=Color3.fromRGB(225,225,225); b.Font=Enum.Font.Gotham; b.TextSize=12
    b.Text=name..(def and "  [ON]" or "  [OFF]"); b.BorderSizePixel=0
    b.LayoutOrder=no(p); b.Parent=p
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    local s=def
    b.MouseButton1Click:Connect(function()
        playPop(); s=not s; b.Text=name..(s and "  [ON]" or "  [OFF]")
        b.BackgroundColor3=s and Color3.fromRGB(255,50,120) or Color3.fromRGB(38,38,50)
        cb(s)
    end)
end

local function sld(p,name,mn,mx,def,cb)
    local ct=Instance.new("Frame"); ct.Size=UDim2.new(1,0,0,38); ct.BackgroundTransparency=1
    ct.LayoutOrder=no(p); ct.Parent=p
    local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,0,0,14); lb.BackgroundTransparency=1
    lb.TextColor3=Color3.fromRGB(185,185,185); lb.Font=Enum.Font.Gotham; lb.TextSize=11
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Text="  "..name..": "..tostring(def); lb.Parent=ct
    local tk=Instance.new("Frame"); tk.Size=UDim2.new(1,-16,0,8); tk.Position=UDim2.new(0,8,0,18)
    tk.BackgroundColor3=Color3.fromRGB(30,30,42); tk.BorderSizePixel=0; tk.Active=true; tk.Parent=ct
    Instance.new("UICorner",tk).CornerRadius=UDim.new(0,4)
    local fl=Instance.new("Frame"); fl.Size=UDim2.new(math.clamp((def-mn)/(mx-mn),0,1),0,1,0)
    fl.BackgroundColor3=Color3.fromRGB(255,80,150); fl.BorderSizePixel=0; fl.Parent=tk
    Instance.new("UICorner",fl).CornerRadius=UDim.new(0,4)
    local dr=false
    local function upd(i)
        local r=math.clamp((i.Position.X-tk.AbsolutePosition.X)/tk.AbsoluteSize.X,0,1)
        local v=math.floor(mn+r*(mx-mn)+0.5)
        fl.Size=UDim2.new(r,0,1,0); lb.Text="  "..name..": "..tostring(v); cb(v)
    end
    tk.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true; upd(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dr and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i) end
    end)
end

-- REAL DROPDOWN (expand/collapse list)
local function drp(p, name, opts, def, cb)
    local container = Instance.new("Frame"); container.Size = UDim2.new(1,0,0,28)
    container.BackgroundTransparency = 1; container.LayoutOrder = no(p)
    container.ClipsDescendants = false; container.Parent = p

    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,0,28)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,42); btn.TextColor3 = Color3.fromRGB(210,210,210)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 12; btn.Text = name..": "..tostring(def).."  ▼"
    btn.BorderSizePixel = 0; btn.ZIndex = 5; btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1,0,0,#opts*26)
    listFrame.Position = UDim2.new(0,0,1,2)
    listFrame.BackgroundColor3 = Color3.fromRGB(22,22,32)
    listFrame.BorderSizePixel = 0; listFrame.Visible = false
    listFrame.ZIndex = 10; listFrame.Parent = container
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0,6)
    local lStr = Instance.new("UIStroke"); lStr.Color = Color3.fromRGB(255,80,150); lStr.Thickness = 1; lStr.Parent = listFrame

    local listLayout = Instance.new("UIListLayout"); listLayout.Padding = UDim.new(0,1)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Parent = listFrame

    local expanded = false

    for i, opt in ipairs(opts) do
        local ob = Instance.new("TextButton"); ob.Size = UDim2.new(1,0,0,25)
        ob.BackgroundColor3 = (opt==def) and Color3.fromRGB(255,50,120) or Color3.fromRGB(28,28,38)
        ob.BackgroundTransparency = 0; ob.TextColor3 = Color3.fromRGB(220,220,220)
        ob.Font = Enum.Font.Gotham; ob.TextSize = 11; ob.Text = "  "..opt
        ob.TextXAlignment = Enum.TextXAlignment.Left
        ob.BorderSizePixel = 0; ob.LayoutOrder = i; ob.ZIndex = 11; ob.Parent = listFrame
        if i == 1 then
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = ob
        elseif i == #opts then
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = ob
        end

        ob.MouseButton1Click:Connect(function()
            playPop()
            btn.Text = name..": "..opt.."  ▼"
            -- highlight selected
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = (child.Text == "  "..opt) and Color3.fromRGB(255,50,120) or Color3.fromRGB(28,28,38)
                end
            end
            expanded = false; listFrame.Visible = false
            cb(opt)
        end)
    end

    btn.MouseButton1Click:Connect(function()
        playPop(); expanded = not expanded; listFrame.Visible = expanded
    end)

    -- close when clicking elsewhere
    UserInputService.InputBegan:Connect(function(input)
        if expanded and input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.defer(function()
                -- check if click was outside
                local mx, my = input.Position.X, input.Position.Y
                local ap = listFrame.AbsolutePosition; local as = listFrame.AbsoluteSize
                local bp = btn.AbsolutePosition; local bs = btn.AbsoluteSize
                local inList = mx>=ap.X and mx<=ap.X+as.X and my>=ap.Y and my<=ap.Y+as.Y
                local inBtn = mx>=bp.X and mx<=bp.X+bs.X and my>=bp.Y and my<=bp.Y+bs.Y
                if not inList and not inBtn then
                    expanded = false; listFrame.Visible = false
                end
            end)
        end
    end)
end

--------------------------------------------------------------------
-- BUILD PAGES
--------------------------------------------------------------------
sep(pgA,"AIMBOT")
tog(pgA,"Enable Aimbot",C.AimbotEnabled,function(v) C.AimbotEnabled=v end)
tog(pgA,"Always-On",C.AlwaysOnAimbot,function(v) C.AlwaysOnAimbot=v end)
tog(pgA,"Wall Check (legit)",C.WallCheck,function(v) C.WallCheck=v end)
tog(pgA,"Force All Enemy",C.ForceAllEnemy,function(v) C.ForceAllEnemy=v; destroyAllChams()
    for _,pl in ipairs(playerCache) do ensureChams(pl) end end)
sld(pgA,"Smoothness",1,20,C.Smoothness,function(v) C.Smoothness=v end)
drp(pgA,"Aimbot Key",KeyOps,C.AimbotKeyName,function(v) C.AimbotKeyName=v end)
drp(pgA,"Aim Part",AimParts,C.AimPart,function(v) C.AimPart=v end)
sep(pgA,"HEAD LOCK")
tog(pgA,"Head Lock",C.HeadLockEnabled,function(v) C.HeadLockEnabled=v end)
drp(pgA,"Head Lock Key",KeyOps,C.HeadLockKeyName,function(v) C.HeadLockKeyName=v end)
sep(pgA,"AIM ASSIST (auto)")
tog(pgA,"Aim Assist",C.AimAssistEnabled,function(v) C.AimAssistEnabled=v end)
sld(pgA,"AA Smoothness",1,30,C.AimAssistSmooth,function(v) C.AimAssistSmooth=v end)
sld(pgA,"AA FOV",30,400,C.AimAssistFOV,function(v) C.AimAssistFOV=v end)
sep(pgA,"FOV")
sld(pgA,"FOV Radius",30,800,C.MaxFOV,function(v) C.MaxFOV=v end)
tog(pgA,"Show FOV",C.FOVEnabled,function(v) C.FOVEnabled=v end)
tog(pgA,"Rainbow FOV",C.RainbowFOV,function(v) C.RainbowFOV=v end)
sep(pgA,"TRIGGERBOT")
tog(pgA,"Triggerbot",C.TriggerbotEnabled,function(v) C.TriggerbotEnabled=v end)
sep(pgA,"SILENT AIM")
tog(pgA,"Silent Aim",C.SilentAimEnabled,function(v) C.SilentAimEnabled=v end)
sld(pgA,"SA FOV",30,500,C.SilentAimFOV,function(v) C.SilentAimFOV=v end)
sld(pgA,"Hit Chance %",1,100,C.SilentAimChance,function(v) C.SilentAimChance=v end)

sep(pgV,"MASTER")
tog(pgV,"Enable Visuals",C.VisualsEnabled,function(v)
    C.VisualsEnabled=v; if not v then destroyAllChams() end
end)
sep(pgV,"ESP")
tog(pgV,"Boxes",C.BoxesEnabled,function(v) C.BoxesEnabled=v end)
tog(pgV,"Tracers",C.TracersEnabled,function(v) C.TracersEnabled=v end)
tog(pgV,"Names",C.NamesEnabled,function(v) C.NamesEnabled=v end)
tog(pgV,"Health Bar",C.HealthBarEnabled,function(v) C.HealthBarEnabled=v end)
drp(pgV,"Tracer Origin",TracerOps,C.TracerOrigin,function(v) C.TracerOrigin=v end)
sep(pgV,"CHAMS")
tog(pgV,"Chams",C.ChamsEnabled,function(v)
    C.ChamsEnabled=v; if not v then destroyAllChams() else
    for _,pl in ipairs(playerCache) do ensureChams(pl) end end
end)
tog(pgV,"Rainbow Chams",C.RainbowChams,function(v) C.RainbowChams=v end)
sld(pgV,"Chams Transp.",0,100,30,function(v) C.ChamsTransparency=v/100 end)
drp(pgV,"Team Chams",TeamOps,C.TeamChams,function(v)
    C.TeamChams=v; destroyAllChams(); for _,pl in ipairs(playerCache) do ensureChams(pl) end
end)
sld(pgV,"Render Dist.",50,500,C.RenderDistance,function(v) C.RenderDistance=v end)

sep(pgM,"3RD PERSON")
tog(pgM,"3rd Person",C.ThirdPersonEnabled,function(v) C.ThirdPersonEnabled=v end)
sld(pgM,"3P Distance",4,30,C.ThirdPersonDist,function(v) C.ThirdPersonDist=v end)
drp(pgM,"3P Key",KeyOps,C.ThirdPersonKey,function(v) C.ThirdPersonKey=v end)
sep(pgM,"SPEED")
tog(pgM,"Speed Hack",C.SpeedEnabled,function(v) C.SpeedEnabled=v
    if not v then pcall(function() local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=16 end end) end
end)
sld(pgM,"Walk Speed",16,150,C.SpeedValue,function(v) C.SpeedValue=v end)
sep(pgM,"MOVEMENT")
tog(pgM,"Bunnyhop",C.BhopEnabled,function(v) C.BhopEnabled=v end)

sep(pgX,"FPS BOOST")
tog(pgX,"FPS Boost",C.FPSBoostEnabled,function(v)
    C.FPSBoostEnabled=v
    if v then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            local ug = UserSettings():GetService("UserGameSettings")
            ug.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 1
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                    pcall(function() d.Enabled = false end)
                end
                if d:IsA("Decal") or d:IsA("Texture") then
                    pcall(function() d.Transparency = 1 end)
                end
                if d:IsA("MeshPart") or d:IsA("UnionOperation") then
                    pcall(function() d.RenderFidelity = Enum.RenderFidelity.Performance end)
                end
            end
            -- disable terrain decoration
            pcall(function() workspace.Terrain.Decoration = false end)
            pcall(function() workspace.Terrain.WaterWaveSize = 0 end)
            pcall(function() workspace.Terrain.WaterReflectance = 0 end)
        end)
    else
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            Lighting.GlobalShadows = true
        end)
    end
end)

sep(pgX,"FPS COUNTER")
tog(pgX,"Show FPS",C.ShowFPS,function(v) C.ShowFPS=v end)

sep(pgX,"DEVICE SPOOF")
drp(pgX,"Spoof As",DeviceOps,C.SpoofDevice,function(v) C.SpoofDevice=v end)
do
    local info=Instance.new("TextLabel"); info.Size=UDim2.new(1,0,0,40)
    info.BackgroundTransparency=1; info.TextColor3=Color3.fromRGB(130,130,130)
    info.Font=Enum.Font.Gotham; info.TextSize=10; info.TextWrapped=true
    info.Text="Hooks TouchEnabled, GetPlatform, GetLastInputType. Works in games that check device client-side."
    info.LayoutOrder=no(pgX); info.Parent=pgX
end

sep(pgX,"UNLOCK ALL")
do
    local ub=Instance.new("TextButton"); ub.Size=UDim2.new(1,0,0,28)
    ub.BackgroundColor3=Color3.fromRGB(80,30,80); ub.TextColor3=Color3.fromRGB(255,200,255)
    ub.Font=Enum.Font.GothamBold; ub.TextSize=12; ub.Text="🔓 Attempt Unlock All"
    ub.BorderSizePixel=0; ub.LayoutOrder=no(pgX); ub.Parent=pgX
    Instance.new("UICorner",ub).CornerRadius=UDim.new(0,6)
    ub.MouseButton1Click:Connect(function()
        playPop()
        ub.Text = "🔄 Scanning remotes..."
        task.spawn(function()
            local found = 0
            pcall(function()
                for _, remote in ipairs(game:GetDescendants()) do
                    if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                        local n = remote.Name:lower()
                        if n:find("unlock") or n:find("purchase") or n:find("buy")
                        or n:find("equip") or n:find("reward") or n:find("claim")
                        or n:find("redeem") or n:find("grant") then
                            found = found + 1
                            pcall(function()
                                if remote:IsA("RemoteEvent") then
                                    remote:FireServer()
                                end
                            end)
                        end
                    end
                end
            end)
            ub.Text = "✅ Fired "..found.." remotes"
            task.wait(3); ub.Text = "🔓 Attempt Unlock All"
        end)
    end)
    local note=Instance.new("TextLabel"); note.Size=UDim2.new(1,0,0,30)
    note.BackgroundTransparency=1; note.TextColor3=Color3.fromRGB(130,130,130)
    note.Font=Enum.Font.Gotham; note.TextSize=10; note.TextWrapped=true
    note.Text="Scans for unlock/purchase/equip remotes and fires them. Results vary per game."
    note.LayoutOrder=no(pgX); note.Parent=pgX
end

--------------------------------------------------------------------
-- CHAMS
--------------------------------------------------------------------
local chamsCache, chamsConns = {}, {}

function destroyAllChams()
    for _,hl in pairs(chamsCache) do pcall(function() hl:Destroy() end) end
    chamsCache={}
    for _,conns in pairs(chamsConns) do for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end end
    chamsConns={}
    for _,p in ipairs(playerCache) do
        if p.Character then for _,o in ipairs(p.Character:GetChildren()) do
            if o:IsA("Highlight") and o.Name=="DoraChams" then pcall(function() o:Destroy() end) end
        end end
    end
end

function ensureChams(player)
    if player==LocalPlayer then return end
    if not C.VisualsEnabled or not C.ChamsEnabled then return end
    local ch=player.Character; if not ch or not isAlive(ch) then return end
    if distTo(ch)>C.RenderDistance then
        if chamsCache[player] then pcall(function() chamsCache[player]:Destroy() end); chamsCache[player]=nil end
        return
    end
    local tm=isTeammate(player)
    if tm and C.TeamChams=="None" then
        if chamsCache[player] then pcall(function() chamsCache[player]:Destroy() end); chamsCache[player]=nil end
        return
    end
    local fc,oc2 = tm and Color3.fromRGB(50,130,255) or Color3.fromRGB(255,20,20),
                   tm and Color3.fromRGB(80,160,255) or Color3.fromRGB(255,60,60)
    local hl=chamsCache[player]
    if hl and hl.Parent then hl.FillColor=fc; hl.OutlineColor=oc2; hl.FillTransparency=C.ChamsTransparency; hl.Adornee=ch; return end
    hl=Instance.new("Highlight"); hl.Name="DoraChams"; hl.FillColor=fc; hl.FillTransparency=C.ChamsTransparency
    hl.OutlineColor=oc2; hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=ch; hl.Parent=ch; chamsCache[player]=hl
    if not chamsConns[player] then chamsConns[player]={} end
    table.insert(chamsConns[player], hl.AncestryChanged:Connect(function(_,np)
        if not np then chamsCache[player]=nil; task.wait(0.3)
            if C.VisualsEnabled and C.ChamsEnabled then ensureChams(player) end
        end
    end))
end

--------------------------------------------------------------------
-- ESP
--------------------------------------------------------------------
local DC={}

local function mkESP(p)
    if DC[p] then return end; local c={}
    pcall(function()
        c.box={}; for i=1,4 do local l=Drawing.new("Line"); l.Visible=false; l.Thickness=1.2; c.box[i]=l end
        c.tracer=Drawing.new("Line"); c.tracer.Visible=false; c.tracer.Thickness=1.2
        c.name=Drawing.new("Text"); c.name.Visible=false; c.name.Size=13; c.name.Center=true
        c.name.Outline=true; c.name.OutlineColor=Color3.fromRGB(0,0,0)
        c.hpBg=Drawing.new("Line"); c.hpBg.Visible=false; c.hpBg.Thickness=3; c.hpBg.Color=Color3.fromRGB(40,40,40)
        c.hpFl=Drawing.new("Line"); c.hpFl.Visible=false; c.hpFl.Thickness=2
    end)
    DC[p]=c
end

local function rmESP(p)
    local c=DC[p]; if not c then return end
    pcall(function() for _,l in ipairs(c.box) do l:Remove() end; c.tracer:Remove(); c.name:Remove(); c.hpBg:Remove(); c.hpFl:Remove() end)
    DC[p]=nil
end

local function hideE(c)
    pcall(function() for _,l in ipairs(c.box) do l.Visible=false end; c.tracer.Visible=false; c.name.Visible=false; c.hpBg.Visible=false; c.hpFl.Visible=false end)
end

local function updESP(p,c)
    if not C.VisualsEnabled then hideE(c); return end
    local ch=p.Character; if not ch or p==LocalPlayer then hideE(c); return end
    local hum=ch:FindFirstChildOfClass("Humanoid"); local hrp=ch:FindFirstChild("HumanoidRootPart"); local hd=ch:FindFirstChild("Head")
    if not hum or not hrp or not hd or hum.Health<=0 then hideE(c); return end
    if distTo(ch)>C.RenderDistance then hideE(c); return end
    local rp,vis=Camera:WorldToViewportPoint(hrp.Position); if not vis then hideE(c); return end
    local hp=Camera:WorldToViewportPoint(hd.Position+Vector3.new(0,1.5,0))
    local fp=Camera:WorldToViewportPoint(hrp.Position-Vector3.new(0,3,0))
    local bH=math.abs(hp.Y-fp.Y); local bW=bH*0.55
    local tl,tr=Vector2.new(rp.X-bW/2,hp.Y),Vector2.new(rp.X+bW/2,hp.Y)
    local bl,br=Vector2.new(rp.X-bW/2,fp.Y),Vector2.new(rp.X+bW/2,fp.Y)
    local clr=isTeammate(p) and Color3.fromRGB(80,150,255) or Color3.fromRGB(255,40,40)
    pcall(function()
        local sb=C.BoxesEnabled
        c.box[1].From=tl;c.box[1].To=tr;c.box[1].Visible=sb;c.box[1].Color=clr
        c.box[2].From=tr;c.box[2].To=br;c.box[2].Visible=sb;c.box[2].Color=clr
        c.box[3].From=br;c.box[3].To=bl;c.box[3].Visible=sb;c.box[3].Color=clr
        c.box[4].From=bl;c.box[4].To=tl;c.box[4].Visible=sb;c.box[4].Color=clr
        c.tracer.Visible=C.TracersEnabled; c.tracer.Color=clr
        if C.TracersEnabled then
            local vp=Camera.ViewportSize; local o
            if C.TracerOrigin=="Top" then o=Vector2.new(vp.X/2,0)
            elseif C.TracerOrigin=="Center" then o=Vector2.new(vp.X/2,vp.Y/2)
            else o=Vector2.new(vp.X/2,vp.Y) end
            c.tracer.From=o; c.tracer.To=Vector2.new(rp.X,fp.Y)
        end
        c.name.Visible=C.NamesEnabled; c.name.Color=clr
        if C.NamesEnabled then c.name.Position=Vector2.new(rp.X,hp.Y-16); c.name.Text=p.DisplayName or p.Name end
        c.hpBg.Visible=C.HealthBarEnabled; c.hpFl.Visible=C.HealthBarEnabled
        if C.HealthBarEnabled then
            local bx=tl.X-5; c.hpBg.From=Vector2.new(bx,fp.Y); c.hpBg.To=Vector2.new(bx,hp.Y)
            local r=math.clamp(hum.Health/hum.MaxHealth,0,1)
            c.hpFl.From=Vector2.new(bx,fp.Y); c.hpFl.To=Vector2.new(bx,fp.Y+(hp.Y-fp.Y)*r)
            c.hpFl.Color=Color3.new(math.clamp(2*(1-r),0,1),math.clamp(2*r,0,1),0)
        end
    end)
end

--------------------------------------------------------------------
-- FOV CIRCLES
--------------------------------------------------------------------
local FovC,SaC,AaC
pcall(function()
    FovC=Drawing.new("Circle");FovC.Visible=true;FovC.Thickness=1.4;FovC.Color=Color3.fromRGB(255,50,120)
    FovC.Transparency=0.5;FovC.Filled=false;FovC.NumSides=64;FovC.Radius=C.MaxFOV
    SaC=Drawing.new("Circle");SaC.Visible=false;SaC.Thickness=1.2;SaC.Color=Color3.fromRGB(255,0,255)
    SaC.Transparency=0.6;SaC.Filled=false;SaC.NumSides=48
    AaC=Drawing.new("Circle");AaC.Visible=false;AaC.Thickness=1;AaC.Color=Color3.fromRGB(100,255,100)
    AaC.Transparency=0.7;AaC.Filled=false;AaC.NumSides=48
end)

--------------------------------------------------------------------
-- CUSTOM CURSOR + TRAIL
--------------------------------------------------------------------
local cursorDot, cursorTrail = nil, {}
pcall(function()
    cursorDot = Drawing.new("Circle")
    cursorDot.Visible = false; cursorDot.Radius = 4; cursorDot.Filled = true
    cursorDot.Color = Color3.fromRGB(255, 80, 180); cursorDot.NumSides = 16
    cursorDot.Transparency = 0

    for i = 1, 8 do
        local t = Drawing.new("Circle")
        t.Visible = false; t.Radius = 3 - (i * 0.3); t.Filled = true
        t.Color = Color3.fromRGB(255, 255, 255); t.NumSides = 12
        t.Transparency = i * 0.1
        cursorTrail[i] = {circle = t, pos = Vector2.new(0,0)}
    end
end)

--------------------------------------------------------------------
-- FPS COUNTER WIDGET
--------------------------------------------------------------------
local fpsGui = Instance.new("ScreenGui"); fpsGui.Name = "DoraFPS"; fpsGui.ResetOnSpawn = false
pcall(function() fpsGui.Parent = game:GetService("CoreGui") end)
if not fpsGui.Parent then fpsGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local fpsFrame = Instance.new("Frame"); fpsFrame.Size = UDim2.new(0,90,0,30)
fpsFrame.Position = UDim2.new(0,10,0,10); fpsFrame.BackgroundColor3 = Color3.fromRGB(14,14,20)
fpsFrame.BorderSizePixel = 0; fpsFrame.Active = true; fpsFrame.Parent = fpsGui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0,8)
local fpStr = Instance.new("UIStroke"); fpStr.Color = Color3.fromRGB(255,50,120); fpStr.Thickness = 1; fpStr.Parent = fpsFrame

local fpsLabel = Instance.new("TextLabel"); fpsLabel.Size = UDim2.new(1,0,1,0)
fpsLabel.BackgroundTransparency = 1; fpsLabel.Text = "0 FPS"
fpsLabel.TextColor3 = Color3.fromRGB(255,100,180); fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 14; fpsLabel.Parent = fpsFrame

-- FPS drag
do local dg,ds,sp=false,nil,nil
    fpsFrame.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dg=true;ds=i.Position;sp=fpsFrame.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dg=false end end)
    end end)
    UserInputService.InputChanged:Connect(function(i)
        if dg and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds; fpsFrame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- FPS tracking
local fpsCounter, fpsTime = 0, tick()
local currentFPS = 0

--------------------------------------------------------------------
-- PLAYER HOOKS
--------------------------------------------------------------------
local function hookP(p) if p==LocalPlayer then return end; mkESP(p)
    p.CharacterAdded:Connect(function() task.wait(0.8); chamsCache[p]=nil; ensureChams(p) end)
    if p.Character then task.spawn(function() ensureChams(p) end) end
end
for _,p in ipairs(playerCache) do hookP(p) end
Players.PlayerAdded:Connect(function(p) refreshPlayerCache(); hookP(p) end)
Players.PlayerRemoving:Connect(function(p) task.defer(refreshPlayerCache); removeChamsFor(p); rmESP(p) end)

function removeChamsFor(p)
    if chamsCache[p] then pcall(function() chamsCache[p]:Destroy() end); chamsCache[p]=nil end
    if chamsConns[p] then for _,c in ipairs(chamsConns[p]) do pcall(function() c:Disconnect() end) end; chamsConns[p]=nil end
    if p.Character then for _,o in ipairs(p.Character:GetChildren()) do
        if o:IsA("Highlight") and o.Name=="DoraChams" then pcall(function() o:Destroy() end) end
    end end
end

--------------------------------------------------------------------
-- TARGET (computed once per frame)
--------------------------------------------------------------------
local silentAimTarget = nil

local function acqTarget(fov,part,wc)
    local best,bd=nil,fov
    local cx,cy=Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2
    local ctr=Vector2.new(cx,cy)
    for _,p in ipairs(playerCache) do
        if isEnemy(p) then local ch=p.Character
            if ch and isAlive(ch) and distTo(ch)<=C.RenderDistance then
                local pt=ch:FindFirstChild(part or "Head") or ch:FindFirstChild("Head")
                if pt then local sp,vis=Camera:WorldToViewportPoint(pt.Position)
                    if vis then local d=(Vector2.new(sp.X,sp.Y)-ctr).Magnitude
                        if d<bd then if not wc or isVisible(pt) then bd=d;best=pt end end
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
pcall(function()
    local oldIdx; oldIdx = hookmetamethod(game, "__index", function(self, key)
        if C.SpoofDevice~="None" then
            if self==UserInputService then
                if C.SpoofDevice=="Phone" or C.SpoofDevice=="Tablet" then
                    if key=="TouchEnabled" then return true end
                    if key=="KeyboardEnabled" then return false end
                    if key=="MouseEnabled" then return false end
                    if key=="GamepadEnabled" then return false end
                end
                if C.SpoofDevice=="Console" then
                    if key=="TouchEnabled" then return false end
                    if key=="KeyboardEnabled" then return false end
                    if key=="MouseEnabled" then return false end
                    if key=="GamepadEnabled" then return true end
                end
            end
        end
        if C.SilentAimEnabled and silentAimTarget and self==Mouse and math.random(1,100)<=C.SilentAimChance then
            if key=="Hit" then return CFrame.new(silentAimTarget.Position) end
            if key=="Target" then return silentAimTarget end
            if key=="UnitRay" then return Ray.new(Camera.CFrame.Position,(silentAimTarget.Position-Camera.CFrame.Position).Unit) end
        end
        return oldIdx(self, key)
    end)
end)

pcall(function()
    local old=UserInputService.GetPlatform
    hookfunction(UserInputService.GetPlatform, function(s)
        if C.SpoofDevice=="Phone" or C.SpoofDevice=="Tablet" then return Enum.Platform.IOS end
        if C.SpoofDevice=="Console" then return Enum.Platform.XBoxOne end
        return old(s)
    end)
end)

pcall(function()
    local old=UserInputService.GetLastInputType
    hookfunction(UserInputService.GetLastInputType, function(s)
        if C.SpoofDevice=="Phone" or C.SpoofDevice=="Tablet" then return Enum.UserInputType.Touch end
        if C.SpoofDevice=="Console" then return Enum.UserInputType.Gamepad1 end
        return old(s)
    end)
end)

--------------------------------------------------------------------
-- SILENT AIM (__namecall)
--------------------------------------------------------------------
pcall(function()
    local old; old=hookmetamethod(game,"__namecall",function(self,...)
        local m=getnamecallmethod()
        if C.SilentAimEnabled and silentAimTarget and math.random(1,100)<=C.SilentAimChance then
            local o=Camera.CFrame.Position
            if m=="Raycast" then
                local a={...}; if typeof(a[1])=="Vector3" and (a[1]-o).Magnitude<20 then
                    return old(self,a[1],(silentAimTarget.Position-a[1]).Unit*5000,select(3,...))
                end
            elseif m=="FindPartOnRay" or m=="FindPartOnRayWithIgnoreList" or m=="FindPartOnRayWithWhitelist" then
                local a={...}; if typeof(a[1])=="Ray" and (a[1].Origin-o).Magnitude<20 then
                    return old(self,Ray.new(a[1].Origin,(silentAimTarget.Position-a[1].Origin).Unit*5000),select(2,...))
                end
            elseif m=="FireServer" or m=="InvokeServer" then
                local a={...}; local mp=Mouse.Hit and Mouse.Hit.Position; local chg=false
                if mp then for i,v in ipairs(a) do
                    if typeof(v)=="Vector3" and (v-mp).Magnitude<15 then a[i]=silentAimTarget.Position; chg=true
                    elseif typeof(v)=="CFrame" and (v.Position-mp).Magnitude<15 then a[i]=CFrame.new(silentAimTarget.Position); chg=true end
                end end
                if chg then return old(self,unpack(a)) end
            end
        end
        return old(self,...)
    end)
end)

--------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(i,proc)
    if proc then return end
    if i.KeyCode==Enum.KeyCode.Insert then C.MenuOpen=not C.MenuOpen; Fr.Visible=C.MenuOpen; return end
    if C.ThirdPersonKey and KM[C.ThirdPersonKey] then
        local m=KMouse[C.ThirdPersonKey] and (i.UserInputType==KM[C.ThirdPersonKey]) or (i.KeyCode==KM[C.ThirdPersonKey])
        if m then C.ThirdPersonEnabled=not C.ThirdPersonEnabled end
    end
    if C.HeadLockEnabled and KM[C.HeadLockKeyName] then
        local m=KMouse[C.HeadLockKeyName] and (i.UserInputType==KM[C.HeadLockKeyName]) or (i.KeyCode==KM[C.HeadLockKeyName])
        if m then local t=acqTarget(C.MaxFOV,"Head",C.WallCheck); if t then Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.Position) end end
    end
end)

--------------------------------------------------------------------
-- MAIN LOOP (split work across frames)
--------------------------------------------------------------------
local hue=0; local tick1,tick2=0,0
local CHAMS_RATE=25; local SPEED_RATE=5
local lastTrig=0

RunService.RenderStepped:Connect(function(dt)
    -- FPS
    fpsCounter=fpsCounter+1
    if tick()-fpsTime>=1 then currentFPS=fpsCounter; fpsCounter=0; fpsTime=tick() end
    fpsFrame.Visible=C.ShowFPS; fpsLabel.Text=currentFPS.." FPS"

    hue=(hue+dt*0.5)%1; local rc=Color3.fromHSV(hue,1,1)
    local vp=Camera.ViewportSize; local sc=Vector2.new(vp.X/2,vp.Y/2)

    -- FOV (cheap)
    if FovC then FovC.Position=sc;FovC.Radius=C.MaxFOV;FovC.Visible=C.AimbotEnabled and C.FOVEnabled
        FovC.Color=C.RainbowFOV and rc or Color3.fromRGB(255,50,120) end
    if SaC then SaC.Position=sc;SaC.Radius=C.SilentAimFOV;SaC.Visible=C.SilentAimEnabled and C.FOVEnabled end
    if AaC then AaC.Position=sc;AaC.Radius=C.AimAssistFOV;AaC.Visible=C.AimAssistEnabled and C.FOVEnabled end

    -- Custom cursor
    if cursorDot then
        local show = C.MenuOpen and Fr.Visible
        local mp = UserInputService:GetMouseLocation()
        cursorDot.Visible = show; cursorDot.Position = mp
        for i, t in ipairs(cursorTrail) do
            t.circle.Visible = show
            t.pos = t.pos:Lerp(mp, 0.3 - i*0.02)
            t.circle.Position = t.pos
        end
    end

    -- ESP (every frame, needed for Drawing API)
    for p,c in pairs(DC) do updESP(p,c) end

    -- Chams (throttled)
    tick1=tick1+1
    if tick1>=CHAMS_RATE then tick1=0
        if C.VisualsEnabled and C.ChamsEnabled then
            for _,p in ipairs(playerCache) do ensureChams(p)
                if C.RainbowChams and isEnemy(p) then
                    local hl=chamsCache[p]; if hl and hl.Parent then hl.FillColor=rc;hl.OutlineColor=rc end
                end
            end
        end
    end

    -- 3P force
    if C.ThirdPersonEnabled then pcall(function()
        if LocalPlayer.CameraMaxZoomDistance<C.ThirdPersonDist then LocalPlayer.CameraMaxZoomDistance=C.ThirdPersonDist end
        if LocalPlayer.CameraMinZoomDistance<C.ThirdPersonDist*0.8 then LocalPlayer.CameraMinZoomDistance=C.ThirdPersonDist*0.8 end
        if LocalPlayer.CameraMode~=Enum.CameraMode.Classic then LocalPlayer.CameraMode=Enum.CameraMode.Classic end
    end) end

    -- Speed (throttled)
    tick2=tick2+1
    if tick2>=SPEED_RATE then tick2=0
        if C.SpeedEnabled then pcall(function()
            local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed=C.SpeedValue end
        end) end
    end

    -- Silent aim target (once per frame)
    silentAimTarget = C.SilentAimEnabled and acqTarget(C.SilentAimFOV,C.AimPart,false) or nil

    -- Aimbot
    if C.AimbotEnabled and (C.AlwaysOnAimbot or keyDown(C.AimbotKeyName)) then
        local t=acqTarget(C.MaxFOV,C.AimPart,C.WallCheck)
        if t then Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,t.Position),1/math.clamp(C.Smoothness,1,20)) end
    end

    -- Aim Assist
    if C.AimAssistEnabled and not (C.AimbotEnabled and (C.AlwaysOnAimbot or keyDown(C.AimbotKeyName))) then
        local t=acqTarget(C.AimAssistFOV,C.AimPart,C.WallCheck)
        if t then Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,t.Position),1/math.clamp(C.AimAssistSmooth,1,30)) end
    end

    -- Triggerbot
    if C.TriggerbotEnabled then local now=tick(); if now-lastTrig>=0.08 then
        local tg=Mouse.Target; if tg then local md=tg:FindFirstAncestorOfClass("Model")
            if md then local pp=Players:GetPlayerFromCharacter(md)
                if pp and isEnemy(pp) then local hm=md:FindFirstChildOfClass("Humanoid")
                    if hm and hm.Health>0 then lastTrig=now; pcall(mouse1click) end
                end
            end
        end
    end end

    -- Bhop
    if C.BhopEnabled then local ch=LocalPlayer.Character; if ch then local h=ch:FindFirstChildOfClass("Humanoid")
        if h and h.Health>0 then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
            or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
                if h.FloorMaterial~=Enum.Material.Air then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end
    end end
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
local nst=Instance.new("UIStroke"); nst.Color=Color3.fromRGB(255,50,180); nst.Thickness=2; nst.Parent=NF
Instance.new("TextLabel",NF).Size=UDim2.new(1,0,0.55,0); NF:FindFirstChildOfClass("TextLabel").Position=UDim2.new(0,0,0,4)
NF:FindFirstChildOfClass("TextLabel").BackgroundTransparency=1; NF:FindFirstChildOfClass("TextLabel").Text="✨ Success!"
NF:FindFirstChildOfClass("TextLabel").TextColor3=Color3.fromRGB(255,100,200)
NF:FindFirstChildOfClass("TextLabel").Font=Enum.Font.GothamBold; NF:FindFirstChildOfClass("TextLabel").TextSize=18
local NS=Instance.new("TextLabel",NF); NS.Size=UDim2.new(1,0,0.4,0); NS.Position=UDim2.new(0,0,0.55,0)
NS.BackgroundTransparency=1; NS.Text="Made by Dora 🌸"; NS.TextColor3=Color3.fromRGB(200,130,200)
NS.Font=Enum.Font.Gotham; NS.TextSize=13
task.spawn(function() task.wait(0.3)
    NF:TweenPosition(UDim2.new(1,-20,1,-80),Enum.EasingDirection.Out,Enum.EasingStyle.Quint,0.6,true)
    task.spawn(function() local t=0; for _=1,80 do t=t+0.05
        nst.Color=Color3.fromRGB(255,math.floor(50+130*(0.5+0.5*math.sin(t*4))),math.floor(180+75*(0.5+0.5*math.sin(t*4))))
        task.wait(0.03) end end)
    task.wait(4)
    NF:TweenPosition(UDim2.new(1,280,1,-80),Enum.EasingDirection.In,Enum.EasingStyle.Quint,0.5,true)
    task.wait(0.6); NG:Destroy()
end)

--------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------
local function cleanup()
    pcall(function() if FovC then FovC:Remove() end end)
    pcall(function() if SaC then SaC:Remove() end end)
    pcall(function() if AaC then AaC:Remove() end end)
    pcall(function() if cursorDot then cursorDot:Remove() end end)
    pcall(function() for _,t in ipairs(cursorTrail) do t.circle:Remove() end end)
    for p in pairs(DC) do rmESP(p) end
    destroyAllChams()
    pcall(function() SG:Destroy() end)
    pcall(function() NG:Destroy() end)
    pcall(function() fpsGui:Destroy() end)
    pcall(function() popSound:Destroy() end)
    pcall(function() LocalPlayer.CameraMaxZoomDistance=0.5;LocalPlayer.CameraMinZoomDistance=0.5
        local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=16 end end)
end

if getgenv then getgenv().DoraCleanup=cleanup end
print("[DORA] v6 loaded — press INSERT")
