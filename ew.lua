-- Syu_uhub - HeadLock + Multi Target + Selective ESP (Orion Library Version)
-- 2026年対応版 / jensonhirst fork使用

local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

-- 変数・サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 設定
local Settings = {
    LockEnabled = false,
    LockDistance = 5,
    LockDistanceLeft = 5,
    LockDistanceRight = 5,
    LockDistanceFront = 5,
    LockDistanceBack = 5,
    LockDuration = 0.5,
    CooldownTime = 1,
    TraceEnabled = false,
    TraceThickness = 1,
    TraceColor = Color3.fromRGB(255, 50, 50),
    NameESPEnabled = false,
    HealthESPEnabled = false,
    BoxESPEnabled = false,
    TargetPlayer = nil,
    TargetPlayerID = nil,
    TargetPlayers = {},          -- 複数ターゲット（Dropdownで選択）
    ESPPlayers = {},             -- ESP対象プレイヤー（複数選択）
    WallCheckEnabled = true,
    WallCheckDelay = 0,
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1,
    NotificationEnabled = true,
    ShowLockIndicator = true,
    LockSoundEnabled = true,
    UnlockSoundEnabled = true,
    ResetOnDeath = true,
    LockPriority = "Closest"
}

-- 状態変数
local isLocking = false
local lastLockTime = 0
local lockConnection = nil
local traceConnections = {}
local nameESPConnections = {}
local healthESPConnections = {}
local boxESPConnections = {}
local currentTarget = nil
local lockIndicator = nil
local wallCheckStartTime = 0
local lockStartTime = 0

-- 音
local lockSound = Instance.new("Sound", workspace)
lockSound.SoundId = "rbxassetid://9128736210"
lockSound.Volume = 0.5

local unlockSound = Instance.new("Sound", workspace)
unlockSound.SoundId = "rbxassetid://9128736804"
unlockSound.Volume = 0.5

-- UI作成
local Window = OrionLib:MakeWindow({
    Name = "Syu_uhub - HeadLock System",
    HidePremium = true,
    SaveConfig = true,
    ConfigFolder = "SyuHub"
})

-- 通知関数（Orionのものを使用）
local function Notify(title, content, time)
    if Settings.NotificationEnabled then
        OrionLib:MakeNotification({
            Name = title,
            Content = content,
            Image = "rbxassetid://4483362458",
            Time = time or 3
        })
    end
end

-- ロックインジケーター
local function CreateLockIndicator()
    if lockIndicator then lockIndicator:Destroy() end
    lockIndicator = Instance.new("BillboardGui")
    lockIndicator.Name = "LockIndicator"
    lockIndicator.AlwaysOnTop = true
    lockIndicator.Size = UDim2.new(4,0,4,0)
    lockIndicator.StudsOffset = Vector3.new(0,3,0)
    lockIndicator.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame", lockIndicator)
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = Color3.fromRGB(255,50,50)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
end

-- プレイヤーリスト取得
local function GetPlayerList()
    local list = {}
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    return list
end

