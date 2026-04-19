--// Services
local Players                         = game:GetService("Players")
local RunService                      = game:GetService("RunService")
local UserInputService                = game:GetService("UserInputService")
local GuiService                      = game:GetService("GuiService")
local Lighting                        = game:GetService("Lighting")
local TeleportService                 = game:GetService("TeleportService")
local HttpService                     = game:GetService("HttpService")

local player                          = Players.LocalPlayer
local mouse                           = player:GetMouse()

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
    -- Fallback to the web version with error handling
    local web_url = "https://raw.githubusercontent.com/zebfires/Aqua/refs/heads/main/Library.lua"
    local success_web, web_src = pcall(game.HttpGet, game, web_url)

    if success_web and web_src then
        local func, err = loadstring(web_src)
        if func then
            Library, EspUI, MiscOptions, Options = func()
        else
            warn("Failed to compile library: " .. tostring(err))
        end
    end
end

if not Library then
    warn("Octohook/Aqua Library not found. Please ensure the file exists or you have an active internet connection.")
    return
end

--// PF Internal Access
local HUD, CharModule, GameState, NetworkClient, StateManager, ReplicationInterface, FirearmObject, MainCameraObject, WeaponController, PublicSettings, BulletObject
local NetworkEvents = {}
pcall(function()
    local require = getrenv().shared.require
    NetworkClient = require("NetworkClient")
    ReplicationInterface = require("ReplicationInterface")
    FirearmObject = require("FirearmObject")
    MainCameraObject = require("MainCameraObject")
    WeaponController = require("WeaponController")
    PublicSettings = require("PublicSettings")
    BulletObject = require("BulletObject")

    -- Stealth Bypass: Extract events table from internal upvalues to avoid MetaTable detection
    local success, container = pcall(debug.getupvalue(NetworkClient.fireReady, 5))
    if success and type(container) == "table" then
        NetworkEvents = container
    end
end)

--// Internal State Helper
local function getFlag(name)
    local val = Library.Flags[name]
    if type(val) == "table" then
        if val.Color then return val.Color end          -- Colorpicker
        if val.Active ~= nil then return val.Active end -- Keybind
        if #val > 0 then return val[1] end              -- Dropdown (if multi, return first for simplicity or handle as table elsewhere)
    end
    return val
end

local function getCharProperties(char)
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if head then
        local tag = head:FindFirstChild("PlayerTag", true)
        if tag then
            local success, color = pcall(function() return tag.TextColor3 end)
            if success and (color.R > color.B or color == Color3.fromRGB(255, 10, 20)) then
                return true -- Is Enemy
            end
        end
    end
    return false
end

--// Visuals
local fovCircle         = Drawing.new("Circle")
fovCircle.Radius        = 150
fovCircle.Color         = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness     = 2
fovCircle.Transparency  = 0.8
fovCircle.Filled        = false
fovCircle.NumSides      = 100
fovCircle.Visible       = false

local targetLine        = Drawing.new("Line")
targetLine.Thickness    = 1
targetLine.Transparency = 1
targetLine.Color        = Color3.new(1, 1, 1)
targetLine.Visible      = false

--// Window Setup
local Holder            = Library:Window({ Name = "Octohook - PF Mentality" })
local Camera            = workspace.CurrentCamera
local dim_offset        = UDim2.fromOffset
local dim2              = UDim2.new

