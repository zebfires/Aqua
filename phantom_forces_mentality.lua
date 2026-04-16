--// Services
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService    = game:GetService("GuiService")
local Lighting      = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService   = game:GetService("HttpService")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

--// Octohook Library Loading
-- Using the local source as requested. 
-- We'll try to load it from the provided path, otherwise we'll use the raw content if we were a normal script.
-- For this implementation, I'll use the logic to load the library provided in Octohook/Library.lua.
local Library, EspUI, MiscOptions, Options
local success, res1, res2, res3, res4 = pcall(function()
    return loadstring(readfile("Octohook/Library.lua"))()
end)

if success and type(res1) == "table" then
    Library, EspUI, MiscOptions, Options = res1, res2, res3, res4
else
    -- Fallback to the web version if local file isn't found
    Library, EspUI, MiscOptions, Options = loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Octohook/Library.lua"))()
end

--// PF Internal Access
local HUD, CharModule, GameState, NetworkClient, StateManager, ReplicationInterface, FirearmObject, MainCameraObject, WeaponController, PublicSettings
local NetworkEvents = {}
pcall(function()
    local require = getrenv().shared.require
    NetworkClient = require("NetworkClient")
    ReplicationInterface = require("ReplicationInterface")
    FirearmObject = require("FirearmObject")
    MainCameraObject = require("MainCameraObject")
    WeaponController = require("WeaponController")
    PublicSettings = require("PublicSettings")
    
    -- Stealth Bypass: Extract events table from internal upvalues to avoid MetaTable detection
    local success, container = pcall(debug.getupvalue, NetworkClient.fireReady, 5)
    if success and type(container) == "table" then 
        NetworkEvents = container 
    end
end)

--// Internal State Helper
local function getFlag(name)
    local val = Library.Flags[name]
    if type(val) == "table" then
        if val.Color then return val.Color end -- Colorpicker
        if val.Active ~= nil then return val.Active end -- Keybind
        if #val > 0 then return val[1] end -- Dropdown (if multi, return first for simplicity or handle as table elsewhere)
    end
    return val
end

--// Visuals
local fovCircle = Drawing.new("Circle")
fovCircle.Radius       = 150
fovCircle.Color        = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness    = 2
fovCircle.Transparency = 0.8
fovCircle.Filled       = false
fovCircle.NumSides     = 100
fovCircle.Visible      = false

local targetLine = Drawing.new("Line")
targetLine.Thickness = 1
targetLine.Transparency = 1
targetLine.Color = Color3.new(1, 1, 1)
targetLine.Visible = false

--// Window Setup
local Holder = Library:Window({Name = "Octohook - PF Mentality"})
local Camera = workspace.CurrentCamera
local dim_offset = UDim2.fromOffset
local dim2 = UDim2.new

local Window = Holder:Panel({
    Name = "Phantom Forces", 
    ButtonName = "Menu", 
    Size = dim_offset(550, 709), 
    Position = dim2(0, (Camera.ViewportSize.X / 2) - 550/2, 0, (Camera.ViewportSize.Y / 2) - 709/2),
})

-- Update Title Loop (from Example)
task.spawn(function()
    while task.wait(1) do
        if not Holder.Items.Holder.Visible then continue end 
        Holder.ChangeMenuTitle(string.format("%s - PF Mentality - %s", Holder.Name, os.date("%b. %d %Y, %X")))
    end 
end)
Holder.ChangeMenuTitle(string.format("%s - PF Mentality - %s", Holder.Name, os.date("%b. %d %Y, %X")))

local Tabs = {
    Combat = Window:Tab({Name = "Combat"}),
    Visuals = Window:Tab({Name = "Visuals"}),
    World = Window:Tab({Name = "World"}),
    Misc = Window:Tab({Name = "Miscellaneous"}),
    Settings = Window:Tab({Name = "Settings"}),
}

--// Combat Tab
local CombatCol1 = Tabs.Combat:Column({})
local CombatCol2 = Tabs.Combat:Column({})

local AimbotSection = CombatCol1:Section({Name = "Aimbot Controls"})
AimbotSection:Toggle({Name = "Aimbot Enabled", Flag = "PF_Aimbot_Enabled", Default = true})
:Keybind({Name = "Aimbot Key", Flag = "PF_Aimbot_Key", Key = Enum.KeyCode.E, Mode = "Hold"})

AimbotSection:Toggle({Name = "Use FOV", Flag = "PF_Aimbot_UseFOV", Default = true})
AimbotSection:Toggle({Name = "Silent Aim", Flag = "PF_SilentAim_Enabled", Default = false})
AimbotSection:Toggle({Name = "Auto Shoot", Flag = "PF_Aimbot_AutoShoot", Default = false})
AimbotSection:Toggle({Name = "Visibility Check", Flag = "PF_Aimbot_VisCheck", Default = false})
AimbotSection:Toggle({Name = "Aimbot Prediction", Flag = "PF_Aimbot_Prediction", Default = true})
AimbotSection:Toggle({Name = "Drop Correction", Flag = "PF_Aimbot_DropCorrection", Default = true})
AimbotSection:Toggle({Name = "Humanize Path", Flag = "PF_Aimbot_Humanize", Default = true})

