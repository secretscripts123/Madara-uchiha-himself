

--// AC-Bypass

local deleted = setmetatable({}, {__mode = "k"})
local keywords = {"Banned", "Walkspeed","Ban"}

local function containsKeyword(str)
    for _, word in ipairs(keywords) do
        if str:find(word, 1, true) then
            return true
        end
    end
    return false
end

local function scanAndDestroy(parent)
    for _, obj in ipairs(parent:GetDescendants()) do
        if (obj:IsA("LocalScript") or obj:IsA("ModuleScript") or 
           (obj:IsA("Script") and obj.RunContext == Enum.RunContext.Client)) and not deleted[obj] then

            local ok, source = pcall(function() return obj.Source end)
            if ok and type(source) == "string" and containsKeyword(source) then
                pcall(function() obj:Destroy() end)
                deleted[obj] = true
            end
        end
    end
end

for _, func in ipairs(getgc(true)) do
    if type(func) == "function" and (islclosure(func) or (isluaclosure and isluaclosure(func))) then
        local success, consts = pcall(getconstants, func)
        if success and type(consts) == "table" then
            for _, const in ipairs(consts) do
                if type(const) == "string" and containsKeyword(const) then
                    local ok, env = pcall(getfenv, func)
                    if ok and type(env) == "table" then
                        local scriptRef = rawget(env, "script")
                        if typeof(scriptRef) == "Instance" and not deleted[scriptRef] then
                            if scriptRef:IsA("LocalScript") or scriptRef:IsA("ModuleScript") or 
                               (scriptRef:IsA("Script") and scriptRef.RunContext == Enum.RunContext.Client) then

                                pcall(function() scriptRef:Destroy() end)
                                deleted[scriptRef] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

spawn(function()
    for _, v in ipairs(game:GetDescendants()) do
        scanAndDestroy(v)
    end
    scanAndDestroy(game)
end)

game.DescendantAdded:Connect(function(obj)
    scanAndDestroy(obj)
end)

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "Kick" and self == game.Players.LocalPlayer then
        return
    end
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

--//






local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Helper function to get character
local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

-- Simple safeFind helper
local function safeFind(parent, child)
    return parent and parent:FindFirstChild(child)
end

-------------------------------------------------
-- (OPTIONAL) sourceHasKeyword FUNCTION FOR ANTICHEAT
-------------------------------------------------
local function sourceHasKeyword(scriptRef)
    if typeof(scriptRef) ~= "Instance" or not scriptRef:IsA("LuaSourceContainer") then
        return false
    end
    local ok, source = pcall(function() return scriptRef.Source end)
    if not ok or typeof(source) ~= "string" then
        return false
    end
    return source:find("Banned") or source:find("Walkspeed")
end

-------------------------------------------------
-- ANTICHEAT/BASIC PATCH
-------------------------------------------------
for _, obj in pairs(game:GetDescendants()) do
    if obj.Name == "Banned" then
        obj:Destroy()
    end
end
game.DescendantAdded:Connect(function(obj)
    if obj.Name == "Banned" then
        obj:Destroy()
    end
end)

local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldindex = mt.__index
mt.__index = newcclosure(function(self, b)
    if b == "WalkSpeed" then return 22 end
    return oldindex(self, b)
end)
setreadonly(mt, true)

