local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local function isMobileDevice()
    return UserInputService.TouchEnabled
        and not UserInputService.KeyboardEnabled
end

local CONFIG = {
    PrivateServerOnly = true,

    AimEnabled = false,
    AimMode = "Toggle",
    AimStyle = "Snap",
    TargetPart = "Head",
    StrictHead = true,
    SnapOnAcquire = true,
    SnapUsePrediction = false,
    HeadOffset = 0,
    SnapThreshold = 70,
    SwitchCooldown = 0.08,
    TargetPriority = "Cursor",
    TargetFilterMode = "All",
    WhitelistCSV = "",
    BlacklistCSV = "",
    DynamicFOV = true,
    DynamicFOVMin = 72,
    DynamicFOVLockedScale = 1.0,
    DynamicFOVSpeedBoost = 0.45,
    BotDifficulty = "Normal",
    LockSoundEnabled = true,
    LockSoundVolume = 0.35,
    WallCheck = true,
    TeamCheck = true,
    BotsEnabled = true,
    Prediction = true,
    PredictionAmount = 0.12,
    PredictionPingCompensation = true,
    AdaptiveSmoothing = true,
    StickyTarget = true,
    LockGrace = 0.45,
    LockFOVMultiplier = 2.0,
    AimDeadzone = 1.5,
    Smoothness = 0.18,
    FOV = 180,
    MaxDistance = 650,
    AutoSwitch = true,
    VisibleTargetsOnly = true,
    AutoShootEnabled = false,
    AutoShootDelay = 0.02,

    ESPEnabled = false,
    BoxESP = true,
    NameESP = true,
    HealthESP = true,
    DistanceESP = true,
    Tracers = false,
    SkeletonESP = false,
    Chams = false,
    HitboxVisualizer = false,
    ReliableESP = true,
    HeadDotESP = true,
    TargetHighlight = true,
    OffscreenArrows = true,
    DistanceFade = true,
    SkeletonMaxDistance = 300,
    MaxVisualTargets = 24,
    ESPStyle = "Full",
    ESPFilter = "All",
    ESPLowHealthThreshold = 35,
    ThreatIndicators = true,

    RadarEnabled = false,
    RadarRange = 350,
    RadarSize = 180,
    RadarRotation = "Camera",
    RadarFollowsESPFilter = false,

    ShowFOV = true,
    ShowTargetIndicator = true,
    ShowTargetMarker = true,
    ShowTargetLine = true,
    TriggerCheck = false,

    PerformanceMode = true,
    AdaptiveVisualQuality = true,
    ShowPerformanceStats = true,

    SpinbotEnabled = false,
    SpinbotSpeed = 720,
    SpinbotDirection = "Right",
    SpinbotJitter = false,
    SpinbotJitterAmount = 18,
    SpinbotOnlyMoving = false,
    SpinbotPauseWhileAiming = true,

    CustomCrosshair = true,
    CrosshairSize = 8,
    CrosshairGap = 5,
    CrosshairThickness = 1,

    DamageNumbers = true,
    HitMarker = true,
    KillConfirmation = true,
    AmmoHUD = true,
    AutoWeaponProfiles = true,
    WeaponProfilesJSON = "",
    ProfileSlot1 = "",
    ProfileSlot2 = "",
    ProfileSlot3 = "",
    LayoutEditor = false,
    LayoutJSON = "",

    ESPColor = {255, 255, 255},
}

local BINDS = {
    ToggleUI = Enum.KeyCode.RightAlt,
    Aim = Enum.KeyCode.Q,
    SwitchTarget = Enum.KeyCode.X,
    ESP = Enum.KeyCode.E,
    Radar = Enum.KeyCode.R,
    Spinbot = Enum.KeyCode.V,
    PreviousTarget = Enum.KeyCode.C,
    Panic = Enum.KeyCode.Backspace,
}

local DEFAULT_CONFIG = {}

for key, value in pairs(CONFIG) do
    DEFAULT_CONFIG[key] = type(value) == "table"
        and table.clone(value)
        or value
end

local DEFAULT_BINDS = table.clone(BINDS)

local function isAuthorized()
    if RunService:IsStudio() then
        return true
    end

    if not CONFIG.PrivateServerOnly then
        return true
    end

    return game.PrivateServerId ~= ""
end

if not isAuthorized() then
    warn("EMPYRE is restricted to Roblox Studio and private/reserved servers.")
    return
end

local previous = PlayerGui:FindFirstChild("EMPYRE_UI")
if previous then
    previous:Destroy()
end

local COLORS = {
    Background = Color3.fromRGB(5, 5, 5),
    Sidebar = Color3.fromRGB(10, 10, 10),
    Surface = Color3.fromRGB(16, 16, 16),
    Surface2 = Color3.fromRGB(24, 24, 24),
    Surface3 = Color3.fromRGB(34, 34, 34),
    Border = Color3.fromRGB(58, 58, 58),
    White = Color3.fromRGB(245, 245, 245),
    Muted = Color3.fromRGB(160, 160, 160),
    Dim = Color3.fromRGB(95, 95, 95),
    Black = Color3.fromRGB(0, 0, 0),
    Success = Color3.fromRGB(220, 220, 220),
    Danger = Color3.fromRGB(255, 100, 100),
}

local currentTarget = nil
local aimActive = false
local captureAction = nil
local targetLastValidAt = -math.huge
local lastTargetSwitchAt = -math.huge
local lastRenderedTarget = nil
local currentPingMs = 0
local smoothedVelocity = setmetatable({}, {__mode = "k"})

local Runtime = {
    FpsFrames = 0,
    FpsWindowStart = os.clock(),
    DisplayedFPS = 0,
    DisplayedPing = "-- ms",
    NextPingSample = 0,
    NextStatusUpdate = 0,
    NextESPUpdate = 0,
    NextRadarUpdate = 0,
    NextTargetScan = 0,
    NextTriggerScan = 0,
    NextAimStatusRefresh = 0,
    NextPerformanceHudUpdate = 0,

    SpinAngle = 0,
    SpinMotor = nil,
    SpinCharacter = nil,
    SpinHumanoid = nil,
    SpinApplied = false,
    SpinAccumulator = 0,

    ESPColorKey = -1,
    ESPColorValue = Color3.fromRGB(255, 255, 255),
    ESPWasEnabled = false,
    RadarWasEnabled = false,
    LastFOVSize = -1,
    LastFOVColor = nil,
    CrosshairVisible = false,

    CrosshairParts = {},
    CrosshairDot = nil,
    Toast = nil,
    ToastText = nil,
    ToastToken = 0,

    TargetHistory = {},
    TargetHistoryLimit = 8,
    BotSeenAt = setmetatable({}, {__mode = "k"}),
    VisibilityLostAt = setmetatable({}, {__mode = "k"}),
    ListCacheWhiteSource = nil,
    ListCacheBlackSource = nil,
    ListCacheWhite = {},
    ListCacheBlack = {},
    WeaponProfiles = {},
    CurrentWeaponName = "NONE",
    LastWeaponName = nil,
    ProfileLoading = false,
    RaycastCount = 0,
    RaycastsPerSecond = 0,
    LastRaycastSample = 0,
    LastRaycastCount = 0,
    ESPUpdateCount = 0,
    ESPUpdatesPerSecond = 0,
    LastESPUpdateSample = 0,
    LastESPUpdateCount = 0,
    Spectators = {},
    NextSpectatorScan = 0,
    NextAmmoUpdate = 0,
    NextDiagnosticsUpdate = 0,
    LastFeedbackAt = 0,
    ActiveProfileSlot = 0,
    FeedbackRemote = nil,
    BotControlRemote = nil,
    LockSound = nil,
    AmmoHud = nil,
    AmmoText = nil,
    SpectatorHud = nil,
    SpectatorText = nil,
    HitMarkerText = nil,
    DiagnosticsLabels = {},
    EditableFrames = {},
    LayoutLoading = false,
}

local currentTab = "Aim"

local espObjects = {}
local radarDots = {}
local tabPages = {}
local tabButtons = {}
local bindButtons = {}
local refreshers = {}
local switchTarget
local QuickControls
local QuickControlsScale

local function new(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius),
    }, parent)
end

local function stroke(parent, transparency, thickness, color)
    return new("UIStroke", {
        Color = color or COLORS.Border,
        Transparency = transparency or 0.5,
        Thickness = thickness or 1,
    }, parent)
end

local function tween(object, properties, duration)
    TweenService:Create(
        object,
        TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        properties
    ):Play()
end

local function text(parent, value, size, color, font, alignment)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = value,
        TextColor3 = color or COLORS.White,
        TextSize = size or 12,
        Font = font or Enum.Font.GothamMedium,
        TextXAlignment = alignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local function button(parent, value)
    return new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = COLORS.Surface2,
        BorderSizePixel = 0,
        Text = value or "",
        TextColor3 = COLORS.White,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
    }, parent)
end

local function espColor()
    local red = CONFIG.ESPColor[1]
    local green = CONFIG.ESPColor[2]
    local blue = CONFIG.ESPColor[3]
    local key = red * 65536 + green * 256 + blue

    if Runtime.ESPColorKey ~= key then
        Runtime.ESPColorKey = key
        Runtime.ESPColorValue = Color3.fromRGB(red, green, blue)
    end

    return Runtime.ESPColorValue
end

local ConfigRemote = ReplicatedStorage:WaitForChild("EMPYRE_ConfigV2", 5)
local AutoShootRemote = ReplicatedStorage:WaitForChild("EMPYRE_AutoShoot", 5)
local lastAutoShot = -math.huge
local saveQueued = false
local saveStatus = ConfigRemote and "SYNCED" or "LOCAL"

local function serialiseConfig()
    local data = {
        Config = {},
        Binds = {},
    }

    for key, value in pairs(CONFIG) do
        if key ~= "PrivateServerOnly" then
            if type(value) == "table" then
                data.Config[key] = table.clone(value)
            else
                data.Config[key] = value
            end
        end
    end

    for action, keyCode in pairs(BINDS) do
        data.Binds[action] = keyCode.Name
    end

    return data
end

local function applySavedConfig(data)
    if type(data) ~= "table" then
        return
    end

    local savedConfig = data.Config
    local savedBinds = data.Binds

    if type(savedConfig) == "table" then
        for key, value in pairs(savedConfig) do
            if CONFIG[key] ~= nil and type(value) == type(CONFIG[key]) then
                if key == "ESPColor" and type(value) == "table" then
                    CONFIG.ESPColor = {
                        math.clamp(tonumber(value[1]) or 255, 0, 255),
                        math.clamp(tonumber(value[2]) or 255, 0, 255),
                        math.clamp(tonumber(value[3]) or 255, 0, 255),
                    }
                else
                    CONFIG[key] = value
                end
            end
        end
    end

    if type(savedBinds) == "table" then
        for action, keyName in pairs(savedBinds) do
            local keyCode = typeof(keyName) == "string" and Enum.KeyCode[keyName]

            if BINDS[action] and keyCode then
                BINDS[action] = keyCode
            end
        end
    end
end

if ConfigRemote then
    local success, saved = pcall(function()
        return ConfigRemote:InvokeServer("Load")
    end)

    if success and type(saved) == "table" then
        applySavedConfig(saved)
        saveStatus = "SYNCED"
    else
        saveStatus = "LOCAL"
    end
end

local function queueSave()
    if not ConfigRemote or saveQueued then
        return
    end

    saveQueued = true
    saveStatus = "SAVING"

    task.delay(1.25, function()
        saveQueued = false

        local success, result = pcall(function()
            return ConfigRemote:InvokeServer("Save", serialiseConfig())
        end)

        saveStatus = success and result == true and "SAVED" or "LOCAL"
    end)
end

local function changed()
    for _, refresh in ipairs(refreshers) do
        refresh()
    end

    queueSave()
end

local ScreenGui = new("ScreenGui", {
    Name = "EMPYRE_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

function Runtime.CreateOverlayExtras()
    for index = 1, 4 do
        Runtime.CrosshairParts[index] = new("Frame", {
            Name = "Crosshair_" .. tostring(index),
            BackgroundColor3 = COLORS.White,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 75,
        }, ScreenGui)
    end

    Runtime.CrosshairDot = new("Frame", {
        Name = "CrosshairDot",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(3, 3),
        BackgroundColor3 = COLORS.White,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 76,
    }, ScreenGui)
    corner(Runtime.CrosshairDot, 4)

    Runtime.Toast = new("Frame", {
        Name = "EMPYRE_Toast",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(310, 42),
        Position = UDim2.new(0.5, 0, 0, -54),
        BackgroundColor3 = COLORS.Background,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 90,
    }, ScreenGui)
    corner(Runtime.Toast, 8)
    stroke(Runtime.Toast, 0.3, 1, COLORS.Border)

    Runtime.ToastText = text(
        Runtime.Toast,
        "",
        10,
        COLORS.White,
        Enum.Font.GothamBold,
        Enum.TextXAlignment.Center
    )
    Runtime.ToastText.Size = UDim2.fromScale(1, 1)
    Runtime.ToastText.ZIndex = 91
end

function Runtime.Notify(message)
    if not Runtime.Toast or not Runtime.ToastText then
        return
    end

    Runtime.ToastToken += 1
    local token = Runtime.ToastToken

    Runtime.ToastText.Text = tostring(message)
    tween(Runtime.Toast, {
        Position = UDim2.new(0.5, 0, 0, 12),
    }, 0.16)

    task.delay(1.5, function()
        if token ~= Runtime.ToastToken or not Runtime.Toast then
            return
        end

        tween(Runtime.Toast, {
            Position = UDim2.new(0.5, 0, 0, -54),
        }, 0.18)
    end)
end

function Runtime.UpdateCrosshair(point)
    local visible = CONFIG.CustomCrosshair
        and Camera ~= nil
        and point ~= nil

    if not visible then
        if Runtime.CrosshairVisible then
            Runtime.CrosshairVisible = false

            for _, part in ipairs(Runtime.CrosshairParts) do
                part.Visible = false
            end

            if Runtime.CrosshairDot then
                Runtime.CrosshairDot.Visible = false
            end
        end

        return
    end

    if not Runtime.CrosshairVisible then
        Runtime.CrosshairVisible = true

        for _, part in ipairs(Runtime.CrosshairParts) do
            part.Visible = true
        end

        if Runtime.CrosshairDot then
            Runtime.CrosshairDot.Visible = true
        end
    end

    local size = math.max(2, CONFIG.CrosshairSize)
    local gap = math.max(0, CONFIG.CrosshairGap)
    local thickness = math.max(1, CONFIG.CrosshairThickness)
    local colour = currentTarget
        and Color3.fromRGB(70, 255, 120)
        or COLORS.White

    local left = Runtime.CrosshairParts[1]
    local right = Runtime.CrosshairParts[2]
    local top = Runtime.CrosshairParts[3]
    local bottom = Runtime.CrosshairParts[4]

    left.BackgroundColor3 = colour
    right.BackgroundColor3 = colour
    top.BackgroundColor3 = colour
    bottom.BackgroundColor3 = colour
    Runtime.CrosshairDot.BackgroundColor3 = colour

    left.Size = UDim2.fromOffset(size, thickness)
    left.Position = UDim2.fromOffset(
        math.round(point.X - gap - size),
        math.round(point.Y - thickness * 0.5)
    )

    right.Size = UDim2.fromOffset(size, thickness)
    right.Position = UDim2.fromOffset(
        math.round(point.X + gap),
        math.round(point.Y - thickness * 0.5)
    )

    top.Size = UDim2.fromOffset(thickness, size)
    top.Position = UDim2.fromOffset(
        math.round(point.X - thickness * 0.5),
        math.round(point.Y - gap - size)
    )

    bottom.Size = UDim2.fromOffset(thickness, size)
    bottom.Position = UDim2.fromOffset(
        math.round(point.X - thickness * 0.5),
        math.round(point.Y + gap)
    )

    Runtime.CrosshairDot.Position = UDim2.fromOffset(
        math.round(point.X),
        math.round(point.Y)
    )
end

Runtime.CreateOverlayExtras()

local PerformanceHud = new("Frame", {
    Name = "PerformanceHud",
    AnchorPoint = Vector2.new(1, 0),
    Size = UDim2.fromOffset(242, 34),
    Position = UDim2.new(1, -12, 0, 12),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    ZIndex = 80,
}, ScreenGui)
corner(PerformanceHud, 8)
stroke(PerformanceHud, 0.35, 1, COLORS.Border)

local PerformanceDot = new("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.new(0, 12, 0.5, 0),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
    ZIndex = 81,
}, PerformanceHud)
corner(PerformanceDot, 7)

local PerformanceText = text(
    PerformanceHud,
    "FPS --  •  PING -- ms",
    10,
    COLORS.White,
    Enum.Font.GothamBold,
    Enum.TextXAlignment.Left
)
PerformanceText.Size = UDim2.new(1, -31, 1, 0)
PerformanceText.Position = UDim2.fromOffset(27, 0)
PerformanceText.ZIndex = 81

local Root = new("Frame", {
    Name = "Root",
    Size = UDim2.fromOffset(700, 490),
    Position = UDim2.new(0, 38, 0.5, -245),
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, ScreenGui)

local RootScale = new("UIScale", {
    Scale = 1,
}, Root)

corner(Root, 15)
stroke(Root, 0.12, 1, Color3.fromRGB(95, 95, 95))

local TopLine = new("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
    ZIndex = 10,
}, Root)

local Sidebar = new("Frame", {
    Size = UDim2.fromOffset(182, 488),
    Position = UDim2.fromOffset(0, 2),
    BackgroundColor3 = COLORS.Sidebar,
    BorderSizePixel = 0,
}, Root)

new("Frame", {
    Size = UDim2.new(0, 1, 1, -24),
    Position = UDim2.new(1, -1, 0, 12),
    BackgroundColor3 = COLORS.Border,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
}, Sidebar)

local Brand = new("Frame", {
    Size = UDim2.new(1, -24, 0, 82),
    Position = UDim2.fromOffset(12, 14),
    BackgroundTransparency = 1,
}, Sidebar)

local Logo = new("Frame", {
    Size = UDim2.fromOffset(50, 50),
    Position = UDim2.fromOffset(0, 5),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
}, Brand)
corner(Logo, 12)
stroke(Logo, 0.35, 1, Color3.fromRGB(255, 255, 255))

local Crown = text(Logo, "", 18, COLORS.Black, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
Crown.Size = UDim2.new(1, 0, 0, 24)
Crown.Position = UDim2.fromOffset(0, 0)

local Emblem = text(Logo, "E", 22, COLORS.Black, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
Emblem.Size = UDim2.fromScale(1, 1)
Emblem.Position = UDim2.fromOffset(0, 0)

local BrandTitle = text(Brand, "EMPYRE", 19, COLORS.White, Enum.Font.GothamBlack)
BrandTitle.Size = UDim2.fromOffset(94, 24)
BrandTitle.Position = UDim2.fromOffset(62, 10)

local BrandSub = text(Brand, "v4.2", 9, COLORS.Muted, Enum.Font.GothamBold)
BrandSub.Size = UDim2.fromOffset(100, 18)
BrandSub.Position = UDim2.fromOffset(63, 34)

local Navigation = new("Frame", {
    Size = UDim2.new(1, -20, 0, 282),
    Position = UDim2.fromOffset(10, 104),
    BackgroundTransparency = 1,
}, Sidebar)

new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Navigation)

local PageTitle
local PageSubtitle

local function setTab(name)
    currentTab = name

    for tabName, page in pairs(tabPages) do
        page.Visible = tabName == name
    end

    for tabName, tab in pairs(tabButtons) do
        local active = tabName == name

        tween(tab, {
            BackgroundColor3 = active and COLORS.White or COLORS.Surface
        }, 0.14)

        tween(tab.ActiveBar, {
            BackgroundTransparency = active and 0 or 1
        }, 0.14)

        tween(tab.Symbol, {
            TextColor3 = active and COLORS.Black or COLORS.Muted
        }, 0.14)

        tween(tab.Label, {
            TextColor3 = active and COLORS.Black or COLORS.Muted
        }, 0.14)
    end

    if PageTitle and PageSubtitle then
        local titles = {
            Aim = {"Aim", "Visible-target camera control"},
            Visuals = {"Visuals", "Line-of-sight player overlay"},
            Radar = {"Radar", "Nearby player positions"},
            Settings = {"Settings", "Controls and account sync"},
            Diagnostics = {"Diagnostics", "Live performance and system state"},
        }

        PageTitle.Text = titles[name][1]
        PageSubtitle.Text = titles[name][2]
    end
end

local function makeTab(name, symbol)
    local Tab = button(Navigation, "")
    Tab.Name = name
    Tab.Size = UDim2.new(1, 0, 0, 46)
    Tab.BackgroundColor3 = COLORS.Surface
    corner(Tab, 9)

    local ActiveBar = new("Frame", {
        Name = "ActiveBar",
        Size = UDim2.fromOffset(3, 22),
        Position = UDim2.fromOffset(0, 12),
        BackgroundColor3 = COLORS.Black,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, Tab)
    corner(ActiveBar, 3)

    local Symbol = text(Tab, symbol, 15, COLORS.Muted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    Symbol.Name = "Symbol"
    Symbol.Visible = false
    Symbol.Size = UDim2.fromOffset(0, 0)

    local Label = text(Tab, string.upper(name), 11, COLORS.Muted, Enum.Font.GothamBold)
    Label.Name = "Label"
    Label.Size = UDim2.new(1, -28, 1, 0)
    Label.Position = UDim2.fromOffset(16, 0)

    tabButtons[name] = Tab

    Tab.MouseButton1Click:Connect(function()
        setTab(name)
    end)
end

makeTab("Aim", "")
makeTab("Visuals", "")
makeTab("Radar", "")
makeTab("Settings", "")
makeTab("Diagnostics", "")

local SidebarStatus = new("Frame", {
    Size = UDim2.new(1, -20, 0, 64),
    Position = UDim2.new(0, 10, 1, -78),
    BackgroundColor3 = COLORS.Surface,
    BorderSizePixel = 0,
}, Sidebar)
corner(SidebarStatus, 10)
stroke(SidebarStatus, 0.65, 1)

local StatusDot = new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.fromOffset(14, 16),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
}, SidebarStatus)
corner(StatusDot, 8)

local StatusTitle = text(SidebarStatus, "EMPYRE READY", 9, COLORS.White, Enum.Font.GothamBold)
StatusTitle.Size = UDim2.new(1, -38, 0, 20)
StatusTitle.Position = UDim2.fromOffset(31, 8)

local StatusDetail = text(SidebarStatus, "RIGHT ALT TO HIDE", 8, COLORS.Dim, Enum.Font.GothamBold)
StatusDetail.Size = UDim2.new(1, -28, 0, 18)
StatusDetail.Position = UDim2.fromOffset(14, 32)

local ReopenButton

local lastViewportSize = Vector2.new(0, 0)

local function updateDeviceLayout()
    Camera = Workspace.CurrentCamera

    if not Camera then
        return
    end

    local viewport = Camera.ViewportSize
    local touchLayout = UserInputService.TouchEnabled

    if touchLayout then
        local widthScale = math.max(viewport.X - 18, 1) / 700
        local heightScale = math.max(viewport.Y - 110, 1) / 490

        RootScale.Scale = math.clamp(
            math.min(widthScale, heightScale),
            0.42,
            1
        )

        Root.AnchorPoint = Vector2.new(0.5, 0.5)
        Root.Position = UDim2.new(0.5, 0, 0.5, -34)

        StatusDetail.Text = "TOUCH"
    else
        RootScale.Scale = 1
        Root.AnchorPoint = Vector2.new(0, 0)

        if Root.Position.X.Scale == 0.5 and Root.Position.Y.Scale == 0.5 then
            Root.Position = UDim2.new(0, 38, 0.5, -245)
        end

        StatusDetail.Text = "DESKTOP"
    end

    if QuickControls and QuickControlsScale then
        QuickControls.Visible = true

        if touchLayout then
            QuickControlsScale.Scale = math.clamp(
                (viewport.X - 12) / 544,
                0.68,
                0.92
            )
        else
            QuickControlsScale.Scale = 1
        end
        QuickControls.Position = touchLayout
            and UDim2.new(0.5, 0, 1, -72)
            or UDim2.new(0.5, 0, 1, -18)
    end

    if ReopenButton then
        ReopenButton.Size = touchLayout
            and UDim2.fromOffset(48, 48)
            or UDim2.fromOffset(42, 42)
        ReopenButton.Position = UDim2.new(1, -16, 0, 16)
    end

    lastViewportSize = viewport
end

local MainArea = new("Frame", {
    Size = UDim2.new(1, -182, 1, 0),
    Position = UDim2.fromOffset(182, 0),
    BackgroundTransparency = 1,
}, Root)

local Header = new("Frame", {
    Size = UDim2.new(1, -32, 0, 72),
    Position = UDim2.fromOffset(16, 12),
    BackgroundTransparency = 1,
}, MainArea)
Header.Active = true

PageTitle = text(Header, "Aim", 22, COLORS.White, Enum.Font.GothamBlack)
PageTitle.Size = UDim2.fromOffset(260, 30)
PageTitle.Position = UDim2.fromOffset(2, 6)

PageSubtitle = text(Header, "", 10, COLORS.Muted, Enum.Font.GothamMedium)
PageSubtitle.Size = UDim2.fromOffset(330, 18)
PageSubtitle.Position = UDim2.fromOffset(3, 37)

local HeaderDivider = new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = COLORS.Border,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
}, Header)