local Window            = Holder:Panel({
    Name = "Phantom Forces",
    ButtonName = "Menu",
    Size = dim_offset(550, 709),
    Position = dim2(0, (Camera.ViewportSize.X / 2) - 550 / 2, 0, (Camera.ViewportSize.Y / 2) - 709 / 2),
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
    Combat = Window:Tab({ Name = "Combat" }),
    Visuals = Window:Tab({ Name = "Visuals" }),
    World = Window:Tab({ Name = "World" }),
    Misc = Window:Tab({ Name = "Miscellaneous" }),
    Settings = Window:Tab({ Name = "Settings" }),
}

--// Combat Tab
local CombatCol1 = Tabs.Combat:Column({})
local CombatCol2 = Tabs.Combat:Column({})

local AimbotSection = CombatCol1:Section({ Name = "Aimbot Controls" })
AimbotSection:Toggle({ Name = "Aimbot Enabled", Flag = "PF_Aimbot_Enabled", Default = true })
    :Keybind({ Name = "Aimbot Key", Flag = "PF_Aimbot_Key", Key = Enum.KeyCode.E, Mode = "Hold" })

AimbotSection:Toggle({ Name = "Use FOV", Flag = "PF_Aimbot_UseFOV", Default = true })
AimbotSection:Toggle({ Name = "Auto Shoot", Flag = "PF_Aimbot_AutoShoot", Default = false })
AimbotSection:Toggle({ Name = "Visibility Check", Flag = "PF_Aimbot_VisCheck", Default = false })
AimbotSection:Toggle({ Name = "Aimbot Prediction", Flag = "PF_Aimbot_Prediction", Default = true })
AimbotSection:Toggle({ Name = "Drop Correction", Flag = "PF_Aimbot_DropCorrection", Default = true })
AimbotSection:Toggle({ Name = "Humanize Path", Flag = "PF_Aimbot_Humanize", Default = true })

local CombatSettings = CombatCol1:Section({ Name = "Aim Settings" })
CombatSettings:Slider({ Name = "Smoothing", Flag = "PF_Aimbot_Smoothing", Min = 1, Max = 50, Default = 5, Decimal = 1 })
CombatSettings:Slider({ Name = "Prediction Scale", Flag = "PF_Aimbot_PredictionScale", Min = 0, Max = 2, Default = 1, Decimal = 0.01 })
CombatSettings:Slider({ Name = "Sensitivity X", Flag = "PF_Aimbot_GainX", Min = 0.1, Max = 5, Default = 1, Decimal = 0.01 })
CombatSettings:Slider({ Name = "Sensitivity Y", Flag = "PF_Aimbot_GainY", Min = 0.1, Max = 5, Default = 1, Decimal = 0.01 })
CombatSettings:Slider({ Name = "Jitter / Shake", Flag = "PF_Aimbot_Jitter", Min = 0, Max = 50, Default = 0, Decimal = 0.1 })
CombatSettings:Slider({ Name = "FOV Radius", Flag = "PF_Aimbot_FOVRadius", Min = 10, Max = 800, Default = 150, Decimal = 1 })
CombatSettings:Toggle({ Name = "Dynamic FOV", Flag = "PF_Aimbot_DynamicFOV", Default = true })
CombatSettings:Slider({ Name = "Max Aim Distance", Flag = "PF_Aimbot_MaxDist", Min = 50, Max = 5000, Default = 1000, Decimal = 1 })

local TargetSection = CombatCol2:Section({ Name = "Target Sorting" })
TargetSection:Dropdown({
    Name = "Target Bone",
    Flag = "PF_Aimbot_Part",
    Options = { "Head", "Torso", "Closest to Crosshair" },
    Default = "Head"
})
TargetSection:Dropdown({
    Name = "Priority Mode",
    Flag = "PF_Aimbot_Priority",
    Options = { "FOV", "Distance" },
    Default = "FOV"
})
TargetSection:Toggle({ Name = "Show FOV Circle", Flag = "PF_FOV_Visible", Default = false })
    :Colorpicker({ Flag = "PF_FOV_Color", Color = Color3.fromRGB(255, 255, 255) })

TargetSection:Toggle({ Name = "Show Target Line", Flag = "PF_Aimbot_TargetLine", Default = false })

local SilentAimSection = CombatCol2:Section({ Name = "Silent Aim" })
SilentAimSection:Toggle({ Name = "Enabled", Flag = "PF_SilentAim_Enabled", Default = false })
    :Keybind({ Name = "Silent Key", Flag = "PF_SilentAim_Key", Key = Enum.KeyCode.Unknown, Mode = "Hold" })
SilentAimSection:Toggle({ Name = "Visible Check", Flag = "PF_SilentAim_VisCheck", Default = false })
SilentAimSection:Slider({ Name = "Hit Chance", Flag = "PF_SilentAim_HitChance", Min = 1, Max = 100, Default = 100, Suffix = "%" })
SilentAimSection:Slider({ Name = "Head Shot Chance", Flag = "PF_SilentAim_HSChance", Min = 0, Max = 100, Default = 100, Suffix = "%" })
SilentAimSection:Toggle({ Name = "Use FOV", Flag = "PF_SilentAim_UseFOV", Default = false })
SilentAimSection:Slider({ Name = "FOV Radius", Flag = "PF_SilentAim_FOVRadius", Min = 2, Max = 1000, Default = 300, Suffix = "px" })
SilentAimSection:Toggle({ Name = "Show FOV Circle", Flag = "PF_SilentAim_ShowFOV", Default = false })
    :Colorpicker({ Flag = "PF_SilentAim_FOVColor", Color = Color3.fromRGB(255, 255, 255) })
SilentAimSection:Toggle({ Name = "Use Dead FOV", Flag = "PF_SilentAim_UseDeadFOV", Default = false })
SilentAimSection:Slider({ Name = "Dead FOV Radius", Flag = "PF_SilentAim_DeadFOVRadius", Min = 1, Max = 1000, Default = 100, Suffix = "px" })
SilentAimSection:Toggle({ Name = "Show Dead FOV Circle", Flag = "PF_SilentAim_ShowDeadFOV", Default = false })
    :Colorpicker({ Flag = "PF_SilentAim_DeadFOVColor", Color = Color3.fromRGB(255, 255, 255) })
SilentAimSection:Dropdown({
    Name = "Target Bone",
    Flag = "PF_SilentAim_Bone",
    Options = { "Head", "Torso" },
    Default = "Head"
})

local GunMods = CombatCol2:Section({ Name = "Gun Enhancements" })
GunMods:Toggle({ Name = "No Gun Sway", Flag = "PF_NoSway", Default = false })
GunMods:Toggle({ Name = "No Camera Sway", Flag = "PF_NoCamSway", Default = false })
GunMods:Toggle({ Name = "Accuracy Booster", Flag = "PF_AccuracyBoost", Default = false })
GunMods:Toggle({ Name = "No Spread", Flag = "PF_NoSpread", Default = false })
GunMods:Slider({ Name = "Recoil Scale", Flag = "PF_RecoilScale", Min = 0, Max = 100, Default = 100, Suffix = "%" })

--// Visuals Tab
local VisualsCol1 = Tabs.Visuals:Column({})
local VisualsCol2 = Tabs.Visuals:Column({})



local PlayersESP = VisualsCol1:Section({ Name = "Player Highlights" })
PlayersESP:Toggle({ Name = "Master ESP", Flag = "PF_ESP_Master", Default = true })
PlayersESP:Toggle({ Name = "3D Highlights", Flag = "PF_ESP_Highlights", Default = true })
PlayersESP:Label({ Name = "Fill Color" }):Colorpicker({ Flag = "PF_ESP_FillColor", Color = Color3.fromRGB(160, 50, 255) })
PlayersESP:Label({ Name = "Outline Color" }):Colorpicker({
    Flag = "PF_ESP_OutlineColor",
    Color = Color3.fromRGB(80, 20,
        180)
})

PlayersESP:Label({ Name = "Teammate Fill" }):Colorpicker({
    Flag = "PF_ESP_TeamFillColor",
    Color = Color3.fromRGB(50, 255,
        50)
})
PlayersESP:Label({ Name = "Teammate Outline" }):Colorpicker({
    Flag = "PF_ESP_TeamOutlineColor",
    Color = Color3.fromRGB(
        255, 255, 255)
})

PlayersESP:Slider({ Name = "Fill Opacity", Flag = "PF_ESP_FillTransparency", Min = 0, Max = 1, Default = 0.5, Decimal = 0.01 })
PlayersESP:Slider({ Name = "Outline Opacity", Flag = "PF_ESP_OutlineTransparency", Min = 0, Max = 1, Default = 0.3, Decimal = 0.01 })
PlayersESP:Toggle({ Name = "Show Teammates", Flag = "PF_ESP_Teammates", Default = false })

local DrawingESP = VisualsCol2:Section({ Name = "Drawing Visuals" })
DrawingESP:Toggle({ Name = "2D Box ESP", Flag = "PF_ESP_Box", Default = false })
    :Colorpicker({ Flag = "PF_ESP_DrawingColor", Color = Color3.fromRGB(255, 0, 0) })

DrawingESP:Toggle({ Name = "Box Outline", Flag = "PF_ESP_BoxOutline", Default = true })
    :Colorpicker({ Flag = "PF_ESP_BoxOutlineColor", Color = Color3.fromRGB(0, 0, 0) })

DrawingESP:Toggle({ Name = "Healthbar", Flag = "PF_ESP_Healthbar", Default = false })
DrawingESP:Toggle({ Name = "Nametags", Flag = "PF_ESP_Nametags", Default = false })

local WeaponESP = VisualsCol2:Section({ Name = "Weapon ESP" })
WeaponESP:Toggle({ Name = "Show Held Weapon", Flag = "PF_ESP_Weapon", Default = false })
    :Colorpicker({ Flag = "PF_ESP_WeaponColor", Color = Color3.fromRGB(255, 255, 255) })

--// World Tab
local WorldCol1 = Tabs.World:Column({})
local WorldCol2 = Tabs.World:Column({})

local WorldLighting = WorldCol1:Section({ Name = "Atmosphere" })
WorldLighting:Toggle({ Name = "Custom Lighting", Flag = "PF_World_Lighting", Default = false })
WorldLighting:Toggle({ Name = "Full Bright", Flag = "PF_World_Fullbright", Default = false })
WorldLighting:Slider({ Name = "Brightness", Flag = "PF_World_Brightness", Min = 0, Max = 10, Default = 1, Decimal = 0.1 })
WorldLighting:Toggle({ Name = "Global Shadows", Flag = "PF_World_Shadows", Default = true })
WorldLighting:Label("Ambient Tint"):Colorpicker({ Flag = "PF_World_Ambient", Color = Color3.fromRGB(127, 127, 127) })

local WorldFog = WorldCol2:Section({ Name = "Fog & Time" })
WorldFog:Toggle({ Name = "Custom Time", Flag = "PF_World_TimeEnabled", Default = false })
WorldFog:Slider({ Name = "Hour", Flag = "PF_World_Time", Min = 0, Max = 24, Default = 12, Decimal = 0.1 })
WorldFog:Toggle({ Name = "Custom Fog", Flag = "PF_World_FogEnabled", Default = false })
WorldFog:Slider({ Name = "Fog Distance", Flag = "PF_World_FogEnd", Min = 0, Max = 10000, Default = 1000 })
WorldFog:Label("Fog Color"):Colorpicker({ Flag = "PF_World_FogColor", Color = Color3.fromRGB(200, 200, 200) })

local WorldSky = WorldCol2:Section({ Name = "Skybox & Presets" })
WorldSky:Dropdown({
    Name = "Active Skybox",
    Flag = "PF_World_Skybox",
    Options = { "Default", "Purple Nebula", "Night Sky", "Pink Aesthetic", "Dark Void" },
    Default = "Default"
})

--// Misc Tab
local MiscCol1 = Tabs.Misc:Column({})
local MiscCol2 = Tabs.Misc:Column({})

local ServerSection = MiscCol1:Section({ Name = "Server Controls" })
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
        local success, result = pcall(function() return REQ({ Url = url, Method = "GET" }) end)
        if success and result.StatusCode == 200 then
            local data = HttpService:JSONDecode(result.Body)
            local servers = {}
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end
            end
            if #servers > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)],
                    player)
            end
        end
    end
})
ServerSection:Button({
    Name = "Unload Script",
    Callback = function() Holder:Unload() end
})