-------------------------------------------------
-- CHARACTER & LIMB FUNCTIONS
-------------------------------------------------
local function duplicateLimbs(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local function createClone(part)
            local newPart = part:Clone()
            newPart.CanCollide = false
            newPart.Anchored = false
            newPart.Massless = true
            newPart.Parent = character
            return newPart
        end
        local limbs = {"Left Leg", "Right Leg", "Left Arm", "Right Arm"}
        for _, limbName in ipairs(limbs) do
            local limb = character:FindFirstChild(limbName)
            if limb then
                limb.Size = Vector3.new(1, 2, 1)
                local clone = createClone(limb)
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = limb
                weld.Part1 = clone
                weld.Parent = limb
            end
        end
    end
end
duplicateLimbs(getCharacter())

local function deleteUnwantedLocalScripts(character)
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("LocalScript") and not (obj.Name == "AirS" or obj.Name == "Animate" or obj.Name == "StaminaClient") then
            pcall(function() obj:Destroy() end)
        end
    end
end
deleteUnwantedLocalScripts(getCharacter())
player.CharacterAdded:Connect(function(char)
    deleteUnwantedLocalScripts(char)
end)

local function makeLimbsMassless(character)
    local names = {"Left Leg", "Right Leg", "Left Arm", "Right Arm", "Head", "Torso", "UpperTorso", "LowerTorso"}
    for _, name in ipairs(names) do
        local part = character:FindFirstChild(name)
        if part then
            pcall(function()
                part.Massless = true
                part.CanCollide = false
            end)
        end
    end
end
makeLimbsMassless(getCharacter())
player.CharacterAdded:Connect(function(char)
    makeLimbsMassless(char)
end)

-------------------------------------------------
-- GLOBAL VARIABLES – For UI Modifications
-------------------------------------------------
-- Leg Resizers
local legResizerXZ = 1      -- Horizontal (X,Z) scaling
local legResizerXYZ = 1     -- Uniform scaling of legs
-- Leg Offsets (one offset applied relative to HumanoidRootPart)
local offsetData = {X = 0, Y = 0, Z = 0}
local legOffsetsEnabled = false
-- Tools Reach (for Main tab; not used in FireTouch)
local toolReach = {X = 2, Y = 2, Z = 2}
local toolReachUniform = 2
-- Head and Arm Resizers
local headSize = 1
local armSize = 1
-- Level spoof variables
local levelSpoofEnabled = false
local currentSpoofLevel = 586
-- Fire Touch Reach – used in Fire Touch tab for detection box size.
local fireTouchReach = 5

-------------------------------------------------
-- UTILITY FUNCTIONS FOR UPDATES
-------------------------------------------------
local function updateLegResizer()
    local char = getCharacter()
    local leftLeg = char:FindFirstChild("Left Leg")
    local rightLeg = char:FindFirstChild("Right Leg")
    if leftLeg then
        leftLeg.Size = Vector3.new(legResizerXZ, leftLeg.Size.Y, legResizerXZ)
    end
    if rightLeg then
        rightLeg.Size = Vector3.new(legResizerXZ, rightLeg.Size.Y, legResizerXZ)
    end
end

local function updateLegUniform()
    local char = getCharacter()
    local leftLeg = char:FindFirstChild("Left Leg")
    local rightLeg = char:FindFirstChild("Right Leg")
    if leftLeg then
        leftLeg.Size = Vector3.new(legResizerXYZ, legResizerXYZ, legResizerXYZ)
    end
    if rightLeg then
        rightLeg.Size = Vector3.new(legResizerXYZ, legResizerXYZ, legResizerXYZ)
    end
end

local function updateLegPositions()
    local char = getCharacter()
    local root = char:FindFirstChild("HumanoidRootPart")
    local leftLeg = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftLowerLeg")
    local rightLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightLowerLeg")
    if legOffsetsEnabled and root and leftLeg and rightLeg then
        local basePos = root.Position
        local offsetVector = Vector3.new(offsetData.X, offsetData.Y, offsetData.Z)
        leftLeg.Position = basePos + offsetVector
        rightLeg.Position = basePos + offsetVector
    end
end

local function updateHeadSize()
    local char = getCharacter()
    local head = char:FindFirstChild("Head")
    if head then
        head.Size = Vector3.new(headSize, headSize, headSize)
    end
end

local function updateArmSize()
    local char = getCharacter()
    local leftArm = char:FindFirstChild("Left Arm")
    local rightArm = char:FindFirstChild("Right Arm")
    if leftArm then
        leftArm.Size = Vector3.new(armSize, armSize, armSize)
    end
    if rightArm then
        rightArm.Size = Vector3.new(armSize, armSize, armSize)
    end
end

-------------------------------------------------
-- UPDATED FIRE TOUCH FUNCTION
-------------------------------------------------
local function fireTouch(limbs)
    local char = getCharacter()
    -- Multiply fireTouchReach by 2 so the detection box is larger.
    local boxSize = Vector3.new(fireTouchReach * 2, fireTouchReach * 2, fireTouchReach * 2)
    for _, limbName in ipairs(limbs) do
        local part = char:FindFirstChild(limbName)
        if part then
            local partsInBox = workspace:GetPartBoundsInBox(part.CFrame, boxSize)
            -- Debug: you could add print("Found",#partsInBox,"parts near", limbName)
            for _, p in ipairs(partsInBox) do
                if p.Name == "PSoccerBall" or p.Name == "TPS" then
                    firetouchinterest(part, p, 0)
                    firetouchinterest(p, part, 0)
                    task.wait(0.01)
                    firetouchinterest(part, p, 1)
                    firetouchinterest(p, part, 1)
                end
            end
        end
    end
end



local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()
 
local Window = Library:CreateWindow{
    Title = `Twistzz Hub [TPS Ultimate Soccer]`,
    SubTitle = "By Twistzz",
    TabWidth = 160,
    Size = UDim2.fromOffset(570, 450),
    Resize = true, -- Resize this ^ Size according to a 1920x1080 screen, good for mobile users but may look weird on some devices
    MinSize = Vector2.new(470, 380),
    Acrylic = true, -- The blur may be detectable, setting this to false disables blur entirely
    Theme = "VS Dark",
    MinimizeKey = Enum.KeyCode.End -- Used when theres no MinimizeKeybind
}

Library:SetTheme("VS Dark")

local Tabs = {
    Tab1 = Window:CreateTab{
        Title = "Reach",
        Icon = "user"
    },
        Tab2 = Window:CreateTab{
        Title = "React",
        Icon = "drill"
    },
      Tab3 = Window:CreateTab{
        Title = "Miscellaneous",
        Icon = "warehouse"
    },
          Tab4 = Window:CreateTab{
        Title = "Physics",
        Icon = "atom"
    },
        Settings = Window:CreateTab{
        Title = "Settings",
        Icon = "settings"
    }

}



local InterfaceSection = Tabs.Tab1:Section("______________________________________________________________________________________")



local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Legs Size Changer [X-Z]",
    Description = "",
    Default = 1,
    Min = 1,
    Max = 100,
    Rounding = 1,
    Callback = function(Value)
        legResizerXZ = Value
        updateLegResizer()
    end
})