local LockBadge = new("Frame", {
    Size = UDim2.fromOffset(128, 32),
    Position = UDim2.new(1, -174, 0, 13),
    BackgroundColor3 = COLORS.Surface2,
    BorderSizePixel = 0,
}, Header)
corner(LockBadge, 8)
stroke(LockBadge, 0.6, 1)

local BadgeDot = new("Frame", {
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.fromOffset(13, 13),
    BackgroundColor3 = COLORS.Dim,
    BorderSizePixel = 0,
}, LockBadge)
corner(BadgeDot, 7)

local BadgeText = text(LockBadge, "IDLE", 9, COLORS.Muted, Enum.Font.GothamBold)
BadgeText.Size = UDim2.new(1, -32, 1, 0)
BadgeText.Position = UDim2.fromOffset(28, 0)

local CloseButton = button(Header, "×")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.fromOffset(32, 32)
CloseButton.Position = UDim2.new(1, -34, 0, 13)
CloseButton.BackgroundColor3 = COLORS.Surface2
CloseButton.TextColor3 = COLORS.White
CloseButton.TextSize = 18
CloseButton.ZIndex = 20
corner(CloseButton, 8)
stroke(CloseButton, 0.6, 1)

ReopenButton = button(ScreenGui, "E")
ReopenButton.Name = "ReopenButton"
ReopenButton.AnchorPoint = Vector2.new(1, 0)
ReopenButton.Size = UDim2.fromOffset(44, 44)
ReopenButton.Position = UDim2.new(1, -18, 0, 18)
ReopenButton.BackgroundColor3 = COLORS.White
ReopenButton.TextColor3 = COLORS.Black
ReopenButton.TextSize = 18
ReopenButton.Visible = false
ReopenButton.ZIndex = 50
corner(ReopenButton, 11)
stroke(ReopenButton, 0.25, 1, COLORS.White)

local function setInterfaceVisible(visible)
    Root.Visible = visible
    ReopenButton.Visible = not visible
end

CloseButton.MouseButton1Click:Connect(function()
    setInterfaceVisible(false)
end)

ReopenButton.MouseButton1Click:Connect(function()
    setInterfaceVisible(true)
end)

QuickControls = new("Frame", {
    Name = "QuickControls",
    AnchorPoint = Vector2.new(0.5, 1),
    Size = UDim2.fromOffset(544, 46),
    Position = UDim2.new(0.5, 0, 1, -18),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 60,
}, ScreenGui)
corner(QuickControls, 7)
stroke(QuickControls, 0.25, 1, COLORS.Border)

QuickControlsScale = new("UIScale", {
    Scale = 1,
}, QuickControls)

new("UIPadding", {
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 5),
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5),
}, QuickControls)

new("UIListLayout", {
    Padding = UDim.new(0, 5),
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, QuickControls)

local quickButtonRefreshers = {}

local function createQuickButton(label, getter, callback, order)
    local QuickButton = button(QuickControls, label)
    QuickButton.Name = label
    QuickButton.Size = UDim2.fromOffset(52, 34)
    QuickButton.LayoutOrder = order
    QuickButton.BackgroundColor3 = COLORS.Surface2
    QuickButton.TextColor3 = COLORS.White
    QuickButton.TextSize = 9
    QuickButton.ZIndex = 61
    corner(QuickButton, 5)

    local function refresh()
        if getter then
            local enabled = getter()
            QuickButton.BackgroundColor3 = enabled and COLORS.White or COLORS.Surface2
            QuickButton.TextColor3 = enabled and COLORS.Black or COLORS.White
            QuickButton.TextTransparency = enabled and 0 or 0.08
        else
            QuickButton.BackgroundColor3 = COLORS.Surface2
            QuickButton.TextColor3 = COLORS.White
        end
    end

    QuickButton.MouseButton1Click:Connect(function()
        callback()

        for _, update in ipairs(quickButtonRefreshers) do
            update()
        end
    end)

    table.insert(quickButtonRefreshers, refresh)
    refresh()
    return QuickButton
end

createQuickButton(
    "AIM",
    function()
        return CONFIG.AimEnabled and aimActive
    end,
    function()
        local enabled = not (CONFIG.AimEnabled and aimActive)
        CONFIG.AimEnabled = enabled
        aimActive = enabled

        if not enabled then
            currentTarget = nil
        end

        changed()
    end,
    1
)

createQuickButton(
    "ESP",
    function()
        return CONFIG.ESPEnabled
    end,
    function()
        CONFIG.ESPEnabled = not CONFIG.ESPEnabled
        changed()
    end,
    2
)

createQuickButton(
    "RADAR",
    function()
        return CONFIG.RadarEnabled
    end,
    function()
        CONFIG.RadarEnabled = not CONFIG.RadarEnabled
        changed()
    end,
    3
)

createQuickButton(
    "NEXT",
    nil,
    function()
        if switchTarget then
            switchTarget()
        end
    end,
    4
)

createQuickButton(
    "AUTO",
    function()
        return CONFIG.VisibleTargetsOnly
    end,
    function()
        CONFIG.VisibleTargetsOnly = not CONFIG.VisibleTargetsOnly
        currentTarget = nil
        changed()
    end,
    5
)

createQuickButton(
    "FIRE",
    function()
        return CONFIG.AutoShootEnabled
    end,
    function()
        CONFIG.AutoShootEnabled = not CONFIG.AutoShootEnabled
        changed()
    end,
    6
)

createQuickButton(
    "SNAP",
    function()
        return CONFIG.AimStyle == "Snap"
    end,
    function()
        CONFIG.AimStyle =
            CONFIG.AimStyle == "Snap" and "Hybrid" or "Snap"
        lastRenderedTarget = nil
        changed()
    end,
    7
)

createQuickButton(
    "SPIN",
    function()
        return CONFIG.SpinbotEnabled
    end,
    function()
        CONFIG.SpinbotEnabled = not CONFIG.SpinbotEnabled
        Runtime.Notify(
            CONFIG.SpinbotEnabled and "VISUAL SPIN ON" or "VISUAL SPIN OFF"
        )
        changed()
    end,
    8
)

createQuickButton(
    "MENU",
    nil,
    function()
        setInterfaceVisible(not Root.Visible)
    end,
    9
)

function Runtime.RefreshQuickButtons()
    for _, refresh in ipairs(quickButtonRefreshers) do
        refresh()
    end
end

function Runtime.Panic()
    CONFIG.AimEnabled = false
    CONFIG.ESPEnabled = false
    CONFIG.RadarEnabled = false
    CONFIG.AutoShootEnabled = false
    CONFIG.TriggerCheck = false
    CONFIG.SpinbotEnabled = false

    aimActive = false
    currentTarget = nil
    lastRenderedTarget = nil
    targetLastValidAt = -math.huge

    Runtime.ResetSpinbot()
    Runtime.RefreshQuickButtons()

    for _, refresh in ipairs(refreshers) do
        refresh()
    end

    Runtime.Notify("PANIC: ALL FEATURES DISABLED")
end

function Runtime.ApplyPreset(name)
    if name == "SNAP" then
        CONFIG.AimStyle = "Snap"
        CONFIG.TargetPart = "Head"
        CONFIG.StrictHead = true
        CONFIG.SnapOnAcquire = true
        CONFIG.SnapUsePrediction = false
        CONFIG.AimDeadzone = 0
        CONFIG.SwitchCooldown = 0.06
        CONFIG.LockGrace = 0.12
        CONFIG.LockFOVMultiplier = 1.45
        CONFIG.FOV = 220
        CONFIG.StickyTarget = true
        Runtime.Notify("SNAP PRESET APPLIED")
    elseif name == "BALANCED" then
        CONFIG.AimStyle = "Hybrid"
        CONFIG.TargetPart = "Head"
        CONFIG.StrictHead = true
        CONFIG.SnapOnAcquire = true
        CONFIG.SnapUsePrediction = true
        CONFIG.AimDeadzone = 1.5
        CONFIG.SwitchCooldown = 0.12
        CONFIG.LockGrace = 0.16
        CONFIG.LockFOVMultiplier = 1.35
        CONFIG.FOV = 180
        CONFIG.StickyTarget = true
        Runtime.Notify("BALANCED PRESET APPLIED")
    elseif name == "FPS" then
        CONFIG.PerformanceMode = true
        CONFIG.AdaptiveVisualQuality = true
        CONFIG.MaxVisualTargets = 12
        CONFIG.SkeletonESP = false
        CONFIG.Chams = false
        CONFIG.HitboxVisualizer = false
        CONFIG.Tracers = false
        CONFIG.DistanceFade = true
        CONFIG.RadarEnabled = false
        Runtime.Notify("FPS PRESET APPLIED")
    end

    currentTarget = nil
    lastRenderedTarget = nil
    targetLastValidAt = -math.huge
    changed()
    Runtime.RefreshQuickButtons()
end

local Pages = new("Frame", {
    Size = UDim2.new(1, -32, 1, -94),
    Position = UDim2.fromOffset(16, 84),
    BackgroundTransparency = 1,
}, MainArea)

local function createPage(name)
    local Page = new("ScrollingFrame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.White,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        Visible = false,
    }, Pages)

    new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, Page)

    new("UIPadding", {
        PaddingRight = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 8),
    }, Page)

    tabPages[name] = Page
    return Page
end

local AimPage = createPage("Aim")
local VisualsPage = createPage("Visuals")
local RadarPage = createPage("Radar")
local SettingsPage = createPage("Settings")
Runtime.DiagnosticsPage = createPage("Diagnostics")

local function createSection(page, titleValue)
    local Section = new("Frame", {
        Size = UDim2.new(1, 0, 0, 27),
        BackgroundTransparency = 1,
    }, page)

    local Label = text(Section, string.upper(titleValue), 9, COLORS.Dim, Enum.Font.GothamBold)
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.Position = UDim2.fromOffset(2, 0)

    return Section
end

local function createCard(page, height)
    local Card = new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 56),
        BackgroundColor3 = COLORS.Surface,
        BorderSizePixel = 0,
    }, page)
    corner(Card, 10)
    stroke(Card, 0.6, 1)
    return Card
end

local function createToggle(page, titleValue, description, getter, setter)
    local Card = createCard(page, 58)

    local Accent = new("Frame", {
        Size = UDim2.fromOffset(2, 30),
        Position = UDim2.fromOffset(0, 14),
        BackgroundColor3 = COLORS.White,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
    }, Card)
    corner(Accent, 2)

    local Title = text(Card, titleValue, 12, COLORS.White, Enum.Font.GothamBold)
    Title.Size = UDim2.new(1, -104, 0, 22)
    Title.Position = UDim2.fromOffset(14, 8)

    local Description = text(Card, description, 9, COLORS.Muted, Enum.Font.GothamMedium)
    Description.Size = UDim2.new(1, -106, 0, 18)
    Description.Position = UDim2.fromOffset(14, 31)

    local Toggle = button(Card, "OFF")
    Toggle.Size = UDim2.fromOffset(68, 30)
    Toggle.Position = UDim2.new(1, -82, 0.5, -15)
    Toggle.BackgroundColor3 = COLORS.Surface3
    Toggle.TextColor3 = COLORS.Muted
    Toggle.TextSize = 9
    corner(Toggle, 7)
    stroke(Toggle, 0.7, 1)

    local function refresh()
        local enabled = getter()

        Toggle.Text = enabled and "ON" or "OFF"

        tween(Toggle, {
            BackgroundColor3 = enabled and COLORS.White or COLORS.Surface3,
            TextColor3 = enabled and COLORS.Black or COLORS.Muted,
        }, 0.14)

        tween(Accent, {
            BackgroundTransparency = enabled and 0.12 or 0.82,
        }, 0.14)
    end

    Toggle.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh()
        changed()
    end)

    table.insert(refreshers, refresh)
    refresh()
    return Card
end

local function createSelector(page, titleValue, description, values, getter, setter)
    local Card = createCard(page, 62)

    local Title = text(Card, titleValue, 12, COLORS.White, Enum.Font.GothamBold)
    Title.Size = UDim2.new(1, -230, 0, 22)
    Title.Position = UDim2.fromOffset(14, 9)

    local Description = text(Card, description, 9, COLORS.Muted, Enum.Font.GothamMedium)
    Description.Size = UDim2.new(1, -230, 0, 18)
    Description.Position = UDim2.fromOffset(14, 33)

    local Holder = new("Frame", {
        Size = UDim2.fromOffset(210, 34),
        Position = UDim2.new(1, -224, 0.5, -17),
        BackgroundColor3 = COLORS.Surface2,
        BorderSizePixel = 0,
    }, Card)
    corner(Holder, 8)

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, Holder)

    local selectorButtons = {}

    local function refresh()
        local selected = getter()

        for value, selectorButton in pairs(selectorButtons) do
            local active = value == selected
            tween(selectorButton, {
                BackgroundColor3 = active and COLORS.White or COLORS.Surface3,
                TextColor3 = active and COLORS.Black or COLORS.Muted,
            }, 0.14)
        end
    end

    for _, value in ipairs(values) do
        local SelectorButton = button(Holder, value)
        SelectorButton.Size = UDim2.new(1 / #values, -5, 1, -6)
        SelectorButton.BackgroundColor3 = COLORS.Surface3
        SelectorButton.TextColor3 = COLORS.Muted
        SelectorButton.TextSize = 9
        corner(SelectorButton, 6)
        selectorButtons[value] = SelectorButton

        SelectorButton.MouseButton1Click:Connect(function()
            setter(value)
            refresh()
            changed()
        end)
    end

    table.insert(refreshers, refresh)
    refresh()
    return Card
end

local function createStepper(page, titleValue, description, getter, setter, minimum, maximum, step, formatter)
    local Card = createCard(page, 60)

    local Title = text(Card, titleValue, 12, COLORS.White, Enum.Font.GothamBold)
    Title.Size = UDim2.new(1, -185, 0, 22)
    Title.Position = UDim2.fromOffset(14, 8)

    local Description = text(Card, description, 9, COLORS.Muted, Enum.Font.GothamMedium)
    Description.Size = UDim2.new(1, -185, 0, 18)
    Description.Position = UDim2.fromOffset(14, 32)

    local Minus = button(Card, "−")
    Minus.Size = UDim2.fromOffset(30, 30)
    Minus.Position = UDim2.new(1, -160, 0.5, -15)
    Minus.BackgroundColor3 = COLORS.Surface3
    Minus.TextSize = 15
    corner(Minus, 8)

    local Value = new("TextLabel", {
        Size = UDim2.fromOffset(82, 30),
        Position = UDim2.new(1, -125, 0.5, -15),
        BackgroundColor3 = COLORS.Surface2,
        BorderSizePixel = 0,
        TextColor3 = COLORS.White,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
    }, Card)
    corner(Value, 8)

    local Plus = button(Card, "+")
    Plus.Size = UDim2.fromOffset(30, 30)
    Plus.Position = UDim2.new(1, -38, 0.5, -15)
    Plus.BackgroundColor3 = COLORS.Surface3
    Plus.TextSize = 14
    corner(Plus, 8)

    local function refresh()
        Value.Text = formatter and formatter(getter()) or tostring(getter())
    end

    Minus.MouseButton1Click:Connect(function()
        setter(math.max(minimum, getter() - step))
        refresh()
        changed()
    end)

    Plus.MouseButton1Click:Connect(function()
        setter(math.min(maximum, getter() + step))
        refresh()
        changed()
    end)

    table.insert(refreshers, refresh)
    refresh()
    return Card
end

local function createBind(page, titleValue, description, action)
    local Card = createCard(page, 58)

    local Title = text(Card, titleValue, 12, COLORS.White, Enum.Font.GothamBold)
    Title.Size = UDim2.new(1, -120, 0, 22)
    Title.Position = UDim2.fromOffset(14, 8)

    local Description = text(Card, description, 9, COLORS.Muted, Enum.Font.GothamMedium)
    Description.Size = UDim2.new(1, -120, 0, 18)
    Description.Position = UDim2.fromOffset(14, 31)

    local Bind = button(Card, BINDS[action].Name)
    Bind.Size = UDim2.fromOffset(94, 32)
    Bind.Position = UDim2.new(1, -108, 0.5, -16)
    Bind.BackgroundColor3 = COLORS.Surface2
    Bind.TextColor3 = COLORS.Muted
    Bind.TextSize = 9
    corner(Bind, 8)
    stroke(Bind, 0.65, 1)

    bindButtons[action] = Bind

    Bind.MouseButton1Click:Connect(function()
        captureAction = action
        Bind.Text = "PRESS KEY"
        Bind.TextColor3 = COLORS.White
        tween(Bind, {BackgroundColor3 = COLORS.Surface3}, 0.14)
    end)

    table.insert(refreshers, function()
        Bind.Text = BINDS[action].Name
    end)

    return Card
end

local function createActionButton(page, titleValue, description, buttonText, callback)
    local Card = createCard(page, 58)

    local Title = text(Card, titleValue, 12, COLORS.White, Enum.Font.GothamBold)
    Title.Size = UDim2.new(1, -130, 0, 22)
    Title.Position = UDim2.fromOffset(14, 8)

    local Description = text(Card, description, 9, COLORS.Muted, Enum.Font.GothamMedium)
    Description.Size = UDim2.new(1, -130, 0, 18)
    Description.Position = UDim2.fromOffset(14, 31)

    local Action = button(Card, buttonText)
    Action.Size = UDim2.fromOffset(104, 32)
    Action.Position = UDim2.new(1, -118, 0.5, -16)
    Action.BackgroundColor3 = COLORS.White
    Action.TextColor3 = COLORS.Black
    Action.TextSize = 9
    corner(Action, 8)

    Action.MouseButton1Click:Connect(callback)
    return Card
end

createSection(AimPage, "Core")
createToggle(
    AimPage,
    "Aim lock",
    "Toggle aim lock",
    function() return CONFIG.AimEnabled end,
    function(value)
        CONFIG.AimEnabled = value

        if not value then
            aimActive = false
            currentTarget = nil
        end
    end
)

createSelector(
    AimPage,
    "Activation",
    "Aim mode",
    {"Toggle", "Hold"},
    function() return CONFIG.AimMode end,
    function(value)
        CONFIG.AimMode = value
        aimActive = false
        currentTarget = nil
    end
)

createSelector(
    AimPage,
    "Aim style",
    "Smooth, Hybrid, or immediate Snap",
    {"Smooth", "Hybrid", "Snap"},
    function() return CONFIG.AimStyle end,
    function(value)
        CONFIG.AimStyle = value
        lastRenderedTarget = nil
    end
)

createSelector(
    AimPage,
    "Target part",
    "Target part",
    {"Head", "Upper torso", "Lower torso", "Arms", "Legs", "Torso", "Closest"},
    function() return CONFIG.TargetPart end,
    function(value)
        CONFIG.TargetPart = value
        currentTarget = nil
    end
)

createToggle(
    AimPage,
    "Strict head",
    "Only acquire targets with a valid Head part",
    function() return CONFIG.StrictHead end,
    function(value)
        CONFIG.StrictHead = value
        currentTarget = nil
    end
)

createToggle(
    AimPage,
    "Snap on acquire",
    "Centre the first frame a target is acquired",
    function() return CONFIG.SnapOnAcquire end,
    function(value)
        CONFIG.SnapOnAcquire = value
        lastRenderedTarget = nil
    end
)

createToggle(
    AimPage,
    "Snap prediction",
    "Lead moving heads while using Snap mode",
    function() return CONFIG.SnapUsePrediction end,
    function(value) CONFIG.SnapUsePrediction = value end
)

createSelector(
    AimPage,
    "Priority",
    "Target priority",
    {"Cursor", "Health", "Range in studs", "Threat", "Recent"},
    function() return CONFIG.TargetPriority end,
    function(value)
        CONFIG.TargetPriority = value
        currentTarget = nil
    end
)

createSection(AimPage, "Behaviour")
createToggle(
    AimPage,
    "Wall check",
    "Require a clear line of sight",
    function() return CONFIG.WallCheck end,
    function(value)
        CONFIG.WallCheck = value
        currentTarget = nil
    end
)

createToggle(
    AimPage,
    "Team check",
    "Ignore teammates for aim and ESP",
    function() return CONFIG.TeamCheck end,
    function(value)
        CONFIG.TeamCheck = value
        currentTarget = nil
    end
)

createToggle(
    AimPage,
    "Bots",
    "Include NPC humanoids in aim, ESP, radar, and auto fire",
    function() return CONFIG.BotsEnabled end,
    function(value)
        CONFIG.BotsEnabled = value
        currentTarget = nil
    end
)

createToggle(
    AimPage,
    "Prediction",
    "Target prediction",
    function() return CONFIG.Prediction end,
    function(value) CONFIG.Prediction = value end
)

createToggle(
    AimPage,
    "Ping compensation",
    "Add measured network delay to prediction",
    function() return CONFIG.PredictionPingCompensation end,
    function(value) CONFIG.PredictionPingCompensation = value end
)

createToggle(
    AimPage,
    "Adaptive smoothing",
    "Keep aim speed consistent at different FPS",
    function() return CONFIG.AdaptiveSmoothing end,
    function(value) CONFIG.AdaptiveSmoothing = value end
)

createToggle(
    AimPage,
    "Sticky target",
    "Hold the current target through tiny interruptions",
    function() return CONFIG.StickyTarget end,
    function(value)
        CONFIG.StickyTarget = value
        targetLastValidAt = -math.huge
    end
)

createToggle(
    AimPage,
    "Auto target switch",
    "Move to the next valid player",
    function() return CONFIG.AutoSwitch end,
    function(value) CONFIG.AutoSwitch = value end
)

createToggle(
    AimPage,
    "Visible targets only",
    "Skip players blocked by walls",
    function() return CONFIG.VisibleTargetsOnly end,
    function(value)
        CONFIG.VisibleTargetsOnly = value
        currentTarget = nil
    end
)

createToggle(
    AimPage,
    "Auto fire",
    "Shoot a visible enemy under the crosshair",
    function() return CONFIG.AutoShootEnabled end,
    function(value) CONFIG.AutoShootEnabled = value end
)

createStepper(
    AimPage,
    "Fire delay",
    "Seconds between automatic shots",
    function() return CONFIG.AutoShootDelay end,
    function(value) CONFIG.AutoShootDelay = value end,
    0.02,
    1,
    0.01,
    function(value) return string.format("%.2f s", value) end
)

createSection(AimPage, "Tuning")
createStepper(
    AimPage,
    "Field of view",
    "Aim radius",
    function() return CONFIG.FOV end,
    function(value) CONFIG.FOV = value end,
    50,
    500,
    10
)

createStepper(
    AimPage,
    "Smoothness",
    "Aim speed",
    function() return CONFIG.Smoothness end,
    function(value) CONFIG.Smoothness = value end,
    0.02,
    1,
    0.02,
    function(value) return string.format("%.2f", value) end
)

createStepper(
    AimPage,
    "Maximum distance",
    "Max range",
    function() return CONFIG.MaxDistance end,
    function(value) CONFIG.MaxDistance = value end,
    50,
    2500,
    50,
    function(value) return tostring(value) .. " studs" end
)

createStepper(
    AimPage,
    "Prediction amount",
    "Prediction",
    function() return CONFIG.PredictionAmount end,
    function(value) CONFIG.PredictionAmount = value end,
    0,
    0.5,
    0.01,
    function(value) return string.format("%.2f", value) end
)

createStepper(
    AimPage,
    "Lock grace",
    "Seconds allowed for a tiny target interruption",
    function() return CONFIG.LockGrace end,
    function(value) CONFIG.LockGrace = value end,
    0,
    0.5,
    0.01,
    function(value) return string.format("%.2f s", value) end
)

createStepper(
    AimPage,
    "Locked FOV",
    "Extra FOV allowed after a target is acquired",
    function() return CONFIG.LockFOVMultiplier end,
    function(value) CONFIG.LockFOVMultiplier = value end,
    1,
    2,
    0.05,
    function(value) return string.format("%.2fx", value) end
)

createStepper(
    AimPage,
    "Aim deadzone",
    "Ignore tiny camera corrections",
    function() return CONFIG.AimDeadzone end,
    function(value) CONFIG.AimDeadzone = value end,
    0,
    8,
    0.5,
    function(value) return string.format("%.1f px", value) end
)

createStepper(
    AimPage,
    "Head offset",
    "Vertical adjustment applied to the selected head",
    function() return CONFIG.HeadOffset end,
    function(value) CONFIG.HeadOffset = value end,
    -1,
    1,
    0.05,
    function(value) return string.format("%.2f studs", value) end
)

createStepper(
    AimPage,
    "Snap threshold",
    "Hybrid snaps above this screen distance",
    function() return CONFIG.SnapThreshold end,
    function(value) CONFIG.SnapThreshold = value end,
    10,
    300,
    10,
    function(value) return tostring(value) .. " px" end
)

createStepper(
    AimPage,
    "Switch cooldown",
    "Minimum time before changing targets",
    function() return CONFIG.SwitchCooldown end,
    function(value) CONFIG.SwitchCooldown = value end,
    0,
    0.6,
    0.02,
    function(value) return string.format("%.2f s", value) end
)

createSection(VisualsPage, "Master")
createToggle(
    VisualsPage,
    "Player ESP",
    "Master visual overlay",
    function() return CONFIG.ESPEnabled end,
    function(value) CONFIG.ESPEnabled = value end
)

createToggle(
    VisualsPage,
    "Reliable ESP",
    "Outline and player tag fallback",
    function() return CONFIG.ReliableESP end,
    function(value) CONFIG.ReliableESP = value end
)

createToggle(
    VisualsPage,
    "Team filter",
    "Hide teammates when Team Check is enabled",
    function() return CONFIG.TeamCheck end,
    function(value)
        CONFIG.TeamCheck = value
        currentTarget = nil
    end
)

local ESPStatusCard = createCard(VisualsPage, 72)

local ESPStatusTitle = text(
    ESPStatusCard,
    "VISIBILITY STATUS",
    9,
    COLORS.Dim,
    Enum.Font.GothamBold
)
ESPStatusTitle.Size = UDim2.new(1, -28, 0, 18)
ESPStatusTitle.Position = UDim2.fromOffset(14, 8)

local VisibleDot = new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.fromOffset(15, 36),
    BackgroundColor3 = Color3.fromRGB(70, 255, 120),
    BorderSizePixel = 0,
}, ESPStatusCard)
corner(VisibleDot, 8)

