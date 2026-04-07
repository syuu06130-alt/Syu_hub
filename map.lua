--[[
    ╔══════════════════════════════════════════════════════╗
    ║        Head Rock + MiniMap  Module v2.0              ║
    ║        Draggable UI / Motion Detection / Map         ║
    ╚══════════════════════════════════════════════════════╝
]]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Services
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 設定 (Settings)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CFG = {
    HeadRock = {
        Enabled            = false,
        SpecificTarget     = nil,   -- nil = 最近のプレイヤーを自動選択
        PauseDuration      = 1.5,  -- 動作検知後の停止時間（秒）
        DetectThreshold    = 0.25, -- 検知角度閾値（ラジアン）
        PauseOnDetect      = true, -- 動作検知時に一時停止するか
    },
    MiniMap = {
        Size        = 180,         -- マップの大きさ（px）
        Scale       = 0.045,       -- 縮尺（小さい = より広い範囲）
        ShowPlayers = true,        -- 他プレイヤー表示
        UpdateRate  = 0.033,       -- 更新間隔（秒）≒ 30fps
    },
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 共通ユーティリティ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(90, 90, 140)
    s.Thickness = thickness or 1.5
    s.Parent = parent
    return s
end

local function makeTween(obj, props, duration, style, dir)
    return TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [1] HEAD ROCK  浮遊UI（ドラッグ可能）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HRGui = Instance.new("ScreenGui")
HRGui.Name           = "HeadRockUI"
HRGui.ResetOnSpawn   = false
HRGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HRGui.DisplayOrder   = 999
HRGui.Parent         = PlayerGui

-- メインフレーム（iPhone版Rayfield相当の幅）
local MainFrame = Instance.new("Frame")
MainFrame.Name            = "MainFrame"
MainFrame.Size            = UDim2.new(0, 220, 0, 58)
MainFrame.Position        = UDim2.new(0.5, -110, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active          = true
MainFrame.Parent          = HRGui
makeCorner(MainFrame, 14)
makeStroke(MainFrame, Color3.fromRGB(70, 70, 120), 1.5)

-- グラデーション装飾
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(22, 22, 38)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(10, 10, 18)),
})
grad.Rotation = 90
grad.Parent = MainFrame

-- ドラッグハンドル表示（上部バー）
local DragBar = Instance.new("Frame")
DragBar.Name              = "DragBar"
DragBar.Size              = UDim2.new(0, 36, 0, 4)
DragBar.Position          = UDim2.new(0.5, -18, 0, 7)
DragBar.BackgroundColor3  = Color3.fromRGB(80, 80, 120)
DragBar.BorderSizePixel   = 0
DragBar.Parent            = MainFrame
makeCorner(DragBar, 4)

-- タイトル
local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size              = UDim2.new(0, 130, 0, 20)
TitleLbl.Position          = UDim2.new(0, 12, 0, 14)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text              = "🔒 Head Rock"
TitleLbl.TextColor3        = Color3.fromRGB(200, 200, 255)
TitleLbl.TextSize          = 13
TitleLbl.Font              = Enum.Font.GothamBold
TitleLbl.TextXAlignment    = Enum.TextXAlignment.Left
TitleLbl.Parent            = MainFrame

-- ステータスラベル
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size              = UDim2.new(0, 140, 0, 14)
StatusLbl.Position          = UDim2.new(0, 12, 0, 36)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text              = "待機中"
StatusLbl.TextColor3        = Color3.fromRGB(130, 130, 170)
StatusLbl.TextSize          = 10
StatusLbl.Font              = Enum.Font.Gotham
StatusLbl.TextXAlignment    = Enum.TextXAlignment.Left
StatusLbl.Parent            = MainFrame

-- ON/OFFトグルボタン
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size              = UDim2.new(0, 56, 0, 26)
ToggleBtn.Position          = UDim2.new(1, -66, 0.5, -2)
ToggleBtn.BackgroundColor3  = Color3.fromRGB(50, 20, 20)
ToggleBtn.Text              = "OFF"
ToggleBtn.TextColor3        = Color3.fromRGB(255, 70, 70)
ToggleBtn.TextSize          = 12
ToggleBtn.Font              = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor   = false
ToggleBtn.Parent            = MainFrame
makeCorner(ToggleBtn, 8)
makeStroke(ToggleBtn, Color3.fromRGB(120, 40, 40), 1)