local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Legs Size Changer [X-Y-Z]",
    Description = "",
    Default = 1,
    Min = 1,
    Max = 100,
    Rounding = 1,
    Callback = function(Value)
        legResizerXYZ = Value
        updateLegUniform()
    end
})

local Input = Tabs.Tab1:CreateInput("Input", {
    Title = "Sync Reach",
    Default = "",
    Placeholder = "Size",
    Numeric = true, -- Only allows numbers
    Finished = true, -- Only calls callback when you press enter
    Callback = function(Value)
         legResizerXYZ = Value
        updateLegUniform()
    end
})

local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Legs Transperency [X-Y-Z]",
    Description = "",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 1,
    Callback = function(val)
        local part = safeFind(getCharacter(), "Right Leg")
        if part then pcall(function() part.Transparency = val end) end

                local part = safeFind(getCharacter(), "Left Leg")
        if part then pcall(function() part.Transparency = val end) end
    end
})

local Toggle = Tabs.Tab1:CreateToggle("MyToggle", {Title = "Enable / Disable Box Offsets", Default = false })

Toggle:OnChanged(function(val)
        legOffsetsEnabled = val
        updateLegPositions()
end)

local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Legs Offset X",
    Description = "",
    Default = 0,
    Min = -5,
    Max = 5,
    Rounding = 1,
    Callback = function(val)
        offsetData.X = val
        updateLegPositions()
    end
})

local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Legs Offset Y",
    Description = "",
    Default = 0,
    Min = -5,
    Max = 5,
    Rounding = 1,
    Callback = function(val)
        offsetData.Y = val
        updateLegPositions()
    end
})

local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Legs Offset Z",
    Description = "",
    Default = 0,
    Min = -5,
    Max = 5,
    Rounding = 1,
    Callback = function(val)
        offsetData.Z = val
        updateLegPositions()
    end
})