local VisibleLabel = text(
    ESPStatusCard,
    "Visible",
    10,
    COLORS.White,
    Enum.Font.GothamMedium
)
VisibleLabel.Size = UDim2.fromOffset(92, 20)
VisibleLabel.Position = UDim2.fromOffset(31, 30)

local BlockedDot = new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.fromOffset(132, 36),
    BackgroundColor3 = Color3.fromRGB(255, 70, 70),
    BorderSizePixel = 0,
}, ESPStatusCard)
corner(BlockedDot, 8)

local BlockedLabel = text(
    ESPStatusCard,
    "Behind wall",
    10,
    COLORS.White,
    Enum.Font.GothamMedium
)
BlockedLabel.Size = UDim2.fromOffset(110, 20)
BlockedLabel.Position = UDim2.fromOffset(148, 30)

local TeamFilterLabel = text(
    ESPStatusCard,
    "TEAM FILTER FOLLOWS TEAM CHECK",
    8,
    COLORS.Muted,
    Enum.Font.GothamBold,
    Enum.TextXAlignment.Right
)
TeamFilterLabel.Size = UDim2.new(1, -280, 0, 20)
TeamFilterLabel.Position = UDim2.fromOffset(266, 30)

createSection(VisualsPage, "Overlay")
createToggle(
    VisualsPage,
    "Box ESP",
    "2D player bounds",
    function() return CONFIG.BoxESP end,
    function(value) CONFIG.BoxESP = value end
)

createToggle(
    VisualsPage,
    "Name ESP",
    "Display names above players",
    function() return CONFIG.NameESP end,
    function(value) CONFIG.NameESP = value end
)

createToggle(
    VisualsPage,
    "Health ESP",
    "Current health beside each player",
    function() return CONFIG.HealthESP end,
    function(value) CONFIG.HealthESP = value end
)

createToggle(
    VisualsPage,
    "Distance ESP",
    "Range in studs",
    function() return CONFIG.DistanceESP end,
    function(value) CONFIG.DistanceESP = value end
)

createToggle(
    VisualsPage,
    "Tracers",
    "Lines from the lower screen edge",
    function() return CONFIG.Tracers end,
    function(value) CONFIG.Tracers = value end
)

createToggle(
    VisualsPage,
    "Skeleton ESP",
    "R6 and R15 limb lines",
    function() return CONFIG.SkeletonESP end,
    function(value) CONFIG.SkeletonESP = value end
)

createToggle(
    VisualsPage,
    "Chams",
    "Filled player highlight",
    function() return CONFIG.Chams end,
    function(value) CONFIG.Chams = value end
)

createToggle(
    VisualsPage,
    "Hitbox visualizer",
    "Root-part test bounds",
    function() return CONFIG.HitboxVisualizer end,
    function(value) CONFIG.HitboxVisualizer = value end
)

createToggle(
    VisualsPage,
    "Off-screen arrows",
    "Point toward targets outside the screen",
    function() return CONFIG.OffscreenArrows end,
    function(value) CONFIG.OffscreenArrows = value end
)

createToggle(
    VisualsPage,
    "Distance fade",
    "Fade distant overlays to reduce clutter",
    function() return CONFIG.DistanceFade end,
    function(value) CONFIG.DistanceFade = value end
)

createStepper(
    VisualsPage,
    "Skeleton range",
    "Maximum range for the heavier skeleton overlay",
    function() return CONFIG.SkeletonMaxDistance end,
    function(value) CONFIG.SkeletonMaxDistance = value end,
    100,
    1000,
    50,
    function(value) return tostring(value) .. " studs" end
)

createStepper(
    VisualsPage,
    "Visual target limit",
    "Maximum nearest targets receiving full ESP",
    function() return CONFIG.MaxVisualTargets end,
    function(value) CONFIG.MaxVisualTargets = value end,
    4,
    64,
    2,
    function(value) return tostring(value) .. " targets" end
)

createSection(VisualsPage, "Indicators")
createToggle(
    VisualsPage,
    "FOV circle",
    "Show the aim radius",
    function() return CONFIG.ShowFOV end,
    function(value) CONFIG.ShowFOV = value end
)

createToggle(
    VisualsPage,
    "Target indicator",
    "Locked-player status panel",
    function() return CONFIG.ShowTargetIndicator end,
    function(value) CONFIG.ShowTargetIndicator = value end
)

createToggle(
    VisualsPage,
    "Head marker",
    "Mark the locked target's head",
    function() return CONFIG.ShowTargetMarker end,
    function(value) CONFIG.ShowTargetMarker = value end
)

createToggle(
    VisualsPage,
    "Target line",
    "Line from screen centre to the locked head",
    function() return CONFIG.ShowTargetLine end,
    function(value) CONFIG.ShowTargetLine = value end
)

createToggle(
    VisualsPage,
    "Head dots",
    "Small visible point over every valid target head",
    function() return CONFIG.HeadDotESP end,
    function(value) CONFIG.HeadDotESP = value end
)

createToggle(
    VisualsPage,
    "Target emphasis",
    "Thicker box and tagged name for the locked target",
    function() return CONFIG.TargetHighlight end,
    function(value) CONFIG.TargetHighlight = value end
)

createToggle(
    VisualsPage,
    "Trigger check",
    "Shows when the crosshair is on a player",
    function() return CONFIG.TriggerCheck end,
    function(value) CONFIG.TriggerCheck = value end
)

createSection(RadarPage, "Radar")
createToggle(
    RadarPage,
    "Enable radar",
    "Show nearby valid players",
    function() return CONFIG.RadarEnabled end,
    function(value) CONFIG.RadarEnabled = value end
)

createStepper(
    RadarPage,
    "Radar range",
    "Radar range",
    function() return CONFIG.RadarRange end,
    function(value) CONFIG.RadarRange = value end,
    50,
    1500,
    50,
    function(value) return tostring(value) .. " studs" end
)

createStepper(
    RadarPage,
    "Radar size",
    "Radar size",
    function() return CONFIG.RadarSize end,
    function(value) CONFIG.RadarSize = value end,
    120,
    280,
    10,
    function(value) return tostring(value) .. " px" end
)

createSection(SettingsPage, "Performance")
createToggle(
    SettingsPage,
    "Performance mode",
    "Adaptive visual refresh with full-speed aiming",
    function() return CONFIG.PerformanceMode end,
    function(value) CONFIG.PerformanceMode = value end
)

createToggle(
    SettingsPage,
    "FPS and ping",
    "Show the live performance counter",
    function() return CONFIG.ShowPerformanceStats end,
    function(value) CONFIG.ShowPerformanceStats = value end
)

createToggle(
    SettingsPage,
    "Adaptive visual quality",
    "Reduce heavy ESP details only when FPS drops",
    function() return CONFIG.AdaptiveVisualQuality end,
    function(value) CONFIG.AdaptiveVisualQuality = value end
)

createSection(SettingsPage, "Client effects")
createToggle(
    SettingsPage,
    "Visual spin",
    "Rotate only your local character model",
    function() return CONFIG.SpinbotEnabled end,
    function(value)
        CONFIG.SpinbotEnabled = value

        if not value then
            Runtime.ResetSpinbot()
        end
    end
)

createSelector(
    SettingsPage,
    "Spin direction",
    "Direction of the cosmetic spin",
    {"Right", "Left"},
    function() return CONFIG.SpinbotDirection end,
    function(value) CONFIG.SpinbotDirection = value end
)

createStepper(
    SettingsPage,
    "Spin speed",
    "Degrees per second",
    function() return CONFIG.SpinbotSpeed end,
    function(value) CONFIG.SpinbotSpeed = value end,
    90,
    2160,
    90,
    function(value) return tostring(value) .. "°/s" end
)

createToggle(
    SettingsPage,
    "Spin jitter",
    "Add a small oscillation to the visual spin",
    function() return CONFIG.SpinbotJitter end,
    function(value) CONFIG.SpinbotJitter = value end
)

createStepper(
    SettingsPage,
    "Jitter amount",
    "Maximum cosmetic jitter angle",
    function() return CONFIG.SpinbotJitterAmount end,
    function(value) CONFIG.SpinbotJitterAmount = value end,
    0,
    45,
    1,
    function(value) return tostring(value) .. "°" end
)

createToggle(
    SettingsPage,
    "Spin while moving",
    "Only spin while your character is moving",
    function() return CONFIG.SpinbotOnlyMoving end,
    function(value) CONFIG.SpinbotOnlyMoving = value end
)

createToggle(
    SettingsPage,
    "Pause spin while aiming",
    "Stop the visual spin during an active aim lock",
    function() return CONFIG.SpinbotPauseWhileAiming end,
    function(value) CONFIG.SpinbotPauseWhileAiming = value end
)

createSection(SettingsPage, "Crosshair")
createToggle(
    SettingsPage,
    "Custom crosshair",
    "Show EMPYRE's lightweight centre crosshair",
    function() return CONFIG.CustomCrosshair end,
    function(value) CONFIG.CustomCrosshair = value end
)

createStepper(
    SettingsPage,
    "Crosshair size",
    "Length of each crosshair arm",
    function() return CONFIG.CrosshairSize end,
    function(value) CONFIG.CrosshairSize = value end,
    2,
    24,
    1,
    function(value) return tostring(value) .. " px" end
)

createStepper(
    SettingsPage,
    "Crosshair gap",
    "Space around the centre dot",
    function() return CONFIG.CrosshairGap end,
    function(value) CONFIG.CrosshairGap = value end,
    0,
    20,
    1,
    function(value) return tostring(value) .. " px" end
)

createStepper(
    SettingsPage,
    "Crosshair thickness",
    "Thickness of the crosshair arms",
    function() return CONFIG.CrosshairThickness end,
    function(value) CONFIG.CrosshairThickness = value end,
    1,
    4,
    1,
    function(value) return tostring(value) .. " px" end
)

createSection(SettingsPage, "FOV and radar colour")
createStepper(
    SettingsPage,
    "Red",
    "Red",
    function() return CONFIG.ESPColor[1] end,
    function(value) CONFIG.ESPColor[1] = value end,
    0,
    255,
    5
)

createStepper(
    SettingsPage,
    "Green",
    "Green",
    function() return CONFIG.ESPColor[2] end,
    function(value) CONFIG.ESPColor[2] = value end,
    0,
    255,
    5
)

createStepper(
    SettingsPage,
    "Blue",
    "Blue",
    function() return CONFIG.ESPColor[3] end,
    function(value) CONFIG.ESPColor[3] = value end,
    0,
    255,
    5
)

createSection(SettingsPage, "Keybinds")
createBind(SettingsPage, "Toggle interface", "Toggle UI", "ToggleUI")
createBind(SettingsPage, "Aim activation", "Aim key", "Aim")
createBind(SettingsPage, "Switch target", "Switch target", "SwitchTarget")
createBind(SettingsPage, "Master visual overlay", "Master visual overlay", "ESP")
createBind(SettingsPage, "Toggle radar", "Toggle radar", "Radar")
createBind(SettingsPage, "Toggle visual spin", "Visual spin", "Spinbot")
createBind(SettingsPage, "Panic disable", "Disable all features", "Panic")

createSection(SettingsPage, "Presets")
createActionButton(
    SettingsPage,
    "Snap preset",
    "Fast head lock with no predictive offset",
    "APPLY",
    function() Runtime.ApplyPreset("SNAP") end
)

createActionButton(
    SettingsPage,
    "Balanced preset",
    "Hybrid tracking with movement prediction",
    "APPLY",
    function() Runtime.ApplyPreset("BALANCED") end
)

createActionButton(
    SettingsPage,
    "FPS preset",
    "Disable heavy visual options",
    "APPLY",
    function() Runtime.ApplyPreset("FPS") end
)

createActionButton(
    SettingsPage,
    "Reset account config",
    "Clear saved settings",
    "RESET",
    function()
        for key, value in pairs(DEFAULT_CONFIG) do
            CONFIG[key] = type(value) == "table"
                and table.clone(value)
                or value
        end

        for action, keyCode in pairs(DEFAULT_BINDS) do
            BINDS[action] = keyCode
        end

        currentTarget = nil
        aimActive = false

        if ConfigRemote then
            local success, result = pcall(function()
                return ConfigRemote:InvokeServer("Reset")
            end)

            saveStatus = success and result == true and "RESET" or "LOCAL"
        end

        changed()
    end
)

local InfoCard = createCard(SettingsPage, 112)

local InfoTitle = text(InfoCard, "EMPYRE v4.2", 13, COLORS.White, Enum.Font.GothamBold)
InfoTitle.Size = UDim2.new(1, -28, 0, 24)
InfoTitle.Position = UDim2.fromOffset(14, 10)

local InfoBody = text(
    InfoCard,
    "Account: @" .. LocalPlayer.Name,
    9,
    COLORS.Muted,
    Enum.Font.GothamMedium
)
InfoBody.Size = UDim2.new(1, -28, 0, 20)
InfoBody.Position = UDim2.fromOffset(14, 35)

local SyncLabel = text(
    InfoCard,
    "CONFIG  •  " .. saveStatus,
    9,
    COLORS.White,
    Enum.Font.GothamBold
)
SyncLabel.Size = UDim2.new(1, -28, 0, 20)
SyncLabel.Position = UDim2.fromOffset(14, 60)

local SyncHint = text(
    InfoCard,
    ConfigRemote and "Auto-save is linked to this Roblox account." or "Install the server script to enable account sync.",
    8,
    COLORS.Dim,
    Enum.Font.GothamMedium
)
SyncHint.Size = UDim2.new(1, -28, 0, 20)
SyncHint.Position = UDim2.fromOffset(14, 82)

setTab("Aim")

local dragging = false
local dragStart = nil
local startPosition = nil
local dragInput = nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragInput = input
        dragStart = input.Position
        startPosition = Root.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragInput = nil
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging or not dragInput then
        return
    end

    local validMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement

    local validTouch = dragInput.UserInputType == Enum.UserInputType.Touch
        and input == dragInput

    if not validMouse and not validTouch then
        return
    end

    local delta = input.Position - dragStart

    Root.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

local FOVCircle = new("Frame", {
    Name = "FOVCircle",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
}, ScreenGui)
corner(FOVCircle, 1000)
local FOVStroke = stroke(FOVCircle, 0.4, 1, COLORS.White)

local TargetIndicator = new("Frame", {
    Name = "TargetIndicator",
    Size = UDim2.fromOffset(260, 46),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 20),
    BackgroundColor3 = COLORS.Surface,
    BackgroundTransparency = 0.03,
    BorderSizePixel = 0,
    Visible = false,
}, ScreenGui)
corner(TargetIndicator, 10)
stroke(TargetIndicator, 0.4, 1, COLORS.White)

local TargetDot = new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.fromOffset(14, 19),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
}, TargetIndicator)
corner(TargetDot, 8)

local TargetText = text(TargetIndicator, "LOCKED", 10, COLORS.White, Enum.Font.GothamBold)
TargetText.Size = UDim2.new(1, -38, 0, 22)
TargetText.Position = UDim2.fromOffset(30, 4)

local TargetDetail = text(TargetIndicator, "", 9, COLORS.Muted, Enum.Font.GothamMedium)
TargetDetail.Size = UDim2.new(1, -38, 0, 18)
TargetDetail.Position = UDim2.fromOffset(30, 23)

local TriggerIndicator = new("Frame", {
    Name = "TriggerIndicator",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(54, 20),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 70,
}, ScreenGui)
corner(TriggerIndicator, 4)
stroke(TriggerIndicator, 0.2, 1, COLORS.White)

local TriggerText = text(
    TriggerIndicator,
    "TARGET",
    8,
    COLORS.White,
    Enum.Font.GothamBold,
    Enum.TextXAlignment.Center
)
TriggerText.Size = UDim2.fromScale(1, 1)
TriggerText.ZIndex = 71

local Radar = new("Frame", {
    Name = "Radar",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -24, 1, -24),
    Size = UDim2.fromOffset(CONFIG.RadarSize, CONFIG.RadarSize),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
}, ScreenGui)
corner(Radar, 1000)
stroke(Radar, 0.25, 1, COLORS.White)

local RadarCrossH = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -16, 0, 1),
    BackgroundColor3 = COLORS.Border,
    BorderSizePixel = 0,
}, Radar)

local RadarCrossV = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0, 1, 1, -16),
    BackgroundColor3 = COLORS.Border,
    BorderSizePixel = 0,
}, Radar)

local RadarCenter = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(8, 8),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
}, Radar)
corner(RadarCenter, 8)

local function makeLine(parent)
    return new("Frame", {
        BackgroundColor3 = COLORS.White,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
    }, parent)
end

local LockedTargetLine = makeLine(ScreenGui)
LockedTargetLine.Name = "LockedTargetLine"
LockedTargetLine.AnchorPoint = Vector2.new(0, 0.5)
LockedTargetLine.ZIndex = 72
LockedTargetLine.BackgroundTransparency = 0.18

local LockedHeadMarker = new("Frame", {
    Name = "LockedHeadMarker",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(22, 22),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 73,
}, ScreenGui)
corner(LockedHeadMarker, 22)

local LockedHeadStroke = stroke(
    LockedHeadMarker,
    0.1,
    2,
    COLORS.White
)