local LoggingSection = MiscCol2:Section({ Name = "Networking" })
LoggingSection:Toggle({ Name = "Traffic Logger", Flag = "PF_Network_Logger", Default = false })

Library:Configs(Holder, Tabs.Settings)


--// Logic Implementation
local CurrentEnemies = {}
local HeadSize = Vector3.new(0.001, 0.001, 0.001)
local ActiveHighlights = {}
local Active2DESP = {}
local DeadFading = {}

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
    outerOutline.Color = Color3.new(0, 0, 0)

    local innerOutline = Drawing.new("Square")
    innerOutline.Thickness = 1
    innerOutline.Filled = false
    innerOutline.Transparency = 1
    innerOutline.Visible = false
    innerOutline.Color = Color3.new(0, 0, 0)

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
        Bk = "rbxassetid://16553683517",
        Dn = "rbxassetid://16553683517",
        Ft = "rbxassetid://16553683517",
        Lf = "rbxassetid://16553683517",
        Rt = "rbxassetid://16553683517",
        Up = "rbxassetid://16553683517"
    },
    ["Night Sky"] = {
        Bk = "rbxassetid://120645737",
        Dn = "rbxassetid://120645217",
        Ft = "rbxassetid://120645533",
        Lf = "rbxassetid://120644033",
        Rt = "rbxassetid://120644033",
        Up = "rbxassetid://120644033"
    },
    ["Pink Aesthetic"] = {
        Bk = "rbxassetid://271042516",
        Dn = "rbxassetid://271042516",
        Ft = "rbxassetid://271042516",
        Lf = "rbxassetid://271042516",
        Rt = "rbxassetid://271042516",
        Up = "rbxassetid://271042516"
    },
    ["Dark Void"] = {
        Bk = "rbxassetid://161092287",
        Dn = "rbxassetid://161092287",
        Ft = "rbxassetid://161092287",
        Lf = "rbxassetid://161092287",
        Rt = "rbxassetid://161092287",
        Up = "rbxassetid://161092287"
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
    local hl                = Instance.new("Highlight")
    hl.FillColor            = getFlag("PF_ESP_FillColor") or Color3.fromRGB(255, 255, 255)
    hl.OutlineColor         = getFlag("PF_ESP_OutlineColor") or Color3.fromRGB(255, 0, 0)
    hl.FillTransparency     = getFlag("PF_ESP_FillTransparency") or 0.7
    hl.OutlineTransparency  = getFlag("PF_ESP_OutlineTransparency") or 0.3
    hl.Adornee              = model
    local gethui            = gethui or function() return game:GetService("CoreGui") end
    hl.Parent               = gethui() or model
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
    local espActive = getFlag("PF_ESP_Master") == true or getFlag("PF_SilentAim_Enabled") == true or
        getFlag("PF_Aimbot_Enabled") == true

    if not espActive then
        CurrentEnemies = {}
        table.clear(TargetMetrics)
        table.clear(DeadFading)
        for char, _ in pairs(Active2DESP) do remove2DESP(char) end
        for model, hl in pairs(ActiveHighlights) do
            if hl then hl:Destroy() end
        end
        table.clear(ActiveHighlights)
        return
    end

    CurrentEnemies = {}

    -- Reset Visiblity for all indicators
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

    if not ReplicationInterface then return end

    ReplicationInterface.operateOnAllEntries(function(playerObj, entry)
        if playerObj == player then return end

        local thirdPerson = entry:getThirdPersonObject()
        if not thirdPerson then return end

        local char = thirdPerson:getCharacterModel()
        local rootPart = thirdPerson:getRootPart()
        if not char or not rootPart or not char.Parent then return end

        local isEnemy = entry._isEnemy
        local healthVal = entry:getHealth()

        if healthVal <= 0 then
            if ActiveHighlights[char] then
                ActiveHighlights[char]:Destroy()
                ActiveHighlights[char] = nil
            end
            -- Start fade out for healthbar and nametags instead of immediate removal
            if Active2DESP[char] and not DeadFading[char] then
                DeadFading[char] = { StartTime = os.clock(), Data = Active2DESP[char] }
            end
            return
        end

        -- Character Bone Mapping
        local charHash = thirdPerson:getCharacterHash()
        local headPart = charHash and charHash.Head or char:FindFirstChild("Head")
        if not headPart then return end

        -- Remove from dead fading if player respawned
        if DeadFading[char] then
            DeadFading[char] = nil
        end

        -- Update Metrics & Velocity for Prediction
        local velocity = Vector3.new(0, 0, 0)
        local last = TargetMetrics[char]
        local currentPos = rootPart.Position
        local currentTime = os.clock()
        if last then
            local dt = currentTime - last.Time
            if dt > 0 and dt < 0.1 then
                local instVelocity = (currentPos - last.Pos) / dt
                velocity = last.Velocity:Lerp(instVelocity, 0.25)
            end
        end
        TargetMetrics[char] = { Pos = currentPos, Time = currentTime, Velocity = velocity }

        if isEnemy then
            CurrentEnemies[char] = { Head = headPart, Torso = rootPart, Velocity = velocity }
        end

        -- Visuals Logic
        if getFlag("PF_ESP_Master") then
            local teamESP = getFlag("PF_ESP_Teammates") == true
            if isEnemy or teamESP then
                -- Highlights (Chams)
                if getFlag("PF_ESP_Highlights") then
                    addHighlight(char)
                    local hl = ActiveHighlights[char]
                    if hl then
                        hl.FillColor = isEnemy and getFlag("PF_ESP_FillColor") or getFlag("PF_ESP_TeamFillColor")
                        hl.OutlineColor = isEnemy and getFlag("PF_ESP_OutlineColor") or
                            getFlag("PF_ESP_TeamOutlineColor")
                        hl.FillTransparency = getFlag("PF_ESP_FillTransparency")
                        hl.OutlineTransparency = getFlag("PF_ESP_OutlineTransparency")
                    end
                elseif ActiveHighlights[char] then
                    ActiveHighlights[char]:Destroy()
                    ActiveHighlights[char] = nil
                end

                -- 2D Drawings
                local espData = Active2DESP[char] or create2DESP(char)
                local boxEnabled = getFlag("PF_ESP_Box")
                local healthEnabled = getFlag("PF_ESP_Healthbar")
                local nametagEnabled = getFlag("PF_ESP_Nametags")
                local weaponEnabled = getFlag("PF_ESP_Weapon")
                local boxVisible = false

                if boxEnabled or healthEnabled or nametagEnabled or weaponEnabled then
                    local cam = workspace.CurrentCamera
                    local hPos, hOn = cam:WorldToViewportPoint(headPart.Position)
                    local tPos, tOn = cam:WorldToViewportPoint(rootPart.Position)

                    if hOn or tOn then
                        local charHeight = (hPos - tPos).Magnitude * 2.5
                        local charWidth = charHeight * 0.5
                        local boxPos = Vector2.new(hPos.X - charWidth / 2, hPos.Y - charHeight / 4)
                        local boxSize = Vector2.new(charWidth, charHeight)

                        if boxEnabled then
                            espData.Box.Visible = true
                            espData.Box.Position = boxPos
                            espData.Box.Size = boxSize
                            espData.Box.Color = getFlag("PF_ESP_DrawingColor")

                            if getFlag("PF_ESP_BoxOutline") then
                                local outColor = getFlag("PF_ESP_BoxOutlineColor")
                                espData.OuterOutline.Visible = true
                                espData.OuterOutline.Position = boxPos - Vector2.new(1, 1)
                                espData.OuterOutline.Size = boxSize + Vector2.new(2, 2)
                                espData.OuterOutline.Color = outColor
                                espData.InnerOutline.Visible = true
                                espData.InnerOutline.Position = boxPos + Vector2.new(1, 1)
                                espData.InnerOutline.Size = boxSize - Vector2.new(2, 2)
                                espData.InnerOutline.Color = outColor
                            end
                            boxVisible = true
                        end

                        if nametagEnabled then
                            local dist = (cam.CFrame.Position - headPart.Position).Magnitude
                            espData.NameTag.Visible = true
                            espData.NameTag.Text = string.format("%s [%dm]", playerObj.Name, dist)
                            espData.NameTag.Position = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y - 15)
                            boxVisible = true
                        end

                        if healthEnabled then
                            local healthPerc = math.clamp(healthVal / 100, 0, 1)
                            espData.HealthOutline.Visible = true
                            espData.HealthOutline.Position = Vector2.new(boxPos.X - 6, boxPos.Y - 1)
                            espData.HealthOutline.Size = Vector2.new(4, boxSize.Y + 2)
                            espData.HealthBar.Visible = true
                            espData.HealthBar.Position = Vector2.new(boxPos.X - 5,
                                boxPos.Y + boxSize.Y - (boxSize.Y * healthPerc))
                            espData.HealthBar.Size = Vector2.new(2, boxSize.Y * healthPerc)
                            espData.HealthBar.Color = Color3.fromHSV(healthPerc * 0.3, 1, 1)
                            boxVisible = true
                        end

                        if weaponEnabled then
                            local weaponObject = entry:getWeaponObject()
                            local weaponName = weaponObject and weaponObject.weaponName or "Unknown"
                            espData.WeaponTag.Visible = true
                            espData.WeaponTag.Text = "[" .. weaponName .. "]"
                            espData.WeaponTag.Position = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y + boxSize.Y + 5)
                            espData.WeaponTag.Color = getFlag("PF_ESP_WeaponColor")
                            boxVisible = true
                        end
                    end
                end

                if not boxVisible and not getFlag("PF_ESP_Highlights") then
                    remove2DESP(char)
                end
            end
        end
    end)

    --// Handle Dead Player Fade-out for Healthbar and Nametags
    local currentTime = os.clock()
    local fadeDuration = 1.5 -- seconds to fully fade out

    for char, fadeData in pairs(DeadFading) do
        local espData = fadeData.Data
        local elapsed = currentTime - fadeData.StartTime
        local fadeAlpha = math.clamp(1 - (elapsed / fadeDuration), 0, 1)

        if fadeAlpha <= 0 or not char.Parent then
            -- Fully faded or character removed, clean up
            remove2DESP(char)
            DeadFading[char] = nil
        else
            -- Apply fade transparency to healthbar and nametags only
            local cam = workspace.CurrentCamera
            local headPart = char:FindFirstChild("Head")
            local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")

            if headPart and rootPart then
                local hPos, hOn = cam:WorldToViewportPoint(headPart.Position)
                local tPos, tOn = cam:WorldToViewportPoint(rootPart.Position)

                if hOn or tOn then
                    local charHeight = (hPos - tPos).Magnitude * 2.5
                    local charWidth = charHeight * 0.5
                    local boxPos = Vector2.new(hPos.X - charWidth / 2, hPos.Y - charHeight / 4)
                    local boxSize = Vector2.new(charWidth, charHeight)

                    -- Fade nametag
                    if getFlag("PF_ESP_Nametags") then
                        espData.NameTag.Visible = true
                        espData.NameTag.Transparency = fadeAlpha
                        espData.NameTag.Position = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y - 15)
                    else
                        espData.NameTag.Visible = false
                    end

                    -- Fade healthbar elements
                    if getFlag("PF_ESP_Healthbar") then
                        espData.HealthOutline.Visible = true
                        espData.HealthOutline.Transparency = fadeAlpha
                        espData.HealthOutline.Position = Vector2.new(boxPos.X - 6, boxPos.Y - 1)
                        espData.HealthOutline.Size = Vector2.new(4, boxSize.Y + 2)

                        espData.HealthBar.Visible = true
                        espData.HealthBar.Transparency = fadeAlpha
                        espData.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + boxSize.Y)
                        espData.HealthBar.Size = Vector2.new(2, 0)
                        espData.HealthBar.Color = Color3.fromRGB(255, 0, 0) -- Empty/red for dead

                        espData.HealthText.Visible = true
                        espData.HealthText.Transparency = fadeAlpha
                        espData.HealthText.Position = Vector2.new(boxPos.X - 10, boxPos.Y + boxSize.Y / 2)
                        espData.HealthText.Text = "DEAD"
                    else
                        espData.HealthOutline.Visible = false
                        espData.HealthBar.Visible = false
                        espData.HealthText.Visible = false
                    end

                    -- Fade box ESP
                    if getFlag("PF_ESP_Box") then
                        local boxColor = getFlag("PF_ESP_DrawingColor")
                        local outColor = getFlag("PF_ESP_BoxOutlineColor")

                        espData.Box.Visible = true
                        espData.Box.Transparency = fadeAlpha
                        espData.Box.Position = boxPos
                        espData.Box.Size = boxSize
                        espData.Box.Color = boxColor

                        if getFlag("PF_ESP_BoxOutline") then
                            espData.OuterOutline.Visible = true
                            espData.OuterOutline.Transparency = fadeAlpha
                            espData.OuterOutline.Position = boxPos - Vector2.new(1, 1)
                            espData.OuterOutline.Size = boxSize + Vector2.new(2, 2)
                            espData.OuterOutline.Color = outColor

                            espData.InnerOutline.Visible = true
                            espData.InnerOutline.Transparency = fadeAlpha
                            espData.InnerOutline.Position = boxPos + Vector2.new(1, 1)
                            espData.InnerOutline.Size = boxSize - Vector2.new(2, 2)
                            espData.InnerOutline.Color = outColor
                        else
                            espData.OuterOutline.Visible = false
                            espData.InnerOutline.Visible = false
                        end
                    else
                        espData.Box.Visible = false
                        espData.OuterOutline.Visible = false
                        espData.InnerOutline.Visible = false
                    end

                    espData.WeaponTag.Visible = false
                else
                    -- Off screen, hide all
                    espData.Box.Visible = false
                    espData.OuterOutline.Visible = false
                    espData.InnerOutline.Visible = false
                    espData.HealthOutline.Visible = false
                    espData.HealthBar.Visible = false
                    espData.HealthText.Visible = false
                    espData.NameTag.Visible = false
                    espData.WeaponTag.Visible = false
                end
            else
                -- Missing parts, remove
                remove2DESP(char)
                DeadFading[char] = nil
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
    local ignoreList = { player.Character, cam, workspace.Terrain }
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
        if mode == "Head" then
            targetPart = parts.Head
        elseif mode == "Torso" then
            targetPart = parts.Torso
        elseif mode == "Closest to Crosshair" then
            local headPos, h_on = cam:WorldToViewportPoint(parts.Head.Position)
            local torsoPos, t_on = cam:WorldToViewportPoint(parts.Torso.Position)
            local h_dist = (h_on and headPos.Z > 0) and
                (Vector2.new(headPos.X, headPos.Y) - Vector2.new(mx, my)).Magnitude or math.huge
            local t_dist = (t_on and torsoPos.Z > 0) and
                (Vector2.new(torsoPos.X, torsoPos.Y) - Vector2.new(mx, my)).Magnitude or math.huge
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
        if evalDist < bestDist then
            bestDist = evalDist; closestPart = targetPart
        end
    end
    return closestPart, bestDist