local InterfaceSection = Tabs.Tab1:Section("______________________________________________________________________________________")

local Input = Tabs.Tab1:CreateInput("Input", {
    Title = "Arms Size Changer[GK] [X-Y-Z]",
    Default = "",
    Placeholder = "Size",
    Numeric = true, -- Only allows numbers
    Finished = true, -- Only calls callback when you press enter
    Callback = function(Value)
        armSize = Value
        updateArmSize()
    end
})



local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Arm Transperency [X-Y-Z]",
    Description = "",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 1,
    Callback = function(val)
        local part = safeFind(getCharacter(), "Right Arm")
        if part then pcall(function() part.Transparency = val end) end

                local part = safeFind(getCharacter(), "Left Arm")
        if part then pcall(function() part.Transparency = val end) end
    end
})


local InterfaceSection = Tabs.Tab1:Section("______________________________________________________________________________________")

local Input = Tabs.Tab1:CreateInput("Input", {
    Title = "Head Size Changer [X-Y-Z]",
    Default = "",
    Placeholder = "Size",
    Numeric = true, -- Only allows numbers
    Finished = true, -- Only calls callback when you press enter
    Callback = function(Value)
        headSize = val
        updateHeadSize()
    end
})

local Slider = Tabs.Tab1:CreateSlider("Slider", {
    Title = "Head Transperency [X-Y-Z]",
    Description = "",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 1,
    Callback = function(val)
        local part = safeFind(getCharacter(), "Head")
        if part then pcall(function() part.Transparency = val end) end
    end
})

local InterfaceSection = Tabs.Tab2:Section("______________________________________________________________________________________")

Tabs.Tab2:CreateButton{ 
    Title = "Twistzz React Killer",
    Description = "Overloads server with goalkeeper-related events",
    Callback = function()
        local mt = getrawmetatable(game)
        local oldNC = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local args = {...}
            if not checkcaller() and getnamecallmethod() == "FireServer" and self == workspace.FE.Scorer.RemoteEvent then
                for i = 1, 10 do
                    if workspace:FindFirstChild("FE") then
                        local fe = workspace.FE
                        if fe:FindFirstChild("Keep") and fe.Keep:FindFirstChild("GK") then
                            pcall(function() fe.Keep.GK:FireServer(unpack(args)) end)
                        end
                        if fe:FindFirstChild("GK") then
                            if fe.GK:FindFirstChild("BGKSaves") then pcall(function() fe.GK.BGKSaves:FireServer(unpack(args)) end) end
                            if fe.GK:FindFirstChild("BGKP") then pcall(function() fe.GK.BGKP:FireServer(unpack(args)) end) end
                            if fe.GK:FindFirstChild("GGKP") then pcall(function() fe.GK.GGKP:FireServer(unpack(args)) end) end
                        end
                    end
                end
                return
            end
            return oldNC(self, unpack(args))
        end)
        setreadonly(mt, true)
    end
}
Tabs.Tab2:CreateButton{ 
    Title = "Better React",
    Description = "Improves reaction by firing extra server events",
    Callback = function()
        local mt = getrawmetatable(game)
        local oldNC = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local args = {...}
            if not checkcaller() and getnamecallmethod() == "FireServer" and self == workspace.FE.Scorer.RemoteEvent then
                pcall(function()
                    workspace.FE.Scorer.RemoteEvent1:FireServer(unpack(args))
                    workspace.FE.Scorer.RemoteEvent2:FireServer(unpack(args))
                end)
                return
            end
            return oldNC(self, unpack(args))
        end)
        setreadonly(mt, true)
    end
}

Tabs.Tab2:CreateButton{ 
    Title = "Better Hit Registration",
    Description = "Attempts to improve hit registration by firing extra times",
    Callback = function()
        local mt = getrawmetatable(game)
        local oldNC = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local args = {...}
            if not checkcaller() and getnamecallmethod() == "FireServer" and self == workspace.FE.Scorer.RemoteEvent then
                for i = 1, 3 do
                    pcall(function()
                        workspace.FE.Scorer.RemoteEvent1:FireServer(unpack(args))
                        workspace.FE.Scorer.RemoteEvent:FireServer(unpack(args))
                    end)
                end
                return
            end
            return oldNC(self, unpack(args))
        end)
        setreadonly(mt, true)
    end
}