local CombatSettings = CombatCol1:Section({Name = "Aim Settings"})
CombatSettings:Slider({Name = "Smoothing", Flag = "PF_Aimbot_Smoothing", Min = 1, Max = 50, Default = 5, Decimal = 1})
CombatSettings:Slider({Name = "Prediction Scale", Flag = "PF_Aimbot_PredictionScale", Min = 0, Max = 2, Default = 1, Decimal = 0.01})
CombatSettings:Slider({Name = "Sensitivity X", Flag = "PF_Aimbot_GainX", Min = 0.1, Max = 5, Default = 1, Decimal = 0.01})
CombatSettings:Slider({Name = "Sensitivity Y", Flag = "PF_Aimbot_GainY", Min = 0.1, Max = 5, Default = 1, Decimal = 0.01})
CombatSettings:Slider({Name = "Jitter / Shake", Flag = "PF_Aimbot_Jitter", Min = 0, Max = 50, Default = 0, Decimal = 0.1})
CombatSettings:Slider({Name = "FOV Radius", Flag = "PF_Aimbot_FOVRadius", Min = 10, Max = 800, Default = 150, Decimal = 1})
CombatSettings:Toggle({Name = "Dynamic FOV", Flag = "PF_Aimbot_DynamicFOV", Default = true})
CombatSettings:Slider({Name = "Max Aim Distance", Flag = "PF_Aimbot_MaxDist", Min = 50, Max = 5000, Default = 1000, Decimal = 1})

local TargetSection = CombatCol2:Section({Name = "Target Sorting"})
TargetSection:Dropdown({
    Name = "Target Bone",
    Flag = "PF_Aimbot_Part",
    Options = {"Head", "Torso", "Closest to Crosshair"},
    Default = "Head"
})
TargetSection:Dropdown({
    Name = "Priority Mode",
    Flag = "PF_Aimbot_Priority",
    Options = {"FOV", "Distance"},
    Default = "FOV"
})
TargetSection:Toggle({Name = "Show FOV Circle", Flag = "PF_FOV_Visible", Default = false})
:Colorpicker({Flag = "PF_FOV_Color", Color = Color3.fromRGB(255, 255, 255)})

TargetSection:Toggle({Name = "Show Target Line", Flag = "PF_Aimbot_TargetLine", Default = false})

local GunMods = CombatCol2:Section({Name = "Gun Enhancements"})
GunMods:Toggle({Name = "No Gun Sway", Flag = "PF_NoSway", Default = false})
GunMods:Toggle({Name = "No Camera Sway", Flag = "PF_NoCamSway", Default = false})
GunMods:Toggle({Name = "Accuracy Booster", Flag = "PF_AccuracyBoost", Default = false})
GunMods:Toggle({Name = "No Spread", Flag = "PF_NoSpread", Default = false})
GunMods:Slider({Name = "Recoil Scale", Flag = "PF_RecoilScale", Min = 0, Max = 100, Default = 100, Suffix = "%"})

--// Visuals Tab
local VisualsCol1 = Tabs.Visuals:Column({})
local VisualsCol2 = Tabs.Visuals:Column({})

-- ESP Preview (from Example)
local EspPreviewSection = VisualsCol1:Section({Name = "ESP Configuration"})
local EspPreview = EspPreviewSection:EspPreview({
    Tooltip = {
        Title = "ESP Preview",
        Text = "Real-time preview of your ESP settings on a dummy model.",
        Width = 200
    }
})
local dummy = EspPreview:AddTab({
    Name = "Preview Player", 
    Model = "rbxassetid://14966982841",
    Chams = true
})
dummy.AddBar({Name = "Healthbar", Prefix = "Healthbar"})
dummy.AddText({Name = "Name", Prefix = "Name"})
dummy.AddText({Name = "Distance", Prefix = "Distance"})
dummy.AddBox({Name = "Box"})

local PlayersESP = VisualsCol1:Section({Name = "Player Highlights"})
PlayersESP:Toggle({Name = "Master ESP", Flag = "PF_ESP_Master", Default = true})
PlayersESP:Toggle({Name = "3D Highlights", Flag = "PF_ESP_Highlights", Default = true})
:Colorpicker({Name = "Fill", Flag = "PF_ESP_FillColor", Color = Color3.fromRGB(160, 50, 255)})
:Colorpicker({Name = "Outline", Flag = "PF_ESP_OutlineColor", Color = Color3.fromRGB(80, 20, 180)})