end

local function solve(v44, v45, v46, v47, v48)
    if not v44 then
        return
    elseif v44 > -1.0E-10 and v44 < 1.0E-10 then
        return solve(v45, v46, v47, v48)
    else
        if v48 then
            local v49 = -v45 / (4 * v44)
            local v50 = (v46 + v49 * (3 * v45 + 6 * v44 * v49)) / v44
            local v51 = (v47 + v49 * (2 * v46 + v49 * (3 * v45 + 4 * v44 * v49))) / v44
            local v52 = (v48 + v49 * (v47 + v49 * (v46 + v49 * (v45 + v44 * v49)))) / v44
            if v51 > -1.0E-10 and v51 < 1.0E-10 then
                local v53, v54 = solve(1, v50, v52)
                if not v54 or v54 < 0 then
                    return
                else
                    local v55 = math.sqrt(v53)
                    local v56 = math.sqrt(v54)
                    return v49 - v56, v49 - v55, v49 + v55, v49 + v56
                end
            else
                local v57, _, v59 = solve(1, 2 * v50, v50 * v50 - 4 * v52, -v51 * v51)
                local v60 = v59 or v57
                local v61 = math.sqrt(v60)
                local v62, v63 = solve(1, v61, (v60 + v50 - v51 / v61) / 2)
                local v64, v65 = solve(1, -v61, (v60 + v50 + v51 / v61) / 2)
                if v62 and v64 then
                    return v49 + v62, v49 + v63, v49 + v64, v49 + v65
                elseif v62 then
                    return v49 + v62, v49 + v63
                elseif v64 then
                    return v49 + v64, v49 + v65
                end
            end
        elseif v47 then
            local v66 = -v45 / (3 * v44);
            local v67 = -(v46 + v66 * (2 * v45 + 3 * v44 * v66)) / (3 * v44)
            local v68 = -(v47 + v66 * (v46 + v66 * (v45 + v44 * v66))) / (2 * v44)
            local v69 = v68 * v68 - v67 * v67 * v67
            local v70 = math.sqrt((math.abs(v69)))
            if v69 > 0 then
                local v71 = v68 + v70
                local v72 = v68 - v70
                v71 = v71 < 0 and -(-v71) ^ 0.3333333333333333 or v71 ^ 0.3333333333333333
                local v73 = v72 < 0 and -(-v72) ^ 0.3333333333333333 or v72 ^ 0.3333333333333333
                return v66 + v71 + v73
            else
                local v74 = math.atan2(v70, v68) / 3
                local v75 = 2 * math.sqrt(v67)
                return v66 - v75 * math.sin(v74 + 0.5235987755982988), v66 + v75 * math.sin(v74 - 0.5235987755982988),
                    v66 + v75 * math.cos(v74)
            end;
        elseif v46 then
            local v76 = -v45 / (2 * v44)
            local v77 = v76 * v76 - v46 / v44
            if v77 < 0 then
                return
            else
                local v78 = math.sqrt(v77)
                return v76 - v78, v76 + v78
            end
        elseif v45 then
            return -v45 / v44
        end
        return
    end