Tabs.Tab2:CreateButton{ 
    Title = "Alz React",
    Description = "Applies velocity to TPS and Practice balls",
    Callback = function()
        pcall(function()
            local tpsPart = workspace.TPSSystem and workspace.TPSSystem:FindFirstChild("TPS")
            if tpsPart then
                tpsPart.Velocity = Vector3.new(100, 100, 100)
            end
        end)

        pcall(function()
            for _, ball in pairs(workspace.Practice:GetChildren()) do
                if ball.Name == "PSoccerBall" and ball:IsA("BasePart") then
                    if ball and ball.Parent then
                        ball.Velocity = Vector3.new(100, 100, 100)
                    end
                end
            end
        end)
    end
}

Tabs.Tab2:CreateButton{ 
    Title = "Boost React Detection (Match Ball)",
    Description = "Fires touch interests on TPS part to boost detection",
    Callback = function()
        local tpsPart = workspace.TPSSystem and workspace.TPSSystem:FindFirstChild("TPS")

        if not tpsPart then
            notify("TPS Part not found!")
            return
        end

        for _, child in pairs(tpsPart:GetChildren()) do
            if child:IsA("TouchInterest") then
                local hrp = getCharacter().HumanoidRootPart
                if hrp then
                    FireTouchInterest(hrp, child.Part0 or child.Part1, Enum.TouchState.Begin)
                    FireTouchInterest(hrp, child.Part0 or child.Part1, Enum.TouchState.End)
                end
            end
        end
    end
}

Tabs.Tab2:CreateButton{ 
    Title = ".Touched Event React (Match Ball)",
    Description = "Spams .Touched events on ball and TPS for more reactions",
    Callback = function()
        local soccerBall = workspace.Practice and workspace.Practice:FindFirstChild("PSoccerBall")
        local tpsPart = workspace.TPSSystem and workspace.TPSSystem:FindFirstChild("TPS")
        local radius = 5
        local spamCount = 15

        if not soccerBall and not tpsPart then
            notify("No target parts found!")
            return
        end

        RunService.Heartbeat:Connect(function()
            local character = getCharacter()
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local function spamTouch(part)
                if not part or (hrp.Position - part.Position).Magnitude > radius then return end

                for _, touching in pairs(part:GetTouchingParts()) do
                    if touching.Parent == character then
                        for _ = 1, spamCount do
                            ReplicateSignal(part, "Touched", touching)
                        end
                    end
                end
            end

            if soccerBall then
                spamTouch(soccerBall)
            end

            if tpsPart then
                spamTouch(tpsPart)
            end
        end)
    end
}

Tabs.Tab2:CreateButton{ 
    Title = "Remove Ball Delay",
    Description = "Destroys APGBDelay objects from TPS part to remove delays",
    Callback = function()
        local function safeExecute(func)
            local success, err = pcall(func)
            if not success then
                -- silently ignore errors
            end
        end

        safeExecute(function()
            local tpsPart = workspace.TPSSystem and workspace.TPSSystem:FindFirstChild("TPS")
            if tpsPart then
                for _, item in pairs(tpsPart:GetChildren()) do
                    if item.Name == "APGBDelay" then
                        item:Destroy()
                    end
                end
            end
        end)
    end
}



local InterfaceSection = Tabs.Tab1:Section("______________________________________________________________________________________")



local Toggle = Tabs.Tab3:CreateToggle("MyToggle", {Title = "Infinite Stamina", Default = false })



Toggle:OnChanged(function(Value)
        -- Hook FireServer to modify Sprint event
        local oldFireServer
        oldFireServer = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if method == "FireServer" and tostring(self) == "Sprint" then
                args[1] = "Ended"
                return oldFireServer(self, unpack(args))
            end
            return oldFireServer(self, ...)
        end)

        -- Set initial WalkSpeed
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 22

        -- Mouse key bindings
        local player = game.Players.LocalPlayer
        local mouse = player:GetMouse()

        mouse.KeyDown:Connect(function(activate)
            activate = activate:lower()
            if activate == "r" then
                game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end)

        mouse.Button1Down:Connect(function()
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 22
        end)