-- 設定ボタン（⚙）
local CfgBtn = Instance.new("TextButton")
CfgBtn.Size             = UDim2.new(0, 22, 0, 22)
CfgBtn.Position         = UDim2.new(1, -30, 0, 6)
CfgBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 45)
CfgBtn.Text             = "⚙"
CfgBtn.TextColor3       = Color3.fromRGB(160, 160, 220)
CfgBtn.TextSize         = 13
CfgBtn.Font             = Enum.Font.GothamBold
CfgBtn.AutoButtonColor  = false
CfgBtn.ZIndex           = 5
CfgBtn.Parent           = MainFrame
makeCorner(CfgBtn, 6)

-- ━━━━━ ドラッグ実装 ━━━━━
do
    local dragging, dragStart, frameStart = false, nil, nil

    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- 設定・トグルボタン上はドラッグしない
            dragging   = true
            dragStart  = input.Position
            frameStart = MainFrame.Position
        end
    end
    local function onInputEnded(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end
    local function onInputChanged(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMove then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end

    MainFrame.InputBegan:Connect(onInputBegan)
    MainFrame.InputEnded:Connect(onInputEnded)
    UserInputService.InputChanged:Connect(onInputChanged)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [2] 設定パネル
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local SettingsPanel = Instance.new("Frame")
SettingsPanel.Name             = "SettingsPanel"
SettingsPanel.Size             = UDim2.new(0, 248, 0, 230)
SettingsPanel.Position         = UDim2.new(0, 0, 1, 6)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
SettingsPanel.BorderSizePixel  = 0
SettingsPanel.Visible          = false
SettingsPanel.ZIndex           = 20
SettingsPanel.Parent           = MainFrame
makeCorner(SettingsPanel, 12)
makeStroke(SettingsPanel, Color3.fromRGB(70, 70, 120), 1.2)

local function makeSectionLabel(parent, text, yOff)
    local l = Instance.new("TextLabel")
    l.Size              = UDim2.new(1, -16, 0, 14)
    l.Position          = UDim2.new(0, 8, 0, yOff)
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextColor3        = Color3.fromRGB(120, 120, 180)
    l.TextSize          = 9
    l.Font              = Enum.Font.GothamBold
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.ZIndex            = 21
    l.Parent            = parent
    return l
end

-- スライダービルダー
local function makeSlider(parent, label, yOff, minV, maxV, defaultV, decimals, callback)
    decimals = decimals or 1

    local rowH  = 38
    local lbl   = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, -16, 0, 14)
    lbl.Position         = UDim2.new(0, 8, 0, yOff)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label .. ": " .. string.format("%." .. decimals .. "f", defaultV)
    lbl.TextColor3       = Color3.fromRGB(190, 190, 230)
    lbl.TextSize         = 10
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 21
    lbl.Parent           = parent

    local track = Instance.new("Frame")
    track.Size            = UDim2.new(1, -20, 0, 5)
    track.Position        = UDim2.new(0, 10, 0, yOff + 17)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    track.ZIndex          = 21
    track.Parent          = parent
    makeCorner(track, 4)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((defaultV - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 90, 210)
    fill.ZIndex           = 22
    fill.Parent           = track
    makeCorner(fill, 4)

    local handle = Instance.new("Frame")
    handle.Size            = UDim2.new(0, 13, 0, 13)
    handle.Position        = UDim2.new((defaultV - minV)/(maxV - minV), -6, 0.5, -6)
    handle.BackgroundColor3 = Color3.fromRGB(160, 160, 255)
    handle.ZIndex          = 23
    handle.Parent          = track
    makeCorner(handle, 8)

    -- スライダードラッグ
    local draggingSlider = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = true
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not draggingSlider then return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseMove then return end

        local tp = track.AbsolutePosition
        local ts = track.AbsoluteSize
        local t  = math.clamp((i.Position.X - tp.X) / ts.X, 0, 1)
        local mult = 10 ^ decimals
        local val  = math.floor((minV + t * (maxV - minV)) * mult + 0.5) / mult
        fill.Size           = UDim2.new(t, 0, 1, 0)
        handle.Position     = UDim2.new(t, -6, 0.5, -6)
        lbl.Text            = label .. ": " .. string.format("%." .. decimals .. "f", val)
        callback(val)
    end)

    return lbl
end

-- ─── HeadRock セクション ───
makeSectionLabel(SettingsPanel, "── Head Rock ──────────", 8)
makeSlider(SettingsPanel, "停止時間（秒）", 24, 0.3, 6.0, CFG.HeadRock.PauseDuration, 1, function(v)
    CFG.HeadRock.PauseDuration = v
end)
makeSlider(SettingsPanel, "検知感度", 68, 0.05, 1.0, CFG.HeadRock.DetectThreshold, 2, function(v)
    CFG.HeadRock.DetectThreshold = v
end)

-- 検知一時停止 ON/OFF チェックボックス
local detectToggle = Instance.new("TextButton")
detectToggle.Size             = UDim2.new(1, -16, 0, 22)
detectToggle.Position         = UDim2.new(0, 8, 0, 112)
detectToggle.BackgroundColor3 = Color3.fromRGB(22, 22, 36)
detectToggle.Text             = (CFG.HeadRock.PauseOnDetect and "✔ " or "✖ ") .. "動作検知で一時停止"
detectToggle.TextColor3       = CFG.HeadRock.PauseOnDetect
    and Color3.fromRGB(100, 220, 140)
    or  Color3.fromRGB(220, 100, 100)
detectToggle.TextSize         = 10
detectToggle.Font             = Enum.Font.GothamBold
detectToggle.AutoButtonColor  = false
detectToggle.ZIndex           = 21
detectToggle.Parent           = SettingsPanel
makeCorner(detectToggle, 7)

detectToggle.MouseButton1Click:Connect(function()
    CFG.HeadRock.PauseOnDetect = not CFG.HeadRock.PauseOnDetect
    if CFG.HeadRock.PauseOnDetect then
        detectToggle.Text      = "✔ 動作検知で一時停止"
        detectToggle.TextColor3 = Color3.fromRGB(100, 220, 140)
    else
        detectToggle.Text      = "✖ 動作検知で一時停止"
        detectToggle.TextColor3 = Color3.fromRGB(220, 100, 100)
    end
end)

-- ─── MiniMap セクション ───
makeSectionLabel(SettingsPanel, "── MiniMap ─────────────", 142)
makeSlider(SettingsPanel, "マップサイズ", 158, 120, 320, CFG.MiniMap.Size, 0, function(v)
    CFG.MiniMap.Size = v
    -- リアルタイムでマップサイズを変更
    if MapFrame then
        MapFrame.Size     = UDim2.new(0, v, 0, v)
        MapFrame.Position = UDim2.new(0, 10, 1, -(v + 10))
    end
end)
makeSlider(SettingsPanel, "マップ縮尺", 200, 0.01, 0.15, CFG.MiniMap.Scale, 3, function(v)
    CFG.MiniMap.Scale = v
end)

-- 設定パネル開閉
CfgBtn.MouseButton1Click:Connect(function()
    SettingsPanel.Visible = not SettingsPanel.Visible
    CfgBtn.TextColor3 = SettingsPanel.Visible
        and Color3.fromRGB(200, 200, 255)
        or  Color3.fromRGB(120, 120, 180)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [3] HEAD ROCK  ロジック
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local hrConnection = nil
local isPaused     = false
local pauseEndTime = 0
local prevCamCF    = nil  -- 前フレームのカメラCF（動作検知用）

-- 最近接プレイヤーを取得
local function getNearestPlayer()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = p
                end
            end
        end
    end
    return best
end

-- カメラの角速度を正確に検知（前フレーム差分）
local function detectMotion(currentCF)
    if not prevCamCF then
        prevCamCF = currentCF
        return false
    end
    -- 相対回転を取得
    local relCF = prevCamCF:ToObjectSpace(currentCF)
    local rx, ry, _ = relCF:ToEulerAnglesXYZ()
    local threshold  = CFG.HeadRock.DetectThreshold

    -- 上下 or 左右の意図的な操作を検知
    local detected = (math.abs(rx) > threshold) or (math.abs(ry) > threshold)
    prevCamCF = currentCF
    return detected
end

local function setStatus(text, color)
    StatusLbl.Text       = text
    StatusLbl.TextColor3 = color or Color3.fromRGB(130, 130, 170)
end

local function startHeadRock()
    if hrConnection then hrConnection:Disconnect() end
    isPaused   = false
    prevCamCF  = Camera.CFrame

    hrConnection = RunService.RenderStepped:Connect(function()
        local now = tick()

        -- ターゲット取得
        local target = CFG.HeadRock.SpecificTarget or getNearestPlayer()
        if not target or not target.Character then
            setStatus("ターゲットなし", Color3.fromRGB(200, 100, 100))
            return
        end
        local head = target.Character:FindFirstChild("Head")
        if not head then
            setStatus("Headなし", Color3.fromRGB(200, 100, 100))
            return
        end

        -- 一時停止中
        if isPaused then
            local remain = pauseEndTime - now
            if remain > 0 then
                setStatus(string.format("⏸ 停止中 %.1fs", remain), Color3.fromRGB(255, 200, 60))
                prevCamCF = Camera.CFrame -- 停止中は参照をリセット
                return
            else
                -- 停止解除 → 次のHead Rockが「作動するまで」停止を維持するため
                -- ここでは停止解除とし、再ロック開始
                isPaused  = false
                prevCamCF = Camera.CFrame
                setStatus("🔒 再ロック: " .. target.Name, Color3.fromRGB(100, 220, 140))
            end
        end

        -- 動作検知
        if CFG.HeadRock.PauseOnDetect then
            if detectMotion(Camera.CFrame) then
                isPaused     = true
                pauseEndTime = now + CFG.HeadRock.PauseDuration
                setStatus("⚠ 動作検知 → 停止", Color3.fromRGB(255, 160, 60))
                return
            end
        end

        -- Head Rockを実行（カメラ向きをHeadに固定）
        local camPos = Camera.CFrame.Position
        Camera.CFrame = CFrame.new(camPos, head.Position)
        prevCamCF     = Camera.CFrame
        setStatus("🔒 " .. target.Name, Color3.fromRGB(80, 220, 140))
    end)
end

local function stopHeadRock()
    if hrConnection then
        hrConnection:Disconnect()
        hrConnection = nil
    end
    isPaused  = false
    prevCamCF = nil
    setStatus("待機中", Color3.fromRGB(130, 130, 170))
end

-- トグルUI更新
local function updateToggleVisual()
    local on = CFG.HeadRock.Enabled
    if on then
        ToggleBtn.Text              = "ON"
        ToggleBtn.TextColor3        = Color3.fromRGB(80, 255, 130)
        ToggleBtn.BackgroundColor3  = Color3.fromRGB(20, 50, 30)
        makeStroke(ToggleBtn, Color3.fromRGB(40, 140, 70), 1):Destroy()
        -- ボーダー色更新
        for _, c in ipairs(ToggleBtn:GetChildren()) do
            if c:IsA("UIStroke") then c.Color = Color3.fromRGB(40, 140, 70) end
        end
    else
        ToggleBtn.Text              = "OFF"
        ToggleBtn.TextColor3        = Color3.fromRGB(255, 70, 70)
        ToggleBtn.BackgroundColor3  = Color3.fromRGB(50, 20, 20)
        for _, c in ipairs(ToggleBtn:GetChildren()) do
            if c:IsA("UIStroke") then c.Color = Color3.fromRGB(120, 40, 40) end
        end
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    CFG.HeadRock.Enabled = not CFG.HeadRock.Enabled
    updateToggleVisual()
    if CFG.HeadRock.Enabled then
        startHeadRock()
    else
        stopHeadRock()
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [4] MINIMAP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local MapGui = Instance.new("ScreenGui")
MapGui.Name           = "MiniMapUI"
MapGui.ResetOnSpawn   = false
MapGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MapGui.DisplayOrder   = 998
MapGui.Parent         = PlayerGui

local MS = CFG.MiniMap.Size  -- 初期サイズ

MapFrame = Instance.new("Frame")
MapFrame.Name              = "MapFrame"
MapFrame.Size              = UDim2.new(0, MS, 0, MS)
MapFrame.Position          = UDim2.new(0, 10, 1, -(MS + 10))
MapFrame.BackgroundColor3  = Color3.fromRGB(8, 10, 16)
MapFrame.BorderSizePixel   = 0
MapFrame.ClipsDescendants  = true
MapFrame.Parent            = MapGui
makeCorner(MapFrame, 14)
makeStroke(MapFrame, Color3.fromRGB(60, 60, 110), 1.5)

-- マップ背景グリッド（深度感）
local MapBG = Instance.new("Frame")
MapBG.Size              = UDim2.new(1, 0, 1, 0)
MapBG.BackgroundColor3  = Color3.fromRGB(10, 12, 20)
MapBG.BorderSizePixel   = 0
MapBG.ZIndex            = 1
MapBG.Parent            = MapFrame

local MapBGGrad = Instance.new("UIGradient")
MapBGGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 16, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 8, 14)),
})
MapBGGrad.Rotation = 135
MapBGGrad.Parent   = MapBG