end

local function complexTrajectory(o, a, t, s, e)
    local ld = t - o
    a = -a
    e = e or Vector3.new(0, 0, 0)

    local r1, r2, r3, r4 = solve(
        a:Dot(a) * 0.25,
        a:Dot(e),
        a:Dot(ld) + e:Dot(e) - s ^ 2,
        ld:Dot(e) * 2,
        ld:Dot(ld)
    )

    local x = (r1 and r1 > 0 and r1) or (r2 and r2 > 0 and r2) or (r3 and r3 > 0 and r3) or r4
    if not x then return nil end
    local v = (ld + e * x + 0.5 * a * x ^ 2) / x
    return v, x
end

local function GetPredictedPosition(targetPart, targetVelocity)
    local pos = targetPart.Position
    local predictionEnabled = getFlag("PF_Aimbot_Prediction")
    local dropEnabled = getFlag("PF_Aimbot_DropCorrection")
    local scale = getFlag("PF_Aimbot_PredictionScale") or 1

    if not predictionEnabled and not dropEnabled then return pos end

    local bulletSpeed, acceleration = 2500, Vector3.new(0, -196.2, 0)

    if WeaponController and PublicSettings then
        local controller = WeaponController.getController()
        if controller and controller._activeWeapon then
            bulletSpeed = controller._activeWeapon:getWeaponStat("bulletspeed") or 2500
        end
        acceleration = PublicSettings.bulletAcceleration
    end

    local cam = workspace.CurrentCamera
    local velocity, timeToHit = complexTrajectory(cam.CFrame.Position, acceleration, pos, bulletSpeed,
        targetVelocity * scale)

    if velocity then
        return cam.CFrame.Position + velocity * timeToHit, velocity
    end

    -- Fallback to basic prediction if solver fails
    local timeToHitBasic = (pos - cam.CFrame.Position).Magnitude / bulletSpeed
    local predictedPos = pos + (targetVelocity * timeToHitBasic * scale)
    if dropEnabled then
        predictedPos = predictedPos + Vector3.new(0, 0.5 * math.abs(acceleration.Y) * (timeToHitBasic ^ 2), 0)
    end
    return predictedPos