end)


local InterfaceSection = Tabs.Tab3:Section("______________________________________________________________________________________")


local Slider = Tabs.Tab3:CreateSlider("Slider", {
    Title = "Walkspeed Changer",
    Description = "",
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 1,
    Callback = function(val)
        local char = getCharacter()
        if char and safeFind(char, "Humanoid") then
            pcall(function() char.Humanoid.WalkSpeed = val end)
        end
    end
})

local InterfaceSection = Tabs.Tab3:Section("______________________________________________________________________________________")

local Toggle = Tabs.Tab3:CreateToggle("MyToggle", {Title = "Enable / Disable Level Spoofer", Default = false })

Toggle:OnChanged(function(state)
        levelSpoofEnabled = state
        if levelSpoofEnabled then
            local originalFireServer
            originalFireServer = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if levelSpoofEnabled and method == "FireServer" and tostring(self) == "Level" then
                    return originalFireServer(self, currentSpoofLevel)
                end
                return originalFireServer(self, ...)
            end)
        end
end)




local Slider = Tabs.Tab3:CreateSlider("Slider", {
    Title = "F.E Level Spoofer",
    Description = "This is a slider",
    Default = 100,
    Min = 1,
    Max = 1000,
    Rounding = 1,
    Callback = function(val)
        currentSpoofLevel = val
    end
})

local InterfaceSection = Tabs.Tab3:Section("______________________________________________________________________________________")

Tabs.Tab3:CreateButton{
    Title = "Anti Offside",
    Description = "",
    Callback = function()
        local function safeExecute(func)
            local success, _ = pcall(func)
        end

        safeExecute(function()
            local tpsPart = workspace:FindFirstChild("TPSSystem") and workspace.TPSSystem:FindFirstChild("TPS")
            if tpsPart then
                for _, name in ipairs({ "Offside", "Offside Check" }) do
                    local obj = tpsPart:FindFirstChild(name)
                    if obj then
                        obj:Destroy()
                    end
                end
            end
        end)

    end
}


local InterfaceSection = Tabs.Tab3:Section("______________________________________________________________________________________")

local Toggle = Tabs.Tab3:CreateToggle("MyToggle", {Title = "Auto Catch [GK]", Default = false })

Toggle:OnChanged(function(Val)
    if Val then
        local KeepRemotes = {
            Throw = workspace.FE and workspace.FE.Keep and workspace.FE.Keep:FindFirstChild("Throw"),
            KeepD = workspace.FE and workspace.FE.Keep and workspace.FE.Keep:FindFirstChild("KeepD"),
            KeepP = workspace.FE and workspace.FE.Keep and workspace.FE.Keep:FindFirstChild("KeepP")
        }
        local function fireKeepEvents()
            if KeepRemotes.Throw then KeepRemotes.Throw:FireServer() end
            if KeepRemotes.KeepD then KeepRemotes.KeepD:FireServer() end
            local char = getCharacter()
            local rightArm = char and char:FindFirstChild("Right Arm")
            if rightArm and KeepRemotes.KeepP then
                pcall(function() KeepRemotes.KeepP:FireServer(rightArm) end)
            end
        end
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
                fireKeepEvents()
            end
        end)
    end
end)

local InterfaceSection = Tabs.Tab3:Section("______________________________________________________________________________________")