local LockedHeadDot = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(4, 4),
    BackgroundColor3 = COLORS.White,
    BorderSizePixel = 0,
    ZIndex = 74,
}, LockedHeadMarker)
corner(LockedHeadDot, 4)

local SKELETON_CONNECTIONS = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local botModels = {}

local function entityIsPlayer(entity)
    return typeof(entity) == "Instance" and entity:IsA("Player")
end

local function entityCharacter(entity)
    if entityIsPlayer(entity) then
        return entity.Character
    end

    if typeof(entity) == "Instance" and entity:IsA("Model") then
        return entity
    end

    return nil
end

local function entityName(entity)
    if entityIsPlayer(entity) then
        return entity.DisplayName
    end

    if typeof(entity) == "Instance" then
        local displayName = entity:GetAttribute("DisplayName")

        if typeof(displayName) == "string" and displayName ~= "" then
            return displayName
        end

        return entity.Name
    end

    return "Target"
end

local function entitySortKey(entity)
    if entityIsPlayer(entity) then
        return string.format("P%012d", entity.UserId)
    end

    if typeof(entity) == "Instance" then
        return "B" .. entity:GetFullName()
    end

    return tostring(entity)
end

local function findHumanoidModel(instance)
    local current = instance

    while current and current ~= Workspace do
        if current:IsA("Model")
            and current:FindFirstChildOfClass("Humanoid") then

            return current
        end

        current = current.Parent
    end

    return nil
end

local function isBotModel(model)
    if not model
        or not model:IsA("Model")
        or model:GetAttribute("EMPYREIgnore") == true then

        return false
    end

    if Players:GetPlayerFromCharacter(model) then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")

    return humanoid ~= nil and root ~= nil
end

local function createESP(entity)
    if entity == LocalPlayer or espObjects[entity] then
        return
    end

    local Holder = new("Frame", {
        Name = "ESP_" .. entitySortKey(entity):gsub("[^%w_]", "_"),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, ScreenGui)

    local Top = makeLine(Holder)
    local Bottom = makeLine(Holder)
    local Left = makeLine(Holder)
    local Right = makeLine(Holder)

    local NameLabel = text(
        Holder,
        entityName(entity),
        11,
        COLORS.White,
        Enum.Font.GothamBold,
        Enum.TextXAlignment.Center
    )
    NameLabel.TextStrokeTransparency = 0.35
    NameLabel.TextStrokeColor3 = COLORS.Black
    NameLabel.Visible = false
    NameLabel.ZIndex = 4

    local DistanceLabel = text(
        Holder,
        "",
        9,
        COLORS.Muted,
        Enum.Font.GothamBold,
        Enum.TextXAlignment.Center
    )
    DistanceLabel.TextStrokeTransparency = 0.35
    DistanceLabel.TextStrokeColor3 = COLORS.Black
    DistanceLabel.Visible = false
    DistanceLabel.ZIndex = 4

    local HealthBack = new("Frame", {
        BackgroundColor3 = COLORS.Black,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
    }, Holder)

    local HealthFill = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = COLORS.White,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, HealthBack)

    local Tracer = makeLine(Holder)
    Tracer.AnchorPoint = Vector2.new(0, 0.5)

    local OffscreenArrow = text(
        Holder,
        "▲",
        18,
        COLORS.White,
        Enum.Font.GothamBold,
        Enum.TextXAlignment.Center
    )
    OffscreenArrow.AnchorPoint = Vector2.new(0.5, 0.5)
    OffscreenArrow.Size = UDim2.fromOffset(30, 30)
    OffscreenArrow.Visible = false
    OffscreenArrow.TextStrokeTransparency = 0.25
    OffscreenArrow.TextStrokeColor3 = COLORS.Black
    OffscreenArrow.ZIndex = 9

    local HeadDot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = COLORS.White,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 8,
    }, Holder)
    corner(HeadDot, 8)
    stroke(HeadDot, 0.25, 1, COLORS.Black)

    local SkeletonLines = {}

    espObjects[entity] = {
        Entity = entity,
        Holder = Holder,
        Top = Top,
        Bottom = Bottom,
        Left = Left,
        Right = Right,
        Name = NameLabel,
        Distance = DistanceLabel,
        HealthBack = HealthBack,
        HealthFill = HealthFill,
        Tracer = Tracer,
        OffscreenArrow = OffscreenArrow,
        HeadDot = HeadDot,
        SkeletonLines = SkeletonLines,
        Highlight = nil,
        Hitbox = nil,
        Billboard = nil,
        TagText = nil,
        HealthTrack = nil,
        HealthFillWorld = nil,
        AncestryConnection = nil,
    }

    if not entityIsPlayer(entity) then
        espObjects[entity].AncestryConnection =
            entity.AncestryChanged:Connect(function(_, parent)
                if parent == nil then
                    botModels[entity] = nil

                    local data = espObjects[entity]

                    if data then
                        if data.Highlight then
                            data.Highlight:Destroy()
                        end

                        if data.Hitbox then
                            data.Hitbox:Destroy()
                        end

                        if data.Billboard then
                            data.Billboard:Destroy()
                        end

                        if data.AncestryConnection then
                            data.AncestryConnection:Disconnect()
                        end

                        data.Holder:Destroy()
                        espObjects[entity] = nil

                        if radarDots[entity] then
                            radarDots[entity]:Destroy()
                            radarDots[entity] = nil
                        end
                    end
                end
            end)
    end
end

local function removeESP(entity)
    local data = espObjects[entity]

    if not data then
        return
    end

    if data.Highlight then
        data.Highlight:Destroy()
    end

    if data.Hitbox then
        data.Hitbox:Destroy()
    end

    if data.Billboard then
        data.Billboard:Destroy()
    end

    if data.AncestryConnection then
        data.AncestryConnection:Disconnect()
    end

    data.Holder:Destroy()
    espObjects[entity] = nil

    if radarDots[entity] then
        radarDots[entity]:Destroy()
        radarDots[entity] = nil
    end
end

local function registerBot(model)
    if isBotModel(model) then
        botModels[model] = true
        createESP(model)
    end
end

local function scanEntities()
    local currentEntities = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            currentEntities[player] = true
            createESP(player)
        end
    end

    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Model") and isBotModel(descendant) then
            botModels[descendant] = true
            currentEntities[descendant] = true
            createESP(descendant)
        end
    end

    for entity in pairs(espObjects) do
        local keep = currentEntities[entity]

        if entityIsPlayer(entity) then
            keep = entity.Parent == Players
        elseif typeof(entity) == "Instance" then
            keep = entity.Parent ~= nil and isBotModel(entity)
        end

        if not keep then
            botModels[entity] = nil
            removeESP(entity)
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    createESP(player)
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

local pendingBotRegistration = setmetatable({}, {__mode = "k"})

Workspace.DescendantAdded:Connect(function(instance)
    local model

    if instance:IsA("Model") then
        model = instance
    elseif instance:IsA("Humanoid")
        or (
            instance:IsA("BasePart")
            and instance.Name == "HumanoidRootPart"
        ) then

        model = instance.Parent
    else
        return
    end

    if model and model:IsA("Model")
        and not pendingBotRegistration[model] then
        pendingBotRegistration[model] = true

        task.delay(0.12, function()
            pendingBotRegistration[model] = nil

            if model.Parent then
                registerBot(model)
            end
        end)
    end
end)

Workspace.DescendantRemoving:Connect(function(instance)
    if instance:IsA("Model") and botModels[instance] then
        botModels[instance] = nil
        removeESP(instance)
    end
end)

scanEntities()

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(600)
        scanEntities()
    end
end)

local function setLine(line, x, y, width, height)
    line.Position = UDim2.fromOffset(x, y)
    line.Size = UDim2.fromOffset(width, height)
end

local function setRotatedLine(line, startPoint, endPoint, thickness)
    local delta = endPoint - startPoint
    local length = delta.Magnitude
    local angle = math.deg(math.atan2(delta.Y, delta.X))

    line.Position = UDim2.fromOffset(startPoint.X, startPoint.Y)
    line.Size = UDim2.fromOffset(length, thickness)
    line.Rotation = angle
end

local function localRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Runtime.FindSpinMotor(character)
    if not character then
        return nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")

    if not root then
        return nil
    end

    local direct = root:FindFirstChild("RootJoint")
        or root:FindFirstChild("Root")

    if direct and direct:IsA("Motor6D") then
        return direct
    end

    local lowerTorso = character:FindFirstChild("LowerTorso")
    local torsoRoot = lowerTorso and lowerTorso:FindFirstChild("Root")

    if torsoRoot and torsoRoot:IsA("Motor6D") then
        return torsoRoot
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D")
            and (
                descendant.Part0 == root
                or descendant.Part1 == root
            ) then

            return descendant
        end
    end

    return nil
end

function Runtime.ResetSpinbot()
    if Runtime.SpinMotor and Runtime.SpinMotor.Parent then
        pcall(function()
            Runtime.SpinMotor.Transform = CFrame.identity
        end)
    end

    Runtime.SpinMotor = nil
    Runtime.SpinCharacter = nil
    Runtime.SpinHumanoid = nil
    Runtime.SpinAngle = 0
    Runtime.SpinAccumulator = 0
    Runtime.SpinApplied = false
end

function Runtime.UpdateSpinbot(deltaTime)
    if not CONFIG.SpinbotEnabled then
        if Runtime.SpinApplied then
            Runtime.ResetSpinbot()
        end

        return
    end

    local character = LocalPlayer.Character

    if Runtime.SpinCharacter ~= character
        or not Runtime.SpinMotor
        or not Runtime.SpinMotor.Parent
        or not Runtime.SpinHumanoid
        or not Runtime.SpinHumanoid.Parent then

        Runtime.ResetSpinbot()
        Runtime.SpinCharacter = character
        Runtime.SpinHumanoid =
            character and character:FindFirstChildOfClass("Humanoid")
        Runtime.SpinMotor = Runtime.FindSpinMotor(character)
    end

    local humanoid = Runtime.SpinHumanoid
    local motor = Runtime.SpinMotor

    if not character
        or not humanoid
        or humanoid.Health <= 0
        or not motor then

        return
    end

    local pause = (
        CONFIG.SpinbotOnlyMoving
        and humanoid.MoveDirection.Magnitude < 0.05
    ) or (
        CONFIG.SpinbotPauseWhileAiming
        and CONFIG.AimEnabled
        and aimActive
    )

    if pause then
        if Runtime.SpinApplied then
            motor.Transform = CFrame.identity
            Runtime.SpinApplied = false
        end

        Runtime.SpinAccumulator = 0
        return
    end

    Runtime.SpinAccumulator += math.max(deltaTime, 0)

    local updateRate = CONFIG.PerformanceMode and (1 / 45) or (1 / 60)

    if Runtime.SpinAccumulator < updateRate then
        return
    end

    local elapsed = Runtime.SpinAccumulator
    Runtime.SpinAccumulator = 0

    local direction =
        CONFIG.SpinbotDirection == "Left" and -1 or 1

    Runtime.SpinAngle = (
        Runtime.SpinAngle
        + math.rad(CONFIG.SpinbotSpeed)
            * elapsed
            * direction
    ) % (math.pi * 2)

    local jitter = 0

    if CONFIG.SpinbotJitter then
        jitter = math.sin(os.clock() * 20)
            * math.rad(CONFIG.SpinbotJitterAmount)
    end

    motor.Transform =
        CFrame.Angles(0, Runtime.SpinAngle + jitter, 0)
    Runtime.SpinApplied = true
end

LocalPlayer.CharacterAdded:Connect(function()
    Runtime.ResetSpinbot()
end)

local function botIsFriendly(model)
    if model:GetAttribute("Friendly") == true then
        return true
    end

    local localTeam = LocalPlayer.Team

    if not localTeam then
        return false
    end

    local teamAttribute = model:GetAttribute("Team")

    if typeof(teamAttribute) == "string"
        and teamAttribute == localTeam.Name then

        return true
    end

    local teamValue = model:FindFirstChild("Team")

    if teamValue then
        if teamValue:IsA("StringValue")
            and teamValue.Value == localTeam.Name then

            return true
        end

        if teamValue:IsA("ObjectValue")
            and teamValue.Value == localTeam then

            return true
        end
    end

    return false
end

local function isEnemy(entity)
    if not entity then
        return false
    end

    if entityIsPlayer(entity) then
        if entity == LocalPlayer then
            return false
        end

        if not CONFIG.TeamCheck then
            return true
        end

        if LocalPlayer.Team == nil or entity.Team == nil then
            return true
        end

        return entity.Team ~= LocalPlayer.Team
    end

    if not CONFIG.BotsEnabled or not isBotModel(entity) then
        return false
    end

    if not CONFIG.TeamCheck then
        return true
    end

    return not botIsFriendly(entity)
end

local function characterAlive(entity)
    local character = entityCharacter(entity)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return nil, nil, nil
    end

    return character, humanoid, root
end

local function getDistance(root)
    local ownRoot = localRoot()

    if not ownRoot then
        return math.huge
    end

    return (root.Position - ownRoot.Position).Magnitude
end

local function getAimScreenPoint()
    if not Camera then
        return Vector2.zero
    end

    if UserInputService.TouchEnabled then
        local viewport = Camera.ViewportSize
        return Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    end

    return UserInputService:GetMouseLocation()
end

local function preferredPart(entity)
    local character, _, root = characterAlive(entity)

    if not character then
        return nil
    end

    if CONFIG.TargetPart == "Head" then
        local head = character:FindFirstChild("Head")

        if head and head:IsA("BasePart") then
            return head
        end

        return CONFIG.StrictHead and nil or root
    end

    if CONFIG.TargetPart == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("UpperBody")
            or root
    end

    local mouse = getAimScreenPoint()
    local parts = {
        character:FindFirstChild("Head"),
        character:FindFirstChild("UpperTorso"),
        character:FindFirstChild("Torso"),
        character:FindFirstChild("UpperBody"),
        root,
    }

    local bestPart = nil
    local bestDistance = math.huge

    for _, part in ipairs(parts) do
        if part and part:IsA("BasePart") then
            local screenPoint, visible =
                Camera:WorldToViewportPoint(part.Position)

            if visible and screenPoint.Z > 0 then
                local distance = (
                    Vector2.new(screenPoint.X, screenPoint.Y) - mouse
                ).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = part
                end
            end
        end
    end

    return bestPart or root
end

local function rawLineOfSight(entity, targetPart)
    Runtime.RaycastCount += 1
    local localCharacter = LocalPlayer.Character
    local targetCharacter = entityCharacter(entity)

    if not localCharacter or not targetCharacter or not targetPart then
        return false
    end

    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local ignored = {localCharacter, Camera}

    for _ = 1, 6 do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignored
        params.IgnoreWater = true

        local result = Workspace:Raycast(origin, direction, params)

        if not result then
            return true
        end

        if result.Instance:IsDescendantOf(targetCharacter) then
            return true
        end

        if result.Instance.Transparency >= 0.95
            or not result.Instance.CanCollide then

            table.insert(ignored, result.Instance)
        else
            return false
        end
    end

    return false
end

local visibilityFrame = 0
local visibilityCache = {}
local VISIBILITY_CHECK_INTERVAL = 0.25
local VISIBILITY_CACHE_SECONDS = 0.09
local lastVisibilityRefresh = -math.huge

local function visibleThisFrame(entity, targetPart)
    if not Camera or not targetPart then
        return false
    end

    local now = os.clock()
    local cameraPosition = Camera.CFrame.Position
    local targetPosition = targetPart.Position
    local cached = visibilityCache[entity]

    if cached
        and cached.Part == targetPart
        and now - cached.Time <= VISIBILITY_CACHE_SECONDS
        and (cached.CameraPosition - cameraPosition).Magnitude < 2
        and (cached.TargetPosition - targetPosition).Magnitude < 2 then

        return cached.Visible
    end

    local visible = rawLineOfSight(entity, targetPart)

    if visible then
        Runtime.VisibilityLostAt[entity] = nil
    else
        local lostAt = Runtime.VisibilityLostAt[entity]

        if not lostAt and cached and cached.Visible then
            lostAt = now
            Runtime.VisibilityLostAt[entity] = lostAt
        end

        if lostAt and now - lostAt <= 0.22 then
            visible = true
        elseif lostAt then
            Runtime.VisibilityLostAt[entity] = nil
        end
    end

    visibilityCache[entity] = {
        Frame = visibilityFrame,
        Time = now,
        Part = targetPart,
        CameraPosition = cameraPosition,
        TargetPosition = targetPosition,
        Visible = visible,
    }

    return visible
end

local function hasLineOfSight(entity, targetPart)
    if not CONFIG.WallCheck then
        return true
    end

    return visibleThisFrame(entity, targetPart)
end

local MAX_TARGET_RAYCASTS = 10

local function targetCandidate(entity, ignoreFOV, locked)
    if not entity or not isEnemy(entity) then
        return nil
    end

    local character, humanoid, root = characterAlive(entity)

    if not character then
        return nil
    end

    local distance = getDistance(root)

    if distance > CONFIG.MaxDistance then
        return nil
    end

    local part = preferredPart(entity)

    if not part then
        return nil
    end

    local screenPoint, visible =
        Camera:WorldToViewportPoint(part.Position)

    if not visible or screenPoint.Z <= 0 then
        return nil
    end

    local mouse = getAimScreenPoint()
    local cursorDistance = (
        Vector2.new(screenPoint.X, screenPoint.Y) - mouse
    ).Magnitude

    local fovLimit = CONFIG.FOV

    if locked and CONFIG.StickyTarget then
        fovLimit *= CONFIG.LockFOVMultiplier
    end

    if not ignoreFOV and cursorDistance > fovLimit then
        return nil
    end

    local metric

    if CONFIG.TargetPriority == "Health" then
        metric = humanoid.Health
    elseif CONFIG.TargetPriority == "Range in studs" then
        metric = distance
    else
        metric = cursorDistance
    end

    if entity == currentTarget and CONFIG.StickyTarget then
        metric *= 0.72
    end

    return {
        Entity = entity,
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Part = part,
        ScreenPoint = screenPoint,
        CursorDistance = cursorDistance,
        Distance = distance,
        Metric = metric,
        SortKey = entitySortKey(entity),
    }
end

local function candidateHasLineOfSight(candidate)
    if not CONFIG.VisibleTargetsOnly and not CONFIG.WallCheck then
        return true
    end

    return visibleThisFrame(
        candidate.Entity,
        candidate.Part
    )
end

local function validTarget(entity, ignoreFOV, locked)
    local candidate =
        targetCandidate(entity, ignoreFOV, locked)

    if not candidate then
        return false
    end

    return candidateHasLineOfSight(candidate)
end

local function temporarilyKeepTarget(entity, now)
    local retentionWindow = math.max(CONFIG.LockGrace, 0.45)

    if not CONFIG.StickyTarget
        or not entity
        or now - targetLastValidAt > retentionWindow then

        return false
    end

    local character, humanoid, root = characterAlive(entity)

    if not character
        or not humanoid
        or not root
        or getDistance(root) > CONFIG.MaxDistance * 1.15 then

        return false
    end

    local part = preferredPart(entity)

    if not part then
        return false
    end

    local point = Camera:WorldToViewportPoint(part.Position)

    return point.Z > -2
end

local function sortedTargets()
    local candidates = {}

    for entity in pairs(espObjects) do
        local candidate = targetCandidate(
            entity,
            false,
            entity == currentTarget
        )

        if candidate then
            table.insert(candidates, candidate)
        end
    end

    table.sort(candidates, function(a, b)
        if a.Metric == b.Metric then
            return a.SortKey < b.SortKey
        end

        return a.Metric < b.Metric
    end)

    local targets = {}
    local raycasts = 0

    for _, candidate in ipairs(candidates) do
        if raycasts >= MAX_TARGET_RAYCASTS then
            break
        end

        raycasts += 1

        if candidateHasLineOfSight(candidate) then
            table.insert(targets, candidate)
        end
    end

    return targets
end

local function findBestTarget(now)
    now = now or os.clock()

    if currentTarget
        and now - lastTargetSwitchAt < CONFIG.SwitchCooldown then

        return currentTarget
    end

    local targets = sortedTargets()
    local nextTarget = targets[1] and targets[1].Entity or nil

    if nextTarget and nextTarget ~= currentTarget then
        lastTargetSwitchAt = now
    end

    return nextTarget
end

switchTarget = function()
    local targets = sortedTargets()

    if #targets == 0 then
        currentTarget = nil
        targetLastValidAt = -math.huge
        return
    end

    local currentIndex = 0

    for index, data in ipairs(targets) do
        if data.Entity == currentTarget then
            currentIndex = index
            break
        end
    end

    local now = os.clock()

    if now - lastTargetSwitchAt < CONFIG.SwitchCooldown then
        return
    end

    currentTarget = targets[currentIndex % #targets + 1].Entity
    lastTargetSwitchAt = now
    targetLastValidAt = now
    lastRenderedTarget = nil
end

local function predictedPosition(entity, part, deltaTime)
    if not CONFIG.Prediction then
        return part.Position
    end

    local rawVelocity = part.AssemblyLinearVelocity
    local previousVelocity = smoothedVelocity[entity] or rawVelocity
    local velocityAlpha = math.clamp((deltaTime or 1 / 60) * 14, 0, 1)
    local velocity = previousVelocity:Lerp(rawVelocity, velocityAlpha)

    smoothedVelocity[entity] = velocity

    local leadTime = CONFIG.PredictionAmount

    if CONFIG.PredictionPingCompensation then
        leadTime += math.clamp(currentPingMs / 2000, 0, 0.12)
    end

    return part.Position + velocity * leadTime
end

local function getCrosshairPlayer()
    if not Camera then
        return nil
    end

    local viewport = Camera.ViewportSize
    local screenPoint

    if UserInputService.TouchEnabled then
        screenPoint = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    else
        screenPoint = UserInputService:GetMouseLocation()
    end

    local ray = Camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
        Camera,
    }
    params.IgnoreWater = true

    Runtime.RaycastCount += 1
    local result = Workspace:Raycast(
        ray.Origin,
        ray.Direction * CONFIG.MaxDistance,
        params
    )

    if not result then
        return nil, screenPoint
    end

    local character = findHumanoidModel(result.Instance)

    if not character then
        return nil, screenPoint
    end

    local player = Players:GetPlayerFromCharacter(character)
    local entity = player or (isBotModel(character) and character)

    if not entity or not isEnemy(entity) then
        return nil, screenPoint
    end

    local _, humanoid = characterAlive(entity)

    if not humanoid then
        return nil, screenPoint
    end

    return entity, screenPoint, result.Instance
end

