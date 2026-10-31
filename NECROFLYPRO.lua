local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- State
local speed = 60
local flying = false
local tourRunning = false
local tourMode = "ONCE"       -- ONCE or LOOP
local eEnabled = true
local eMode = "TOGGLE"        -- TOGGLE or HOLD
local eHeld = false
local verticalInput = 0
local selectedId, nextId = nil, 1
local savedPoints = {}
local flyConnection, attachment, velocity, align
local gui, uiScale, icon, frame, status, pages
local currentTab = "FLY"
local shuttingDown = false
local iconDragging, iconMoved, suppressIconClick = false, false, false
local iconDragStart, iconStartPosition

local function create(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local function stroke(obj, color)
    create("UIStroke", {Color = color or Color3.fromRGB(0, 180, 255), Thickness = 1.5}, obj)
end

local function setStatus(message)
    if status and status.Parent then status.Text = message end
end

local function button(parent, text, color, height)
    local b = create("TextButton", {
        Size = UDim2.new(1, -8, 0, height or 36),
        BackgroundColor3 = color or Color3.fromRGB(28, 72, 105),
        TextColor3 = Color3.new(1, 1, 1),
        Text = text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = true
    }, parent)
    corner(b, 7)
    return b
end

local function box(parent, placeholder, initial, height)
    local b = create("TextBox", {
        Size = UDim2.new(1, -8, 0, height or 34),
        BackgroundColor3 = Color3.fromRGB(30, 38, 53),
        TextColor3 = Color3.new(1, 1, 1),
        PlaceholderColor3 = Color3.fromRGB(165, 180, 195),
        PlaceholderText = placeholder,
        Text = initial or "",
        TextSize = 12,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        TextWrapped = true
    }, parent)
    corner(b, 7)
    return b
end

local function label(parent, text, height)
    return create("TextLabel", {
        Size = UDim2.new(1, -8, 0, height or 27),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(0, 220, 255),
        Text = text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true
    }, parent)
end

local old = playerGui:FindFirstChild("NecroFlyPro")
if old then old:Destroy() end

gui = create("ScreenGui", {
    Name = "NecroFlyPro",
    ResetOnSpawn = false,
    DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, playerGui)

uiScale = create("UIScale", {Scale = 1}, gui)

icon = create("TextButton", {
    Name = "NecroIcon",
    Size = UDim2.fromOffset(84, 48),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(12, 22, 38),
    TextColor3 = Color3.fromRGB(0, 230, 255),
    Text = "⚡ NECRO",
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    Active = true,
    Selectable = true
}, gui)
corner(icon, 12)
stroke(icon)

frame = create("Frame", {
    Name = "MainMenu",
    Size = UDim2.fromOffset(370, 480),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(14, 20, 33),
    ClipsDescendants = true
}, gui)
corner(frame, 12)
stroke(frame)

create("TextLabel", {
    Position = UDim2.fromOffset(12, 6),
    Size = UDim2.new(1, -58, 0, 28),
    BackgroundTransparency = 1,
    Text = "NECRO FLY PRO",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, frame)

local closeButton = create("TextButton", {
    Size = UDim2.fromOffset(30, 27),
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -7, 0, 6),
    BackgroundColor3 = Color3.fromRGB(110, 40, 50),
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    Font = Enum.Font.GothamBold
}, frame)
corner(closeButton, 6)

local tabBar = create("Frame", {
    Position = UDim2.fromOffset(7, 38),
    Size = UDim2.new(1, -14, 0, 31),
    BackgroundTransparency = 1
}, frame)

local tabNames = {"FLY", "TP", "TOUR", "CONFIG"}
local tabButtons = {}
for i, name in ipairs(tabNames) do
    local b = create("TextButton", {
        Position = UDim2.new((i - 1) / 4, 0, 0, 0),
        Size = UDim2.new(1 / 4, -3, 1, 0),
        BackgroundColor3 = Color3.fromRGB(30, 42, 60),
        Text = name,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = Enum.Font.GothamBold
    }, tabBar)
    corner(b, 6)
    tabButtons[name] = b
end

local pageHolder = create("Frame", {
    Position = UDim2.fromOffset(8, 76),
    Size = UDim2.new(1, -16, 1, -112),
    BackgroundTransparency = 1,
    ClipsDescendants = true
}, frame)

status = create("TextLabel", {
    Position = UDim2.new(0, 9, 1, -29),
    Size = UDim2.new(1, -18, 0, 22),
    BackgroundTransparency = 1,
    Text = "Ready",
    TextColor3 = Color3.fromRGB(0, 210, 255),
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true
}, frame)

pages = {}
local function makePage(name)
    local page = create("ScrollingFrame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 5,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false
    }, pageHolder)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)
    pages[name] = page
    return page