Tabs.Tab3:CreateButton{
    Title = "Instant Stamina Adder",
    Description = "",
    Callback = function()
        local args = {1540385087, "SkillA", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}
local InterfaceSection = Tabs.Tab3:Section("______________________________________________________________________________________")


local Toggle = Tabs.Tab3:CreateToggle("MyToggle", {Title = "Anti VoteKick ", Default = false })

Toggle:OnChanged(function(Val)
    if Val then
        -- First, delete any object named "RemoteEventVKick"
        for _, obj in ipairs(game:GetDescendants()) do
            if obj.Name == "RemoteEventVKick" then
                pcall(function() obj:Destroy() end)
            end
        end
        -- Then run the bypass anticheat code:
        local deleted = {}
        local found = false

        for _, func in ipairs(getgc(true)) do
            if typeof(func) == "function" and (islclosure(func) or (isluaclosure and isluaclosure(func))) then
                local success, consts = pcall(getconstants, func)
                if success and typeof(consts) == "table" then
                    for _, const in ipairs(consts) do
                        if typeof(const) == "string" and (const:find("Banned") or const:find("Walkspeed")) then
                            local ok, env = pcall(getfenv, func)
                            if ok and typeof(env) == "table" then
                                local scriptRef = rawget(env, "script")
                                if typeof(scriptRef) == "Instance" and not deleted[scriptRef] then
                                    if (scriptRef:IsA("LocalScript") or scriptRef:IsA("ModuleScript") or (scriptRef:IsA("Script") and scriptRef.RunContext == Enum.RunContext.Client)) and scriptRef.Name ~= "TakeG1" then
                                        scriptRef:Destroy()
                                        deleted[scriptRef] = true
                                        found = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        for _, scriptRef in ipairs(game:GetDescendants()) do
            if not deleted[scriptRef] and (scriptRef:IsA("LocalScript") or scriptRef:IsA("ModuleScript") or (scriptRef:IsA("Script") and scriptRef.RunContext == Enum.RunContext.Client)) then
                if scriptRef.Name ~= "TakeG1" then
                    if sourceHasKeyword and pcall(sourceHasKeyword, scriptRef) then
                        if sourceHasKeyword(scriptRef) then
                            scriptRef:Destroy()
                            deleted[scriptRef] = true
                            found = true
                        end
                    end
                end
            end
        end

        if not found then
            print("Bypass Failed.")
        end
    end
end)


local InterfaceSection = Tabs.Tab4:Section("______________________________________________________________________________________")

Tabs.Tab4:CreateButton{
    Title = "Shoot Power",
    Description = "Activates Shoot Power boost",
    Callback = function()
        local args = {1540385087, "SkillA", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

Tabs.Tab4:CreateButton{
    Title = "Pass / Long Power",
    Description = "Activates Pass/Long Power boost",
    Callback = function()
        local args = {1588192351, "SkillB", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

Tabs.Tab4:CreateButton{
    Title = "Curve Power",
    Description = "Activates Curve Power boost",
    Callback = function()
        local args = {1309722229, "SkillC", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

Tabs.Tab4:CreateButton{
    Title = "Tackle Power",
    Description = "Activates Tackle Power boost",
    Callback = function()
        local args = {862012192, "SkillD", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

Tabs.Tab4:CreateButton{
    Title = "Skill Power",
    Description = "Activates Skill Power boost",
    Callback = function()
        local args = {417646286, "SkillE", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

Tabs.Tab4:CreateButton{
    Title = "GK Power",
    Description = "Activates Goalkeeper Power boost",
    Callback = function()
        local args = {628934962, "SkillF", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

Tabs.Tab4:CreateButton{
    Title = "Durability",
    Description = "Activates Durability boost",
    Callback = function()
        local args = {5550729447, "SkillH", false}
        pcall(function() workspace.FE.PlayerCard.Boost:FireServer(unpack(args)) end)
    end
}

local InterfaceSection = Tabs.Tab4:Section("______________________________________________________________________________________")

Tabs.Tab4:CreateButton{
    Title = "Prevent Physics Sleep",
    Description = "Disables physics sleep to keep parts active",
    Callback = function()
        settings().Physics.AllowSleep = false
    end
}

Tabs.Tab4:CreateButton{
    Title = "Maximize Simulation Range",
    Description = "Sets player's simulation radius to maximum",
    Callback = function()
        player.SimulationRadius = math.huge
        sethiddenproperty(player, "MaximumSimulationRadius", math.huge)
    end
}




-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- InterfaceManager (Allows you to have a interface managment system)

-- Hand the library over to our managers
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- You can add indexes of elements the save manager should ignore
SaveManager:SetIgnoreIndexes{}

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)


Window:SelectTab(1)

Library:Notify{
    Title = "Fluent",
    Content = "The script has been loaded.",
    Duration = 8
}

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()

Library:SetTheme("VS Dark")