local function ensureReliableESP(entity, data, character, humanoid, root, colour, distance, healthRatio)
    if not CONFIG.ESPEnabled or not CONFIG.ReliableESP then
        if data.Highlight then
            data.Highlight.Enabled = false
        end

        if data.Billboard then
            data.Billboard.Enabled = false
        end

        return
    end

    if not data.Highlight or data.Highlight.Parent ~= character then
        if data.Highlight then
            data.Highlight:Destroy()
        end

        data.Highlight = new("Highlight", {
            Name = "EMPYRE_Outline",
            Adornee = character,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency = CONFIG.Chams and 0.78 or 1,
            OutlineTransparency = 0,
            FillColor = colour,
            OutlineColor = colour,
            Enabled = true,
        }, character)
    end

    data.Highlight.Enabled = true
    data.Highlight.Adornee = character
    data.Highlight.FillTransparency = CONFIG.Chams and 0.78 or 1
    data.Highlight.FillColor = colour
    data.Highlight.OutlineColor = colour

    if CONFIG.PerformanceMode then
        if data.Billboard then
            data.Billboard.Enabled = false
        end

        return
    end

    local head = character:FindFirstChild("Head") or root

    if not data.Billboard or data.Billboard.Adornee ~= head then
        if data.Billboard then
            data.Billboard:Destroy()
        end

        local billboard = new("BillboardGui", {
            Name = "EMPYRE_Tag",
            Adornee = head,
            Size = UDim2.fromOffset(190, 44),
            StudsOffsetWorldSpace = Vector3.new(0, 3.25, 0),
            AlwaysOnTop = true,
            LightInfluence = 0,
            MaxDistance = CONFIG.MaxDistance,
            Enabled = true,
        }, ScreenGui)

        local tagText = new("TextLabel", {
            Name = "Text",
            Size = UDim2.new(1, 0, 0, 25),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            TextColor3 = colour,
            TextStrokeColor3 = COLORS.Black,
            TextStrokeTransparency = 0.15,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5,
        }, billboard)

        local healthTrack = new("Frame", {
            Name = "HealthTrack",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 28),
            Size = UDim2.fromOffset(110, 5),
            BackgroundColor3 = COLORS.Black,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            ZIndex = 5,
        }, billboard)
        corner(healthTrack, 3)

        local healthFill = new("Frame", {
            Name = "HealthFill",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = colour,
            BorderSizePixel = 0,
            ZIndex = 6,
        }, healthTrack)
        corner(healthFill, 3)

        data.Billboard = billboard
        data.TagText = tagText
        data.HealthTrack = healthTrack
        data.HealthFillWorld = healthFill
    end

    data.Billboard.Enabled = true
    data.Billboard.MaxDistance = CONFIG.MaxDistance

    local parts = {}

    if CONFIG.NameESP then
        table.insert(parts, entityName(entity))
    end

    if CONFIG.DistanceESP then
        table.insert(parts, tostring(math.floor(distance + 0.5)) .. " studs")
    end

    data.TagText.Visible = #parts > 0
    data.TagText.Text = table.concat(parts, "  •  ")
    data.TagText.TextColor3 = colour

    data.HealthTrack.Visible = CONFIG.HealthESP
    data.HealthFillWorld.Size = UDim2.new(healthRatio, 0, 1, 0)
    data.HealthFillWorld.BackgroundColor3 = colour
end

local function ensureWorldVisuals(data, root, worldColour, distance)
    local reducedQuality = CONFIG.PerformanceMode
        and CONFIG.AdaptiveVisualQuality
        and Runtime.DisplayedFPS > 0
        and Runtime.DisplayedFPS < 42

    if data.Highlight and CONFIG.ESPEnabled and CONFIG.ReliableESP then
        data.Highlight.FillTransparency =
            CONFIG.Chams and not reducedQuality and 0.78 or 1
        data.Highlight.FillColor = worldColour
        data.Highlight.OutlineColor = worldColour
    end

    if CONFIG.ESPEnabled
        and CONFIG.HitboxVisualizer
        and not reducedQuality
        and (not CONFIG.PerformanceMode or distance <= 350) then
        if not data.Hitbox or data.Hitbox.Adornee ~= root then
            if data.Hitbox then
                data.Hitbox:Destroy()
            end

            data.Hitbox = new("BoxHandleAdornment", {
                Name = "EMPYRE_Hitbox",
                Adornee = root,
                AlwaysOnTop = true,
                ZIndex = 5,
                Transparency = 0.72,
                Color3 = worldColour,
                Size = root.Size,
            }, root)
        end

        data.Hitbox.Visible = true
        data.Hitbox.Color3 = worldColour
        data.Hitbox.Size = root.Size
    elseif data.Hitbox then
        data.Hitbox.Visible = false
    end
end

local function getCharacterScreenBounds(character)
    local viewport = Camera.ViewportSize
    local success, boxCFrame, boxSize = pcall(function()
        local cframe, size = character:GetBoundingBox()
        return cframe, size
    end)

    if not success or not boxCFrame or not boxSize then
        return nil
    end

    local half = boxSize * 0.5
    local minimumX = math.huge
    local minimumY = math.huge
    local maximumX = -math.huge
    local maximumY = -math.huge
    local pointsInFront = 0

    local zStart = CONFIG.PerformanceMode and 0 or -1
    local zEnd = CONFIG.PerformanceMode and 0 or 1
    local zStep = CONFIG.PerformanceMode and 1 or 2

    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = zStart, zEnd, zStep do
                local worldPoint = boxCFrame:PointToWorldSpace(
                    Vector3.new(
                        half.X * x,
                        half.Y * y,
                        half.Z * z
                    )
                )

                local screenPoint =
                    Camera:WorldToViewportPoint(worldPoint)

                if screenPoint.Z > 0.05 then
                    pointsInFront += 1
                    minimumX = math.min(minimumX, screenPoint.X)
                    minimumY = math.min(minimumY, screenPoint.Y)
                    maximumX = math.max(maximumX, screenPoint.X)
                    maximumY = math.max(maximumY, screenPoint.Y)
                end
            end
        end
    end

    if pointsInFront == 0 then
        return nil
    end

    minimumX = math.clamp(minimumX, 0, viewport.X)
    minimumY = math.clamp(minimumY, 0, viewport.Y)
    maximumX = math.clamp(maximumX, 0, viewport.X)
    maximumY = math.clamp(maximumY, 0, viewport.Y)

    local width = maximumX - minimumX
    local height = maximumY - minimumY

    if width < 3 or height < 6 then
        return nil
    end

    if width > viewport.X * 0.95 or height > viewport.Y * 0.95 then
        return nil
    end

    return minimumX, minimumY, maximumX, maximumY
end

local function hideSkeleton(data)
    for _, line in ipairs(data.SkeletonLines) do
        line.Visible = false
    end
end

local function hideScreenESP(data)
    data.Top.Visible = false
    data.Bottom.Visible = false
    data.Left.Visible = false
    data.Right.Visible = false
    data.Name.Visible = false
    data.Distance.Visible = false
    data.HealthBack.Visible = false
    data.Tracer.Visible = false
    data.HeadDot.Visible = false
end

local function showOffscreenArrow(entity, data, root, colour)
    hideScreenESP(data)
    hideSkeleton(data)

    if data.Billboard then
        data.Billboard.Enabled = false
    end

    if not CONFIG.OffscreenArrows then
        data.OffscreenArrow.Visible = false
        data.Holder.Visible = false
        return
    end

    local viewport = Camera.ViewportSize
    local cameraSpace =
        Camera.CFrame:PointToObjectSpace(root.Position)
    local direction =
        Vector2.new(cameraSpace.X, -cameraSpace.Y)

    if cameraSpace.Z > 0 then
        direction = -direction
    end

    if direction.Magnitude < 0.001 then
        direction = Vector2.new(0, -1)
    else
        direction = direction.Unit
    end

    local margin = 42
    local centre = Vector2.new(
        viewport.X * 0.5,
        viewport.Y * 0.5
    )
    local radius = math.max(
        20,
        math.min(viewport.X, viewport.Y) * 0.5 - margin
    )
    local position = centre + direction * radius

    data.Holder.Visible = true
    data.OffscreenArrow.Visible = true
    data.OffscreenArrow.TextColor3 = colour
    data.OffscreenArrow.Position = UDim2.fromOffset(
        math.round(position.X),
        math.round(position.Y)
    )
    data.OffscreenArrow.Rotation =
        math.deg(math.atan2(direction.Y, direction.X)) + 90
end

local function applyDistanceFade(data, distance)
    local fade = 0

    if CONFIG.DistanceFade then
        local ratio = math.clamp(
            distance / math.max(CONFIG.MaxDistance, 1),
            0,
            1
        )
        fade = math.clamp((ratio - 0.35) / 0.65, 0, 1) * 0.62
    end

    for _, line in ipairs({
        data.Top,
        data.Bottom,
        data.Left,
        data.Right,
        data.Tracer,
    }) do
        line.BackgroundTransparency = fade
    end

    for _, line in ipairs(data.SkeletonLines) do
        line.BackgroundTransparency = fade
    end

    data.OffscreenArrow.TextTransparency = fade
    data.Name.TextTransparency = fade
    data.Distance.TextTransparency = fade
    data.Name.TextStrokeTransparency =
        math.clamp(0.35 + fade * 0.55, 0, 1)
    data.Distance.TextStrokeTransparency =
        math.clamp(0.35 + fade * 0.55, 0, 1)
    data.HealthBack.BackgroundTransparency =
        math.clamp(0.15 + fade, 0, 1)
    data.HealthFill.BackgroundTransparency = fade

    if data.Highlight then
        data.Highlight.OutlineTransparency =
            math.clamp(fade * 0.75, 0, 0.75)
    end

    if data.TagText then
        data.TagText.TextTransparency = fade
        data.TagText.TextStrokeTransparency =
            math.clamp(0.15 + fade * 0.7, 0, 1)
    end

    if data.HealthTrack then
        data.HealthTrack.BackgroundTransparency =
            math.clamp(0.15 + fade, 0, 1)
    end

    if data.HealthFillWorld then
        data.HealthFillWorld.BackgroundTransparency = fade
    end
end

local function updateSkeleton(character, data, colour, distance)
    if not CONFIG.ESPEnabled
        or not CONFIG.SkeletonESP
        or (
            CONFIG.PerformanceMode
            and CONFIG.AdaptiveVisualQuality
            and Runtime.DisplayedFPS > 0
            and Runtime.DisplayedFPS < 38
        )
        or (distance and distance > CONFIG.SkeletonMaxDistance) then

        hideSkeleton(data)
        return
    end

    colour = colour or espColor()

    if #data.SkeletonLines == 0 then
        for index = 1, #SKELETON_CONNECTIONS do
            local line = makeLine(data.Holder)
            line.AnchorPoint = Vector2.new(0, 0.5)
            data.SkeletonLines[index] = line
        end
    end

    for index, connection in ipairs(SKELETON_CONNECTIONS) do
        local line = data.SkeletonLines[index]
        local first = character:FindFirstChild(connection[1])
        local second = character:FindFirstChild(connection[2])

        if first and second and first:IsA("BasePart") and second:IsA("BasePart") then
            local firstPoint, firstVisible = Camera:WorldToViewportPoint(first.Position)
            local secondPoint, secondVisible = Camera:WorldToViewportPoint(second.Position)

            if firstVisible
                and secondVisible
                and firstPoint.Z > 0.05
                and secondPoint.Z > 0.05 then

                line.Visible = true
                line.BackgroundColor3 = colour

                setRotatedLine(
                    line,
                    Vector2.new(
                        math.round(firstPoint.X),
                        math.round(firstPoint.Y)
                    ),
                    Vector2.new(
                        math.round(secondPoint.X),
                        math.round(secondPoint.Y)
                    ),
                    1
                )
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

local function hideESPData(data)
    data.Holder.Visible = false
    data.OffscreenArrow.Visible = false
    data.HeadDot.Visible = false
    hideSkeleton(data)

    if data.Highlight then
        data.Highlight.Enabled = false
    end

    if data.Hitbox then
        data.Hitbox.Visible = false
    end

    if data.Billboard then
        data.Billboard.Enabled = false
    end
end

local function updateESP(entity, data)
    local character, humanoid, root = characterAlive(entity)

    if not character or not humanoid or not root then
        hideESPData(data)
        return
    end

    if not CONFIG.ESPEnabled or not isEnemy(entity) then
        hideESPData(data)
        return
    end

    local distance = getDistance(root)

    if distance > CONFIG.MaxDistance then
        hideESPData(data)
        return
    end

    local healthRatio = math.clamp(
        humanoid.Health / math.max(humanoid.MaxHealth, 1),
        0,
        1
    )

    local visibilityPart = preferredPart(entity) or root
    local visibleThroughWorld =
        visibleThisFrame(entity, visibilityPart)
    local colour = visibleThroughWorld
        and Color3.fromRGB(70, 255, 120)
        or Color3.fromRGB(255, 70, 70)

    ensureReliableESP(
        entity,
        data,
        character,
        humanoid,
        root,
        colour,
        distance,
        healthRatio
    )
    ensureWorldVisuals(data, root, colour, distance)

    local needsBounds = CONFIG.BoxESP
        or CONFIG.NameESP
        or CONFIG.HealthESP
        or CONFIG.DistanceESP
        or CONFIG.Tracers
        or CONFIG.HeadDotESP

    if not needsBounds then
        data.Holder.Visible = CONFIG.SkeletonESP
        updateSkeleton(character, data, colour, distance)
        return
    end

    local rootPoint, rootVisible =
        Camera:WorldToViewportPoint(root.Position)

    if not rootVisible or rootPoint.Z <= 0.05 then
        showOffscreenArrow(entity, data, root, colour)
        applyDistanceFade(data, distance)
        return
    end

    data.OffscreenArrow.Visible = false

    local left, top, right, bottom =
        getCharacterScreenBounds(character)

    if not left then
        data.Holder.Visible = false
        hideSkeleton(data)
        return
    end

    left = math.round(left)
    top = math.round(top)
    right = math.round(right)
    bottom = math.round(bottom)

    local width = math.max(3, right - left)
    local height = math.max(6, bottom - top)
    local centreX = left + width * 0.5
    local lockedTarget =
        CONFIG.TargetHighlight and entity == currentTarget
    local lineThickness = lockedTarget and 2 or 1

    data.Holder.Visible = true

    data.Top.BackgroundColor3 = colour
    data.Bottom.BackgroundColor3 = colour
    data.Left.BackgroundColor3 = colour
    data.Right.BackgroundColor3 = colour
    data.Tracer.BackgroundColor3 = colour

    data.Top.Visible = CONFIG.BoxESP
    data.Bottom.Visible = CONFIG.BoxESP
    data.Left.Visible = CONFIG.BoxESP
    data.Right.Visible = CONFIG.BoxESP

    if CONFIG.BoxESP then
        setLine(data.Top, left, top, width, lineThickness)
        setLine(data.Bottom, left, bottom, width, lineThickness)
        setLine(data.Left, left, top, lineThickness, height)
        setLine(data.Right, right, top, lineThickness, height)
    end

    data.Name.Visible = CONFIG.NameESP
    data.Name.TextColor3 = colour
    data.Name.Size = UDim2.fromOffset(width + 80, 18)
    data.Name.Position = UDim2.fromOffset(
        math.round(centreX - (width + 80) * 0.5),
        math.max(0, top - 20)
    )
    data.Name.Text =
        (lockedTarget and "[LOCK] " or "") .. entityName(entity)

    local head = character:FindFirstChild("Head")
    data.HeadDot.Visible = false

    if CONFIG.HeadDotESP
        and head
        and head:IsA("BasePart") then

        local headPoint, headVisible =
            Camera:WorldToViewportPoint(head.Position)

        if headVisible and headPoint.Z > 0.05 then
            data.HeadDot.Visible = true
            data.HeadDot.BackgroundColor3 = colour
            data.HeadDot.Size = UDim2.fromOffset(
                lockedTarget and 9 or 6,
                lockedTarget and 9 or 6
            )
            data.HeadDot.Position = UDim2.fromOffset(
                math.round(headPoint.X),
                math.round(headPoint.Y)
            )
        end
    end

    data.Distance.Visible = CONFIG.DistanceESP
    data.Distance.TextColor3 = colour
    data.Distance.Size = UDim2.fromOffset(width + 80, 18)
    data.Distance.Position = UDim2.fromOffset(
        math.round(centreX - (width + 80) * 0.5),
        bottom + 3
    )
    data.Distance.Text =
        tostring(math.floor(distance + 0.5)) .. " studs"

    data.HealthBack.Visible = CONFIG.HealthESP
    data.HealthBack.Size = UDim2.fromOffset(4, height)
    data.HealthBack.Position = UDim2.fromOffset(left - 8, top)
    data.HealthFill.Size =
        UDim2.new(1, 0, healthRatio, 0)

    local red = math.floor(255 * (1 - healthRatio))
    local green = math.floor(255 * healthRatio)

    data.HealthFill.BackgroundColor3 = Color3.fromRGB(
        red,
        green,
        70
    )

    data.Tracer.Visible = CONFIG.Tracers

    if CONFIG.Tracers then
        local viewport = Camera.ViewportSize

        setRotatedLine(
            data.Tracer,
            Vector2.new(
                math.round(viewport.X * 0.5),
                viewport.Y - 2
            ),
            Vector2.new(
                math.round(centreX),
                bottom
            ),
            1
        )
    end

    updateSkeleton(character, data, colour, distance)
    applyDistanceFade(data, distance)
end

local function updateRadar()
    Radar.Visible = CONFIG.RadarEnabled
    Radar.Size = UDim2.fromOffset(CONFIG.RadarSize, CONFIG.RadarSize)

    if not CONFIG.RadarEnabled then
        for _, dot in pairs(radarDots) do
            dot.Visible = false
        end

        return
    end

    local ownRoot = localRoot()

    if not ownRoot then
        return
    end

    local radarRadius = CONFIG.RadarSize / 2 - 10

    for entity in pairs(espObjects) do
        if isEnemy(entity) then
            local _, _, root = characterAlive(entity)

            if root then
                local relative =
                    ownRoot.CFrame:PointToObjectSpace(root.Position)
                local distance2D =
                    Vector2.new(relative.X, relative.Z).Magnitude
                local dot = radarDots[entity]

                if not dot then
                    dot = new("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Size = UDim2.fromOffset(
                            entityIsPlayer(entity) and 6 or 7,
                            entityIsPlayer(entity) and 6 or 7
                        ),
                        BackgroundColor3 = COLORS.White,
                        BorderSizePixel = 0,
                    }, Radar)
                    corner(dot, 7)
                    radarDots[entity] = dot
                end

                if distance2D <= CONFIG.RadarRange then
                    local visibilityPart = preferredPart(entity) or root
                    local colour = visibleThisFrame(
                        entity,
                        visibilityPart
                    ) and Color3.fromRGB(70, 255, 120)
                        or Color3.fromRGB(255, 70, 70)

                    local scale = radarRadius / CONFIG.RadarRange
                    local x = math.clamp(
                        relative.X * scale,
                        -radarRadius,
                        radarRadius
                    )
                    local y = math.clamp(
                        relative.Z * scale,
                        -radarRadius,
                        radarRadius
                    )

                    dot.Visible = true
                    dot.BackgroundColor3 = colour
                    dot.Position = UDim2.fromOffset(
                        CONFIG.RadarSize / 2 + x,
                        CONFIG.RadarSize / 2 + y
                    )
                else
                    dot.Visible = false
                end
            elseif radarDots[entity] then
                radarDots[entity].Visible = false
            end
        elseif radarDots[entity] then
            radarDots[entity].Visible = false
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    if captureAction then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            BINDS[captureAction] = input.KeyCode

            local Bind = bindButtons[captureAction]

            if Bind then
                Bind.Text = input.KeyCode.Name
                Bind.TextColor3 = COLORS.Muted
                tween(Bind, {BackgroundColor3 = COLORS.Surface2}, 0.14)
            end

            captureAction = nil
            changed()
        end

        return
    end

    if input.KeyCode == BINDS.ToggleUI then
        setInterfaceVisible(not Root.Visible)
        return
    end

    if input.KeyCode == BINDS.Panic then
        Runtime.Panic()
        return
    end

    if gameProcessed then
        return
    end

    if input.KeyCode == BINDS.ESP then
        CONFIG.ESPEnabled = not CONFIG.ESPEnabled
        changed()

        for _, refresh in ipairs(quickButtonRefreshers) do
            refresh()
        end
    end

    if input.KeyCode == BINDS.Radar then
        CONFIG.RadarEnabled = not CONFIG.RadarEnabled
        changed()

        for _, refresh in ipairs(quickButtonRefreshers) do
            refresh()
        end
    end

    if input.KeyCode == BINDS.Spinbot then
        CONFIG.SpinbotEnabled = not CONFIG.SpinbotEnabled

        if not CONFIG.SpinbotEnabled then
            Runtime.ResetSpinbot()
        end

        Runtime.Notify(
            CONFIG.SpinbotEnabled and "VISUAL SPIN ON" or "VISUAL SPIN OFF"
        )
        changed()
        Runtime.RefreshQuickButtons()
    end

    if input.KeyCode == BINDS.SwitchTarget then
        switchTarget()
    end

    if input.KeyCode == BINDS.PreviousTarget then
        Runtime.SelectPreviousTarget()
    end

    if input.KeyCode == BINDS.Aim and CONFIG.AimEnabled then
        if CONFIG.AimMode == "Toggle" then
            aimActive = not aimActive

            if not aimActive then
                currentTarget = nil
            end
        else
            aimActive = true
        end

        for _, refresh in ipairs(quickButtonRefreshers) do
            refresh()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    if input.KeyCode == BINDS.Aim and CONFIG.AimMode == "Hold" then
        aimActive = false
        currentTarget = nil

        for _, refresh in ipairs(quickButtonRefreshers) do
            refresh()
        end
    end
end)

local visualEntityCache = {}
local nextVisualListRefresh = 0

local function refreshVisualEntityCache()
    local candidates = {}

    for entity, data in pairs(espObjects) do
        local _, _, root = characterAlive(entity)

        if CONFIG.ESPEnabled
            and root
            and isEnemy(entity) then

            local distance = getDistance(root)

            if distance <= CONFIG.MaxDistance then
                table.insert(candidates, {
                    Entity = entity,
                    Data = data,
                    Distance = distance,
                })
            else
                hideESPData(data)
            end
        else
            hideESPData(data)
        end
    end

    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)

    table.clear(visualEntityCache)

    local configuredLimit =
        math.floor(CONFIG.MaxVisualTargets)

    if CONFIG.PerformanceMode
        and CONFIG.AdaptiveVisualQuality
        and Runtime.DisplayedFPS > 0 then

        if Runtime.DisplayedFPS < 35 then
            configuredLimit = math.min(configuredLimit, 8)
        elseif Runtime.DisplayedFPS < 45 then
            configuredLimit = math.min(configuredLimit, 12)
        elseif Runtime.DisplayedFPS < 55 then
            configuredLimit = math.min(configuredLimit, 18)
        end
    end

    local limit = math.min(
        #candidates,
        configuredLimit
    )

    local allowed = {}

    for index = 1, limit do
        local candidate = candidates[index]
        visualEntityCache[index] = candidate
        allowed[candidate.Entity] = true
    end

    for entity, data in pairs(espObjects) do
        if not allowed[entity] then
            hideESPData(data)
        end
    end