end

local function TryAim()
    if getFlag("PF_Aimbot_Enabled") ~= true then return end
    local keyHeld = getFlag("PF_Aimbot_Key")
    if not keyHeld then return end
    local targetPart = getClosestEnemy()
    if not targetPart then
        targetLine.Visible = false; return
    end
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
        moveX, moveY = moveX + (math.noise(os.clock() * 10) * j), moveY + (math.noise(0, os.clock() * 10) * j)
    end
    if moveMouse then moveMouse(math.round(moveX), math.round(moveY)) end
    if getFlag("PF_Aimbot_TargetLine") then
        targetLine.From, targetLine.To, targetLine.Visible =
            Vector2.new(mousePos.X, mousePos.Y), Vector2.new(screenPos.X, screenPos.Y), true
    else
        targetLine.Visible = false
    end
end

--// Silent Aim Drawings
local silentFovCircle        = Drawing.new("Circle")
silentFovCircle.Radius       = 300
silentFovCircle.Color        = Color3.fromRGB(255, 255, 255)
silentFovCircle.Thickness    = 2
silentFovCircle.Transparency = 0.8
silentFovCircle.Filled       = false
silentFovCircle.NumSides     = 64
silentFovCircle.Visible      = false

local silentDeadFovCircle        = Drawing.new("Circle")
silentDeadFovCircle.Radius       = 100
silentDeadFovCircle.Color        = Color3.fromRGB(255, 255, 255)
silentDeadFovCircle.Thickness    = 2
silentDeadFovCircle.Transparency = 0.8
silentDeadFovCircle.Filled       = false
silentDeadFovCircle.NumSides     = 64
silentDeadFovCircle.Visible      = false