-- GetBestEnemy（複数ターゲット対応）
local function GetBestEnemy()
    local best, bestPriority, bestDist = nil, -math.huge, math.huge
    local candidates = (#Settings.TargetPlayers > 0) and {} or Players:GetPlayers()

    if #Settings.TargetPlayers > 0 then
        for _, name in Settings.TargetPlayers do
            local p = Players:FindFirstChild(name)
            if p then table.insert(candidates, p) end
        end
    end

    for _, player in candidates do
        if player == LocalPlayer or not player.Character then continue end
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        local head = player.Character:FindFirstChild("Head")
        local hum = player.Character:FindFirstChild("Humanoid")
        if not (hrp and head and hum and hum.Health > 0) then continue end

        local dist = (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
        if dist > Settings.LockDistance then continue end

        local look = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
        -- IsWithinDirectionalDistance, CheckWallBetween関数は元のものをそのまま使用してください

        local priority = (Settings.LockPriority == "LowestHealth") and (hum.Health/hum.MaxHealth) or
                         (Settings.LockPriority == "Random") and math.random() or
                         1 / (dist + 1)

        if priority > bestPriority then
            bestPriority = priority
            best = player
            bestDist = dist
        end
    end
    return best, bestDist
end

-- LockToHead関数（省略：元のロジックをほぼそのまま使用。必要ならコメントで補完）

-- ESP関数群（CreateNameESP, CreateHealthESP, CreateBoxESP, CreateTrace）も元のものをコピー

local function UpdateESP()
    -- 全削除 → 選択されたプレイヤーのみ再作成
    for _, conn in pairs({nameESPConnections, healthESPConnections, boxESPConnections, traceConnections}) do
        for p, data in pairs(conn) do
            data.connection:Disconnect()
            data[data.nameTag or data.healthBar or data.box or data.trace]:Remove()
        end
        conn = {}
    end

    for _, name in Settings.ESPPlayers do
        local p = Players:FindFirstChild(name)
        if p and p ~= LocalPlayer then
            CreateNameESP(p)
            CreateHealthESP(p)
            CreateBoxESP(p)
            CreateTrace(p)
        end
    end
end

-- =======================
--         UI構築
-- =======================

local MainTab = Window:MakeTab({
    Name = "メイン",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

MainTab:AddToggle({
    Name = "ヘッドロック メイン",
    Default = false,
    Callback = function(v)
        Settings.LockEnabled = v
        if not v then
            if lockConnection then lockConnection:Disconnect() end
            isLocking = false
        end
        Notify("ヘッドロック", v and "有効化" or "無効化", 2)
    end
})

MainTab:AddButton({
    Name = "ロックリセット",
    Callback = function()
        if lockConnection then lockConnection:Disconnect() end
        isLocking = false
        currentTarget = nil
        Notify("リセット", "完了", 2)
    end
})

-- ターゲット選択（単体）
local SingleTarget = MainTab:AddDropdown({
    Name = "単体ターゲット",
    Default = "なし",
    Options = {"なし"},
    Callback = function(v)
        Settings.TargetPlayer = (v == "なし") and nil or v
    end
})

-- 複数ターゲット（重要：Multi = true）
MainTab:AddDropdown({
    Name = "複数ターゲット選択 (最大25)",
    Default = {},
    Options = GetPlayerList(),
    Multi = true,
    Callback = function(selected)
        if #selected > 25 then
            Notify("警告", "25人を超えたため最初の25人だけ適用", 3)
            selected = table.create(25)
            for i = 1, 25 do selected[i] = selected[i] end
        end
        Settings.TargetPlayers = selected
        Notify("複数ターゲット", "設定完了 ("..#selected.."人)", 3)
    end
})

-- ESPトグル
MainTab:AddToggle({Name = "Name ESP", Default = false, Callback = function(v) Settings.NameESPEnabled = v UpdateESP() end})
MainTab:AddToggle({Name = "Health ESP", Default = false, Callback = function(v) Settings.HealthESPEnabled = v UpdateESP() end})
MainTab:AddToggle({Name = "Box ESP", Default = false, Callback = function(v) Settings.BoxESPEnabled = v UpdateESP() end})
MainTab:AddToggle({Name = "Trace (赤線)", Default = false, Callback = function(v) Settings.TraceEnabled = v UpdateESP() end})

-- 複数ESP選択
MainTab:AddDropdown({
    Name = "ESP対象プレイヤー（複数選択）",
    Default = {},
    Options = GetPlayerList(),
    Multi = true,
    Callback = function(selected)
        Settings.ESPPlayers = selected
        UpdateESP()
        Notify("ESP対象", "更新 ("..#selected.."人)", 2)
    end
})

-- 設定タブ（距離・時間など）
local SettingsTab = Window:MakeTab({Name = "設定", Icon = "rbxassetid://4483345998", PremiumOnly = false})

SettingsTab:AddSlider({Name = "全体距離", Min = 1, Max = 100, Default = 5, Rounding = 0, Callback = function(v) Settings.LockDistance = v end})
-- 他スライダーも同様に追加（前方/後方/左右/持続時間/クールダウンなど）

SettingsTab:AddToggle({Name = "壁判定", Default = true, Callback = function(v) Settings.WallCheckEnabled = v end})
SettingsTab:AddSlider({Name = "壁判定遅延(秒)", Min = 0, Max = 5, Default = 0, Rounding = 1, Callback = function(v) Settings.WallCheckDelay = v end})

-- 情報タブなど必要に応じて追加

-- プレイヤーリスト自動更新
spawn(function()
    while wait(3) do
        local list = GetPlayerList()
        SingleTarget:Refresh(list, true)
        -- DropdownのRefreshメソッドで更新（Orionの機能）
    end
end)

-- 初期化
spawn(function()
    wait(1)
    CreateLockIndicator()
    Notify("Syu_uhub", "起動完了！（静かに）", 4)
end)

RunService.RenderStepped:Connect(function()
    if Settings.LockEnabled then
        -- LockToHead() を呼ぶ
    end
end)

OrionLib:Init()