end

local function showTab(name)
    currentTab = name
    for n, p in pairs(pages) do p.Visible = n == name end
    for n, b in pairs(tabButtons) do
        b.BackgroundColor3 = n == name and Color3.fromRGB(0, 115, 155)
            or Color3.fromRGB(30, 42, 60)
    end
end

for name, b in pairs(tabButtons) do
    b.Activated:Connect(function() showTab(name) end)
end

-- Character helpers
local function getCharacter()
    local character = player.Character
    if not character then return nil end
    local r = character:FindFirstChild("HumanoidRootPart")
    local h = character:FindFirstChildOfClass("Humanoid")
    if r and h and h.Health > 0 then return character, r, h end
    return nil
end

local function teleportTo(cf)
    local _, r = getCharacter()
    if not r then setStatus("Character is not ready."); return false end
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    r.CFrame = cf + Vector3.new(0, 3, 0)
    return true
end

local function getKey(text)
    text = string.upper((text or ""):gsub("%s+", ""))
    if text == "]" then return Enum.KeyCode.RightBracket end
    if text == "[" then return Enum.KeyCode.LeftBracket end
    if #text == 1 and text:match("%a") then return Enum.KeyCode[text] end
    if text:match("^F%d+$") then
        local n = tonumber(text:sub(2))
        if n and n >= 1 and n <= 12 then return Enum.KeyCode[text] end
    end
    return nil
end

local function sortedPoints()
    local result = {}
    for _, p in pairs(savedPoints) do table.insert(result, p) end
    table.sort(result, function(a, b)
        if a.priority == b.priority then return a.id < b.id end
        return a.priority < b.priority
    end)
    return result
end

-- FLY TAB
local flyPage = makePage("FLY")
label(flyPage, "FLIGHT CONTROL")
local flyToggle = button(flyPage, "FLY: OFF")
local speedBox = box(flyPage, "Speed 1-300", "60")
local setSpeedButton = button(flyPage, "APPLY SPEED")
local upButton = button(flyPage, "HOLD TO FLY UP")
local downButton = button(flyPage, "HOLD TO FLY DOWN")
local levelButton = button(flyPage, "STOP VERTICAL MOVEMENT")

local function stopFly()
    flying = false
    verticalInput = 0
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if velocity then velocity:Destroy(); velocity = nil end
    if align then align:Destroy(); align = nil end
    if attachment then attachment:Destroy(); attachment = nil end
    local _, _, h = getCharacter()
    if h then
        h.AutoRotate = true
        h.PlatformStand = false
        h:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if flyToggle and flyToggle.Parent then flyToggle.Text = "FLY: OFF" end
end

local function startFly()
    if flying then return end
    local _, r, h = getCharacter()
    if not r then setStatus("Character is not ready."); return end
    flying = true
    h.AutoRotate = false

    attachment = Instance.new("Attachment")
    attachment.Name = "NecroFlyAttachment"
    attachment.Parent = r

    velocity = Instance.new("LinearVelocity")
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.MaxForce = math.huge
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = r

    align = Instance.new("AlignOrientation")
    align.Attachment0 = attachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.Responsiveness = 15
    align.MaxTorque = math.huge
    align.Parent = r

    h:ChangeState(Enum.HumanoidStateType.Freefall)
    flyToggle.Text = "FLY: ON"

    flyConnection = RunService.Heartbeat:Connect(function()
        if not flying or not r.Parent or h.Health <= 0
            or not velocity or not velocity.Parent then
            stopFly()
            return
        end
        local camera = workspace.CurrentCamera
        local direction = h.MoveDirection
        local vertical = verticalInput
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vertical -= 1 end
        vertical = math.clamp(vertical, -1, 1)
        velocity.VectorVelocity = direction * speed + Vector3.new(0, vertical * speed, 0)
        if camera then
            local look = camera.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.001 then
                align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
            end
        end
    end)