-- タイトルバー
local MapTitle = Instance.new("Frame")
MapTitle.Size             = UDim2.new(1, 0, 0, 20)
MapTitle.Position         = UDim2.new(0, 0, 0, 0)
MapTitle.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
MapTitle.BorderSizePixel  = 0
MapTitle.ZIndex           = 5
MapTitle.Parent           = MapFrame

local MapTitleLbl = Instance.new("TextLabel")
MapTitleLbl.Size              = UDim2.new(1, 0, 1, 0)
MapTitleLbl.BackgroundTransparency = 1
MapTitleLbl.Text              = "📡  MINIMAP"
MapTitleLbl.TextColor3        = Color3.fromRGB(160, 160, 220)
MapTitleLbl.TextSize          = 10
MapTitleLbl.Font              = Enum.Font.GothamBold
MapTitleLbl.ZIndex            = 6
MapTitleLbl.Parent            = MapTitle

-- 自分ドット（マップ中心・固定）
local SelfDot = Instance.new("Frame")
SelfDot.Name             = "SelfDot"
SelfDot.Size             = UDim2.new(0, 10, 0, 10)
SelfDot.Position         = UDim2.new(0.5, -5, 0.5, -5)
SelfDot.BackgroundColor3 = Color3.fromRGB(60, 200, 255)
SelfDot.ZIndex           = 8
SelfDot.Parent           = MapFrame
makeCorner(SelfDot, 6)