PlayersESP:Slider({Name = "Fill Opacity", Flag = "PF_ESP_FillTransparency", Min = 0, Max = 1, Default = 0.5, Decimal = 0.01})
PlayersESP:Slider({Name = "Outline Opacity", Flag = "PF_ESP_OutlineTransparency", Min = 0, Max = 1, Default = 0.3, Decimal = 0.01})
PlayersESP:Toggle({Name = "Show Teammates", Flag = "PF_ESP_Teammates", Default = false})

local DrawingESP = VisualsCol2:Section({Name = "Drawing Visuals"})
DrawingESP:Toggle({Name = "2D Box ESP", Flag = "PF_ESP_Box", Default = false})
:Colorpicker({Flag = "PF_ESP_DrawingColor", Color = Color3.fromRGB(255, 0, 0)})

DrawingESP:Toggle({Name = "Box Outline", Flag = "PF_ESP_BoxOutline", Default = true})
:Colorpicker({Flag = "PF_ESP_BoxOutlineColor", Color = Color3.fromRGB(0, 0, 0)})

DrawingESP:Toggle({Name = "Healthbar", Flag = "PF_ESP_Healthbar", Default = false})
DrawingESP:Toggle({Name = "Nametags", Flag = "PF_ESP_Nametags", Default = false})

local WeaponESP = VisualsCol2:Section({Name = "Weapon ESP"})
WeaponESP:Toggle({Name = "Show Held Weapon", Flag = "PF_ESP_Weapon", Default = false})
:Colorpicker({Flag = "PF_ESP_WeaponColor", Color = Color3.fromRGB(255, 255, 255)})

--// World Tab
local WorldCol1 = Tabs.World:Column({})
local WorldCol2 = Tabs.World:Column({})

local WorldLighting = WorldCol1:Section({Name = "Atmosphere"})
WorldLighting:Toggle({Name = "Custom Lighting", Flag = "PF_World_Lighting", Default = false})
WorldLighting:Toggle({Name = "Full Bright", Flag = "PF_World_Fullbright", Default = false})
WorldLighting:Slider({Name = "Brightness", Flag = "PF_World_Brightness", Min = 0, Max = 10, Default = 1, Decimal = 0.1})
WorldLighting:Toggle({Name = "Global Shadows", Flag = "PF_World_Shadows", Default = true})
WorldLighting:Label("Ambient Tint"):Colorpicker({Flag = "PF_World_Ambient", Color = Color3.fromRGB(127, 127, 127)})

local WorldFog = WorldCol2:Section({Name = "Fog & Time"})
WorldFog:Toggle({Name = "Custom Time", Flag = "PF_World_TimeEnabled", Default = false})
WorldFog:Slider({Name = "Hour", Flag = "PF_World_Time", Min = 0, Max = 24, Default = 12, Decimal = 0.1})
WorldFog:Toggle({Name = "Custom Fog", Flag = "PF_World_FogEnabled", Default = false})
WorldFog:Slider({Name = "Fog Distance", Flag = "PF_World_FogEnd", Min = 0, Max = 10000, Default = 1000})
WorldFog:Label("Fog Color"):Colorpicker({Flag = "PF_World_FogColor", Color = Color3.fromRGB(200, 200, 200)})

local WorldSky = WorldCol2:Section({Name = "Skybox & Presets"})
WorldSky:Dropdown({
    Name = "Active Skybox",
    Flag = "PF_World_Skybox",
    Options = {"Default", "Purple Nebula", "Night Sky", "Pink Aesthetic", "Dark Void"},
    Default = "Default"
})

--// Misc Tab
local MiscCol1 = Tabs.Misc:Column({})
local MiscCol2 = Tabs.Misc:Column({})

local ServerSection = MiscCol1:Section({Name = "Server Controls"})
ServerSection:Button({
    Name = "Rejoin",
    Callback = function()
        if #Players:GetPlayers() <= 1 then
            player:Kick("\nRejoining...")
            task.wait()
            TeleportService:Teleport(game.PlaceId, player)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
        end
    end
})
ServerSection:Button({
    Name = "Server Hop",
    Callback = function()
        local REQ = request or http_request or (syn and syn.request)
        if not REQ then return end
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
        local success, result = pcall(function() return REQ({Url = url, Method = "GET"}) end)
        if success and result.StatusCode == 200 then
            local data = HttpService:JSONDecode(result.Body)
            local servers = {}
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end
            end
            if #servers > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player) end
        end
    end
})
ServerSection:Button({
    Name = "Unload Script",
    Callback = function() Holder:Unload() end
})

local LoggingSection = MiscCol2:Section({Name = "Networking"})
LoggingSection:Toggle({Name = "Traffic Logger", Flag = "PF_Network_Logger", Default = false})