end

flyToggle.Activated:Connect(function()
    if flying then stopFly() else startFly() end
end)

setSpeedButton.Activated:Connect(function()
    local n = tonumber(speedBox.Text)
    if not n or n ~= n or math.abs(n) == math.huge then
        setStatus("Enter a valid speed."); return
    end
    speed = math.clamp(math.floor(n), 1, 300)
    speedBox.Text = tostring(speed)
    setStatus("Flight speed set to " .. speed)
end)

speedBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then setSpeedButton:Activate() end
end)

local function holdVertical(b, amount)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            verticalInput = amount
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if verticalInput == amount then verticalInput = 0 end
        end
    end)
end
holdVertical(upButton, 1)
holdVertical(downButton, -1)
levelButton.Activated:Connect(function() verticalInput = 0 end)

-- TP MANAGER TAB
local tpPage = makePage("TP")
label(tpPage, "LOCATION DETAILS")
local nameBox = box(tpPage, "Location name")
local priorityBox = box(tpPage, "Priority (1-9999)")
local keyBox = box(tpPage, "Key: A-Z, F1-F12, [ or ]")
local savePointButton = button(tpPage, "SAVE CURRENT LOCATION")
local updatePointButton = button(tpPage, "UPDATE SELECTED POSITION")
local applyPointButton = button(tpPage, "APPLY NAME / PRIORITY / KEY")
local teleportButton = button(tpPage, "TELEPORT TO SELECTED")
local deletePointButton = button(tpPage, "DELETE SELECTED", Color3.fromRGB(120, 40, 50))
label(tpPage, "SAVED LOCATIONS")
local listScroll = create("ScrollingFrame", {
    Size = UDim2.new(1, -8, 0, 210),
    BackgroundColor3 = Color3.fromRGB(20, 28, 43),
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new()
}, tpPage)
corner(listScroll, 7)
create("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder
}, listScroll)