end

local function readPing()
    local success, value = pcall(function()
        local network = Stats:FindFirstChild("Network")
        local serverItems =
            network and network:FindFirstChild("ServerStatsItem")
        local pingItem =
            serverItems and serverItems:FindFirstChild("Data Ping")

        if pingItem then
            return pingItem:GetValueString()
        end

        return nil
    end)

    if success and typeof(value) == "string" then
        local number = value:match("[%d%.]+")

        if number then
            return tostring(
                math.floor((tonumber(number) or 0) + 0.5)
            ) .. " ms"
        end
    end

    local fallbackSuccess, fallback = pcall(function()
        return LocalPlayer:GetNetworkPing()
    end)

    if fallbackSuccess and typeof(fallback) == "number" then
        return tostring(
            math.floor(fallback * 1000 + 0.5)
        ) .. " ms"
    end

    return "-- ms"
end

local function visualInterval()
    if not CONFIG.PerformanceMode then
        return 1 / 60
    end

    if Runtime.DisplayedFPS > 0 and Runtime.DisplayedFPS < 38 then
        return 1 / 10
    end

    if Runtime.DisplayedFPS > 0 and Runtime.DisplayedFPS < 52 then
        return 1 / 15
    end

    return 1 / 24
end

local function radarInterval()
    if not CONFIG.PerformanceMode then
        return 1 / 24
    end

    if Runtime.DisplayedFPS > 0 and Runtime.DisplayedFPS < 45 then
        return 1 / 5
    end

    return 1 / 8
end

local function targetInterval()
    if not currentTarget or CONFIG.AimStyle == "Snap" then
        return 1 / 60
    end

    return CONFIG.PerformanceMode and (1 / 30) or (1 / 60)
end

RunService:UnbindFromRenderStep("EMPYRE_V2_UPDATE")

RunService:BindToRenderStep(
    "EMPYRE_V2_UPDATE",
    Enum.RenderPriority.Camera.Value + 1,
    function(deltaTime)
        Camera = Workspace.CurrentCamera

        if not Camera then
            return
        end

        local now = os.clock()
        Runtime.FpsFrames += 1

        local fpsElapsed = now - Runtime.FpsWindowStart

        if fpsElapsed >= 0.5 then
            Runtime.DisplayedFPS = math.max(
                0,
                math.floor(Runtime.FpsFrames / fpsElapsed + 0.5)
            )
            Runtime.FpsFrames = 0
            Runtime.FpsWindowStart = now
        end

        if now >= Runtime.NextPingSample then
            Runtime.NextPingSample = now + 1
            Runtime.DisplayedPing = readPing()
            currentPingMs =
                tonumber(Runtime.DisplayedPing:match("[%d%.]+")) or 0
        end

        PerformanceHud.Visible =
            CONFIG.ShowPerformanceStats

        if PerformanceHud.Visible
            and now >= Runtime.NextPerformanceHudUpdate then

            Runtime.NextPerformanceHudUpdate = now + 0.25
            PerformanceText.Text = string.format(
                "FPS %d  •  PING %s  •  ESP %dHz",
                Runtime.DisplayedFPS,
                Runtime.DisplayedPing,
                math.floor(1 / visualInterval() + 0.5)
            )

            PerformanceDot.BackgroundTransparency =
                Runtime.DisplayedFPS > 0 and Runtime.DisplayedFPS < 40
                    and 0.45
                    or 0
        end

        if now - lastVisibilityRefresh
            >= VISIBILITY_CHECK_INTERVAL then

            lastVisibilityRefresh = now
            visibilityFrame += 1
            table.clear(visibilityCache)
        end

        if Camera.ViewportSize ~= lastViewportSize then
            updateDeviceLayout()
        end

        local mouse = getAimScreenPoint()

        if CONFIG.SpinbotEnabled or Runtime.SpinApplied then
            Runtime.UpdateSpinbot(deltaTime)
        end

        Runtime.UpdateCrosshair(mouse)
        Runtime.UpdateFeatureHUDs(now, deltaTime)

        if now >= Runtime.NextStatusUpdate then
            Runtime.NextStatusUpdate = now + 0.5

            if SyncLabel then
                local tracked = 0

                for entity in pairs(espObjects) do
                    if entityIsPlayer(entity) then
                        if entity.Parent == Players then
                            tracked += 1
                        end
                    elseif typeof(entity) == "Instance"
                        and entity.Parent then

                        tracked += 1
                    end
                end

                SyncLabel.Text = string.format(
                    "CONFIG  •  %s  |  ESP %d  |  %d FPS",
                    saveStatus,
                    tracked,
                    Runtime.DisplayedFPS
                )
            end
        end

        local showFOV = CONFIG.ShowFOV and CONFIG.AimEnabled
        FOVCircle.Visible = showFOV

        if showFOV then
            local activeFOV = Runtime.GetCurrentFOV()
            local colour = espColor()

            if Runtime.LastFOVSize ~= activeFOV then
                Runtime.LastFOVSize = activeFOV
                FOVCircle.Size =
                    UDim2.fromOffset(activeFOV * 2, activeFOV * 2)
            end

            FOVCircle.Position =
                UDim2.fromOffset(mouse.X, mouse.Y)

            if Runtime.LastFOVColor ~= colour then
                Runtime.LastFOVColor = colour
                FOVStroke.Color = colour
            end
        end

        if CONFIG.ESPEnabled then
            Runtime.ESPWasEnabled = true

            if now >= nextVisualListRefresh then
                local refreshDelay =
                    Runtime.DisplayedFPS > 0
                    and Runtime.DisplayedFPS < 45
                    and 0.65
                    or 0.45

                nextVisualListRefresh = now + refreshDelay
                refreshVisualEntityCache()
            end

            if now >= Runtime.NextESPUpdate then
                Runtime.NextESPUpdate = now + visualInterval()

                for _, candidate in ipairs(visualEntityCache) do
                    updateESP(candidate.Entity, candidate.Data)
                end
            end
        elseif Runtime.ESPWasEnabled then
            Runtime.ESPWasEnabled = false
            table.clear(visualEntityCache)

            for _, data in pairs(espObjects) do
                hideESPData(data)
            end
        end

        if CONFIG.RadarEnabled then
            Runtime.RadarWasEnabled = true

            if now >= Runtime.NextRadarUpdate then
                Runtime.NextRadarUpdate = now + radarInterval()
                updateRadar()
            end
        elseif Runtime.RadarWasEnabled then
            Runtime.RadarWasEnabled = false
            updateRadar()
        end

        local crosshairEntity
        local crosshairPoint
        local crosshairPart

        if CONFIG.AutoShootEnabled then
            crosshairEntity, crosshairPoint, crosshairPart =
                getCrosshairPlayer()
        elseif CONFIG.TriggerCheck
            and now >= Runtime.NextTriggerScan then

            Runtime.NextTriggerScan = now + visualInterval()
            crosshairEntity, crosshairPoint, crosshairPart =
                getCrosshairPlayer()
        end

        if CONFIG.TriggerCheck then
            if crosshairEntity and crosshairPoint then
                TriggerIndicator.Visible = true
                TriggerIndicator.Position = UDim2.fromOffset(
                    math.round(crosshairPoint.X),
                    math.round(crosshairPoint.Y + 24)
                )
                TriggerText.Text = entityName(crosshairEntity)
            else
                TriggerIndicator.Visible = false
            end
        else
            TriggerIndicator.Visible = false
        end

        if CONFIG.AutoShootEnabled
            and AutoShootRemote
            and crosshairEntity
            and crosshairPart
            and now - lastAutoShot
                >= CONFIG.AutoShootDelay then

            lastAutoShot = now
            AutoShootRemote:FireServer(crosshairPart)
        end

        local shouldAim =
            CONFIG.AimEnabled and aimActive

        if shouldAim then
            if now >= Runtime.NextTargetScan then
                Runtime.NextTargetScan = now + targetInterval()

                if validTarget(currentTarget, false, true) then
                    targetLastValidAt = now
                elseif not temporarilyKeepTarget(currentTarget, now) then
                    if CONFIG.AutoSwitch or not currentTarget then
                        currentTarget = findBestTarget(now)

                        if currentTarget then
                            targetLastValidAt = now
                        end
                    else
                        currentTarget = nil
                        targetLastValidAt = -math.huge
                    end
                end
            end
        else
            currentTarget = nil
            targetLastValidAt = -math.huge
            Runtime.NextTargetScan = 0
        end

        if currentTarget then
            local character, humanoid, root =
                characterAlive(currentTarget)
            local part = preferredPart(currentTarget)

            if character and humanoid and root and part then
                local targetPosition

                if CONFIG.AimStyle == "Snap"
                    and not CONFIG.SnapUsePrediction then

                    targetPosition = part.Position
                else
                    targetPosition = predictedPosition(
                        currentTarget,
                        part,
                        deltaTime
                    )
                end

                if part.Name == "Head" then
                    targetPosition += Vector3.new(
                        0,
                        CONFIG.HeadOffset,
                        0
                    )
                end

                local cameraPosition =
                    Camera.CFrame.Position
                local targetScreen =
                    Camera:WorldToViewportPoint(targetPosition)
                local aimPoint = getAimScreenPoint()
                local pixelError = (
                    Vector2.new(
                        targetScreen.X,
                        targetScreen.Y
                    ) - aimPoint
                ).Magnitude

                local targetChanged =
                    currentTarget ~= lastRenderedTarget

                if targetChanged then
                    Runtime.OnTargetChanged(currentTarget)
                end

                targetPosition += Runtime.GetBotAimOffset(
                    currentTarget,
                    now
                )

                local desired =
                    CFrame.lookAt(cameraPosition, targetPosition)

                if pixelError > CONFIG.AimDeadzone then
                    local shouldSnap =
                        CONFIG.AimStyle == "Snap"
                        or (
                            CONFIG.AimStyle == "Hybrid"
                            and pixelError >= CONFIG.SnapThreshold
                        )
                        or (
                            CONFIG.SnapOnAcquire
                            and targetChanged
                        )

                    if shouldSnap then
                        Camera.CFrame = desired
                    else
                        local alpha

                        if CONFIG.AdaptiveSmoothing then
                            local response = math.clamp(
                                CONFIG.Smoothness * 60,
                                1.2,
                                60
                            )
                            alpha = 1 - math.exp(
                                -response
                                    * math.max(deltaTime, 1 / 240)
                            )
                        else
                            alpha = math.clamp(
                                CONFIG.Smoothness,
                                0.02,
                                1
                            )
                        end

                        Camera.CFrame =
                            Camera.CFrame:Lerp(desired, alpha)
                    end
                end

                lastRenderedTarget = currentTarget
                Camera.Focus = CFrame.new(targetPosition)

                BadgeText.Text = "LOCKED"
                BadgeText.TextColor3 = COLORS.White
                BadgeDot.BackgroundColor3 = COLORS.White

                TargetIndicator.Visible =
                    CONFIG.ShowTargetIndicator
                TargetText.Text =
                    entityName(currentTarget)

                local targetScreenPoint, targetOnScreen =
                    Camera:WorldToViewportPoint(part.Position)

                if targetOnScreen and targetScreenPoint.Z > 0 then
                    local markerColour =
                        visibleThisFrame(currentTarget, part)
                            and Color3.fromRGB(70, 255, 120)
                            or Color3.fromRGB(255, 70, 70)

                    LockedHeadMarker.Visible =
                        CONFIG.ShowTargetMarker
                    LockedHeadMarker.Position =
                        UDim2.fromOffset(
                            math.round(targetScreenPoint.X),
                            math.round(targetScreenPoint.Y)
                        )
                    LockedHeadStroke.Color = markerColour
                    LockedHeadDot.BackgroundColor3 = markerColour

                    LockedTargetLine.Visible =
                        CONFIG.ShowTargetLine

                    if LockedTargetLine.Visible then
                        local viewport = Camera.ViewportSize
                        local startPoint = Vector2.new(
                            viewport.X * 0.5,
                            viewport.Y * 0.5
                        )
                        local endPoint = Vector2.new(
                            targetScreenPoint.X,
                            targetScreenPoint.Y
                        )
                        local difference = endPoint - startPoint
                        local length = difference.Magnitude

                        LockedTargetLine.BackgroundColor3 =
                            markerColour
                        LockedTargetLine.Size =
                            UDim2.fromOffset(
                                math.max(1, length),
                                1
                            )
                        LockedTargetLine.Position =
                            UDim2.fromOffset(
                                startPoint.X,
                                startPoint.Y
                            )
                        LockedTargetLine.Rotation =
                            math.deg(
                                math.atan2(
                                    difference.Y,
                                    difference.X
                                )
                            )
                    end
                else
                    LockedHeadMarker.Visible = false
                    LockedTargetLine.Visible = false
                end
                if now >= Runtime.NextAimStatusRefresh then
                    Runtime.NextAimStatusRefresh = now + 0.1

                    local visibleStatus =
                        visibleThisFrame(currentTarget, part)
                            and "VISIBLE"
                            or "BLOCKED"

                    TargetDetail.Text = string.format(
                        "%d HP  •  %d studs  •  %s  •  %s",
                        math.floor(humanoid.Health),
                        math.floor(getDistance(root)),
                        visibleStatus,
                        string.upper(CONFIG.AimStyle)
                    )
                    TargetDot.BackgroundColor3 =
                        visibleStatus == "VISIBLE"
                            and Color3.fromRGB(70, 255, 120)
                            or Color3.fromRGB(255, 70, 70)
                end
            else
                currentTarget = nil
            end
        end

        if not currentTarget then
            lastRenderedTarget = nil
            LockedHeadMarker.Visible = false
            LockedTargetLine.Visible = false
            BadgeText.Text =
                shouldAim and "SEARCHING" or "IDLE"
            BadgeText.TextColor3 = COLORS.Muted
            BadgeDot.BackgroundColor3 =
                shouldAim and COLORS.White or COLORS.Dim
            TargetIndicator.Visible = false
        end
    end
)

updateDeviceLayout()

-- ============================================================================
-- EMPYRE V4 FEATURE MODULE
-- All state is stored on Runtime to preserve Luau's top-level register budget.
-- ============================================================================

function Runtime.SplitCSV(value)
    local result = {}

    for token in string.gmatch(tostring(value or ""), "[^,]+") do
        token = string.lower((token:gsub("^%s+", ""):gsub("%s+$", "")))

        if token ~= "" then
            result[token] = true
        end
    end

    return result
end

function Runtime.EntityFilterKey(entity)
    if entityIsPlayer(entity) then
        return "player:" .. tostring(entity.UserId)
    end

    return "bot:" .. string.lower(entityName(entity))
end

function Runtime.GetCachedTargetList(kind)
    if kind == "Whitelist" then
        if Runtime.ListCacheWhiteSource ~= CONFIG.WhitelistCSV then
            Runtime.ListCacheWhiteSource = CONFIG.WhitelistCSV
            Runtime.ListCacheWhite = Runtime.SplitCSV(CONFIG.WhitelistCSV)
        end

        return Runtime.ListCacheWhite
    end

    if Runtime.ListCacheBlackSource ~= CONFIG.BlacklistCSV then
        Runtime.ListCacheBlackSource = CONFIG.BlacklistCSV
        Runtime.ListCacheBlack = Runtime.SplitCSV(CONFIG.BlacklistCSV)
    end

    return Runtime.ListCacheBlack
end

function Runtime.TargetAllowed(entity)
    local mode = CONFIG.TargetFilterMode

    if mode == "All" then
        return true
    end

    local key = Runtime.EntityFilterKey(entity)

    if mode == "Whitelist" then
        return Runtime.GetCachedTargetList("Whitelist")[key] == true
    end

    if mode == "Blacklist" then
        return Runtime.GetCachedTargetList("Blacklist")[key] ~= true
    end

    return true
end

function Runtime.SetListEntry(listName, entity, enabled)
    if not entity then
        Runtime.Notify("NO CURRENT TARGET")
        return
    end

    local configKey = listName == "Whitelist" and "WhitelistCSV" or "BlacklistCSV"
    local entries = Runtime.SplitCSV(CONFIG[configKey])
    local key = Runtime.EntityFilterKey(entity)

    if enabled then
        entries[key] = true
    else
        entries[key] = nil
    end

    local ordered = {}

    for entry in pairs(entries) do
        table.insert(ordered, entry)
    end

    table.sort(ordered)
    CONFIG[configKey] = table.concat(ordered, ",")
    changed()
    Runtime.Notify(listName:upper() .. (enabled and " ADDED" or " REMOVED"))
end

function Runtime.IsThreat(entity, root)
    local ownRoot = localRoot()

    if not ownRoot or not root then
        return false
    end

    local delta = ownRoot.Position - root.Position

    if delta.Magnitude <= 0.01 or delta.Magnitude > 700 then
        return false
    end

    local direction = delta.Unit
    local facing = root.CFrame.LookVector:Dot(direction)
    return facing >= 0.74
end

function Runtime.GetCurrentFOV()
    if not CONFIG.DynamicFOV then
        return CONFIG.FOV
    end

    local ownRoot = localRoot()
    local speed = ownRoot and ownRoot.AssemblyLinearVelocity.Magnitude or 0
    local result = CONFIG.FOV + math.clamp(speed / 70, 0, 1)
        * CONFIG.FOV
        * CONFIG.DynamicFOVSpeedBoost

    if currentTarget then
        result *= math.max(CONFIG.DynamicFOVLockedScale, 1)
    end

    local minimum = math.min(CONFIG.DynamicFOVMin, CONFIG.FOV)
    return math.clamp(result, minimum, CONFIG.FOV * 1.75)
end

function Runtime.HistoryIndex(entity)
    for index, target in ipairs(Runtime.TargetHistory) do
        if target == entity then
            return index
        end
    end

    return math.huge
end

function Runtime.RecordTarget(entity)
    if not entity then
        return
    end

    for index = #Runtime.TargetHistory, 1, -1 do
        if Runtime.TargetHistory[index] == entity
            or not Runtime.TargetHistory[index]
            or (
                typeof(Runtime.TargetHistory[index]) == "Instance"
                and Runtime.TargetHistory[index].Parent == nil
            ) then

            table.remove(Runtime.TargetHistory, index)
        end
    end

    table.insert(Runtime.TargetHistory, 1, entity)

    while #Runtime.TargetHistory > Runtime.TargetHistoryLimit do
        table.remove(Runtime.TargetHistory)
    end
end

function Runtime.SelectPreviousTarget()
    local now = os.clock()

    for _, entity in ipairs(Runtime.TargetHistory) do
        if entity ~= currentTarget
            and validTarget(entity, false, true) then

            currentTarget = entity
            targetLastValidAt = now
            lastTargetSwitchAt = now
            lastRenderedTarget = nil
            Runtime.Notify("HISTORY: " .. entityName(entity))
            return
        end
    end

    Runtime.Notify("NO VALID TARGET HISTORY")
end

function Runtime.EnsureLockSound()
    if Runtime.LockSound and Runtime.LockSound.Parent then
        return Runtime.LockSound
    end

    Runtime.LockSound = Instance.new("Sound")
    Runtime.LockSound.Name = "EMPYRE_LockSound"
    Runtime.LockSound.SoundId = "rbxassetid://6026984224"
    Runtime.LockSound.Volume = CONFIG.LockSoundVolume
    Runtime.LockSound.Parent = game:GetService("SoundService")
    return Runtime.LockSound
end

function Runtime.OnTargetChanged(entity)
    Runtime.RecordTarget(entity)

    if CONFIG.LockSoundEnabled then
        local sound = Runtime.EnsureLockSound()
        sound.Volume = CONFIG.LockSoundVolume
        sound.TimePosition = 0
        sound:Play()
    end
end

function Runtime.GetBotDifficulty()
    local profiles = {
        Easy = {Reaction = 0.28, Accuracy = 0.55},
        Normal = {Reaction = 0.12, Accuracy = 0.24},
        Hard = {Reaction = 0.04, Accuracy = 0.08},
        Perfect = {Reaction = 0, Accuracy = 0},
    }

    return profiles[CONFIG.BotDifficulty] or profiles.Normal
end

function Runtime.GetBotAimOffset(entity, now)
    if entityIsPlayer(entity) then
        return Vector3.zero
    end

    local difficulty = Runtime.GetBotDifficulty()

    if difficulty.Accuracy <= 0 then
        return Vector3.zero
    end

    local seed = 0

    if typeof(entity) == "Instance" then
        for index = 1, #entity.Name do
            seed += string.byte(entity.Name, index)
        end
    end

    local phase = (now or os.clock()) * 2.2 + seed
    return Vector3.new(
        math.sin(phase) * difficulty.Accuracy,
        math.cos(phase * 0.83) * difficulty.Accuracy * 0.55,
        math.sin(phase * 0.61) * difficulty.Accuracy
    )
end

function Runtime.FindBone(character, names)
    for _, name in ipairs(names) do
        local part = character:FindFirstChild(name)

        if part and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end

preferredPart = function(entity)
    local character, _, root = characterAlive(entity)

    if not character then
        return nil
    end

    local targetPart = CONFIG.TargetPart

    if targetPart == "Head" then
        return Runtime.FindBone(character, {"Head"})
            or (CONFIG.StrictHead and nil or root)
    elseif targetPart == "Upper torso" then
        return Runtime.FindBone(character, {"UpperTorso", "Torso", "UpperBody"}) or root
    elseif targetPart == "Lower torso" then
        return Runtime.FindBone(character, {"LowerTorso", "Torso", "LowerBody"}) or root
    elseif targetPart == "Torso" then
        return Runtime.FindBone(character, {
            "UpperTorso", "LowerTorso", "Torso", "UpperBody"
        }) or root
    elseif targetPart == "Arms" then
        return Runtime.FindBone(character, {
            "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm",
            "Right Arm", "Left Arm", "RightHand", "LeftHand"
        }) or root
    elseif targetPart == "Legs" then
        return Runtime.FindBone(character, {
            "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg",
            "Right Leg", "Left Leg", "RightFoot", "LeftFoot"
        }) or root
    end

    local mouse = getAimScreenPoint()
    local bestPart = nil
    local bestDistance = math.huge
    local candidates = {
        Runtime.FindBone(character, {"Head"}),
        Runtime.FindBone(character, {"UpperTorso", "Torso"}),
        Runtime.FindBone(character, {"LowerTorso"}),
        Runtime.FindBone(character, {"RightUpperArm", "Right Arm"}),
        Runtime.FindBone(character, {"LeftUpperArm", "Left Arm"}),
        Runtime.FindBone(character, {"RightUpperLeg", "Right Leg"}),
        Runtime.FindBone(character, {"LeftUpperLeg", "Left Leg"}),
        root,
    }

    for _, part in ipairs(candidates) do
        if part then
            local point, visible = Camera:WorldToViewportPoint(part.Position)

            if visible and point.Z > 0 then
                local distance = (
                    Vector2.new(point.X, point.Y) - mouse
                ).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = part
                end
            end
        end
    end

    return bestPart or root
end

Runtime.BaseTargetCandidate = targetCandidate