Library:Configs(Holder, Tabs.Settings)

--// Logic Implementation
local CurrentEnemies = {}
local HeadSize = Vector3.new(0.001, 0.001, 0.001)
local ActiveHighlights = {}
local Active2DESP = {}

local function create2DESP(char)
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    local outerOutline = Drawing.new("Square")
    outerOutline.Thickness = 1
    outerOutline.Filled = false
    outerOutline.Transparency = 1
    outerOutline.Visible = false
    outerOutline.Color = Color3.new(0,0,0)

    local innerOutline = Drawing.new("Square")
    innerOutline.Thickness = 1
    innerOutline.Filled = false
    innerOutline.Transparency = 1
    innerOutline.Visible = false
    innerOutline.Color = Color3.new(0,0,0)

    local healthOutline = Drawing.new("Square")
    healthOutline.Thickness = 1
    healthOutline.Filled = true
    healthOutline.Transparency = 1
    healthOutline.Visible = false
    healthOutline.Color = Color3.new(0, 0, 0)

    local healthBar = Drawing.new("Square")
    healthBar.Thickness = 1
    healthBar.Filled = true
    healthBar.Transparency = 1
    healthBar.Visible = false

    local healthText = Drawing.new("Text")
    healthText.Size = 13
    healthText.Center = true
    healthText.Outline = true
    healthText.Transparency = 1
    healthText.Visible = false
    healthText.Color = Color3.new(1, 1, 1)

    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    name.Transparency = 1
    name.Visible = false
    name.Color = Color3.new(1, 1, 1)

    local weaponText = Drawing.new("Text")
    weaponText.Size = 13
    weaponText.Center = true
    weaponText.Outline = true
    weaponText.Transparency = 1
    weaponText.Visible = false
    weaponText.Color = Color3.new(1, 1, 1)

    Active2DESP[char] = {
        Box = box,
        OuterOutline = outerOutline,
        InnerOutline = innerOutline,
        HealthOutline = healthOutline,
        HealthBar = healthBar,
        HealthText = healthText,
        NameTag = name,
        WeaponTag = weaponText
    }
    return Active2DESP[char]
end

local function remove2DESP(char)
    if Active2DESP[char] then
        Active2DESP[char].Box:Remove()
        Active2DESP[char].OuterOutline:Remove()
        Active2DESP[char].InnerOutline:Remove()
        Active2DESP[char].HealthOutline:Remove()
        Active2DESP[char].HealthBar:Remove()
        Active2DESP[char].HealthText:Remove()
        Active2DESP[char].NameTag:Remove()
        Active2DESP[char].WeaponTag:Remove()
        Active2DESP[char] = nil
    end
end

--// Executor Check
local moveMouse = mousemoverel or (Input and Input.RelativeMove)
if not moveMouse then
    warn("Executor missing mousemoverel/RelativeMove. Aimbot will only work in Silent Aim mode.")
end

--// Skybox Logic
local SkyboxData = {
    ["Default"] = {
        Bk = "", Dn = "", Ft = "", Lf = "", Rt = "", Up = ""
    },
    ["Purple Nebula"] = {
        Bk = "rbxassetid://16553683517", Dn = "rbxassetid://16553683517", Ft = "rbxassetid://16553683517", 
        Lf = "rbxassetid://16553683517", Rt = "rbxassetid://16553683517", Up = "rbxassetid://16553683517"
    },
    ["Night Sky"] = {
        Bk = "rbxassetid://120645737", Dn = "rbxassetid://120645217", Ft = "rbxassetid://120645533", 
        Lf = "rbxassetid://120644033", Rt = "rbxassetid://120644033", Up = "rbxassetid://120644033"
    },
    ["Pink Aesthetic"] = {
        Bk = "rbxassetid://271042516", Dn = "rbxassetid://271042516", Ft = "rbxassetid://271042516", 
        Lf = "rbxassetid://271042516", Rt = "rbxassetid://271042516", Up = "rbxassetid://271042516"
    },
    ["Dark Void"] = {
        Bk = "rbxassetid://161092287", Dn = "rbxassetid://161092287", Ft = "rbxassetid://161092287", 
        Lf = "rbxassetid://161092287", Rt = "rbxassetid://161092287", Up = "rbxassetid://161092287"
    }
}

local function ApplySkybox(name)
    local data = SkyboxData[name]
    if not data then return end
    
    local sky = Lighting:FindFirstChildOfClass("Sky")
    
    if name == "Default" then
        if sky then sky:Destroy() end
        -- Re-enable game atmosphere if it exists
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("Atmosphere") then obj.Parent = Lighting end 
        end
        return
    end

    if not sky then
        sky = Instance.new("Sky")
        sky.Name = "Nil_Sky"
        sky.Parent = Lighting
    end
    
    sky.SkyboxBk = data.Bk
    sky.SkyboxDn = data.Dn
    sky.SkyboxFt = data.Ft
    sky.SkyboxLf = data.Lf
    sky.SkyboxRt = data.Rt
    sky.SkyboxUp = data.Up
    sky.SunTextureId = "" 
    sky.MoonTextureId = ""
