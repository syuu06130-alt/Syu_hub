-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

-- Player & GUI
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- =============================================
--          設定テーブル（元の機能を維持）
-- =============================================
local Settings = {
    LockEnabled = false,
    LockDistance = 5,
    LockDistanceLeft = 5,
    LockDistanceRight = 5,
    LockDistanceFront = 5,
    LockDistanceBack = 5,
    LockDuration = 0.5,
    CooldownTime = 1,
    WallCheckEnabled = true,
    WallCheckDelay = 0,
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1,
    LockPriority = "Closest", -- "Closest", "LowestHealth", "Random"
    
    -- 複数ターゲット（名前をカンマ区切りで入力）
    TargetPlayers = {},       -- table形式で保持
    
    -- 複数ESP対象
    ESPPlayers = {},
    
    -- ESPトグル
    NameESPEnabled = false,
    HealthESPEnabled = false,
    BoxESPEnabled = false,
    TraceEnabled = false,
    TraceThickness = 1,
    TraceColor = Color3.fromRGB(255, 50, 50),
    
    -- その他
    ShowLockIndicator = true,
    LockSoundEnabled = true,
    UnlockSoundEnabled = true,
    ResetOnDeath = true,
    NotificationEnabled = true
}

-- 状態管理
local isLocking = false
local lastLockTime = 0
local lockConnection = nil
local currentTarget = nil
local lockIndicator = nil
local wallCheckStartTime = 0
local lockStartTime = 0

-- Drawing objects
local nameESPConnections = {}
local healthESPConnections = {}
local boxESPConnections = {}
local traceConnections = {}

-- Sounds
local lockSound = Instance.new("Sound")
lockSound.SoundId = "rbxassetid://9128736210"
lockSound.Volume = 0.5
lockSound.Parent = workspace

local unlockSound = Instance.new("Sound")
unlockSound.SoundId = "rbxassetid://9128736804"
unlockSound.Volume = 0.5
unlockSound.Parent = workspace

-- =============================================
--          自作UIの作成（あなたのコードそのまま）
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SyuDarkUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 420)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

-- （以下、影・角丸・タイトルバー・閉じるボタン・最小化ボタンなどはあなたのコードをそのまま流用）
-- ※ここでは省略してスペース節約。あなたのコードのこの部分はそのままコピーしてください。
-- 必要な部分だけ抜粋して続けますが、実際はあなたのUIコード全体をここに貼り付けてください。

-- =============================================
--          機能実装用のヘルパー関数（簡略版）
-- =============================================

local function Notify(msg)
    if Settings.NotificationEnabled then
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title = "Syu_uhub",
            Text = msg,
            Duration = 3
        })
    end
end

local function GetPlayerList()
    local list = {}
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

-- カンマ区切り文字列 → テーブル変換（重複除去・トリム）
local function ParseMultiSelect(str)
    if not str or str == "" then return {} end
    local t = {}
    local seen = {}
    for name in str:gmatch("[^,]+") do
        name = name:match("^%s*(.-)%s*$") -- トリム
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(t, name)
        end
    end
    return t
end

-- =============================================
--          UI要素の追加（あなたのセクションに追加）
-- =============================================

-- 例：メイン機能セクションに追加する場合
local MainContainer = createSection("🎯 Syu_uhub メイン", 1)

-- ヘッドロックトグル
createToggle(MainContainer, "ヘッドロック (ON/OFF)", "lockEnabled", nil)

-- WallCheck
createToggle(MainContainer, "壁判定", "wallCheck", nil)

-- Smooth Lock
createToggle(MainContainer, "スムーズロック", "smoothLock", nil)

-- ESP各種
createToggle(MainContainer, "Name ESP", "nameESP", nil)
createToggle(MainContainer, "Health ESP", "healthESP", nil)
createToggle(MainContainer, "Box ESP", "boxESP", nil)
createToggle(MainContainer, "Trace (赤線)", "traceESP", nil)

-- 複数ターゲット入力
local MultiTargetFrame = Instance.new("Frame")
MultiTargetFrame.Size = UDim2.new(1, 0, 0, 70)
MultiTargetFrame.BackgroundTransparency = 1
MultiTargetFrame.Parent = MainContainer

local MultiTargetLabel = Instance.new("TextLabel")
MultiTargetLabel.Size = UDim2.new(1, 0, 0, 20)
MultiTargetLabel.BackgroundTransparency = 1
MultiTargetLabel.Text = "複数ターゲット (カンマ区切り)"
MultiTargetLabel.TextColor3 = Color3.fromRGB(180,180,255)
MultiTargetLabel.Font = Enum.Font.Gotham
MultiTargetLabel.TextSize = 13
MultiTargetLabel.Parent = MultiTargetFrame

local MultiTargetBox = Instance.new("TextBox")
MultiTargetBox.Size = UDim2.new(1, -20, 0, 30)
MultiTargetBox.Position = UDim2.new(0, 10, 0, 25)
MultiTargetBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
MultiTargetBox.TextColor3 = Color3.fromRGB(220,220,220)
MultiTargetBox.PlaceholderText = "例: player1,player2,xyz"
MultiTargetBox.Text = ""
MultiTargetBox.ClearTextOnFocus = false
MultiTargetBox.Parent = MultiTargetFrame

local MultiTargetCorner = Instance.new("UICorner")
MultiTargetCorner.CornerRadius = UDim.new(0,6)
MultiTargetCorner.Parent = MultiTargetBox

-- 複数ESP対象入力（同様）
local MultiESPFrame = Instance.new("Frame")
MultiESPFrame.Size = UDim2.new(1, 0, 0, 70)
MultiESPFrame.BackgroundTransparency = 1
MultiESPFrame.Parent = MainContainer

-- （MultiTargetFrameとほぼ同じ構造で作成）

-- =============================================
--          トグル状態の同期（クリック時にSettings更新）
-- =============================================

-- 例: ヘッドロックトグル
Button.MouseButton1Click:Connect(function()  -- ← ここは各createToggle内のButton
    Settings.LockEnabled = not Settings.LockEnabled
    updateToggle(Settings.LockEnabled)        -- スイッチアニメーション
    Notify("ヘッドロック: " .. (Settings.LockEnabled and "ON" or "OFF"))
end)

-- TextBox変更時
MultiTargetBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        Settings.TargetPlayers = ParseMultiSelect(MultiTargetBox.Text)
        Notify("複数ターゲット更新: " .. #Settings.TargetPlayers .. "人")
    end
end)

-- ※他のトグル、ESP対象TextBoxも同様に実装してください

-- =============================================
--          元のLockToHead関数（ほぼそのまま）
--          ※必要に応じてGetBestEnemy内のロジックを
--            Settings.TargetPlayers を参照するように調整
-- =============================================

-- （ここに元の LockToHead / GetBestEnemy / ESP作成関数などを貼り付け）

-- メインループ
RunService.RenderStepped:Connect(LockToHead)

print("Syu_uhub 自作UI版 読み込み完了！")