targetCandidate = function(entity, ignoreFOV, locked)
    if not entity
        or not isEnemy(entity)
        or not Runtime.TargetAllowed(entity) then

        return nil
    end

    local character, humanoid, root = characterAlive(entity)

    if not character then
        return nil
    end

    if not entityIsPlayer(entity) then
        local firstSeen = Runtime.BotSeenAt[entity]

        if not firstSeen then
            Runtime.BotSeenAt[entity] = os.clock()
            firstSeen = Runtime.BotSeenAt[entity]
        end

        if os.clock() - firstSeen < Runtime.GetBotDifficulty().Reaction then
            return nil
        end
    end

    local distance = getDistance(root)

    if distance > CONFIG.MaxDistance then
        return nil
    end

    local part = preferredPart(entity)

    if not part then
        return nil
    end

    local screenPoint, visible = Camera:WorldToViewportPoint(part.Position)

    if not visible or screenPoint.Z <= 0 then
        return nil
    end

    local mouse = getAimScreenPoint()
    local cursorDistance = (
        Vector2.new(screenPoint.X, screenPoint.Y) - mouse
    ).Magnitude
    local fovLimit = Runtime.GetCurrentFOV()

    if locked and CONFIG.StickyTarget then
        local lockMultiplier =
            math.max(CONFIG.LockFOVMultiplier, 1.75)

        fovLimit = math.max(fovLimit, CONFIG.FOV)
            * lockMultiplier
    end

    if not ignoreFOV and cursorDistance > fovLimit then
        return nil
    end

    local metric

    if CONFIG.TargetPriority == "Health" then
        metric = humanoid.Health
    elseif CONFIG.TargetPriority == "Range in studs" then
        metric = distance
    elseif CONFIG.TargetPriority == "Threat" then
        metric = Runtime.IsThreat(entity, root)
            and distance * 0.1
            or 100000 + cursorDistance
    elseif CONFIG.TargetPriority == "Recent" then
        metric = Runtime.HistoryIndex(entity) * 1000 + cursorDistance
    else
        metric = cursorDistance
    end

    if entity == currentTarget and CONFIG.StickyTarget then
        metric *= 0.72
    end

    return {
        Entity = entity,
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Part = part,
        ScreenPoint = screenPoint,
        CursorDistance = cursorDistance,
        Distance = distance,
        Metric = metric,
        SortKey = entitySortKey(entity),
    }
end

function Runtime.ESPAllowed(entity, humanoid, root, visibilityPart)
    if not Runtime.TargetAllowed(entity) then
        return false
    end

    local filter = CONFIG.ESPFilter

    if filter == "All" then
        return true
    elseif filter == "Players" then
        return entityIsPlayer(entity)
    elseif filter == "Bots" then
        return not entityIsPlayer(entity)
    elseif filter == "Low health" then
        local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
        return ratio * 100 <= CONFIG.ESPLowHealthThreshold
    elseif filter == "Visible" then
        return visibleThisFrame(entity, visibilityPart or root)
    elseif filter == "Threats" then
        return Runtime.IsThreat(entity, root)
    end

    return true
end

function Runtime.EnsureAdvancedESP(data)
    if CONFIG.BoxESP
        and CONFIG.ESPStyle == "Corner"
        and not data.CornerLines then

        data.CornerLines = {}

        for index = 1, 8 do
            data.CornerLines[index] = makeLine(data.Holder)
            data.CornerLines[index].ZIndex = 4
        end
    end

    if CONFIG.ThreatIndicators and not data.ThreatLabel then
        data.ThreatLabel = text(
            data.Holder,
            "! THREAT",
            9,
            Color3.fromRGB(255, 190, 70),
            Enum.Font.GothamBold,
            Enum.TextXAlignment.Center
        )
        data.ThreatLabel.TextStrokeTransparency = 0.25
        data.ThreatLabel.TextStrokeColor3 = COLORS.Black
        data.ThreatLabel.Visible = false
        data.ThreatLabel.ZIndex = 8
    end
end

function Runtime.HideAdvancedESP(data)
    if data.CornerLines then
        for _, line in ipairs(data.CornerLines) do
            line.Visible = false
        end
    end

    if data.ThreatLabel then
        data.ThreatLabel.Visible = false
    end
end

Runtime.BaseHideESPData = hideESPData
hideESPData = function(data)
    Runtime.BaseHideESPData(data)
    Runtime.HideAdvancedESP(data)
end

function Runtime.SetCornerBox(data, left, top, right, bottom, colour, thickness)
    Runtime.EnsureAdvancedESP(data)

    local width = right - left
    local height = bottom - top
    local cornerWidth = math.max(5, width * 0.28)
    local cornerHeight = math.max(7, height * 0.22)
    local lines = data.CornerLines

    for _, line in ipairs(lines) do
        line.Visible = true
        line.BackgroundColor3 = colour
    end

    setLine(lines[1], left, top, cornerWidth, thickness)
    setLine(lines[2], left, top, thickness, cornerHeight)
    setLine(lines[3], right - cornerWidth, top, cornerWidth, thickness)
    setLine(lines[4], right - thickness, top, thickness, cornerHeight)
    setLine(lines[5], left, bottom - thickness, cornerWidth, thickness)
    setLine(lines[6], left, bottom - cornerHeight, thickness, cornerHeight)
    setLine(lines[7], right - cornerWidth, bottom - thickness, cornerWidth, thickness)
    setLine(lines[8], right - thickness, bottom - cornerHeight, thickness, cornerHeight)
end

updateESP = function(entity, data)
    Runtime.ESPUpdateCount += 1

    local character, humanoid, root = characterAlive(entity)

    if not character or not humanoid or not root then
        hideESPData(data)
        return
    end

    if not CONFIG.ESPEnabled or not isEnemy(entity) then
        hideESPData(data)
        return
    end

    local distance = getDistance(root)

    if distance > CONFIG.MaxDistance then
        hideESPData(data)
        return
    end

    local visibilityPart = preferredPart(entity) or root

    if not Runtime.ESPAllowed(entity, humanoid, root, visibilityPart) then
        hideESPData(data)
        return
    end

    Runtime.EnsureAdvancedESP(data)

    local healthRatio = math.clamp(
        humanoid.Health / math.max(humanoid.MaxHealth, 1),
        0,
        1
    )
    local visibleThroughWorld = visibleThisFrame(entity, visibilityPart)
    local colour = visibleThroughWorld
        and Color3.fromRGB(70, 255, 120)
        or Color3.fromRGB(255, 70, 70)

    ensureReliableESP(
        entity, data, character, humanoid, root,
        colour, distance, healthRatio
    )
    ensureWorldVisuals(data, root, colour, distance)

    local rootPoint, rootVisible = Camera:WorldToViewportPoint(root.Position)

    if not rootVisible or rootPoint.Z <= 0.05 then
        Runtime.HideAdvancedESP(data)
        showOffscreenArrow(entity, data, root, colour)
        applyDistanceFade(data, distance)
        return
    end

    data.OffscreenArrow.Visible = false

    local left, top, right, bottom = getCharacterScreenBounds(character)

    if not left then
        hideESPData(data)
        return
    end

    left = math.round(left)
    top = math.round(top)
    right = math.round(right)
    bottom = math.round(bottom)

    local width = math.max(3, right - left)
    local height = math.max(6, bottom - top)
    local centreX = left + width * 0.5
    local lockedTarget = CONFIG.TargetHighlight and entity == currentTarget
    local lineThickness = lockedTarget and 2 or 1
    local style = CONFIG.ESPStyle
    local fullBox = style == "Full"
    local cornerBox = style == "Corner"
    local outlineOnly = style == "Outline"
    local minimal = style == "Minimal"
    local namesOnly = style == "Names"

    if data.Billboard then
        data.Billboard.Enabled = fullBox or cornerBox
    end

    data.Holder.Visible = true
    Runtime.HideAdvancedESP(data)

    data.Top.BackgroundColor3 = colour
    data.Bottom.BackgroundColor3 = colour
    data.Left.BackgroundColor3 = colour
    data.Right.BackgroundColor3 = colour
    data.Tracer.BackgroundColor3 = colour

    data.Top.Visible = CONFIG.BoxESP and fullBox
    data.Bottom.Visible = CONFIG.BoxESP and fullBox
    data.Left.Visible = CONFIG.BoxESP and fullBox
    data.Right.Visible = CONFIG.BoxESP and fullBox

    if CONFIG.BoxESP and fullBox then
        setLine(data.Top, left, top, width, lineThickness)
        setLine(data.Bottom, left, bottom, width, lineThickness)
        setLine(data.Left, left, top, lineThickness, height)
        setLine(data.Right, right, top, lineThickness, height)
    elseif CONFIG.BoxESP and cornerBox then
        Runtime.SetCornerBox(
            data, left, top, right, bottom, colour, lineThickness
        )
    end

    if data.Highlight then
        data.Highlight.Enabled = CONFIG.ReliableESP
            and (outlineOnly or fullBox or cornerBox)
    end

    data.Name.Visible = CONFIG.NameESP
        and not minimal
        and (not outlineOnly or lockedTarget)
    data.Name.TextColor3 = colour
    data.Name.Size = UDim2.fromOffset(width + 100, 18)
    data.Name.Position = UDim2.fromOffset(
        math.round(centreX - (width + 100) * 0.5),
        math.max(0, top - 20)
    )
    data.Name.Text = (lockedTarget and "[LOCK] " or "") .. entityName(entity)

    local head = character:FindFirstChild("Head")
    data.HeadDot.Visible = false

    if (CONFIG.HeadDotESP or minimal)
        and head
        and head:IsA("BasePart") then

        local headPoint, headVisible = Camera:WorldToViewportPoint(head.Position)

        if headVisible and headPoint.Z > 0.05 then
            data.HeadDot.Visible = true
            data.HeadDot.BackgroundColor3 = colour
            data.HeadDot.Size = UDim2.fromOffset(
                lockedTarget and 10 or (minimal and 8 or 6),
                lockedTarget and 10 or (minimal and 8 or 6)
            )
            data.HeadDot.Position = UDim2.fromOffset(
                math.round(headPoint.X),
                math.round(headPoint.Y)
            )
        end
    end

    data.Distance.Visible = CONFIG.DistanceESP
        and not minimal
        and not outlineOnly
    data.Distance.TextColor3 = colour
    data.Distance.Size = UDim2.fromOffset(width + 100, 18)
    data.Distance.Position = UDim2.fromOffset(
        math.round(centreX - (width + 100) * 0.5),
        bottom + 3
    )
    data.Distance.Text = tostring(math.floor(distance + 0.5)) .. " studs"

    data.HealthBack.Visible = CONFIG.HealthESP
        and not minimal
        and not namesOnly
        and not outlineOnly
    data.HealthBack.Size = UDim2.fromOffset(4, height)
    data.HealthBack.Position = UDim2.fromOffset(left - 8, top)
    data.HealthFill.Size = UDim2.new(1, 0, healthRatio, 0)
    data.HealthFill.BackgroundColor3 = Color3.fromRGB(
        math.floor(255 * (1 - healthRatio)),
        math.floor(255 * healthRatio),
        70
    )

    data.Tracer.Visible = CONFIG.Tracers
        and not minimal
        and not namesOnly
        and not outlineOnly

    if data.Tracer.Visible then
        local viewport = Camera.ViewportSize
        setRotatedLine(
            data.Tracer,
            Vector2.new(math.round(viewport.X * 0.5), viewport.Y - 2),
            Vector2.new(math.round(centreX), bottom),
            1
        )
    end

    local threat = CONFIG.ThreatIndicators and Runtime.IsThreat(entity, root)

    if data.ThreatLabel then
        data.ThreatLabel.Visible = threat

        if threat then
            data.ThreatLabel.Size = UDim2.fromOffset(82, 18)
            data.ThreatLabel.Position = UDim2.fromOffset(right - 75, top - 20)
        end
    end

    if minimal or namesOnly or outlineOnly then
        hideSkeleton(data)
    else
        updateSkeleton(character, data, colour, distance)
    end

    applyDistanceFade(data, distance)

    if data.CornerLines then
        local fade = CONFIG.DistanceFade
            and math.clamp((distance / math.max(CONFIG.MaxDistance, 1) - 0.35) / 0.65, 0, 1) * 0.62
            or 0

        for _, line in ipairs(data.CornerLines) do
            line.BackgroundTransparency = fade
        end
    end
end

refreshVisualEntityCache = function()
    local candidates = {}

    for entity, data in pairs(espObjects) do
        local _, humanoid, root = characterAlive(entity)

        if CONFIG.ESPEnabled
            and humanoid
            and root
            and isEnemy(entity)
            and Runtime.TargetAllowed(entity) then

            local distance = getDistance(root)
            local visibilityPart = preferredPart(entity) or root

            if distance <= CONFIG.MaxDistance
                and Runtime.ESPAllowed(entity, humanoid, root, visibilityPart) then

                table.insert(candidates, {
                    Entity = entity,
                    Data = data,
                    Distance = distance,
                })
            else
                hideESPData(data)
            end
        else
            hideESPData(data)
        end
    end

    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)

    table.clear(visualEntityCache)
    local configuredLimit = math.floor(CONFIG.MaxVisualTargets)

    if CONFIG.PerformanceMode
        and CONFIG.AdaptiveVisualQuality
        and Runtime.DisplayedFPS > 0 then

        if Runtime.DisplayedFPS < 35 then
            configuredLimit = math.min(configuredLimit, 8)
        elseif Runtime.DisplayedFPS < 45 then
            configuredLimit = math.min(configuredLimit, 12)
        elseif Runtime.DisplayedFPS < 55 then
            configuredLimit = math.min(configuredLimit, 18)
        end
    end

    local limit = math.min(#candidates, configuredLimit)
    local allowed = {}

    for index = 1, limit do
        local candidate = candidates[index]
        visualEntityCache[index] = candidate
        allowed[candidate.Entity] = true
    end

    for entity, data in pairs(espObjects) do
        if not allowed[entity] then
            hideESPData(data)
        end
    end
end

updateRadar = function()
    Radar.Visible = CONFIG.RadarEnabled
    Radar.Size = UDim2.fromOffset(CONFIG.RadarSize, CONFIG.RadarSize)

    if not CONFIG.RadarEnabled then
        for _, dot in pairs(radarDots) do
            dot.Visible = false
        end

        return
    end

    local ownRoot = localRoot()

    if not ownRoot then
        return
    end

    local radarRadius = CONFIG.RadarSize / 2 - 10

    for entity in pairs(espObjects) do
        local character, humanoid, root = characterAlive(entity)
        local allowed = character and humanoid and root and isEnemy(entity)
            and Runtime.TargetAllowed(entity)

        if allowed and CONFIG.RadarFollowsESPFilter then
            allowed = Runtime.ESPAllowed(
                entity, humanoid, root, preferredPart(entity) or root
            )
        end

        if allowed then
            local delta = root.Position - ownRoot.Position
            local relative

            if CONFIG.RadarRotation == "North" then
                relative = Vector3.new(delta.X, 0, delta.Z)
            elseif CONFIG.RadarRotation == "Character" then
                relative = ownRoot.CFrame:VectorToObjectSpace(delta)
            else
                relative = Camera.CFrame:VectorToObjectSpace(delta)
            end

            local distance2D = Vector2.new(relative.X, relative.Z).Magnitude
            local dot = radarDots[entity]

            if not dot then
                dot = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.fromOffset(
                        entityIsPlayer(entity) and 6 or 7,
                        entityIsPlayer(entity) and 6 or 7
                    ),
                    BackgroundColor3 = COLORS.White,
                    BorderSizePixel = 0,
                }, Radar)
                corner(dot, 7)
                radarDots[entity] = dot
            end

            if distance2D <= CONFIG.RadarRange then
                local visibilityPart = preferredPart(entity) or root
                local colour

                if Runtime.IsThreat(entity, root) then
                    colour = Color3.fromRGB(255, 190, 70)
                else
                    colour = visibleThisFrame(entity, visibilityPart)
                        and Color3.fromRGB(70, 255, 120)
                        or Color3.fromRGB(255, 70, 70)
                end

                local scale = radarRadius / CONFIG.RadarRange
                local x = math.clamp(relative.X * scale, -radarRadius, radarRadius)
                local y = math.clamp(relative.Z * scale, -radarRadius, radarRadius)

                dot.Visible = true
                dot.BackgroundColor3 = colour
                dot.Position = UDim2.fromOffset(
                    CONFIG.RadarSize / 2 + x,
                    CONFIG.RadarSize / 2 + y
                )
            else
                dot.Visible = false
            end
        elseif radarDots[entity] then
            radarDots[entity].Visible = false
        end
    end
end

function Runtime.ReadToolValue(tool, name)
    if not tool then
        return nil
    end

    local attribute = tool:GetAttribute(name)

    if attribute ~= nil then
        return attribute
    end

    local valueObject = tool:FindFirstChild(name)

    if valueObject and valueObject:IsA("ValueBase") then
        return valueObject.Value
    end

    return nil
end

function Runtime.GetEquippedTool()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Tool")
end

function Runtime.DecodeWeaponProfiles()
    Runtime.WeaponProfiles = {}

    if CONFIG.WeaponProfilesJSON == "" then
        return
    end

    local success, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(CONFIG.WeaponProfilesJSON)
    end)

    if success and type(result) == "table" then
        Runtime.WeaponProfiles = result
    end
end

function Runtime.EncodeWeaponProfiles()
    local success, result = pcall(function()
        return game:GetService("HttpService"):JSONEncode(Runtime.WeaponProfiles)
    end)

    if success then
        CONFIG.WeaponProfilesJSON = result
        changed()
    end
end

function Runtime.CurrentWeaponProfile()
    return {
        AimStyle = CONFIG.AimStyle,
        TargetPart = CONFIG.TargetPart,
        FOV = CONFIG.FOV,
        PredictionAmount = CONFIG.PredictionAmount,
        Smoothness = CONFIG.Smoothness,
        AutoShootDelay = CONFIG.AutoShootDelay,
        HeadOffset = CONFIG.HeadOffset,
        SnapUsePrediction = CONFIG.SnapUsePrediction,
    }
end

function Runtime.ApplyWeaponProfile(name)
    local profile = Runtime.WeaponProfiles[name]

    if type(profile) ~= "table" then
        return false
    end

    for key, value in pairs(profile) do
        if CONFIG[key] ~= nil and type(CONFIG[key]) == type(value) then
            CONFIG[key] = value
        end
    end

    currentTarget = nil
    lastRenderedTarget = nil

    for _, refresh in ipairs(refreshers) do
        refresh()
    end

    Runtime.RefreshQuickButtons()
    Runtime.Notify("WEAPON PROFILE: " .. name)
    return true
end

function Runtime.SaveCurrentWeaponProfile()
    local tool = Runtime.GetEquippedTool()

    if not tool then
        Runtime.Notify("EQUIP A TOOL FIRST")
        return
    end

    Runtime.WeaponProfiles[tool.Name] = Runtime.CurrentWeaponProfile()
    Runtime.EncodeWeaponProfiles()
    Runtime.Notify("SAVED WEAPON: " .. tool.Name)
end

function Runtime.DeleteCurrentWeaponProfile()
    local tool = Runtime.GetEquippedTool()

    if not tool then
        Runtime.Notify("EQUIP A TOOL FIRST")
        return
    end

    Runtime.WeaponProfiles[tool.Name] = nil
    Runtime.EncodeWeaponProfiles()
    Runtime.Notify("DELETED WEAPON: " .. tool.Name)
end

function Runtime.CreateCombatHUDs()
    Runtime.AmmoHud = new("Frame", {
        Name = "AmmoHud",
        AnchorPoint = Vector2.new(1, 1),
        Size = UDim2.fromOffset(250, 56),
        Position = UDim2.new(1, -18, 1, -74),
        BackgroundColor3 = COLORS.Background,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 78,
    }, ScreenGui)
    corner(Runtime.AmmoHud, 9)
    stroke(Runtime.AmmoHud, 0.3, 1, COLORS.Border)

    Runtime.AmmoText = text(
        Runtime.AmmoHud,
        "NO WEAPON",
        11,
        COLORS.White,
        Enum.Font.GothamBold,
        Enum.TextXAlignment.Center
    )
    Runtime.AmmoText.Size = UDim2.fromScale(1, 1)
    Runtime.AmmoText.ZIndex = 79

    Runtime.SpectatorHud = new("Frame", {
        Name = "SpectatorHud",
        Size = UDim2.fromOffset(240, 54),
        Position = UDim2.fromOffset(12, 54),
        BackgroundColor3 = COLORS.Background,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 78,
    }, ScreenGui)
    corner(Runtime.SpectatorHud, 9)
    stroke(Runtime.SpectatorHud, 0.3, 1, COLORS.Border)

    Runtime.SpectatorText = text(
        Runtime.SpectatorHud,
        "SPECTATORS: 0",
        10,
        COLORS.White,
        Enum.Font.GothamBold,
        Enum.TextXAlignment.Center
    )
    Runtime.SpectatorText.Size = UDim2.fromScale(1, 1)
    Runtime.SpectatorText.ZIndex = 79

    Runtime.HitMarkerText = text(
        ScreenGui,
        "×",
        28,
        COLORS.White,
        Enum.Font.GothamBlack,
        Enum.TextXAlignment.Center
    )
    Runtime.HitMarkerText.AnchorPoint = Vector2.new(0.5, 0.5)
    Runtime.HitMarkerText.Size = UDim2.fromOffset(40, 40)
    Runtime.HitMarkerText.Visible = false
    Runtime.HitMarkerText.TextTransparency = 0
    Runtime.HitMarkerText.TextStrokeTransparency = 0.2
    Runtime.HitMarkerText.ZIndex = 88
end

function Runtime.ShowHitMarker()
    if not CONFIG.HitMarker or not Runtime.HitMarkerText or not Camera then
        return
    end

    local viewport = Camera.ViewportSize
    Runtime.HitMarkerText.Position = UDim2.fromOffset(
        viewport.X * 0.5,
        viewport.Y * 0.5
    )
    Runtime.HitMarkerText.Visible = true
    Runtime.HitMarkerText.TextTransparency = 0

    local token = os.clock()
    Runtime.HitMarkerToken = token

    task.delay(0.13, function()
        if Runtime.HitMarkerToken == token and Runtime.HitMarkerText then
            Runtime.HitMarkerText.Visible = false
        end
    end)
end

function Runtime.ShowDamageNumber(position, amount)
    if not CONFIG.DamageNumbers or not Camera then
        return
    end

    local point, visible = Camera:WorldToViewportPoint(position)

    if not visible or point.Z <= 0 then
        return
    end

    local label = text(
        ScreenGui,
        "-" .. tostring(math.floor(amount + 0.5)),
        16,
        Color3.fromRGB(255, 225, 120),
        Enum.Font.GothamBlack,
        Enum.TextXAlignment.Center
    )
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Size = UDim2.fromOffset(90, 28)
    label.Position = UDim2.fromOffset(point.X, point.Y)
    label.TextStrokeTransparency = 0.15
    label.ZIndex = 89

    tween(label, {
        Position = UDim2.fromOffset(point.X, point.Y - 42),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }, 0.55)

    task.delay(0.6, function()
        if label then
            label:Destroy()
        end
    end)