end

local function addHighlight(model)
    if not model or ActiveHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor           = getFlag("PF_ESP_FillColor") or Color3.fromRGB(255, 255, 255)
    hl.OutlineColor        = getFlag("PF_ESP_OutlineColor") or Color3.fromRGB(255, 0, 0)
    hl.FillTransparency    = getFlag("PF_ESP_FillTransparency") or 0.7
    hl.OutlineTransparency = getFlag("PF_ESP_OutlineTransparency") or 0.3
    hl.Adornee = model
    local CoreGui = game:GetService("CoreGui")
    hl.Parent = select(1, pcall(function() return CoreGui end)) and CoreGui or model
    ActiveHighlights[model] = hl
    model.Destroying:Connect(function()
        if ActiveHighlights[model] then
            ActiveHighlights[model]:Destroy()
            ActiveHighlights[model] = nil
        end
        remove2DESP(model)
    end)
end

local TargetMetrics = {}

local function UpdateEnemies()
    local espActive = getFlag("PF_ESP_Master") == true or getFlag("PF_SilentAim_Enabled") == true or getFlag("PF_Aimbot_Enabled") == true

    if not espActive then 
        CurrentEnemies = {}
        table.clear(TargetMetrics)
        for char, _ in pairs(Active2DESP) do remove2DESP(char) end 
        return 
    end

    CurrentEnemies = {}
    
    for _, espData in pairs(Active2DESP) do
        espData.Box.Visible = false
        espData.OuterOutline.Visible = false
        espData.InnerOutline.Visible = false
        espData.HealthOutline.Visible = false
        espData.HealthBar.Visible = false
        espData.HealthText.Visible = false
        espData.NameTag.Visible = false
        espData.WeaponTag.Visible = false
    end

    for model, hl in pairs(ActiveHighlights) do
        if not model or not model.Parent then
            if hl then hl:Destroy() end
            ActiveHighlights[model] = nil
        end
        -- Update colors live
        if hl then
            hl.FillColor           = getFlag("PF_ESP_FillColor") or Color3.fromRGB(255, 255, 255)
            hl.OutlineColor        = getFlag("PF_ESP_OutlineColor") or Color3.fromRGB(255, 0, 0)
            hl.FillTransparency    = getFlag("PF_ESP_FillTransparency") or 0.7
            hl.OutlineTransparency = getFlag("PF_ESP_OutlineTransparency") or 0.3
        end
    end

    local playersFolder = workspace:FindFirstChild("Players")
    if not playersFolder then return end

    for _, teamFolder in ipairs(playersFolder:GetChildren()) do
        for _, char in ipairs(teamFolder:GetChildren()) do
            if char.Name == player.Name then continue end
            
            local headPart, torsoPart
            local isEnemy = false

            local function getHealth(model)
                if not model then return nil end
                local targetPlayer = Players:GetPlayerFromCharacter(model) or Players:FindFirstChild(model.Name)
                if not targetPlayer and model:IsA("BasePart") then
                    targetPlayer = Players:GetPlayerFromCharacter(model.Parent) or Players:FindFirstChild(model.Parent.Name)
                end

                if ReplicationInterface and targetPlayer then
                    local entry = ReplicationInterface.getEntry(targetPlayer)
                    if entry and entry._healthstate then
                        local h = entry._healthstate.health0
                        if h then return h end
                    end
                end

                local descendants = char:GetDescendants()
                for _, obj in ipairs(descendants) do
                    local h = obj:GetAttribute("Health") or obj:GetAttribute("health") or obj:GetAttribute("hp") or obj:GetAttribute("HP")
                    if h then return tonumber(h) end
                    if obj:IsA("ValueBase") then
                        local n = obj.Name:lower()
                        if n:find("health") or n:find("hp") then return tonumber(obj.Value) end
                    end
                end

                if targetPlayer then
                    local h = targetPlayer:GetAttribute("Health") or targetPlayer:GetAttribute("health") or 
                              targetPlayer:GetAttribute("hp") or targetPlayer:GetAttribute("HP")
                    if h then return tonumber(h) end
                end

                return nil
            end

            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    local pName = string.lower(part.Name)
                    if pName:find("torso") or pName:find("root") or pName:find("chest") or pName:find("body") then
                        torsoPart = part
                    elseif part.Size == HeadSize or part.Name == "Head" then
                        local tag = part:FindFirstChild("PlayerTag", true)
                        if tag then
                            local success, color = pcall(function() return tag.TextColor3 end)
                            if success and (color.R > color.B or color == Color3.fromRGB(255, 10, 20)) then
                                headPart = part
                                isEnemy = true
                            elseif success then
                                headPart = part
                                isEnemy = false
                            end
                        end
                    end
                end
            end

            local rawHP = getHealth(char)
            local healthVal = rawHP or 100
            if healthVal <= 0 and healthVal ~= nil then 
                if ActiveHighlights[char] then ActiveHighlights[char].Adornee = nil end
                remove2DESP(char)
                continue 
            end

            if headPart then
                local safeTorso = torsoPart or {Parent = char, Position = headPart.Position - Vector3.new(0, 1.5, 0)}
                
                if isEnemy then
                    local root = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
                    local velocity = Vector3.new(0, 0, 0)
                    if root then
                        local last = TargetMetrics[char]
                        local currentPos = root.Position
                        local currentTime = tick()
                        if last then
                            local dt = currentTime - last.Time
                            if dt > 0 and dt < 0.1 then
                                local instVelocity = (currentPos - last.Pos) / dt
                                velocity = last.Velocity:Lerp(instVelocity, 0.25)
                            end
                        end
                        TargetMetrics[char] = {Pos = currentPos, Time = currentTime, Velocity = velocity}
                    end
                    CurrentEnemies[char] = {Head = headPart, Torso = safeTorso, Velocity = velocity}
                end

                if getFlag("PF_ESP_Master") then
                    local teamESP = getFlag("PF_ESP_Teammates") == true
                    if isEnemy or teamESP then
                        if getFlag("PF_ESP_Highlights") then
                            addHighlight(char)
                        elseif ActiveHighlights[char] then
                            ActiveHighlights[char]:Destroy()
                            ActiveHighlights[char] = nil
                        end
                        
                        local espData = Active2DESP[char] or create2DESP(char)
                        local boxEnabled = getFlag("PF_ESP_Box")
                        local healthEnabled = getFlag("PF_ESP_Healthbar")
                        local nametagEnabled = getFlag("PF_ESP_Nametags")
                        local boxVisible = false
                        
                        if boxEnabled or healthEnabled or nametagEnabled then
                            local cam = workspace.CurrentCamera
                            local hPos, hOn = cam:WorldToViewportPoint(headPart.Position)
                            local tPos, tOn = cam:WorldToViewportPoint(safeTorso.Position)
                            
                            if hOn or tOn then
                                local charHeight = (hPos - tPos).Magnitude * 2.5
                                local charWidth = charHeight * 0.5
                                local boxPos = Vector2.new(hPos.X - charWidth/2, hPos.Y - charHeight/4)
                                local boxSize = Vector2.new(charWidth, charHeight)
                                
                                if boxEnabled then
                                    espData.Box.Visible = true
                                    espData.Box.Position = boxPos
                                    espData.Box.Size = boxSize
                                    espData.Box.Color = getFlag("PF_ESP_DrawingColor") or Color3.new(1,0,0)

                                    if getFlag("PF_ESP_BoxOutline") then
                                        local outColor = getFlag("PF_ESP_BoxOutlineColor") or Color3.new(0,0,0)
                                        espData.OuterOutline.Visible = true
                                        espData.OuterOutline.Position = boxPos - Vector2.new(1, 1)
                                        espData.OuterOutline.Size = boxSize + Vector2.new(2, 2)
                                        espData.OuterOutline.Color = outColor
                                        espData.InnerOutline.Visible = true
                                        espData.InnerOutline.Position = boxPos + Vector2.new(1, 1)
                                        espData.InnerOutline.Size = boxSize - Vector2.new(2, 2)
                                        espData.InnerOutline.Color = outColor
                                    else
                                        espData.OuterOutline.Visible = false
                                        espData.InnerOutline.Visible = false
                                    end
                                    boxVisible = true
                                end 

                                if nametagEnabled then
                                    local nameText = char.Name
                                    local tag = headPart:FindFirstChild("PlayerTag", true)
                                    if tag and tag:IsA("TextLabel") then nameText = tag.Text end
                                    local dist = (cam.CFrame.Position - headPart.Position).Magnitude
                                    espData.NameTag.Visible = true
                                    espData.NameTag.Text = string.format("%s [%dm]", nameText, dist)
                                    espData.NameTag.Position = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y - 15)
                                    boxVisible = true
                                end

                                if healthEnabled then
                                    local currentHealth = rawHP or 100
                                    local maxHealth = 100
                                    local healthPerc = math.clamp(currentHealth / maxHealth, 0, 1)
                                    espData.HealthOutline.Visible = true
                                    espData.HealthOutline.Position = Vector2.new(boxPos.X - 6, boxPos.Y - 1)
                                    espData.HealthOutline.Size = Vector2.new(4, boxSize.Y + 2)
                                    espData.HealthBar.Visible = true
                                    espData.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + boxSize.Y - (boxSize.Y * healthPerc))
                                    espData.HealthBar.Size = Vector2.new(2, boxSize.Y * healthPerc)
                                    espData.HealthBar.Color = Color3.fromHSV(healthPerc * 0.3, 1, 1)
                                    boxVisible = true
                                end

                                if getFlag("PF_ESP_Weapon") then
                                    local heldWeapon = "None"
                                    for _, obj in ipairs(char:GetChildren()) do
                                        if obj:IsA("Model") and obj:FindFirstChild("Handle") then heldWeapon = obj.Name; break end
                                    end
                                    espData.WeaponTag.Visible = true
                                    espData.WeaponTag.Text = "[" .. heldWeapon .. "]"
                                    espData.WeaponTag.Position = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y + 5)
                                    espData.WeaponTag.Color = getFlag("PF_ESP_WeaponColor")
                                    boxVisible = true
                                end
                            end
                        end
                        if not boxVisible then remove2DESP(char) end
                    end
                end
            end
        end
    end