--// Silent Aim Target Selection
local function getSilentTarget(bonePreference)
    local cam = workspace.CurrentCamera
    local centerPos = silentFovCircle.Position
    local cx, cy = centerPos.X, centerPos.Y
    local useFov = getFlag("PF_SilentAim_UseFOV")
    local useDead = getFlag("PF_SilentAim_UseDeadFOV")
    local fovRadius = silentFovCircle.Radius
    local deadRadius = silentDeadFovCircle.Radius
    local visCheck = getFlag("PF_SilentAim_VisCheck")

    local bestPart, bestDist = nil, math.huge
    local bestChar, bestData = nil, nil

    for char, parts in pairs(CurrentEnemies) do
        local targetPart = (bonePreference == "Torso") and parts.Torso or parts.Head
        if targetPart then
            local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
            if onScreen and screenPos.Z > 0 then
                local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(cx, cy)).Magnitude
                local pass = true
                if useFov and fovDist > fovRadius then pass = false end
                if pass and useDead and fovDist < deadRadius then pass = false end
                if pass and visCheck and not isVisible(targetPart, char) then pass = false end
                if pass and fovDist < bestDist then
                    bestDist = fovDist
                    bestPart = targetPart
                    bestChar = char
                    bestData = parts
                end
            end
        end
    end
    return bestPart, bestChar, bestData
end