-- 自分の向き矢印
local DirArrow = Instance.new("Frame")
DirArrow.Size            = UDim2.new(0, 2, 0, 9)
DirArrow.Position        = UDim2.new(0.5, -1, 0, -9)
DirArrow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
DirArrow.ZIndex          = 9
DirArrow.Parent          = SelfDot
makeCorner(DirArrow, 2)

-- 座標表示
local CoordsLbl = Instance.new("TextLabel")
CoordsLbl.Size              = UDim2.new(1, -6, 0, 14)
CoordsLbl.Position          = UDim2.new(0, 3, 1, -16)
CoordsLbl.BackgroundTransparency = 1
CoordsLbl.Text              = "X:0  Y:0  Z:0"
CoordsLbl.TextColor3        = Color3.fromRGB(100, 180, 220)
CoordsLbl.TextSize          = 8
CoordsLbl.Font              = Enum.Font.Code
CoordsLbl.TextXAlignment    = Enum.TextXAlignment.Left
CoordsLbl.ZIndex            = 8
CoordsLbl.Parent            = MapFrame

-- プレイヤードットプール
local playerDots = {}   -- [UserId] = Frame

local function getOrMakeDot(player)
    if playerDots[player.UserId] then return playerDots[player.UserId] end

    local dot = Instance.new("Frame")
    dot.Name             = "Dot_" .. player.Name
    dot.Size             = UDim2.new(0, 8, 0, 8)
    dot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    dot.ZIndex           = 7
    dot.Parent           = MapFrame
    makeCorner(dot, 5)

    -- 名前ラベル
    local nl = Instance.new("TextLabel")
    nl.Name              = "NameLbl"
    nl.Size              = UDim2.new(0, 80, 0, 12)
    nl.Position          = UDim2.new(0, 10, 0, -2)
    nl.BackgroundTransparency = 1
    nl.Text              = player.Name
    nl.TextColor3        = Color3.fromRGB(255, 160, 160)
    nl.TextSize          = 8
    nl.Font              = Enum.Font.Gotham
    nl.ZIndex            = 8
    nl.TextXAlignment    = Enum.TextXAlignment.Left
    nl.Parent            = dot

    playerDots[player.UserId] = dot
    return dot