end

local function isVisible(targetPart, enemyModel)
    if not targetPart then return false end
    local cam = workspace.CurrentCamera
    local origin = cam.CFrame.Position
    local dir = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {player.Character, cam, workspace.Terrain}
    if workspace:FindFirstChild("Ignore") then table.insert(ignoreList, workspace.Ignore) end
    params.FilterDescendantsInstances = ignoreList
    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end
    if enemyModel and result.Instance:IsDescendantOf(enemyModel) then return true end
    return false
end

local function getClosestEnemy()
    local cam = workspace.CurrentCamera
    local mousePos = UserInputService:GetMouseLocation()
    local mx, my = mousePos.X, mousePos.Y
    local fovRadius = getFlag("PF_Aimbot_FOVRadius") or 150
    local closestPart, bestDist = nil, math.huge

    for char, parts in pairs(CurrentEnemies) do
        local targetPart = parts.Head
        local mode = getFlag("PF_Aimbot_Part")
        if mode == "Head" then targetPart = parts.Head
        elseif mode == "Torso" then targetPart = parts.Torso
        elseif mode == "Closest to Crosshair" then
            local headPos, h_on = cam:WorldToViewportPoint(parts.Head.Position)
            local torsoPos, t_on = cam:WorldToViewportPoint(parts.Torso.Position)
            local h_dist = (h_on and headPos.Z > 0) and (Vector2.new(headPos.X, headPos.Y) - Vector2.new(mx, my)).Magnitude or math.huge
            local t_dist = (t_on and torsoPos.Z > 0) and (Vector2.new(torsoPos.X, torsoPos.Y) - Vector2.new(mx, my)).Magnitude or math.huge
            targetPart = (h_dist < t_dist) and parts.Head or parts.Torso
        end
        local dist = (targetPart.Position - cam.CFrame.Position).Magnitude
        if dist > (getFlag("PF_Aimbot_MaxDist") or 1000) then continue end
        local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
        if not onScreen or screenPos.Z <= 0 then continue end
        local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mx, my)).Magnitude
        if getFlag("PF_Aimbot_UseFOV") and fovDist > fovRadius then continue end
        if getFlag("PF_Aimbot_VisCheck") and not isVisible(targetPart, char) then continue end
        local evalDist = (getFlag("PF_Aimbot_Priority") == "Distance") and dist or fovDist
        if evalDist < bestDist then bestDist = evalDist; closestPart = targetPart end
    end
    return closestPart, bestDist