local function refreshList()
    for _, child in ipairs(listScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for order, p in ipairs(sortedPoints()) do
        local point = p
        local b = create("TextButton", {
            Size = UDim2.new(1, -8, 0, 36),
            BackgroundColor3 = selectedId == p.id and Color3.fromRGB(0, 110, 155)
                or Color3.fromRGB(32, 45, 64),
            TextColor3 = Color3.new(1, 1, 1),
            Text = string.format("%d. %s | %s", p.priority, p.name,
                p.keyText == "" and "No key" or p.keyText),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            LayoutOrder = order
        }, listScroll)
        corner(b, 5)
        b.Activated:Connect(function()
            selectedId = point.id
            nameBox.Text = point.name
            priorityBox.Text = tostring(point.priority)
            keyBox.Text = point.keyText
            refreshList()
            setStatus("Selected: " .. point.name)
        end)
    end
end

local function readPointConfig()
    local name = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    local priority = tonumber(priorityBox.Text)
    local keyText = keyBox.Text:gsub("%s+", "")
    if name == "" then setStatus("Enter a location name."); return nil end
    if not priority or priority % 1 ~= 0 or priority < 1 or priority > 9999 then
        setStatus("Priority must be 1-9999."); return nil
    end
    if keyText ~= "" and not getKey(keyText) then
        setStatus("Invalid key. Use A-Z, F1-F12, [ or ]."); return nil
    end
    local newKey = keyText ~= "" and getKey(keyText)
    for _, p in pairs(savedPoints) do
        if p.id ~= selectedId and newKey and p.keyText ~= ""
            and getKey(p.keyText) == newKey then
            setStatus("That key is already used."); return nil
        end
    end
    return name, priority, keyText
end

savePointButton.Activated:Connect(function()
    local name, priority, keyText = readPointConfig()
    if not name then return end
    local _, r = getCharacter()
    if not r then setStatus("Character is not ready."); return end
    local id = nextId
    nextId += 1
    savedPoints[id] = {id = id, name = name, priority = priority,
        keyText = keyText, cframe = r.CFrame}
    selectedId = id
    refreshList()
    setStatus("Saved: " .. name)
end)

local function updateSelected(updatePosition)
    local p = selectedId and savedPoints[selectedId]
    if not p then setStatus("Select a point first."); return end
    local name, priority, keyText = readPointConfig()
    if not name then return end
    local cf = p.cframe
    if updatePosition then
        local _, r = getCharacter()
        if not r then setStatus("Character is not ready."); return end
        cf = r.CFrame
    end
    p.name, p.priority, p.keyText, p.cframe = name, priority, keyText, cf
    refreshList()
    setStatus("Updated: " .. name)
end

updatePointButton.Activated:Connect(function() updateSelected(true) end)
applyPointButton.Activated:Connect(function() updateSelected(false) end)
teleportButton.Activated:Connect(function()
    local p = selectedId and savedPoints[selectedId]
    if not p then setStatus("Select a point first."); return end
    if teleportTo(p.cframe) then setStatus("Teleported to " .. p.name) end
end)
deletePointButton.Activated:Connect(function()
    local p = selectedId and savedPoints[selectedId]
    if not p then setStatus("Select a point first."); return end
    savedPoints[selectedId] = nil
    selectedId = nil
    nameBox.Text, priorityBox.Text, keyBox.Text = "", "", ""
    refreshList()
    setStatus("Deleted: " .. p.name)
end)

-- TOUR TAB
local tourPage = makePage("TOUR")
label(tourPage, "TOUR CONTROL")
local tourStartButton = button(tourPage, "START TOUR")
local tourModeButton = button(tourPage, "MODE: ONCE")
local eEnableButton = button(tourPage, "E KEY: ENABLED")
local eModeButton = button(tourPage, "E MODE: TOGGLE")
local tourInfo = label(tourPage, "ONCE visits each point once. LOOP repeats until stopped.\nE Toggle: press to start/stop. E Hold: tour runs only while E is held.", 54)
tourInfo.TextColor3 = Color3.fromRGB(190, 210, 225)
tourInfo.Font = Enum.Font.Gotham

local function stopTour(message)
    tourRunning = false
    if tourStartButton and tourStartButton.Parent then
        tourStartButton.Text = "START TOUR"
    end
    if message then setStatus(message) end
end

local function startTour()
    if tourRunning then return end
    local points = sortedPoints()
    if #points == 0 then setStatus("Save at least one location first."); return end
    tourRunning = true
    tourStartButton.Text = "STOP TOUR"
    task.spawn(function()
        repeat
            local tourPoints = sortedPoints()
            for _, p in ipairs(tourPoints) do
                if not tourRunning then break end
                if eMode == "HOLD" and eEnabled and not eHeld then
                    tourRunning = false
                    break
                end
                setStatus("Tour: " .. p.name)
                if not teleportTo(p.cframe) then
                    tourRunning = false
                    break
                end
                task.wait(0.15)
            end
            if tourMode == "ONCE" then break end
            if tourRunning then task.wait(0.2) end
        until not tourRunning
        tourRunning = false
        tourStartButton.Text = "START TOUR"
        if not shuttingDown then setStatus("Tour finished/stopped.") end
    end)
end

tourStartButton.Activated:Connect(function()
    if tourRunning then stopTour("Tour stopped.") else startTour() end
end)
tourModeButton.Activated:Connect(function()
    tourMode = tourMode == "ONCE" and "LOOP" or "ONCE"
    tourModeButton.Text = "MODE: " .. tourMode
    setStatus("Tour mode: " .. tourMode)
end)
eEnableButton.Activated:Connect(function()
    eEnabled = not eEnabled
    eEnableButton.Text = eEnabled and "E KEY: ENABLED" or "E KEY: DISABLED"
    if not eEnabled and eMode == "HOLD" then eHeld = false; stopTour("E key disabled.") end
end)
eModeButton.Activated:Connect(function()
    eMode = eMode == "TOGGLE" and "HOLD" or "TOGGLE"
    eHeld = false
    eModeButton.Text = "E MODE: " .. eMode
    setStatus("E mode: " .. eMode)
end)

-- CONFIG TAB
local configPage = makePage("CONFIG")
label(configPage, "EXPORT / IMPORT")
local exportButton = button(configPage, "EXPORT CONFIG TO JSON")
local importBox = box(configPage, "Paste JSON here, or export appears here", "", 90)
importBox.MultiLine = true
importBox.TextXAlignment = Enum.TextXAlignment.Left
importBox.TextYAlignment = Enum.TextYAlignment.Top
local copyHintButton = button(configPage, "FOCUS EXPORT TEXT TO COPY")
local importButton = button(configPage, "IMPORT JSON CONFIG")
label(configPage, "UI SIZE")
local smallerButton = button(configPage, "MAKE UI SMALLER")
local biggerButton = button(configPage, "MAKE UI BIGGER")
local resetSizeButton = button(configPage, "RESET UI SIZE")
local shutdownButton = button(configPage, "SHUT DOWN | REMOVE MENU", Color3.fromRGB(130, 35, 48))

local function exportConfig()
    local data = {version = 1, speed = speed, tourMode = tourMode,
        eEnabled = eEnabled, eMode = eMode, points = {}}
    for _, p in ipairs(sortedPoints()) do
        table.insert(data.points, {
            id = p.id, name = p.name, priority = p.priority,
            keyText = p.keyText, cframe = {p.cframe:GetComponents()}
        })
    end
    local ok, result = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then setStatus("Export failed: " .. tostring(result)); return end
    importBox.Text = result
    setStatus("JSON ready. Focus the box, then copy its text.")
end
exportButton.Activated:Connect(exportConfig)
copyHintButton.Activated:Connect(function()
    importBox:CaptureFocus()
    importBox.CursorPosition = #importBox.Text + 1
    setStatus("Select/copy the JSON text manually (Ctrl+A, Ctrl+C).")
end)

importButton.Activated:Connect(function()
    local ok, data = pcall(function() return HttpService:JSONDecode(importBox.Text) end)
    if not ok or type(data) ~= "table" or type(data.points) ~= "table" then
        setStatus("Invalid JSON config."); return
    end
    local newPoints, usedKeys, highestId = {}, {}, 0
    for _, p in ipairs(data.points) do
        if type(p) ~= "table" or type(p.name) ~= "string" or p.name == ""
            or type(p.priority) ~= "number" or p.priority % 1 ~= 0
            or p.priority < 1 or p.priority > 9999
            or type(p.keyText) ~= "string" or type(p.cframe) ~= "table"
            or #p.cframe ~= 12 then
            setStatus("Invalid point data in JSON."); return
        end
        local components = {}
        for i = 1, 12 do
            local n = p.cframe[i]
            if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
                setStatus("Invalid position data."); return
            end
            components[i] = n
        end
        local key = p.keyText ~= "" and getKey(p.keyText)
        if p.keyText ~= "" and not key then setStatus("Invalid imported key."); return end
        if key and usedKeys[key] then setStatus("Duplicate key in imported config."); return end
        if key then usedKeys[key] = true end
        local id = p.id
        if type(id) ~= "number" or id % 1 ~= 0 or id < 1 then id = highestId + 1 end
        if newPoints[id] then setStatus("Duplicate point ID in config."); return end
        highestId = math.max(highestId, id)
        newPoints[id] = {id = id, name = p.name, priority = p.priority,
            keyText = p.keyText, cframe = CFrame.new(table.unpack(components))}
    end

    savedPoints, nextId, selectedId = newPoints, highestId + 1, nil
    if type(data.speed) == "number" and data.speed == data.speed then
        speed = math.clamp(math.floor(data.speed), 1, 300)
        speedBox.Text = tostring(speed)
    end
    if data.tourMode == "ONCE" or data.tourMode == "LOOP" then
        tourMode = data.tourMode
        tourModeButton.Text = "MODE: " .. tourMode
    end
    if type(data.eEnabled) == "boolean" then
        eEnabled = data.eEnabled
        eEnableButton.Text = eEnabled and "E KEY: ENABLED" or "E KEY: DISABLED"
    end
    if data.eMode == "TOGGLE" or data.eMode == "HOLD" then
        eMode = data.eMode
        eModeButton.Text = "E MODE: " .. eMode
    end
    refreshList()
    setStatus("Imported " .. tostring(#data.points) .. " locations.")
end)

local function changeScale(delta)
    uiScale.Scale = math.clamp(uiScale.Scale + delta, 0.6, 1.25)
    setStatus("UI size: " .. math.floor(uiScale.Scale * 100) .. "%")
end
smallerButton.Activated:Connect(function() changeScale(-0.1) end)
biggerButton.Activated:Connect(function() changeScale(0.1) end)
resetSizeButton.Activated:Connect(function()
    uiScale.Scale = 1
    setStatus("UI size reset.")
end)

-- Draggable floating icon. Only one Activated connection is used to avoid double-toggle.
icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        iconDragging = true
        iconMoved = false
        iconDragStart = input.Position
        iconStartPosition = icon.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not iconDragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - iconDragStart
    if delta.Magnitude > 8 then iconMoved = true end
    if iconMoved then
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize
        local x = iconStartPosition.X.Offset + delta.X
        local y = iconStartPosition.Y.Offset + delta.Y
        if viewport then
            x = math.clamp(x, 0, math.max(0, viewport.X - icon.AbsoluteSize.X))
            y = math.clamp(y, 0, math.max(0, viewport.Y - icon.AbsoluteSize.Y))
        end
        icon.Position = UDim2.fromOffset(x, y)
    end
end)

UIS.InputEnded:Connect(function(input)
    if iconDragging and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
        iconDragging = false
        if iconMoved then
            suppressIconClick = true
            task.delay(0.2, function() suppressIconClick = false end)
        end
    end
end)

icon.Activated:Connect(function()
    if suppressIconClick then return end
    frame.Visible = not frame.Visible
end)
closeButton.Activated:Connect(function() frame.Visible = false end)

-- Keyboard shortcuts: F toggles menu; E controls tour; point keys teleport.
UIS.InputBegan:Connect(function(input, processed)
    if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F then
        frame.Visible = not frame.Visible
        return
    end
    if input.KeyCode == Enum.KeyCode.E and eEnabled then
        eHeld = true
        if eMode == "TOGGLE" then
            if tourRunning then stopTour("Tour stopped by E.")
            else startTour() end
        elseif eMode == "HOLD" then
            if not tourRunning then startTour() end
        end
        return
    end
    for _, p in pairs(savedPoints) do
        local key = p.keyText ~= "" and getKey(p.keyText)
        if key and input.KeyCode == key then
            if teleportTo(p.cframe) then setStatus("Teleported to " .. p.name) end
            return
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        eHeld = false
        if eEnabled and eMode == "HOLD" and tourRunning then
            stopTour("Tour stopped: E released.")
        end
    end
end)

-- Shutdown and respawn cleanup
shutdownButton.Activated:Connect(function()
    if shuttingDown then return end
    shuttingDown = true
    stopTour()
    stopFly()
    if gui then gui:Destroy() end
end)

player.CharacterAdded:Connect(function()
    stopFly()
end)

-- Responsive scale: preserve user's chosen scale while fitting small screens.
local function updateResponsiveScale()
    local camera = workspace.CurrentCamera
    if not camera or not uiScale or not uiScale.Parent then return end
    local viewport = camera.ViewportSize
    local fit = math.min(1, (viewport.X - 16) / 370, (viewport.Y - 24) / 480)
    fit = math.clamp(fit, 0.6, 1)
    uiScale.Scale = math.min(userScale or 1, fit)
end

-- Keep manual scale separate from responsive fit.
userScale = 1
local function setUserScale(value)
    userScale = math.clamp(value, 0.6, 1.25)
    updateResponsiveScale()
    setStatus("UI size: " .. math.floor(userScale * 100) .. "%")
end
smallerButton.Activated:Connect(function() setUserScale(userScale - 0.1) end)
biggerButton.Activated:Connect(function() setUserScale(userScale + 0.1) end)
resetSizeButton.Activated:Connect(function() setUserScale(1) end)

local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
    end
    updateResponsiveScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

showTab("FLY")
refreshList()
print("[NECRO FLY PRO] Loaded successfully")