end

Players.PlayerRemoving:Connect(function(p)
    if playerDots[p.UserId] then
        playerDots[p.UserId]:Destroy()
        playerDots[p.UserId] = nil
    end
end)

-- マップ更新ループ（リアルタイム）
local lastMapTick = 0
RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastMapTick < CFG.MiniMap.UpdateRate then return end
    lastMapTick = now

    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local myPos = myHRP.Position
    -- Y軸回転（ヨー）を取得して自分ドットを回転
    local look   = myHRP.CFrame.LookVector
    local yaw    = math.atan2(-look.X, -look.Z)
    SelfDot.Rotation = math.deg(yaw)

    -- 座標更新
    CoordsLbl.Text = string.format("X:%.0f  Y:%.0f  Z:%.0f", myPos.X, myPos.Y, myPos.Z)

    -- マップ半サイズ
    local half  = CFG.MiniMap.Size / 2
    local scale = CFG.MiniMap.Scale
    local cosY  = math.cos(-yaw)
    local sinY  = math.sin(-yaw)

    -- 使用済みIDを追跡（消滅検知）
    local activeIds = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        activeIds[p.UserId] = true

        local char = p.Character
        local dot  = getOrMakeDot(p)

        if not CFG.MiniMap.ShowPlayers or not char then
            dot.Visible = false
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            dot.Visible = false
            continue
        end

        -- 相対位置（自分を中心）
        local rel = hrp.Position - myPos
        -- 自分の向きに合わせて回転
        local rx = rel.X * cosY - rel.Z * sinY
        local rz = rel.X * sinY + rel.Z * cosY

        local px = half + rx * scale
        local pz = half + rz * scale

        -- マップ外でも端に表示（クランプ）
        local margin = 6
        local titleH = 20
        px = math.clamp(px, margin, CFG.MiniMap.Size - margin - 8)
        pz = math.clamp(pz, titleH + margin, CFG.MiniMap.Size - margin - 8)

        dot.Position = UDim2.new(0, px - 4, 0, pz - 4)
        dot.Visible  = true

        -- 距離表示
        local dist = math.floor((hrp.Position - myPos).Magnitude)
        local nl   = dot:FindFirstChild("NameLbl")
        if nl then
            nl.Text = string.format("%s [%dm]", p.Name, dist)
        end

        -- 距離で色変化（近い=赤, 遠い=オレンジ）
        local distRatio = math.clamp(dist / 200, 0, 1)
        dot.BackgroundColor3 = Color3.fromRGB(
            255,
            math.floor(60 + distRatio * 100),
            math.floor(60 * (1 - distRatio))
        )
    end

    -- 切断済みプレイヤーのドットを削除
    for uid, dot in pairs(playerDots) do
        if not activeIds[uid] then
            dot:Destroy()
            playerDots[uid] = nil
        end
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 完了メッセージ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print("╔════════════════════════════════╗")
print("║  Head Rock + MiniMap  Loaded   ║")
print("║  ・浮遊UI（ドラッグ対応）      ║")
print("║  ・動作検知 + 一時停止          ║")
print("║  ・リアルタイムミニマップ       ║")
print("╚════════════════════════════════╝")