end

local function GetPredictedPosition(targetPart, targetVelocity)
    local pos = targetPart.Position
    local predictionEnabled = getFlag("PF_Aimbot_Prediction")
    local dropEnabled = getFlag("PF_Aimbot_DropCorrection")
    local scale = getFlag("PF_Aimbot_PredictionScale") or 1
    if not predictionEnabled and not dropEnabled then return pos end

    local bulletSpeed, gravity = 2500, -196.2
    pcall(function()
        local req = getrenv().shared.require
        local controller = req("WeaponController").getController()
        if controller and controller._activeWeapon then bulletSpeed = controller._activeWeapon:getWeaponStat("bulletspeed") or 2500 end
        gravity = req("PublicSettings").bulletAcceleration.Y
    end)

    local cam = workspace.CurrentCamera
    local timeToHit = (pos - cam.CFrame.Position).Magnitude / bulletSpeed
    local predictedPos = pos + (targetVelocity * timeToHit * scale)
    if dropEnabled then predictedPos = predictedPos + Vector3.new(0, 0.5 * math.abs(gravity) * (timeToHit ^ 2), 0) end
    return predictedPos
end

local function TryAim()
    if getFlag("PF_Aimbot_Enabled") ~= true then return end
    local keyHeld = getFlag("PF_Aimbot_Key")
    if not keyHeld then return end
    local targetPart = getClosestEnemy()
    if not targetPart then targetLine.Visible = false; return end
    local targetPos = targetPart.Position
    local enemyData = CurrentEnemies[targetPart.Parent]
    if enemyData then targetPos = GetPredictedPosition(targetPart, enemyData.Velocity) end
    local cam = workspace.CurrentCamera
    local screenPos, onScreen = cam:WorldToViewportPoint(targetPos)
    if not onScreen then return end
    local mousePos = UserInputService:GetMouseLocation()
    local deltaX, deltaY = screenPos.X - mousePos.X, screenPos.Y - mousePos.Y
    local smoothing = getFlag("PF_Aimbot_Smoothing") or 5
    local moveX = (deltaX / smoothing) * (getFlag("PF_Aimbot_GainX") or 1)
    local moveY = (deltaY / smoothing) * (getFlag("PF_Aimbot_GainY") or 1)
    if (getFlag("PF_Aimbot_Jitter") or 0) > 0 then
        local j = getFlag("PF_Aimbot_Jitter")
        moveX, moveY = moveX + (math.noise(tick()*10)*j), moveY + (math.noise(0,tick()*10)*j)
    end
    if moveMouse then moveMouse(math.round(moveX), math.round(moveY)) end
    if getFlag("PF_Aimbot_TargetLine") then targetLine.From, targetLine.To, targetLine.Visible = Vector2.new(mousePos.X, mousePos.Y), Vector2.new(screenPos.X, screenPos.Y), true else targetLine.Visible = false end