end

function Runtime.ScanSpectators()
    table.clear(Runtime.Spectators)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local spectatingId = player:GetAttribute("SpectatingUserId")
            local spectatingName = player:GetAttribute("SpectatingName")
            local targetValue = player:FindFirstChild("SpectateTarget")
            local matches = spectatingId == LocalPlayer.UserId
                or spectatingName == LocalPlayer.Name
                or (
                    targetValue
                    and targetValue:IsA("ObjectValue")
                    and (
                        targetValue.Value == LocalPlayer
                        or targetValue.Value == LocalPlayer.Character
                    )
                )

            if matches then
                table.insert(Runtime.Spectators, player.DisplayName)
            end
        end
    end

    if Runtime.SpectatorText then
        Runtime.SpectatorHud.Visible = #Runtime.Spectators > 0
        Runtime.SpectatorText.Text = #Runtime.Spectators > 0
            and ("SPECTATORS: " .. table.concat(Runtime.Spectators, ", "))
            or "SPECTATORS: 0"
    end
end

function Runtime.UpdateAmmoHud(now)
    if not Runtime.AmmoHud or not Runtime.AmmoText then
        return
    end

    local tool = Runtime.GetEquippedTool()
    Runtime.AmmoHud.Visible = CONFIG.AmmoHUD and tool ~= nil

    if not tool then
        Runtime.CurrentWeaponName = "NONE"
        Runtime.LastWeaponName = nil
        return
    end

    Runtime.CurrentWeaponName = tool.Name

    if Runtime.LastWeaponName ~= tool.Name then
        Runtime.LastWeaponName = tool.Name

        if CONFIG.AutoWeaponProfiles then
            Runtime.ApplyWeaponProfile(tool.Name)
        end
    end

    local ammo = Runtime.ReadToolValue(tool, "Ammo")
    local reserve = Runtime.ReadToolValue(tool, "ReserveAmmo")
    local reloading = Runtime.ReadToolValue(tool, "Reloading") == true
    local ammoText = ammo ~= nil and tostring(ammo) or "--"
    local reserveText = reserve ~= nil and tostring(reserve) or "--"

    Runtime.AmmoText.Text = string.format(
        "%s  •  %s / %s%s",
        tool.Name,
        ammoText,
        reserveText,
        reloading and "  •  RELOADING" or ""
    )
end

function Runtime.SnapshotConfig()
    local snapshot = {}

    for key, value in pairs(CONFIG) do
        if key ~= "PrivateServerOnly"
            and key ~= "ProfileSlot1"
            and key ~= "ProfileSlot2"
            and key ~= "ProfileSlot3"
            and key ~= "WeaponProfilesJSON"
            and key ~= "LayoutJSON" then

            snapshot[key] = type(value) == "table"
                and table.clone(value)
                or value
        end
    end

    return snapshot
end

function Runtime.SaveProfileSlot(index)
    local success, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(
            Runtime.SnapshotConfig()
        )
    end)

    if success then
        CONFIG["ProfileSlot" .. tostring(index)] = encoded
        Runtime.ActiveProfileSlot = index
        changed()
        Runtime.Notify("SAVED PROFILE SLOT " .. tostring(index))
    end
end

function Runtime.LoadProfileSlot(index)
    local encoded = CONFIG["ProfileSlot" .. tostring(index)]

    if type(encoded) ~= "string" or encoded == "" then
        Runtime.Notify("PROFILE SLOT " .. tostring(index) .. " IS EMPTY")
        return
    end

    local success, snapshot = pcall(function()
        return game:GetService("HttpService"):JSONDecode(encoded)
    end)

    if not success or type(snapshot) ~= "table" then
        Runtime.Notify("PROFILE SLOT IS INVALID")
        return
    end

    Runtime.ProfileLoading = true

    for key, value in pairs(snapshot) do
        if CONFIG[key] ~= nil and type(CONFIG[key]) == type(value) then
            CONFIG[key] = value
        end
    end

    Runtime.ProfileLoading = false
    Runtime.ActiveProfileSlot = index
    currentTarget = nil
    lastRenderedTarget = nil

    for _, refresh in ipairs(refreshers) do
        refresh()
    end

    Runtime.RefreshQuickButtons()
    changed()
    Runtime.Notify("LOADED PROFILE SLOT " .. tostring(index))
end

function Runtime.ClearProfileSlot(index)
    CONFIG["ProfileSlot" .. tostring(index)] = ""
    changed()
    Runtime.Notify("CLEARED PROFILE SLOT " .. tostring(index))
end

function Runtime.SerializeFramePosition(frame)
    return {
        XS = frame.Position.X.Scale,
        XO = frame.Position.X.Offset,
        YS = frame.Position.Y.Scale,
        YO = frame.Position.Y.Offset,
    }
end

function Runtime.SaveLayout()
    if Runtime.LayoutLoading then
        return
    end

    local layout = {}

    for name, frame in pairs(Runtime.EditableFrames) do
        if frame and frame.Parent then
            layout[name] = Runtime.SerializeFramePosition(frame)
        end
    end

    local success, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(layout)
    end)

    if success then
        CONFIG.LayoutJSON = encoded
        queueSave()
    end
end

function Runtime.LoadLayout()
    if type(CONFIG.LayoutJSON) ~= "string" or CONFIG.LayoutJSON == "" then
        return
    end

    local success, layout = pcall(function()
        return game:GetService("HttpService"):JSONDecode(CONFIG.LayoutJSON)
    end)

    if not success or type(layout) ~= "table" then
        return
    end

    Runtime.LayoutLoading = true

    for name, position in pairs(layout) do
        local frame = Runtime.EditableFrames[name]

        if frame and type(position) == "table" then
            frame.Position = UDim2.new(
                tonumber(position.XS) or 0,
                tonumber(position.XO) or 0,
                tonumber(position.YS) or 0,
                tonumber(position.YO) or 0
            )
        end
    end

    Runtime.LayoutLoading = false
end

function Runtime.MakeEditable(name, frame)
    Runtime.EditableFrames[name] = frame
    frame.Active = true

    local dragging = false
    local dragStart = nil
    local startPosition = nil

    frame.InputBegan:Connect(function(input)
        if not CONFIG.LayoutEditor then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    Runtime.SaveLayout()
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not CONFIG.LayoutEditor then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

function Runtime.ResetLayout()
    QuickControls.Position = UDim2.new(0.5, 0, 1, -18)
    Radar.Position = UDim2.new(1, -24, 1, -24)
    PerformanceHud.Position = UDim2.new(1, -12, 0, 12)
    TargetIndicator.Position = UDim2.new(0.5, 0, 0, 20)

    if Runtime.AmmoHud then
        Runtime.AmmoHud.Position = UDim2.new(1, -18, 1, -74)
    end

    if Runtime.SpectatorHud then
        Runtime.SpectatorHud.Position = UDim2.fromOffset(12, 54)
    end

    CONFIG.LayoutJSON = ""
    changed()
    Runtime.Notify("HUD LAYOUT RESET")
end

function Runtime.CreateInfoCard(page, titleValue)
    local card = createCard(page, 62)
    local titleLabel = text(
        card, titleValue, 9, COLORS.Dim,
        Enum.Font.GothamBold
    )
    titleLabel.Size = UDim2.new(1, -28, 0, 18)
    titleLabel.Position = UDim2.fromOffset(14, 7)

    local valueLabel = text(
        card, "--", 11, COLORS.White,
        Enum.Font.GothamBold
    )
    valueLabel.Size = UDim2.new(1, -28, 0, 26)
    valueLabel.Position = UDim2.fromOffset(14, 27)
    return valueLabel
end

function Runtime.BuildDiagnosticsPage()
    createSection(Runtime.DiagnosticsPage, "Runtime")
    Runtime.DiagnosticsLabels.Performance = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "PERFORMANCE"
    )
    Runtime.DiagnosticsLabels.Target = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "TARGETING"
    )
    Runtime.DiagnosticsLabels.Entities = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "ENTITIES"
    )
    Runtime.DiagnosticsLabels.Raycasts = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "WORKLOAD"
    )
    Runtime.DiagnosticsLabels.Weapon = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "WEAPON"
    )
    Runtime.DiagnosticsLabels.Network = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "REMOTES AND SYNC"
    )
    Runtime.DiagnosticsLabels.Filters = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "ACTIVE FILTERS"
    )
    Runtime.DiagnosticsLabels.Spectators = Runtime.CreateInfoCard(
        Runtime.DiagnosticsPage, "SPECTATORS"
    )

    createSection(Runtime.DiagnosticsPage, "Actions")
    createActionButton(
        Runtime.DiagnosticsPage,
        "Rescan entities",
        "Refresh players and NPC bot registry",
        "RESCAN",
        function()
            scanEntities()
            Runtime.Notify("ENTITY RESCAN COMPLETE")
        end
    )
    createActionButton(
        Runtime.DiagnosticsPage,
        "Clear target history",
        "Remove remembered recent targets",
        "CLEAR",
        function()
            table.clear(Runtime.TargetHistory)
            Runtime.Notify("TARGET HISTORY CLEARED")
        end
    )
end

function Runtime.UpdateDiagnostics(now)
    if now - Runtime.LastRaycastSample >= 1 then
        Runtime.RaycastsPerSecond =
            Runtime.RaycastCount - Runtime.LastRaycastCount
        Runtime.LastRaycastCount = Runtime.RaycastCount
        Runtime.LastRaycastSample = now
    end

    if now - Runtime.LastESPUpdateSample >= 1 then
        Runtime.ESPUpdatesPerSecond =
            Runtime.ESPUpdateCount - Runtime.LastESPUpdateCount
        Runtime.LastESPUpdateCount = Runtime.ESPUpdateCount
        Runtime.LastESPUpdateSample = now
    end

    if now < Runtime.NextDiagnosticsUpdate then
        return
    end

    Runtime.NextDiagnosticsUpdate = now + 0.5

    if not Runtime.DiagnosticsLabels.Performance then
        return
    end
    local tracked = 0
    local alive = 0

    for entity in pairs(espObjects) do
        tracked += 1

        if characterAlive(entity) then
            alive += 1
        end
    end

    local targetName = currentTarget and entityName(currentTarget) or "NONE"
    local activeFOV = math.floor(Runtime.GetCurrentFOV() + 0.5)
    local spectatorText = #Runtime.Spectators > 0
        and table.concat(Runtime.Spectators, ", ")
        or "NONE"

    Runtime.DiagnosticsLabels.Performance.Text = string.format(
        "%d FPS  •  %s  •  ESP %d Hz",
        Runtime.DisplayedFPS,
        Runtime.DisplayedPing,
        math.floor(1 / visualInterval() + 0.5)
    )
    Runtime.DiagnosticsLabels.Target.Text = string.format(
        "%s  •  %s  •  FOV %d",
        targetName,
        CONFIG.AimStyle,
        activeFOV
    )
    Runtime.DiagnosticsLabels.Entities.Text = string.format(
        "%d tracked  •  %d alive  •  %d full ESP",
        tracked,
        alive,
        #visualEntityCache
    )
    Runtime.DiagnosticsLabels.Raycasts.Text = string.format(
        "%d raycasts/s  •  %d ESP updates/s",
        Runtime.RaycastsPerSecond,
        Runtime.ESPUpdatesPerSecond
    )
    Runtime.DiagnosticsLabels.Weapon.Text = string.format(
        "%s  •  weapon profile %s  •  slot %d",
        Runtime.CurrentWeaponName,
        Runtime.WeaponProfiles[Runtime.CurrentWeaponName] and "YES" or "NO",
        Runtime.ActiveProfileSlot
    )
    Runtime.DiagnosticsLabels.Network.Text = string.format(
        "CONFIG %s  •  FIRE %s  •  FEEDBACK %s  •  BOT %s",
        saveStatus,
        AutoShootRemote and "OK" or "MISSING",
        Runtime.FeedbackRemote and "OK" or "MISSING",
        Runtime.BotControlRemote and "OK" or "MISSING"
    )
    Runtime.DiagnosticsLabels.Filters.Text = string.format(
        "%s targets  •  %s ESP  •  %s radar",
        CONFIG.TargetFilterMode,
        CONFIG.ESPFilter,
        CONFIG.RadarRotation
    )
    Runtime.DiagnosticsLabels.Spectators.Text = spectatorText
end

function Runtime.UpdateFeatureHUDs(now, deltaTime)
    if now >= Runtime.NextAmmoUpdate then
        Runtime.NextAmmoUpdate = now + 0.15
        Runtime.UpdateAmmoHud(now)
    end

    if now >= Runtime.NextSpectatorScan then
        Runtime.NextSpectatorScan = now + 1.25
        Runtime.ScanSpectators()
    end

    if currentTab == "Diagnostics" then
        Runtime.UpdateDiagnostics(now)
    end
end

Runtime.CreateCombatHUDs()
Runtime.DecodeWeaponProfiles()
Runtime.FeedbackRemote = ReplicatedStorage:WaitForChild("EMPYRE_Feedback", 5)
Runtime.BotControlRemote = ReplicatedStorage:WaitForChild("EMPYRE_BotControl", 5)

if Runtime.BotControlRemote then
    Runtime.BotControlRemote:FireServer(CONFIG.BotDifficulty)
end

if Runtime.FeedbackRemote then
    Runtime.FeedbackRemote.OnClientEvent:Connect(function(action, payload)
        if action == "Hit" and type(payload) == "table" then
            Runtime.ShowHitMarker()

            if typeof(payload.Position) == "Vector3" then
                Runtime.ShowDamageNumber(
                    payload.Position,
                    tonumber(payload.Damage) or 0
                )
            end
        elseif action == "Kill" and CONFIG.KillConfirmation then
            Runtime.Notify("ELIMINATED: " .. tostring(payload or "TARGET"))
        end
    end)
end

-- Feature UI: target control.
createSection(AimPage, "Advanced targeting")
createSelector(
    AimPage,
    "Target filter",
    "Use all targets or maintain a session whitelist/blacklist",
    {"All", "Whitelist", "Blacklist"},
    function() return CONFIG.TargetFilterMode end,
    function(value)
        CONFIG.TargetFilterMode = value
        currentTarget = nil
    end
)
createToggle(
    AimPage,
    "Dynamic FOV",
    "Shrink after locking and expand slightly while moving",
    function() return CONFIG.DynamicFOV end,
    function(value) CONFIG.DynamicFOV = value end
)
createStepper(
    AimPage,
    "Minimum dynamic FOV",
    "Smallest locked aim radius",
    function() return CONFIG.DynamicFOVMin end,
    function(value) CONFIG.DynamicFOVMin = value end,
    30, 250, 5,
    function(value) return tostring(value) .. " px" end
)
createStepper(
    AimPage,
    "Locked FOV scale",
    "Dynamic FOV multiplier while locked",
    function() return CONFIG.DynamicFOVLockedScale end,
    function(value) CONFIG.DynamicFOVLockedScale = value end,
    0.35, 1, 0.05,
    function(value) return string.format("%.2fx", value) end
)
createStepper(
    AimPage,
    "Movement FOV boost",
    "Extra unlocked FOV while your character moves quickly",
    function() return CONFIG.DynamicFOVSpeedBoost end,
    function(value) CONFIG.DynamicFOVSpeedBoost = value end,
    0, 1, 0.05,
    function(value) return string.format("%.2fx", value) end
)
createSelector(
    AimPage,
    "Bot difficulty",
    "Reaction delay and aim accuracy used for NPC targets",
    {"Easy", "Normal", "Hard", "Perfect"},
    function() return CONFIG.BotDifficulty end,
    function(value)
        CONFIG.BotDifficulty = value
        table.clear(Runtime.BotSeenAt)

        if Runtime.BotControlRemote then
            Runtime.BotControlRemote:FireServer(value)
        end
    end
)
createToggle(
    AimPage,
    "Lock sound",
    "Play a confirmation sound on a new lock",
    function() return CONFIG.LockSoundEnabled end,
    function(value) CONFIG.LockSoundEnabled = value end
)
createStepper(
    AimPage,
    "Lock volume",
    "Lock confirmation volume",
    function() return CONFIG.LockSoundVolume end,
    function(value) CONFIG.LockSoundVolume = value end,
    0, 1, 0.05,
    function(value) return string.format("%.2f", value) end
)
createActionButton(
    AimPage,
    "Whitelist current",
    "Add the current target to the whitelist",
    "ADD",
    function() Runtime.SetListEntry("Whitelist", currentTarget, true) end
)
createActionButton(
    AimPage,
    "Blacklist current",
    "Add the current target to the blacklist",
    "ADD",
    function() Runtime.SetListEntry("Blacklist", currentTarget, true) end
)
createActionButton(
    AimPage,
    "Remove current from lists",
    "Remove the current target from both lists",
    "REMOVE",
    function()
        Runtime.SetListEntry("Whitelist", currentTarget, false)
        Runtime.SetListEntry("Blacklist", currentTarget, false)
    end
)
createActionButton(
    AimPage,
    "Clear target lists",
    "Remove all saved whitelist and blacklist entries",
    "CLEAR",
    function()
        CONFIG.WhitelistCSV = ""
        CONFIG.BlacklistCSV = ""
        currentTarget = nil
        changed()
        Runtime.Notify("TARGET LISTS CLEARED")
    end
)
createActionButton(
    AimPage,
    "Previous target",
    "Return to the most recent valid target",
    "PREVIOUS",
    Runtime.SelectPreviousTarget
)

-- Feature UI: ESP styles and filtering.
createSection(VisualsPage, "Styles and filters")
createSelector(
    VisualsPage,
    "ESP style",
    "Full, corner, outline, minimal dot, or names only",
    {"Full", "Corner", "Outline", "Minimal", "Names"},
    function() return CONFIG.ESPStyle end,
    function(value) CONFIG.ESPStyle = value end
)
createSelector(
    VisualsPage,
    "ESP filter",
    "Limit overlays to a target category",
    {"All", "Visible", "Low health", "Players", "Bots", "Threats"},
    function() return CONFIG.ESPFilter end,
    function(value) CONFIG.ESPFilter = value end
)
createStepper(
    VisualsPage,
    "Low-health threshold",
    "Health percentage used by the low-health filter",
    function() return CONFIG.ESPLowHealthThreshold end,
    function(value) CONFIG.ESPLowHealthThreshold = value end,
    5, 95, 5,
    function(value) return tostring(value) .. "%" end
)
createToggle(
    VisualsPage,
    "Threat indicators",
    "Mark targets facing toward your character",
    function() return CONFIG.ThreatIndicators end,
    function(value) CONFIG.ThreatIndicators = value end
)

-- Radar rotation modes.
createSection(RadarPage, "Orientation")
createSelector(
    RadarPage,
    "Radar rotation",
    "Camera-facing, character-facing, or north-facing",
    {"Camera", "Character", "North"},
    function() return CONFIG.RadarRotation end,
    function(value) CONFIG.RadarRotation = value end
)
createToggle(
    RadarPage,
    "Follow ESP filter",
    "Use the same category filter on radar dots",
    function() return CONFIG.RadarFollowsESPFilter end,
    function(value) CONFIG.RadarFollowsESPFilter = value end
)

-- Feedback, weapon profiles, slots and layout editor.
createSection(SettingsPage, "Combat feedback")
createToggle(
    SettingsPage,
    "Damage numbers",
    "Show floating damage from EMPYRE auto-fire",
    function() return CONFIG.DamageNumbers end,
    function(value) CONFIG.DamageNumbers = value end
)
createToggle(
    SettingsPage,
    "Hit marker",
    "Show a centre marker after confirmed damage",
    function() return CONFIG.HitMarker end,
    function(value) CONFIG.HitMarker = value end
)
createToggle(
    SettingsPage,
    "Kill confirmation",
    "Show an elimination notification",
    function() return CONFIG.KillConfirmation end,
    function(value) CONFIG.KillConfirmation = value end
)
createToggle(
    SettingsPage,
    "Ammo HUD",
    "Read Ammo, ReserveAmmo and Reloading tool values or attributes",
    function() return CONFIG.AmmoHUD end,
    function(value) CONFIG.AmmoHUD = value end
)

createSection(SettingsPage, "Weapon profiles")
createToggle(
    SettingsPage,
    "Auto weapon profiles",
    "Apply saved aim settings when the equipped tool changes",
    function() return CONFIG.AutoWeaponProfiles end,
    function(value) CONFIG.AutoWeaponProfiles = value end
)
createActionButton(
    SettingsPage,
    "Save equipped weapon",
    "Save aim and fire settings under the current tool name",
    "SAVE",
    Runtime.SaveCurrentWeaponProfile
)
createActionButton(
    SettingsPage,
    "Apply equipped weapon",
    "Load the profile saved for the current tool",
    "APPLY",
    function()
        local tool = Runtime.GetEquippedTool()
        if not tool or not Runtime.ApplyWeaponProfile(tool.Name) then
            Runtime.Notify("NO WEAPON PROFILE")
        end
    end
)
createActionButton(
    SettingsPage,
    "Delete equipped profile",
    "Delete the current tool profile",
    "DELETE",
    Runtime.DeleteCurrentWeaponProfile
)

createSection(SettingsPage, "Profile slots")
for index = 1, 3 do
    local slot = index

    createActionButton(
        SettingsPage,
        "Save profile slot " .. tostring(slot),
        "Store the current complete EMPYRE configuration",
        "SAVE",
        function() Runtime.SaveProfileSlot(slot) end
    )
    createActionButton(
        SettingsPage,
        "Load profile slot " .. tostring(slot),
        "Restore the saved configuration",
        "LOAD",
        function() Runtime.LoadProfileSlot(slot) end
    )
end

createSection(SettingsPage, "Mobile HUD editor")
createToggle(
    SettingsPage,
    "Layout editor",
    "Drag HUD elements while this option is enabled",
    function() return CONFIG.LayoutEditor end,
    function(value)
        CONFIG.LayoutEditor = value
        Runtime.Notify(value and "HUD EDITOR ON" or "HUD EDITOR OFF")
    end
)
createActionButton(
    SettingsPage,
    "Reset HUD layout",
    "Restore default positions for editable overlays",
    "RESET",
    Runtime.ResetLayout
)
createBind(
    SettingsPage,
    "Previous target",
    "Return to a recent target",
    "PreviousTarget"
)

Runtime.BuildDiagnosticsPage()
Runtime.MakeEditable("QuickControls", QuickControls)
Runtime.MakeEditable("Radar", Radar)
Runtime.MakeEditable("PerformanceHud", PerformanceHud)
Runtime.MakeEditable("TargetIndicator", TargetIndicator)
Runtime.MakeEditable("AmmoHud", Runtime.AmmoHud)
Runtime.MakeEditable("SpectatorHud", Runtime.SpectatorHud)
Runtime.LoadLayout()

setTab(currentTab)
Runtime.Notify("EMPYRE V4 READY")