--// Silent Aim & Networking
if NetworkClient then
    local oldSend = NetworkClient.send
    NetworkClient.send = function(self, event, ...)
        local args = { ... }
        if getFlag("PF_Network_Logger") then print("[Network Out]", event, HttpService:JSONEncode(args)) end

        local chanceOne = math.random(1, 100)
        local chanceTwo = math.random(1, 100)

        if getFlag("PF_SilentAim_Enabled") == true and event == "newbullets"
            and (getFlag("PF_SilentAim_HitChance") or 100) >= chanceOne then
            local bulletData = args[2]
            if bulletData and bulletData.firepos and bulletData.bullets then
                local bonePref = getFlag("PF_SilentAim_Bone") or "Head"
                if bonePref == "Head" and (getFlag("PF_SilentAim_HSChance") or 100) < chanceTwo then
                    bonePref = "Torso"
                end

                local targetPart, _, enemyData = getSilentTarget(bonePref)
                if targetPart and enemyData then
                    local bulletSpeed = 2500
                    local acceleration = Vector3.new(0, -196.2, 0)
                    if WeaponController and PublicSettings then
                        local controller = WeaponController.getController()
                        if controller and controller._activeWeapon then
                            bulletSpeed = controller._activeWeapon:getWeaponStat("bulletspeed") or 2500
                        end
                        acceleration = PublicSettings.bulletAcceleration or acceleration
                    end

                    local velocity = complexTrajectory(bulletData.firepos, acceleration, targetPart.Position,
                        bulletSpeed, enemyData.Velocity or Vector3.zero)
                    if velocity then
                        local unitVel = velocity.Unit
                        for _, bullet in ipairs(bulletData.bullets) do
                            bullet[1] = unitVel
                        end
                    end
                end
            end
        end
        return oldSend(self, event, unpack(args))
    end
end

--// Visual Synchronization hook
if BulletObject then
    local oldNew = BulletObject.new
    BulletObject.new = function(bulletData)
        local chanceOne = math.random(1, 100)
        local chanceTwo = math.random(1, 100)

        if getFlag("PF_SilentAim_Enabled") == true
            and (getFlag("PF_SilentAim_HitChance") or 100) >= chanceOne
            and bulletData.position and bulletData.velocity then
            local bonePref = getFlag("PF_SilentAim_Bone") or "Head"
            if bonePref == "Head" and (getFlag("PF_SilentAim_HSChance") or 100) < chanceTwo then
                bonePref = "Torso"
            end

            local targetPart, _, enemyData = getSilentTarget(bonePref)
            if targetPart and enemyData then
                local velocity = complexTrajectory(bulletData.position, bulletData.acceleration or Vector3.zero,
                    targetPart.Position, bulletData.velocity.Magnitude, enemyData.Velocity or Vector3.zero)
                if velocity then
                    bulletData.velocity = velocity
                end
            end
        end
        return oldNew(bulletData)
    end
end

--// Weapon Mods & Camera Bypass
pcall(function()
    if FirearmObject then
        local oldSway = FirearmObject.computeGunSway
        FirearmObject.computeGunSway = function(self, ...)
            return getFlag("PF_NoSway") and CFrame.new() or
                oldSway(self, ...)
        end
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
        Lighting.Brightness, Lighting.GlobalShadows, Lighting.Ambient = getFlag("PF_World_Brightness"),
            getFlag("PF_World_Shadows"), getFlag("PF_World_Ambient")
    end
    if getFlag("PF_World_TimeEnabled") then Lighting.ClockTime = getFlag("PF_World_Time") end
    if getFlag("PF_World_FogEnabled") then
        Lighting.FogEnd, Lighting.FogColor = getFlag("PF_World_FogEnd"),
            getFlag("PF_World_FogColor")
    end

    local activeSky = getFlag("PF_World_Skybox")
    if activeSky and activeSky ~= "Default" then ApplySkybox(activeSky) end

    local baseFOV = getFlag("PF_Aimbot_FOVRadius") or 150
    local dynScale = getFlag("PF_Aimbot_DynamicFOV") and (70 / workspace.CurrentCamera.FieldOfView) or 1
    fovCircle.Radius = baseFOV * dynScale
    fovCircle.Visible, fovCircle.Color, fovCircle.Position = getFlag("PF_FOV_Visible"), getFlag("PF_FOV_Color"),
        UserInputService:GetMouseLocation()

    local mousePos = UserInputService:GetMouseLocation()
    local silentBase = getFlag("PF_SilentAim_FOVRadius") or 300
    silentFovCircle.Radius = silentBase * dynScale
    silentFovCircle.Position = mousePos
    silentFovCircle.Color = getFlag("PF_SilentAim_FOVColor") or Color3.new(1, 1, 1)
    silentFovCircle.Visible = getFlag("PF_SilentAim_ShowFOV") == true

    local deadBase = getFlag("PF_SilentAim_DeadFOVRadius") or 100
    silentDeadFovCircle.Radius = deadBase * dynScale
    silentDeadFovCircle.Position = mousePos
    silentDeadFovCircle.Color = getFlag("PF_SilentAim_DeadFOVColor") or Color3.new(1, 1, 1)
    silentDeadFovCircle.Visible = getFlag("PF_SilentAim_ShowDeadFOV") == true

    pcall(TryAim)
end)

--// Menu Toggle Logic (Ensuring it works even if callback is missed)
-- Redundant listener removed. Octohook handles this via callback.

Library:Notification({ Name = "Phantom Forces Script Loaded", Lifetime = 3 })


-- Trigger MiscOptions (from Example)
if MiscOptions then
    for index, value in pairs(MiscOptions) do
        Options[index] = value
    end
end