end

--// Silent Aim & Networking
if NetworkClient then
    local oldSend = NetworkClient.send
    NetworkClient.send = function(self, event, ...)
        local args = {...}
        if getFlag("PF_Network_Logger") then print("[Network Out]", event, HttpService:JSONEncode(args)) end
        if getFlag("PF_SilentAim_Enabled") == true and (event == "newbullet" or event == "bullet") then
            local targetPart = getClosestEnemy()
            if targetPart and args[1].p and args[1].v then
                local targetPos = targetPart.Position
                local enemyData = CurrentEnemies[targetPart.Parent]
                if enemyData then targetPos = GetPredictedPosition(targetPart, enemyData.Velocity) end
                args[1].v = (targetPos - args[1].p).Unit * args[1].v.Magnitude
            end
        end
        return oldSend(self, event, unpack(args))
    end
end

--// Weapon Mods & Camera Bypass
pcall(function()
    if FirearmObject then
        local oldSway = FirearmObject.computeGunSway
        FirearmObject.computeGunSway = function(self, ...) return getFlag("PF_NoSway") and CFrame.new() or oldSway(self, ...) end
        local oldImpulse = FirearmObject.impulseSprings
        FirearmObject.impulseSprings = function(self, ...) 
            local scale = getFlag("PF_RecoilScale") / 100
            return scale < 1 and oldImpulse(self, scale, scale) or oldImpulse(self, ...) 
        end
    end
end)

--// Main Loop
RunService.Heartbeat:Connect(function()
    UpdateEnemies()
    if getFlag("PF_World_Fullbright") then
        Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows = 2, 14, 100000, false
    elseif getFlag("PF_World_Lighting") then
        Lighting.Brightness, Lighting.GlobalShadows, Lighting.Ambient = getFlag("PF_World_Brightness"), getFlag("PF_World_Shadows"), getFlag("PF_World_Ambient")
    end
    if getFlag("PF_World_TimeEnabled") then Lighting.ClockTime = getFlag("PF_World_Time") end
    if getFlag("PF_World_FogEnabled") then Lighting.FogEnd, Lighting.FogColor = getFlag("PF_World_FogEnd"), getFlag("PF_World_FogColor") end
    
    local activeSky = getFlag("PF_World_Skybox")
    if activeSky and activeSky ~= "Default" then ApplySkybox(activeSky) end

    local baseFOV = getFlag("PF_Aimbot_FOVRadius") or 150
    fovCircle.Radius = getFlag("PF_Aimbot_DynamicFOV") and (baseFOV * (70 / workspace.CurrentCamera.FieldOfView)) or baseFOV
    fovCircle.Visible, fovCircle.Color, fovCircle.Position = getFlag("PF_FOV_Visible"), getFlag("PF_FOV_Color"), UserInputService:GetMouseLocation()
    
    pcall(TryAim)
end)

Library:Notification({Name = "Phantom Forces Script Loaded", Lifetime = 3})

-- Trigger MiscOptions (from Example)
if MiscOptions then
    for index, value in pairs(MiscOptions) do 
        Options[index] = value 
    end
end

-- Menu Toggle Bind
local MenuOpen = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
        MenuOpen = not MenuOpen
        if Holder and Holder.SetVisible then
            Holder:SetVisible(MenuOpen)
        end
    end
end)
