-- ============================================================
-- [ modulo: Header.lua ]
-- ============================================================

if getgenv().Library then
    getgenv().Library:Unload()
end

local Library do
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local RunService = game:GetService("RunService")
    local TextService = game:GetService("TextService")
    local CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local Lighting = game:GetService("Lighting")

    gethui = gethui or function()
        return CoreGui
    end

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local Mouse = LocalPlayer:GetMouse()

    local function FallbackFromHex(Hex)
        Hex = tostring(Hex or ""):gsub("#", "")

        if #Hex == 3 then
            Hex = Hex:sub(1, 1) .. Hex:sub(1, 1)
                .. Hex:sub(2, 2) .. Hex:sub(2, 2)
                .. Hex:sub(3, 3) .. Hex:sub(3, 3)
        end

        local R = tonumber(Hex:sub(1, 2), 16) or 255
        local G = tonumber(Hex:sub(3, 4), 16) or 255
        local B = tonumber(Hex:sub(5, 6), 16) or 255

        return Color3.fromRGB(R, G, B)
    end

    local function FallbackClamp(Value, Min, Max)
        if Value < Min then
            return Min
        end

        if Value > Max then
            return Max
        end

        return Value
    end

    local function FallbackFind(List, Target)
        for Index, Value in next, List do
            if Value == Target then
                return Index
            end
        end
    end

    local function FallbackClone(List)
        local NewList = {}

        for Index, Value in next, List do
            NewList[Index] = Value
        end

        return NewList
    end

    local FromRGB = Color3.fromRGB
    local FromHSV = Color3.fromHSV
    local FromHex = Color3.fromHex or FallbackFromHex

    local RGBSequence = ColorSequence.new
    local RGBSequenceKeypoint = ColorSequenceKeypoint.new
    local NumSequence = NumberSequence.new
    local NumSequenceKeypoint = NumberSequenceKeypoint.new

    local UDim2New = UDim2.new
    local UDimNew = UDim.new
    local UDim2FromOffset = UDim2.fromOffset
    local TweenInfoNew = TweenInfo.new
    local Vector2New = Vector2.new
    local Vector3New = Vector3.new

    local MathClamp = math.clamp or FallbackClamp
    local MathFloor = math.floor
    local MathAbs = math.abs
    local MathSin = math.sin

    local TableInsert = table.insert
    local TableFind = table.find or FallbackFind
    local TableRemove = table.remove
    local TableConcat = table.concat
    local TableClone = table.clone or FallbackClone
    local TableUnpack = table.unpack or unpack

    local StringFormat = string.format
    local StringFind = string.find
    local StringGSub = string.gsub
    local StringLower = string.lower
    local StringLen = string.len

    local InstanceNew = Instance.new

    local RectNew = Rect.new

-- ============================================================
-- [ modulo: LibraryTable.lua ]
-- ============================================================

    Library = {
        Theme =  { },

        MenuKeybind = tostring(Enum.KeyCode.RightControl), 
        DefaultToggleButtonIcon = "rbxassetid://85556830856878",
        DefaultToggleButtonPosition = UDim2.new(0.5, -25, 0, 50),
        DefaultKeybindListPosition = UDim2.new(1, -18, 0, 120),
        DefaultHeaderLogo = "rbxassetid://75802679174420",
        DefaultHeaderLogoSize = 52,

        -- Info page defaults (Window:CreateInfoPage). The hub scripts
        -- repeated these same values everywhere — now they live here and can be
        -- changed in one place.
        DefaultInfoSubtitle = "#1 Script HUB",
        DefaultInfoCredits = { "Lead Developer: @dexz0", "UI Library: VyLib" },
        DefaultDiscordLink = "https://discord.gg/CgxQjT2F9p",

        Flags = { },
        KeybindRegistry = { },
        KeybindLists = { },

        Tween = {
            Time = 0.2,
            Style = Enum.EasingStyle.Quart,
            Direction = Enum.EasingDirection.Out
        },

        FadeSpeed = 0.2,

        Folders = {
            Directory = "VYHUB",
            Configs = "VYHUB/Configs",
            Assets = "VYHUB/Assets",
            Settings = "VYHUB/Settings",
        },

        -- Ignore below
        Pages = { },
        Sections = { },

        Connections = { },
        Threads = { },
        CleanupCallbacks = { },

        ThemeMap = { },
        ThemeItems = { },

        OpenFrames = { },

        SetFlags = { },
        IgnoredFlags = { },

        ExecutorSettings = {
            AutoExec = false,
            MenuKeybind = nil
        },

        _ExecutorSettingsLoaded = false,
        _AutoExecRunId = 0,
        _AutoExecLastQueuedFingerprint = nil,
        _AutoLoadApplied = false,
        _AutoLoadScheduled = false,

        UnnamedConnections = 0,
        UnnamedFlags = 0,

        Holder = nil,
        NotifHolder = nil,
        UnusedHolder = nil,

        Font = nil,
        Unloading = false,
        Unloaded = false
    }

    Library.__index = Library
    Library.Sections.__index = Library.Sections
    Library.Pages.__index = Library.Pages

    Library.IsMobileClient = function(self)
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

-- ============================================================
-- [ modulo: Storage.lua ]
-- ============================================================


    -- ══════════════════════════════════════════════════════════════════════
    -- Storage — persistence that adapts to the executor
    -- ══════════════════════════════════════════════════════════════════════
    -- Not every executor has a working file sandbox. Solara, for one, resolves a
    -- relative path from the process CWD (C:/Windows/System32/workspace/...),
    -- where creating a folder is denied — and a bare `makefolder` at boot killed
    -- the loadstring of the whole lib.
    --
    -- Instead of assuming subfolders, the lib PROBES at startup (writes, reads
    -- back and deletes a test file) and keeps the first strategy that works:
    --
    --   "folders" — VYHUB/Configs/name.json          (ideal)
    --   "flat"    — VYHUB_Configs_name.json          (no makefolder)
    --   "memory"  — session only, gone on close      (last resort)
    --
    -- "flat" is what genuinely supports anyone who only fails at
    -- create_directories but writes files fine. "memory" still allows saving and
    -- switching configs within the session instead of the Configs tab being dead.
    Library.Storage = {
        Mode = "memory",
        Memory = { },
        Root = "VYHUB"
    }

    do
        local Storage = Library.Storage

        local function HasFunctions()
            return type(writefile) == "function"
                and type(readfile) == "function"
                and type(isfile) == "function"
        end

        -- The real path of an item under the current mode. `Kind` is a key of
        -- Library.Folders: "Configs" | "Assets" | "Settings".
        function Library:FilePath(Kind, Name)
            Kind = tostring(Kind or "Configs")
            Name = tostring(Name or "")

            if Storage.Mode == "flat" then
                return Storage.Root .. "_" .. Kind .. "_" .. Name
            end

            return Storage.Root .. "/" .. Kind .. "/" .. Name
        end

        function Library:FileWrite(Kind, Name, Content)
            if Storage.Mode == "memory" then
                Storage.Memory[Kind .. "/" .. Name] = tostring(Content)
                return true
            end

            return (pcall(writefile, self:FilePath(Kind, Name), Content))
        end

        function Library:FileRead(Kind, Name)
            if Storage.Mode == "memory" then
                return Storage.Memory[Kind .. "/" .. Name]
            end

            local Success, Content = pcall(readfile, self:FilePath(Kind, Name))
            return Success and Content or nil
        end

        function Library:FileExists(Kind, Name)
            if Storage.Mode == "memory" then
                return Storage.Memory[Kind .. "/" .. Name] ~= nil
            end

            local Success, Exists = pcall(isfile, self:FilePath(Kind, Name))
            return Success and Exists == true
        end

        function Library:FileDelete(Kind, Name)
            if Storage.Mode == "memory" then
                Storage.Memory[Kind .. "/" .. Name] = nil
                return true
            end

            if type(delfile) ~= "function" then
                return false
            end

            if not self:FileExists(Kind, Name) then
                return false
            end

            return (pcall(delfile, self:FilePath(Kind, Name)))
        end

        -- Nomes dos itens de um Kind, sem o caminho e sem o prefixo do modo.
        function Library:FileList(Kind)
            local Out = { }

            if Storage.Mode == "memory" then
                local Prefix = Kind .. "/"

                for Key in next, Storage.Memory do
                    if Key:sub(1, #Prefix) == Prefix then
                        Out[#Out + 1] = Key:sub(#Prefix + 1)
                    end
                end

                return Out
            end

            if type(listfiles) ~= "function" then
                return Out
            end

            -- In flat mode everything lives in the same folder, so filter by prefix.
            local Where = Storage.Mode == "flat" and "" or (Storage.Root .. "/" .. Kind)
            local Success, List = pcall(listfiles, Where)

            if not Success or type(List) ~= "table" then
                return Out
            end

            local FlatPrefix = Storage.Root .. "_" .. Kind .. "_"

            for _, Path in next, List do
                -- listfiles returns a full path; keep only the file name
                local File = tostring(Path):match("[^/\\]+$")

                if File then
                    if Storage.Mode == "flat" then
                        if File:sub(1, #FlatPrefix) == FlatPrefix then
                            Out[#Out + 1] = File:sub(#FlatPrefix + 1)
                        end
                    else
                        Out[#Out + 1] = File
                    end
                end
            end

            return Out
        end

        -- ── Probe ─────────────────────────────────────────────────────────
        -- Write, read back and delete. "Wrote with no error" is not enough: on an
        -- executor with a broken sandbox the writefile passes and the file does not
        -- exist afterwards.
        local function Probe()
            local Name = "vylib_probe.txt"
            local Stamp = "vy"

            if not Library:FileWrite("Configs", Name, Stamp) then
                return false
            end

            local Back = Library:FileRead("Configs", Name)
            Library:FileDelete("Configs", Name)

            return Back == Stamp
        end

        if HasFunctions() then
            -- 1) subpastas
            if type(makefolder) == "function" and type(isfolder) == "function" then
                local Made = true

                for _, Path in ipairs({
                    Storage.Root,
                    Storage.Root .. "/Configs",
                    Storage.Root .. "/Assets",
                    Storage.Root .. "/Settings"
                }) do
                    local Success = pcall(function()
                        if not isfolder(Path) then
                            makefolder(Path)
                        end
                    end)

                    if not Success then
                        Made = false
                        break
                    end
                end

                if Made then
                    Storage.Mode = "folders"

                    if not Probe() then
                        Storage.Mode = "memory"
                    end
                end
            end

            -- 2) everything at the root, creating no folder at all
            if Storage.Mode ~= "folders" then
                Storage.Mode = "flat"

                if not Probe() then
                    Storage.Mode = "memory"
                end
            end
        end

        -- Compat: hub scripts build paths by hand from here
        -- (`Library.Folders.Configs .. "/" .. name`). Nothing inside the lib does that
        -- any more — everything goes through FilePath/FileWrite/FileRead, which is the
        -- only way flat mode works. Here the values become each mode's REAL directory,
        -- so that external concatenation still lands somewhere writable.
        if Storage.Mode == "flat" then
            Library.Folders = {
                Directory = "",
                Configs   = "",
                Assets    = "",
                Settings  = ""
            }
        end

        -- For anyone who just wants to know "can this persist between sessions?".
        Library.FileSystemReady = Storage.Mode ~= "memory"
    end
-- ============================================================
-- [ modulo: Keys.lua ]
-- ============================================================

    local Keys = {
        ["Unknown"]           = "Unknown",
        ["Backspace"]         = "Back",
        ["Tab"]               = "Tab",
        ["Clear"]             = "Clear",
        ["Return"]            = "Return",
        ["Pause"]             = "Pause",
        ["Escape"]            = "Escape",
        ["Space"]             = "Space",
        ["QuotedDouble"]      = '"',
        ["Hash"]              = "#",
        ["Dollar"]            = "$",
        ["Percent"]           = "%",
        ["Ampersand"]         = "&",
        ["Quote"]             = "'",
        ["LeftParenthesis"]   = "(",
        ["RightParenthesis"]  = " )",
        ["Asterisk"]          = "*",
        ["Plus"]              = "+",
        ["Comma"]             = ",",
        ["Minus"]             = "-",
        ["Period"]            = ".",
        ["Slash"]             = "`",
        ["Three"]             = "3",
        ["Seven"]             = "7",
        ["Eight"]             = "8",
        ["Colon"]             = ":",
        ["Semicolon"]         = ";",
        ["LessThan"]          = "<",
        ["GreaterThan"]       = ">",
        ["Question"]          = "?",
        ["Equals"]            = "=",
        ["At"]                = "@",
        ["LeftBracket"]       = "LeftBracket",
        ["RightBracket"]      = "RightBracked",
        ["BackSlash"]         = "BackSlash",
        ["Caret"]             = "^",
        ["Underscore"]        = "_",
        ["Backquote"]         = "`",
        ["LeftCurly"]         = "{",
        ["Pipe"]              = "|",
        ["RightCurly"]        = "}",
        ["Tilde"]             = "~",
        ["Delete"]            = "Delete",
        ["End"]               = "End",
        ["KeypadZero"]        = "Keypad0",
        ["KeypadOne"]         = "Keypad1",
        ["KeypadTwo"]         = "Keypad2",
        ["KeypadThree"]       = "Keypad3",
        ["KeypadFour"]        = "Keypad4",
        ["KeypadFive"]        = "Keypad5",
        ["KeypadSix"]         = "Keypad6",
        ["KeypadSeven"]       = "Keypad7",
        ["KeypadEight"]       = "Keypad8",
        ["KeypadNine"]        = "Keypad9",
        ["KeypadPeriod"]      = "KeypadP",
        ["KeypadDivide"]      = "KeypadD",
        ["KeypadMultiply"]    = "KeypadM",
        ["KeypadMinus"]       = "KeypadM",
        ["KeypadPlus"]        = "KeypadP",
        ["KeypadEnter"]       = "KeypadE",
        ["KeypadEquals"]      = "KeypadE",
        ["Insert"]            = "Insert",
        ["Home"]              = "Home",
        ["PageUp"]            = "PageUp",
        ["PageDown"]          = "PageDown",
        ["RightShift"]        = "RightShift",
        ["LeftShift"]         = "LeftShift",
        ["RightControl"]      = "RightControl",
        ["LeftControl"]       = "LeftControl",
        ["LeftAlt"]           = "LeftAlt",
        ["RightAlt"]          = "RightAlt"
    }

-- ============================================================
-- [ modulo: Themes.lua ]
-- ============================================================

    -- Monochrome only. Accent is the one bright value (white on the dark
    -- presets, black on Paper); AccentText is whatever stays readable on top
    -- of it, for the toggle knob and filled chips.
    local Themes = {
        ["Onyx"] = {
            ["Background"]   = FromRGB(0, 0, 0),
            ["Panel"]        = FromRGB(8, 8, 8),
            ["Surface"]      = FromRGB(13, 13, 13),
            ["Inline"]       = FromRGB(10, 10, 10),
            ["Element"]      = FromRGB(20, 20, 20),
            ["Outline"]      = FromRGB(48, 48, 48),
            ["OutlineSoft"]  = FromRGB(28, 28, 28),
            ["Accent"]       = FromRGB(255, 255, 255),
            ["AccentSoft"]   = FromRGB(40, 40, 40),
            ["AccentText"]   = FromRGB(0, 0, 0),
            ["Text"]         = FromRGB(255, 255, 255),
            ["TextMuted"]    = FromRGB(138, 138, 138)
        },
        ["Graphite"] = {
            ["Background"]   = FromRGB(16, 16, 16),
            ["Panel"]        = FromRGB(22, 22, 22),
            ["Surface"]      = FromRGB(28, 28, 28),
            ["Inline"]       = FromRGB(24, 24, 24),
            ["Element"]      = FromRGB(36, 36, 36),
            ["Outline"]      = FromRGB(66, 66, 66),
            ["OutlineSoft"]  = FromRGB(46, 46, 46),
            ["Accent"]       = FromRGB(240, 240, 240),
            ["AccentSoft"]   = FromRGB(58, 58, 58),
            ["AccentText"]   = FromRGB(16, 16, 16),
            ["Text"]         = FromRGB(240, 240, 240),
            ["TextMuted"]    = FromRGB(150, 150, 150)
        },
        ["Paper"] = {
            ["Background"]   = FromRGB(250, 250, 250),
            ["Panel"]        = FromRGB(255, 255, 255),
            ["Surface"]      = FromRGB(245, 245, 245),
            ["Inline"]       = FromRGB(252, 252, 252),
            ["Element"]      = FromRGB(236, 236, 236),
            ["Outline"]      = FromRGB(200, 200, 200),
            ["OutlineSoft"]  = FromRGB(226, 226, 226),
            ["Accent"]       = FromRGB(0, 0, 0),
            ["AccentSoft"]   = FromRGB(218, 218, 218),
            ["AccentText"]   = FromRGB(255, 255, 255),
            ["Text"]         = FromRGB(0, 0, 0),
            ["TextMuted"]    = FromRGB(110, 110, 110)
        },
    }
    Library.Themes = Themes  -- exposed for the Settings page dropdown

    function Library:ApplyThemePreset(name)
        local preset = Themes[name]
        if type(preset) ~= "table" then return false end
        for key, color in pairs(preset) do
            Library.Theme[key] = color
            pcall(function() Library:ChangeTheme(key, color) end)
        end
        Library.CurrentThemeName = name
        return true
    end

    function Library:SetBackgroundImage(assetIdOrUrl, transparency)
        -- Accepts rbxassetid://N, a number, or an http URL
        local imageId = assetIdOrUrl
        if type(imageId) == "number" then
            imageId = "rbxassetid://" .. tostring(imageId)
        elseif type(imageId) == "string" then
            local asNumber = tonumber(imageId)
            if asNumber then imageId = "rbxassetid://" .. tostring(asNumber) end
        end

        local mainFrame = Library.Holder and Library.Holder.Instance
        if not mainFrame then return false end

        local existing = mainFrame:FindFirstChild("VyHub_BackgroundImage")
        if not imageId or imageId == "" then
            if existing then existing:Destroy() end
            return true
        end

        local bg = existing
        if not bg then
            bg = Instance.new("ImageLabel")
            bg.Name = "VyHub_BackgroundImage"
            bg.BackgroundTransparency = 1
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.ZIndex = 0
            bg.ScaleType = Enum.ScaleType.Crop
            bg.Parent = mainFrame
        end
        bg.Image = imageId
        bg.ImageTransparency = transparency or 0.5
        return true
    end

    Library.Theme = TableClone(Themes["Onyx"])
    Library.CurrentThemeName = "Onyx"

    -- (folder creation moved house: it became the Storage module, which probes
    -- what the executor accepts and picks between subfolder, prefix or memory.)

    local AutoExecGuardKey = "VyLib_AutoExecGuard"
    local AutoExecSourceKeys = {
        { Script = "VyLib_AutoExecScript", Url = "VyLib_AutoExecURL", File = "VyLib_AutoExecFile" },
        { Script = "VyHub_AutoExecScript", Url = "VyHub_AutoExecURL", File = "VyHub_AutoExecFile" }
    }
-- ============================================================
-- [ modulo: Tween.lua ]
-- ============================================================


    -- Tweening
    local FadePropertyStates = setmetatable({ }, { __mode = "k" })

    local Tween = { } do
        Tween.__index = Tween

        Tween.Create = function(self, Item, Info, Goal, IsRawItem)
            Item = IsRawItem and Item or Item.Instance
            Info = Info or TweenInfo.new(Library.Tween.Time, Library.Tween.Style, Library.Tween.Direction)

            local NewTween = {
                Tween = TweenService:Create(Item, Info, Goal),
                Info = Info,
                Goal = Goal,
                Item = Item
            }

            NewTween.Tween:Play()

            setmetatable(NewTween, Tween)

            return NewTween
        end

        Tween.GetProperty = function(self, Item)
            Item = Item or self.Item 

            if Item:IsA("Frame") then
                return { "BackgroundTransparency" }
            elseif Item:IsA("TextLabel") or Item:IsA("TextButton") then
                return { "TextTransparency", "BackgroundTransparency" }
            elseif Item:IsA("ImageLabel") or Item:IsA("ImageButton") then
                return { "BackgroundTransparency", "ImageTransparency" }
            elseif Item:IsA("ScrollingFrame") then
                return { "BackgroundTransparency", "ScrollBarImageTransparency" }
            elseif Item:IsA("TextBox") then
                return { "TextTransparency", "BackgroundTransparency" }
            elseif Item:IsA("UIStroke") then 
                return { "Transparency" }
            end
        end

        Tween.FadeItem = function(self, Item, Property, Visibility, Speed)
            local Item = Item or self.Item 
            local ItemState = FadePropertyStates[Item]

            if not ItemState then
                ItemState = { }
                FadePropertyStates[Item] = ItemState
            end

            local PropertyState = ItemState[Property]

            if not PropertyState then
                PropertyState = {
                    BaseTransparency = Item[Property],
                    Tween = nil,
                    Token = 0
                }
                ItemState[Property] = PropertyState
            end

            if PropertyState.Tween then
                pcall(function()
                    PropertyState.Tween:Cancel()
                end)
                PropertyState.Tween = nil
            end

            PropertyState.Token += 1
            local CurrentToken = PropertyState.Token

            if Visibility then
                PropertyState.BaseTransparency = Item[Property]
                Item[Property] = 1
            end

            local BaseTransparency = PropertyState.BaseTransparency

            local NewTween = Tween:Create(Item, TweenInfo.new(Speed or Library.Tween.Time, Library.Tween.Style, Library.Tween.Direction), {
                [Property] = Visibility and BaseTransparency or 1
            }, true)

            PropertyState.Tween = NewTween.Tween

            Library:Connect(NewTween.Tween.Completed, function()
                if PropertyState.Token ~= CurrentToken then
                    return
                end

                PropertyState.Tween = nil

                if not Visibility then 
                    task.wait()

                    if PropertyState.Token ~= CurrentToken then
                        return
                    end

                    Item[Property] = BaseTransparency
                end
            end)

            return NewTween
        end

        Tween.Get = function(self)
            if not self.Tween then 
                return
            end

            return self.Tween, self.Info, self.Goal
        end

        Tween.Pause = function(self)
            if not self.Tween then 
                return
            end

            self.Tween:Pause()
        end

        Tween.Play = function(self)
            if not self.Tween then 
                return
            end

            self.Tween:Play()
        end

        Tween.Clean = function(self)
            if not self.Tween then 
                return
            end

            Tween:Pause()
            self = nil
        end
    end
-- ============================================================
-- [ modulo: Instances.lua ]
-- ============================================================


    -- Instances
    local Instances = { } do
        Instances.__index = Instances

        Instances.Create = function(self, Class, Properties)
            local NewItem = {
                Instance = InstanceNew(Class),
                Properties = Properties,
                Class = Class
            }

            setmetatable(NewItem, Instances)

            for Property, Value in NewItem.Properties do
                NewItem.Instance[Property] = Value
            end

            return NewItem
        end

        Instances.AddToTheme = function(self, Properties)
            if not self.Instance then 
                return
            end

            local ActiveLibrary = Library
            if type(ActiveLibrary) ~= "table" or ActiveLibrary.Unloading or ActiveLibrary.Unloaded then
                return self
            end

            ActiveLibrary:AddToTheme(self, Properties)
            return self
        end

        Instances.ChangeItemTheme = function(self, Properties)
            if not self.Instance then 
                return
            end

            local ActiveLibrary = Library
            if type(ActiveLibrary) ~= "table" or ActiveLibrary.Unloading or ActiveLibrary.Unloaded then
                return
            end

            ActiveLibrary:ChangeItemTheme(self, Properties)
        end

        Instances.Connect = function(self, Event, Callback, Name)
            if not self.Instance then 
                return
            end

            if not self.Instance[Event] then 
                return
            end

            local ActiveLibrary = Library
            if type(ActiveLibrary) ~= "table" or ActiveLibrary.Unloading or ActiveLibrary.Unloaded then
                return
            end

            return ActiveLibrary:Connect(self.Instance[Event], Callback, Name)
        end

        Instances.Tween = function(self, Info, Goal)
            if not self.Instance then 
                return
            end

            return Tween:Create(self, Info, Goal)
        end

        Instances.Disconnect = function(self, Name)
            if not self.Instance then 
                return
            end

            local ActiveLibrary = Library
            if type(ActiveLibrary) ~= "table" or ActiveLibrary.Unloading or ActiveLibrary.Unloaded then
                return
            end

            return ActiveLibrary:Disconnect(Name)
        end

        Instances.Clean = function(self)
            if not self.Instance then 
                return
            end

            self.Instance:Destroy()
            self = nil
        end

        Instances.MakeDraggable = function(self)
            if not self.Instance then 
                return
            end
        
            local Gui = self.Instance
            local Dragging = false 
            local DragStart
            local StartAbsolutePosition

            local function GetParentBounds()
                local Parent = Gui.Parent

                if Parent and Parent:IsA("GuiObject") then
                    return Parent.AbsolutePosition, Parent.AbsoluteSize
                end

                return Vector2New(0, 0), (Camera and Camera.ViewportSize) or Vector2New(1920, 1080)
            end
        
            local Set = function(Input)
                if not DragStart or not StartAbsolutePosition then
                    return
                end

                local DragDelta = Input.Position - DragStart
                local ParentPosition, ParentSize = GetParentBounds()
                local GuiSize = Gui.AbsoluteSize
                local AnchorPoint = Gui.AnchorPoint

                local NewLeft = (StartAbsolutePosition.X - ParentPosition.X) + DragDelta.X
                local NewTop = (StartAbsolutePosition.Y - ParentPosition.Y) + DragDelta.Y

                -- Allows dragging off screen, but keeps at least 40px visible on each side
                -- so the window is not lost permanently.
                local Margin = 40
                NewLeft = MathClamp(NewLeft, -(GuiSize.X - Margin), ParentSize.X - Margin)
                NewTop = MathClamp(NewTop, -(GuiSize.Y - Margin), ParentSize.Y - Margin)
        
                Gui.Position = UDim2FromOffset(
                    NewLeft + (GuiSize.X * AnchorPoint.X),
                    NewTop + (GuiSize.Y * AnchorPoint.Y)
                )
            end
        
            local InputChanged
        
            self:Connect("InputBegan", function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    -- Optional hook: called BEFORE capturing the initial position.
                    -- Used by Window to unmaximise when the user drags.
                    if self.OnDragStarted then
                        self.OnDragStarted(Input)
                    end

                    Dragging = true
                    DragStart = Input.Position
                    StartAbsolutePosition = Gui.AbsolutePosition
        
                    if InputChanged then 
                        return
                    end
        
                    InputChanged = Input.Changed:Connect(function()
                        if Input.UserInputState == Enum.UserInputState.End then
                            Dragging = false
                            DragStart = nil
                            StartAbsolutePosition = nil
                            InputChanged:Disconnect()
                            InputChanged = nil
                        end
                    end)
                end
            end)
        
            Library:Connect(UserInputService.InputChanged, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                    if Dragging then
                        Set(Input)
                    end
                end
            end)
        
            return Dragging
        end

        Instances.MakeResizeable = function(self, Minimum, Maximum)
            if not self.Instance then 
                return
            end

            local Gui = self.Instance

            local Resizing = false 
            local CurrentSide = nil

            local StartMouse = nil 
            local StartPosition = nil 
            local StartSize = nil
            
            local EdgeThickness = 3

            local MakeEdge = function(Name, Position, Size)
                local Button = Instances:Create("TextButton", {
                    Name = "\0",
                    Size = Size,
                    Position = Position,
                    BackgroundColor3 = FromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Parent = Gui,
                    ZIndex = 99999,
                })  Button:AddToTheme({BackgroundColor3 = "Accent"})

                return Button
            end

            local Edges = {
                {Button = MakeEdge(
                    "Left", 
                    UDim2.new(0, 0, 0, 0), 
                    UDim2.new(0, EdgeThickness, 1, 0)), 
                    Side = "L"
                },

                {Button = MakeEdge(
                    "Right", 
                    UDim2.new(1, -EdgeThickness, 0, 0), 
                    UDim2.new(0, EdgeThickness, 1, 0)), 
                    Side = "R"
                },

                {Button = MakeEdge(
                    "Top", UDim2.new(0, 0, 0, 0), 
                    UDim2.new(1, 0, 0, EdgeThickness)), 
                    Side = "T"
                },

                {Button = MakeEdge(
                    "Bottom", 
                    UDim2.new(0, 0, 1, -EdgeThickness), 
                    UDim2.new(1, 0, 0, EdgeThickness)), 
                    Side = "B"
                },
            }

            local BeginResizing = function(Side)
                Resizing = true 
                CurrentSide = Side 

                StartMouse = UserInputService:GetMouseLocation()

                -- store offsets, not absolute screen pos
                StartPosition = Vector2New(Gui.Position.X.Offset, Gui.Position.Y.Offset)
                StartSize = Vector2New(Gui.Size.X.Offset, Gui.Size.Y.Offset)
                
                for Index, Value in Edges do 
                    Value.Button.Instance.BackgroundTransparency = (Value.Side == Side) and 0 or 1
                end
            end

            local EndResizing = function()
                Resizing = false 
                CurrentSide = nil

                for Index, Value in ipairs(Edges) do
                    Value.Button.Instance.BackgroundTransparency = 1
                end
            end

            for Index, Value in ipairs(Edges) do
                Value.Button:Connect("InputBegan", function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        BeginResizing(Value.Side)
                    end
                end)
            end

            Library:Connect(UserInputService.InputEnded, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    if Resizing then
                        EndResizing()
                    end
                end
            end)

            Library:Connect(RunService.RenderStepped, function()
                if not Resizing or not CurrentSide then 
                    return 
                end

                local MouseLocation = UserInputService:GetMouseLocation()
                local dx = MouseLocation.X - StartMouse.X
                local dy = MouseLocation.Y - StartMouse.Y
            
                local x, y = StartPosition.X, StartPosition.Y
                local w, h = StartSize.X, StartSize.Y

                if CurrentSide == "L" then
                    x = StartPosition.X + dx
                    w = StartSize.X - dx
                elseif CurrentSide == "R" then
                    w = StartSize.X + dx
                elseif CurrentSide == "T" then
                    y = StartPosition.Y + dy
                    h = StartSize.Y - dy
                elseif CurrentSide == "B" then
                    h = StartSize.Y + dy
                end
            
                if w < Minimum.X then
                    if CurrentSide == "L" then
                        x = x - (Minimum.X - w)
                    end
                    w = Minimum.X
                end
                if h < Minimum.Y then
                    if CurrentSide == "T" then
                        y = y - (Minimum.Y - h)
                    end
                    h = Minimum.Y
                end
            
                self:Tween(TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2FromOffset(x, y)})
                self:Tween(TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2FromOffset(w, h)})
            end)
        end

        Instances.OnHover = function(self, Function)
            if not self.Instance then 
                return
            end
            
            return Library:Connect(self.Instance.MouseEnter, Function)
        end

        Instances.OnHoverLeave = function(self, Function)
            if not self.Instance then 
                return
            end
            
            return Library:Connect(self.Instance.MouseLeave, Function)
        end
    end
-- ============================================================
-- [ modulo: Font.lua ]
-- ============================================================


    -- Custom font
    local CustomFont = { } do
        -- Downloads the font and registers it as an asset. Returns nil (rather than
        -- throwing) when the executor will not let us write files — see
        -- `FileSystemReady` in Themes.lua. Without this the whole lib died at boot on
        -- an executor with no file sandbox.
        function CustomFont:New(Name, Weight, Style, Data)
            -- `getcustomasset` needs a REAL file on disk, so Storage's "memory" mode is
            -- no good here.
            if not Library.FileSystemReady or type(getcustomasset) ~= "function" then
                return nil
            end

            local TtfFile = Name .. ".ttf"
            local FontFile = Name .. ".font"

            local Success, Result = pcall(function()
                if not Library:FileExists("Assets", TtfFile) then
                    if not Library:FileWrite("Assets", TtfFile, game:HttpGet(Data.Url)) then
                        return nil
                    end
                end

                local FontData = {
                    name = Name,
                    faces = {
                        {
                            name = Name,
                            weight = Weight,
                            style = Style,
                            assetId = getcustomasset(Library:FilePath("Assets", TtfFile))
                        }
                    }
                }

                if not Library:FileWrite("Assets", FontFile, HttpService:JSONEncode(FontData)) then
                    return nil
                end

                return Font.new(getcustomasset(Library:FilePath("Assets", FontFile)))
            end)

            return Success and Result or nil
        end

        Library.Font = CustomFont:New("OutfitMedium", 400, "Regular", {
            Id = "OutfitMedium",
            Url = "https://github.com/sametexe001/luas/raw/refs/heads/main/fonts/Outfit-Medium.ttf"
        })

        -- Without the custom font the UI still has to come up: fall back to a native one.
        if not Library.Font then
            local BuiltinSuccess, Builtin = pcall(function()
                return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
            end)

            Library.Font = BuiltinSuccess and Builtin or Font.fromEnum(Enum.Font.Gotham)
        end

        local TitleFontSuccess, TitleFont = pcall(function()
            return Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
        end)

        local TitleFontEnumSuccess, TitleFontEnum = pcall(function()
            return Enum.Font.BuilderSansBold
        end)

        local BrandFontSuccess, BrandFont = pcall(function()
            return Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
        end)

        Library.TitleFont = TitleFontSuccess and TitleFont or Library.Font
        Library.TitleFontEnum = TitleFontEnumSuccess and TitleFontEnum or Enum.Font.GothamBold
        Library.BrandFont = BrandFontSuccess and BrandFont or Library.TitleFont
        Library.BrandFontEnum = Library.TitleFontEnum
    end
-- ============================================================
-- [ modulo: Holders.lua ]
-- ============================================================


    Library.Holder = Instances:Create("ScreenGui", {
        Parent = gethui(),
        Name = "\0",
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 2,
        ResetOnSpawn = false
    })

    Library.NotifHolder = Instances:Create("ScreenGui", {
        Parent = gethui(),
        Name = "\0",
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 10,
        ResetOnSpawn = false
    })

    Library.NotifAnchor = Instances:Create("Frame", {
        Parent = Library.NotifHolder.Instance,
        Name = "\0",
        BackgroundTransparency = 1,
        BorderColor3 = FromRGB(0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0
    })

    Library.UnusedHolder = Instances:Create("ScreenGui", {
        Parent = gethui(),
        Name = "\0",
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        Enabled = false,
        ResetOnSpawn = false
    })
-- ============================================================
-- [ modulo: NotificationState.lua ]
-- ============================================================


    local NotificationCards = { }
    -- Mobile: narrower so the notification card doesn't get clipped on the
    -- left edge of phones (~360px wide). Desktop keeps the original 312.
    local NotificationWidth = Library:IsMobileClient() and 260 or 312
    local NotificationMinHeight = 82
    local NotificationGap = 12
    local NotificationEdgeX = 20
    local NotificationEdgeY = 20

    local function MeasureNotificationTextHeight(Text, FontSize, FontEnum, Width)
        local Success, Bounds = pcall(function()
            return TextService:GetTextSize(Text, FontSize, FontEnum, Vector2New(Width, 1000))
        end)

        if Success and Bounds then
            return MathFloor(Bounds.Y)
        end

        return FontSize
    end

    local function GetNotificationHeight(NotificationData)
        local CardInstance = NotificationData and NotificationData.Card and NotificationData.Card.Instance

        if CardInstance and CardInstance.Parent then
            return math.max(MathFloor(CardInstance.AbsoluteSize.Y), NotificationMinHeight)
        end

        return NotificationMinHeight
    end

    local function GetNotificationOffset(Index)
        local TotalHeight = NotificationEdgeY

        for CurrentIndex = 1, Index - 1 do
            TotalHeight += GetNotificationHeight(NotificationCards[CurrentIndex]) + NotificationGap
        end

        return -TotalHeight
    end

    local function RestackNotifications()
        for Index, NotificationData in next, NotificationCards do
            local CardInstance = NotificationData.Card and NotificationData.Card.Instance

            if CardInstance and CardInstance.Parent then
                TweenService:Create(CardInstance, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(1, -NotificationEdgeX, 1, GetNotificationOffset(Index))
                }):Play()
            end
        end
    end
-- ============================================================
-- [ modulo: Unload.lua ]
-- ============================================================


    Library.Unload = function(self)
        if self.Unloading or self.Unloaded then
            return
        end

        self.Unloading = true

        for Index, Value in self.Connections do 
            if Value.Connection then
                Value.Connection:Disconnect()
            end
        end

        for Index, Value in self.Threads do 
            pcall(coroutine.close, Value)
        end

        for _, Callback in self.CleanupCallbacks do
            pcall(Callback)
        end

        if self.Holder then 
            self.Holder:Clean()
        end

        if self.NotifHolder then
            self.NotifHolder:Clean()
        end

        if self.UnusedHolder then
            self.UnusedHolder:Clean()
        end

        self.Unloaded = true
        getgenv().Library = nil
    end

    Library.OnUnload = function(self, Callback)
        if type(Callback) == "function" then
            TableInsert(self.CleanupCallbacks, Callback)
        end

        return Callback
    end
-- ============================================================
-- [ modulo: Utils.lua ]
-- ============================================================


    Library.Round = function(self, Number, Float)
        local Multiplier = 1 / (Float or 1)
        return MathFloor(Number * Multiplier) / Multiplier
    end

    Library.Thread = function(self, Function)
        -- Guard: callbacks opcionais (ex: AddToggle sem Callback) chegam nil aqui.
        -- Without this coroutine.create(nil) blows up with "function expected, got nil".
        if type(Function) ~= "function" then
            return nil
        end

        local NewThread = coroutine.create(Function)

        coroutine.wrap(function()
            coroutine.resume(NewThread)
        end)()

        TableInsert(self.Threads, NewThread)
        return NewThread
    end
    
    Library.SafeCall = function(self, Function, ...)
        local Arguements = { ... }
        local Success, Result = pcall(Function, TableUnpack(Arguements))

        if not Success then
            warn(Result)
            return false
        end

        return Success
    end

    Library.Connect = function(self, Event, Callback, Name)
        Name = Name or StringFormat("connection_number_%s_%s", self.UnnamedConnections + 1, HttpService:GenerateGUID(false))

        local NewConnection = {
            Event = Event,
            Callback = Callback,
            Name = Name,
            Connection = nil
        }

        Library:Thread(function()
            NewConnection.Connection = Event:Connect(Callback)
        end)

        TableInsert(self.Connections, NewConnection)
        return NewConnection
    end

    Library.Disconnect = function(self, Name)
        for _, Connection in self.Connections do 
            if Connection.Name == Name then
                Connection.Connection:Disconnect()
                break
            end
        end
    end

    Library.NextFlag = function(self)
        -- Increment a session counter and return a DETERMINISTIC flag id.
        -- The previous version appended a per-call GUID, which made every
        -- reload generate new flag names — so saved configs never matched
        -- the widgets on autoload (the values existed in the JSON but
        -- Library.SetFlags[Index] was nil for the new GUID-suffixed names).
        -- Widgets are created in a fixed order per script run, so a plain
        -- counter is stable across reloads.
        self.UnnamedFlags = (self.UnnamedFlags or 0) + 1
        return StringFormat("flag_number_%d", self.UnnamedFlags)
    end
-- ============================================================
-- [ modulo: ThemeFlags.lua ]
-- ============================================================


    Library.AddToTheme = function(self, Item, Properties)
        -- Accepts lib wrappers (with .Instance) OR raw Roblox instances.
        -- Reading .Instance on a raw instance errors, so check the type first.
        if type(Item) == "table" and Item.Instance then
            Item = Item.Instance
        end

        local ThemeData = {
            Item = Item,
            Properties = Properties,
        }

        for Property, Value in ThemeData.Properties do
            if type(Value) == "string" then
                if not self.Theme[Value] then
                    Item[Property] = Value 
                end

                Item[Property] = self.Theme[Value]
            else
                Item[Property] = Value()
            end
        end

        TableInsert(self.ThemeItems, ThemeData)
        self.ThemeMap[Item] = ThemeData
    end

	Library.ToRich = function(self, Text, Color)
		return `<font color="rgb({MathFloor(Color.R * 255)}, {MathFloor(Color.G * 255)}, {MathFloor(Color.B * 255)})">{Text}</font>`
	end

    Library.RegisterIgnoredFlag = function(self, Flag)
        if type(Flag) == "string" and Flag ~= "" then
            self.IgnoredFlags[Flag] = true
        end
    end

    Library.RegisterIgnoredFlags = function(self, Flags)
        if type(Flags) ~= "table" then
            return
        end

        for _, Flag in next, Flags do
            self:RegisterIgnoredFlag(Flag)
        end
    end

    Library.ShouldIgnoreFlag = function(self, Flag)
        return self.IgnoredFlags[Flag] == true
    end
-- ============================================================
-- [ modulo: Config.lua ]
-- ============================================================


    Library.GetConfig = function(self)
        local Config = { } 

        local Success, Result = Library:SafeCall(function()
            for Index, Value in Library.Flags do 
                if Library:ShouldIgnoreFlag(Index) then
                    continue
                end

                if type(Value) == "table" and Value.Key then
                    Config[Index] = {Key = tostring(Value.Key), Mode = Value.Mode}
                elseif type(Value) == "table" and Value.Color then
                    Config[Index] = {Color = "#" .. Value.HexValue, Alpha = Value.Alpha}
                else
                    Config[Index] = Value
                end
            end
        end)

        return HttpService:JSONEncode(Config)
    end

    -- `OnlyThese` (optional) is a set of flag names: when given, only those
    -- indices are processed. It is what lets autoload repeat the pass over the
    -- SKIPPED ones without re-applying what already landed — see `ScheduleAutoload`.
    Library.LoadConfig = function(self, Config, OnlyThese)
        local Decoded = HttpService:JSONDecode(Config)

        -- Count returned to the caller. This used to be silent: a flag that no longer
        -- existed was skipped without a trace, and "the config does not load" arrived
        -- as a report with not a single clue where to look.
        local Applied, Skipped, Failed = 0, 0, 0

        -- WHICH ones were skipped, not just how many. Without the names autoload has
        -- no way to retry only what was missing.
        local SkippedKeys = { }

        local Success, Result = Library:SafeCall(function()
            for Index, Value in Decoded do
                if Library:ShouldIgnoreFlag(Index) then
                    continue
                end

                if OnlyThese and not OnlyThese[Index] then
                    continue
                end

                local SetFunction = Library.SetFlags[Index]

                if not SetFunction then
                    Skipped += 1
                    SkippedKeys[#SkippedKeys + 1] = Index
                    continue
                end

                -- One pcall PER FLAG. The whole loop used to live inside a single SafeCall:
                -- ONE element throwing partway through lost every following flag at once. And
                -- since the order comes from the decoded JSON (a hash), which ones were lost
                -- changed on each load — hence the symptom "sometimes it loads".
                local Ok = pcall(function()
                    if type(Value) == "table" and Value.Key then
                        SetFunction(Value)
                    elseif type(Value) == "table" and Value.Color then
                        SetFunction(Value.Color, Value.Alpha)
                    else
                        SetFunction(Value)
                    end
                end)

                if Ok then
                    Applied += 1
                else
                    Failed += 1
                    warn("[vylib] flag failed to apply:", Index)
                end
            end
        end)

        return Success, Result, {
            Applied = Applied,
            Skipped = Skipped,
            Failed = Failed,
            SkippedKeys = SkippedKeys
        }
    end

    Library.DeleteConfig = function(self, Config)
        return self:FileDelete("Configs", Config)
    end

    -- Names of the saved configs, without the extension. Storage already returns
    -- just the file name and already handles the current mode (subfolder, prefix
    -- or memory).
    Library.RefreshConfigsList = function(self, Element)
        local ReturnList = { }

        for _, File in next, self:FileList("Configs") do
            if File:sub(-5) == ".json" then
                TableInsert(ReturnList, File:sub(1, #File - 5))
            end
        end

        table.sort(ReturnList)

        if Element then
            Element:Refresh(ReturnList)
        end

        return ReturnList
    end
-- ============================================================
-- [ modulo: ExecutorSettings.lua ]
-- ============================================================


    Library.GetExecutorSettingsPath = function(self)
        local PlayerName = LocalPlayer and LocalPlayer.Name or "default"
        return self:FilePath("Settings", PlayerName .. ".json")
    end

    Library.NormalizeMenuKeybind = function(self, Value)
        if typeof(Value) == "EnumItem" then
            return tostring(Value)
        end

        if type(Value) == "table" and Value.Key then
            return tostring(Value.Key)
        end

        if type(Value) == "string" and Value ~= "" then
            return Value
        end

        return nil
    end

    Library.GetMenuKeybindDisplay = function(self, Value)
        local Normalized = self:NormalizeMenuKeybind(Value or self.MenuKeybind)
        if not Normalized then
            return "Unknown"
        end

        return Keys[Normalized]
            or StringGSub(StringGSub(Normalized, "Enum.KeyCode.", ""), "Enum.UserInputType.", "")
            or tostring(Normalized)
    end

    Library.SetMenuKeybind = function(self, Value, SkipSave)
        local Normalized = self:NormalizeMenuKeybind(Value)
        if not Normalized then
            return false, "invalid keybind"
        end

        self.MenuKeybind = Normalized
        self.ExecutorSettings.MenuKeybind = Normalized

        if SkipSave then
            return true
        end

        return self:SaveExecutorSettings()
    end

    Library.GetAutoloadPath = function(self)
        return self:FilePath("Settings", "autoload.txt")
    end

    Library.ResolveTeleportQueueFunction = function(self)
        return queue_on_teleport
            or queueonteleport
            or (syn and syn.queue_on_teleport)
            or (fluxus and fluxus.queue_on_teleport)
    end

    Library.GetAutoExecGuard = function(self)
        local Environment = (getgenv and getgenv()) or _G
        local Guard = Environment[AutoExecGuardKey]

        if type(Guard) ~= "table" then
            Guard = { }
            Environment[AutoExecGuardKey] = Guard
        end

        return Guard
    end

    Library.BuildAutoExecSource = function(self)
        local Environment = (getgenv and getgenv()) or _G

        local function WrapAutoExecBody(Body)
            return TableConcat({
                "pcall(function()",
                "	repeat task.wait() until game and game:IsLoaded()",
                Body,
                "end)"
            }, "\n")
        end

        for _, KeysData in next, AutoExecSourceKeys do
            local RawScript = Environment[KeysData.Script]
            if type(RawScript) == "string" and RawScript ~= "" then
                return WrapAutoExecBody(RawScript)
            end

            local Url = Environment[KeysData.Url]
            if type(Url) == "string" and Url ~= "" then
                return WrapAutoExecBody(StringFormat("	loadstring(game:HttpGet(%q))()", Url))
            end

            local FilePath = Environment[KeysData.File]
            if type(FilePath) == "string" and FilePath ~= "" then
                return WrapAutoExecBody(StringFormat("	if readfile and isfile and isfile(%q) then loadstring(readfile(%q))() end", FilePath, FilePath))
            end
        end

        return nil
    end

    Library.BuildAutoExecFingerprint = function(self, Source)
        if type(Source) ~= "string" then
            return nil
        end

        return tostring(#Source) .. ":" .. Source:sub(1, 160)
    end

    Library.LoadExecutorSettings = function(self)
        if self._ExecutorSettingsLoaded then
            return true
        end

        self._ExecutorSettingsLoaded = true

        local SettingsFile = (LocalPlayer and LocalPlayer.Name or "default") .. ".json"

        if not self:FileExists("Settings", SettingsFile) then
            return false, "settings file missing"
        end

        local Raw = self:FileRead("Settings", SettingsFile)
        if type(Raw) ~= "string" or Raw == "" then
            return false, "settings file unreadable"
        end

        local OkDecode, Decoded = pcall(function()
            return HttpService:JSONDecode(Raw)
        end)
        if not OkDecode or type(Decoded) ~= "table" then
            return false, Decoded
        end

        if type(Decoded.AutoExec) == "boolean" then
            self.ExecutorSettings.AutoExec = Decoded.AutoExec
        end

        if type(Decoded.MenuKeybind) == "string" and Decoded.MenuKeybind ~= "" then
            self:SetMenuKeybind(Decoded.MenuKeybind, true)
        end

        return true
    end

    Library.SaveExecutorSettings = function(self)
        local SettingsFile = (LocalPlayer and LocalPlayer.Name or "default") .. ".json"

        if not self:FileWrite("Settings", SettingsFile, HttpService:JSONEncode(self.ExecutorSettings)) then
            return false, "failed to write settings"
        end

        return true
    end

    Library.GetAutoExecEnabled = function(self)
        return self.ExecutorSettings.AutoExec == true
    end

    Library.QueueAutoExec = function(self, ForceQueue)
        local QueueFunction = self:ResolveTeleportQueueFunction()
        local Source = self:BuildAutoExecSource()

        if not QueueFunction or not Source then
            return false, "queue or source unavailable"
        end

        local Fingerprint = self:BuildAutoExecFingerprint(Source)
        local CurrentJobId = tostring(game.JobId or "")
        local Guard = self:GetAutoExecGuard()

        if not ForceQueue and Fingerprint and self._AutoExecLastQueuedFingerprint == Fingerprint then
            return false, "already queued"
        end

        if not ForceQueue and Fingerprint and Guard.JobId == CurrentJobId and Guard.Fingerprint == Fingerprint then
            return false, "guard prevented duplicate"
        end

        local OkQueue, QueueError = pcall(QueueFunction, Source)
        if not OkQueue then
            return false, QueueError
        end

        self._AutoExecLastQueuedFingerprint = Fingerprint
        Guard.JobId = CurrentJobId
        Guard.Fingerprint = Fingerprint
        Guard.QueuedAt = os.clock()

        return true
    end

    Library.RefreshAutoExecQueue = function(self, ForceQueue)
        self._AutoExecRunId += 1

        if not self:GetAutoExecEnabled() then
            self._AutoExecLastQueuedFingerprint = nil

            local Guard = self:GetAutoExecGuard()
            if Guard.JobId == tostring(game.JobId or "") then
                Guard.JobId = nil
                Guard.Fingerprint = nil
                Guard.QueuedAt = nil
            end

            return false, "auto exec disabled"
        end

        return self:QueueAutoExec(ForceQueue)
    end

    Library.SetAutoExecEnabled = function(self, State, ForceQueue)
        self.ExecutorSettings.AutoExec = State and true or false
        self:SaveExecutorSettings()
        return self:RefreshAutoExecQueue(ForceQueue)
    end

    Library.GetAutoloadConfigName = function(self)
        if not self:FileExists("Settings", "autoload.txt") then
            return nil
        end

        local Name = self:FileRead("Settings", "autoload.txt")
        if type(Name) ~= "string" then
            return nil
        end

        Name = StringGSub(Name, "\r", "")
        Name = StringGSub(Name, "\n", "")

        if Name == "" then
            return nil
        end

        return Name
    end

    Library.SetAutoloadConfig = function(self, Name)
        if type(Name) ~= "string" or Name == "" then
            return false, "autoload unavailable"
        end

        if not self:FileWrite("Settings", "autoload.txt", Name) then
            return false, "failed to write autoload"
        end

        return true
    end

    Library.ClearAutoloadConfig = function(self)
        if not self:FileExists("Settings", "autoload.txt") then
            return false, "autoload not set"
        end

        if not self:FileDelete("Settings", "autoload.txt") then
            return false, "failed to clear autoload"
        end

        return true
    end

    Library.CountSetFlags = function(self)
        local Count = 0

        for _ in next, self.SetFlags do
            Count += 1
        end

        return Count
    end

    Library.WaitForFlagRegistration = function(self, Timeout, StableTicks)
        local TimeoutValue = Timeout or 3
        local RequiredStableTicks = StableTicks or 3
        local LastCount = -1
        local StableCount = 0
        local Deadline = os.clock() + TimeoutValue

        repeat
            local CurrentCount = self:CountSetFlags()

            if CurrentCount == LastCount and CurrentCount > 0 then
                StableCount += 1
            else
                LastCount = CurrentCount
                StableCount = 0
            end

            if StableCount >= RequiredStableTicks then
                break
            end

            task.wait(0.1)
        until os.clock() >= Deadline
    end

    Library.LoadAutoloadConfig = function(self, Force)
        if self._AutoLoadApplied and not Force then
            return false, "autoload already applied"
        end

        local Name = self:GetAutoloadConfigName()
        if not Name then
            return false, "autoload not configured"
        end

        self:WaitForFlagRegistration()

        if not self:FileExists("Configs", Name .. ".json") then
            return false, "autoload config missing"
        end

        local RawConfig = self:FileRead("Configs", Name .. ".json")
        if type(RawConfig) ~= "string" then
            return false, "autoload config unreadable"
        end

        local Success, Result, Stats = self:LoadConfig(RawConfig)
        if Success then
            self._AutoLoadApplied = true
            -- The raw config travels along so the caller can re-feed the skipped ones
            -- later without re-reading the file.
            if Stats then
                Stats.Raw = RawConfig
            end
            return true, Name, Stats
        end

        return false, Result
    end

    Library.ScheduleAutoload = function(self)
        if self._AutoLoadScheduled then
            return
        end

        self._AutoLoadScheduled = true

        task.defer(function()
            task.wait()
            local Success, Result, Stats = self:LoadAutoloadConfig()

            if not Success then
                if Result ~= "autoload not configured" and Result ~= "autoload already applied" then
                    warn("[vylib] autoload failed:", Result)
                end

                -- This was the only completely silent path: no console, no screen. The label
                -- kept saying "Autoload • <name>", nothing happened, and whoever reported it
                -- had no line to quote. It is exactly the shape of the report that came in
                -- ("it says that my auto load is set" + it does not load), so now it speaks.
                if Result == "autoload config missing" then
                    self:Notification("Autoload",
                        StringFormat("%q is set to autoload, but its config file is gone.",
                            tostring(self:GetAutoloadConfigName())), 8)
                end

                return
            end

            -- Always to the console, to give something to ask about when someone reports
            -- "it did not load". On screen only when something actually went wrong —
            -- announcing a successful autoload on every join would be noise.
            Stats = Stats or { Applied = 0, Skipped = 0, Failed = 0 }

            -- ── A second chance for the skipped ones ────────────────────────────
            -- `ScheduleAutoload` runs at the end of `CreateWindow`, i.e. BEFORE the
            -- script has created a single tab: at that moment `SetFlags` only holds the
            -- Settings page's own flags. `WaitForFlagRegistration` exists to cover that,
            -- but it gives up once the count sits still for 0.3s (3 ticks) — and on a
            -- cold join, which is exactly the reported case ("rollback and restart"), UI
            -- construction stalls longer than that partway through.
            --
            -- Then the config was applied against a nearly empty `SetFlags`, EVERYTHING
            -- fell into "skipped", and since `LoadConfig` reports SUCCESS even having
            -- skipped everything, `_AutoLoadApplied = true` shut the door for the rest of
            -- the session. Symptom: "it says autoload is set and it does not load".
            --
            -- Only the SKIPPED ones go back in the queue. Re-applying the whole config
            -- would be wrong: `Toggle:Set` fires the Callback even for an unchanged
            -- value, so anything already applied would re-fire and whatever the user
            -- changed by hand between attempts would be undone. A skipped flag was never
            -- applied — repeating it steps on nothing.
            local Pending = Stats.SkippedKeys

            if Stats.Raw and Pending and #Pending > 0 then
                local Deadline = os.clock() + 20
                local LastFlagCount = -1

                repeat
                    task.wait(0.5)

                    -- With no new flag registered since the last pass there is nothing to try:
                    -- skip the JSONDecode instead of repeating it for nothing.
                    local FlagCount = self:CountSetFlags()

                    if FlagCount ~= LastFlagCount then
                        LastFlagCount = FlagCount

                        local Wanted = { }
                        for _, Key in ipairs(Pending) do
                            Wanted[Key] = true
                        end

                        local RetryOk, _, Retry = self:LoadConfig(Stats.Raw, Wanted)

                        if RetryOk and Retry then
                            Stats.Applied += Retry.Applied
                            Stats.Failed += Retry.Failed
                            Pending = Retry.SkippedKeys
                        end
                    end
                until #Pending == 0 or os.clock() >= Deadline

                -- What is left here is genuinely skipped: a flag this script really does not
                -- have (a config saved in another game, a removed widget).
                Stats.Skipped = #Pending
            end
            warn(StringFormat("[vylib] autoload %q: %d applied, %d skipped, %d failed",
                tostring(Result), Stats.Applied, Stats.Skipped, Stats.Failed))

            if Stats.Failed > 0 then
                self:Notification("Autoload",
                    StringFormat("%d setting(s) in %q failed to apply.", Stats.Failed, tostring(Result)), 8)
            elseif Stats.Applied == 0 then
                self:Notification("Autoload",
                    StringFormat("%q loaded nothing — it has no settings this script knows.", tostring(Result)), 8)
            end
        end)
    end

    Library:LoadExecutorSettings()
    Library:RefreshAutoExecQueue()
-- ============================================================
-- [ modulo: ThemeChange.lua ]
-- ============================================================


    Library.ChangeItemTheme = function(self, Item, Properties)
        if self.Unloading or self.Unloaded then
            return
        end

        Item = Item.Instance or Item

        if not self.ThemeMap[Item] then 
            return
        end

        self.ThemeMap[Item].Properties = Properties
        self.ThemeMap[Item] = self.ThemeMap[Item]
    end

    Library.ChangeTheme = function(self, Theme, Color)
        self.Theme[Theme] = Color

        for _, Item in self.ThemeItems do
            for Property, Value in Item.Properties do
                if type(Value) == "string" and Value == Theme then
                    Item.Item[Property] = Color
                elseif type(Value) == "function" then
                    Item.Item[Property] = Value()
                end
            end
        end
    end
-- ============================================================
-- [ modulo: Notification.lua ]
-- ============================================================


    Library.Notification = function(self, Title, Description, Duration)
        if not Description and Title then
            Description = Title
            Title = "VY HUB"
        end

        Title = tostring(Title or "Notification")
        Description = tostring(Description or "")
        Duration = math.max(tonumber(Duration) or 3, 1)

        local Notification = { }
        local Closing = false
        local ProgressTween
        local CountdownEndsAt = os.clock() + Duration
        local LastCountdownValue

        local Items = { } do
            Items["Card"] = Instances:Create("TextButton", {
                Parent = Library.NotifAnchor.Instance,
                Name = "\0",
                Text = "",
                AutoButtonColor = false,
                Active = true,
                Selectable = false,
                AnchorPoint = Vector2New(1, 1),
                Position = UDim2.new(1, NotificationWidth + 16, 1, GetNotificationOffset(#NotificationCards + 1)),
                Size = UDim2FromOffset(NotificationWidth, NotificationMinHeight),
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Library.Theme["Panel"],
                BackgroundTransparency = 1,
                ZIndex = 20,
                TextSize = 14
            })

            Instances:Create("UICorner", {
                Parent = Items["Card"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 16)
            })

            Items["Shadow"] = Instances:Create("Frame", {
                Parent = Items["Card"].Instance,
                Name = "\0",
                BackgroundColor3 = FromRGB(0, 0, 0),
                BackgroundTransparency = 0.66,
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2FromOffset(0, 7),
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 19
            })

            Instances:Create("UICorner", {
                Parent = Items["Shadow"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 16)
            })

            Instances:Create("UIStroke", {
                Parent = Items["Card"].Instance,
                Name = "\0",
                Color = Library.Theme["OutlineSoft"],
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            }):AddToTheme({Color = 'OutlineSoft'})

            Items["Surface"] = Instances:Create("Frame", {
                Parent = Items["Card"].Instance,
                Name = "\0",
                BackgroundColor3 = Library.Theme["Surface"],
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2FromOffset(0, 0),
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 21
            }):AddToTheme({BackgroundColor3 = 'Surface'})

            Instances:Create("UICorner", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 16)
            })

            Items["IconChip"] = Instances:Create("Frame", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                BackgroundColor3 = Library.Theme["Element"],
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2FromOffset(14, 12),
                Size = UDim2FromOffset(26, 26),
                ZIndex = 21
            }):AddToTheme({BackgroundColor3 = 'Element'})

            Instances:Create("UICorner", {
                Parent = Items["IconChip"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 8)
            })

            Instances:Create("UIStroke", {
                Parent = Items["IconChip"].Instance,
                Name = "\0",
                Color = Library.Theme["OutlineSoft"],
                Transparency = 0.15,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            }):AddToTheme({Color = 'OutlineSoft'})

            Items["Icon"] = Instances:Create("ImageLabel", {
                Parent = Items["IconChip"].Instance,
                Name = "\0",
                ScaleType = Enum.ScaleType.Fit,
                ImageTransparency = 0.08,
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                AnchorPoint = Vector2New(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Image = Library:ResolveIcon("bell"),
                BackgroundTransparency = 1,
                Size = UDim2FromOffset(15, 15),
                ZIndex = 22
            }):AddToTheme({ImageColor3 = 'Accent'})

            Items["Kicker"] = Instances:Create("TextLabel", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                Font = Enum.Font.GothamSemibold,
                TextColor3 = Library.Theme["TextMuted"],
                TextTransparency = 0.35,
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "VY HUB",
                BackgroundTransparency = 1,
                Position = UDim2FromOffset(46, 12),
                Size = UDim2FromOffset(72, 12),
                BorderSizePixel = 0,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextSize = 10,
                ZIndex = 21
            }):AddToTheme({TextColor3 = 'TextMuted'})

            Items["TimerPill"] = Instances:Create("Frame", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                BackgroundColor3 = Library.Theme["Element"],
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                AnchorPoint = Vector2New(1, 0),
                Position = UDim2.new(1, -12, 0, 12),
                Size = UDim2FromOffset(30, 16),
                ZIndex = 21
            }):AddToTheme({BackgroundColor3 = 'Element'})

            Instances:Create("UICorner", {
                Parent = Items["TimerPill"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(1, 0)
            })

            Items["TimerText"] = Instances:Create("TextLabel", {
                Parent = Items["TimerPill"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                Font = Enum.Font.GothamMedium,
                TextColor3 = Library.Theme["TextMuted"],
                Text = string.format("%ss", math.max(1, math.ceil(Duration))),
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 22
            }):AddToTheme({TextColor3 = 'TextMuted'})

            Items["Title"] = Instances:Create("TextLabel", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                FontFace = Library.TitleFont or Library.Font,
                Font = Library.TitleFontEnum or Enum.Font.GothamBold,
                TextColor3 = Library.Theme["Text"],
                TextTransparency = 0,
                BorderColor3 = FromRGB(0, 0, 0),
                Text = Title,
                BackgroundTransparency = 1,
                Position = UDim2FromOffset(46, 24),
                Size = UDim2.new(1, -90, 0, 18),
                BorderSizePixel = 0,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextSize = 14,
                ZIndex = 21
            }):AddToTheme({TextColor3 = 'Text'})

            Items["Description"] = Instances:Create("TextLabel", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = Library.Theme["TextMuted"],
                TextTransparency = 0,
                BorderColor3 = FromRGB(0, 0, 0),
                Text = Description,
                BackgroundTransparency = 1,
                Position = UDim2FromOffset(46, 44),
                Size = UDim2.new(1, -58, 0, 16),
                BorderSizePixel = 0,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextSize = 12,
                ZIndex = 21
            }):AddToTheme({TextColor3 = 'TextMuted'})

            Items["ProgressTrack"] = Instances:Create("Frame", {
                Parent = Items["Surface"].Instance,
                Name = "\0",
                BackgroundColor3 = Library.Theme["Element"],
                BackgroundTransparency = 0.35,
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2FromOffset(46, 0),
                Size = UDim2FromOffset(NotificationWidth - 58, 2),
                ZIndex = 21
            }):AddToTheme({BackgroundColor3 = 'Element'})

            Instances:Create("UICorner", {
                Parent = Items["ProgressTrack"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(1, 0)
            })

            Items["Progress"] = Instances:Create("Frame", {
                Parent = Items["ProgressTrack"].Instance,
                Name = "\0",
                BackgroundColor3 = Library.Theme["Accent"],
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 22
            }):AddToTheme({BackgroundColor3 = 'Accent'})

            Instances:Create("UICorner", {
                Parent = Items["Progress"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(1, 0)
            })
        end

        local function UpdateNotificationLayout()
            local TitleWidth = NotificationWidth - 90
            local DescriptionWidth = NotificationWidth - 58
            local TitleHeight = math.max(MeasureNotificationTextHeight(Title, 14, Library.TitleFontEnum or Enum.Font.GothamBold, TitleWidth), 18)
            local DescriptionHeight = math.max(MeasureNotificationTextHeight(Description, 12, Enum.Font.Gotham, DescriptionWidth), 14)
            local ContentHeight = 12 + 12 + 4 + TitleHeight + 4 + DescriptionHeight + 12 + 2 + 10
            local CardHeight = math.max(NotificationMinHeight, ContentHeight)

            Items["Title"].Instance.Position = UDim2FromOffset(46, 24)
            Items["Title"].Instance.Size = UDim2.new(1, -90, 0, TitleHeight)
            Items["Description"].Instance.Position = UDim2FromOffset(46, 24 + TitleHeight + 4)
            Items["Description"].Instance.Size = UDim2.new(1, -58, 0, DescriptionHeight)
            Items["ProgressTrack"].Instance.Position = UDim2FromOffset(46, CardHeight - 12)
            Items["ProgressTrack"].Instance.Size = UDim2FromOffset(NotificationWidth - 58, 2)
            Items["Card"].Instance.Size = UDim2FromOffset(NotificationWidth, CardHeight)

            RestackNotifications()
        end

        Notification.Items = Items
        Notification.Card = Items["Card"]

        local function UpdateCountdownText()
            if not Items["TimerText"] or not Items["TimerText"].Instance or not Items["TimerText"].Instance.Parent then
                return
            end

            local Remaining = math.max(0, CountdownEndsAt - os.clock())
            local DisplayValue = math.max(0, math.ceil(Remaining))

            if DisplayValue ~= LastCountdownValue then
                LastCountdownValue = DisplayValue
                Items["TimerText"].Instance.Text = tostring(DisplayValue) .. "s"
            end
        end

        UpdateCountdownText()
        UpdateNotificationLayout()
        TableInsert(NotificationCards, Notification)
        RestackNotifications()

        Library.Thread(function()
            local SlideTween = TweenService:Create(Items["Card"].Instance, TweenInfoNew(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(1, -NotificationEdgeX, 1, GetNotificationOffset(#NotificationCards))
            })

            SlideTween:Play()
        end)

        ProgressTween = TweenService:Create(Items["Progress"].Instance, TweenInfoNew(Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 0, 1, 0)
        })
        ProgressTween:Play()

        Library.Thread(function()
            while not Closing do
                UpdateCountdownText()

                if CountdownEndsAt - os.clock() <= 0 then
                    break
                end

                task.wait(0.1)
            end

            if not Closing then
                UpdateCountdownText()
            end
        end)

        function Notification:Close()
            if Closing then
                return
            end

            Closing = true

            local RemoveIndex = TableFind(NotificationCards, Notification)

            if RemoveIndex then
                TableRemove(NotificationCards, RemoveIndex)
            end

            if ProgressTween then
                ProgressTween:Cancel()
            end

            local SlideTween = TweenService:Create(Items["Card"].Instance, TweenInfoNew(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, NotificationWidth + 16, 1, Items["Card"].Instance.Position.Y.Offset)
            })

            SlideTween:Play()
            -- Tracked + one-shot: avoids firing after Library:Unload touches Items["Card"]
            local slideConn
            slideConn = Library:Connect(SlideTween.Completed, function()
                if slideConn and slideConn.Connection then
                    slideConn.Connection:Disconnect()
                end
                if Items["Card"] then
                    Items["Card"]:Clean()
                end
            end)

            RestackNotifications()
        end

        Items["Card"]:Connect("MouseButton1Down", function()
            Notification:Close()
        end)

        task.defer(function()
            local Remaining = math.max(0, CountdownEndsAt - os.clock())

            if Remaining > 0 then
                task.wait(Remaining)
            end

            if not Closing then
                Notification:Close()
            end
        end)

        return Notification
    end

    Library.Notify = function(self, Description, Duration)
        return self:Notification("VY HUB", Description, Duration)
    end

    Library.IsMouseOverFrame = function(self, Frame)
        Frame = Frame.Instance

        local MousePosition = Vector2New(Mouse.X, Mouse.Y)

        return MousePosition.X >= Frame.AbsolutePosition.X and MousePosition.X <= Frame.AbsolutePosition.X + Frame.AbsoluteSize.X 
        and MousePosition.Y >= Frame.AbsolutePosition.Y and MousePosition.Y <= Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y
    end

    Library.Lerp = function(self, Start, Finish, Time)
        return Start + (Finish - Start) * Time
    end

    Library.CompareVectors = function(self, PointA, PointB)
        return (PointA.X < PointB.X) or (PointA.Y < PointB.Y)
    end

    Library.IsClipped = function(self, Object, Column)
        local Parent = Column
        
        local BoundryTop = Parent.AbsolutePosition
        local BoundryBottom = BoundryTop + Parent.AbsoluteSize

        local Top = Object.AbsolutePosition
        local Bottom = Top + Object.AbsoluteSize 

        return Library:CompareVectors(Top, BoundryTop) or Library:CompareVectors(BoundryBottom, Bottom)
    end

    Library.RegisterKeybind = function(self, Keybind)
        if type(Keybind) ~= "table" or not Keybind.Flag then
            return
        end

        self.KeybindRegistry[Keybind.Flag] = Keybind
        self:RefreshKeybindLists()
    end

    Library.UnregisterKeybind = function(self, Keybind)
        local Flag = type(Keybind) == "table" and Keybind.Flag or Keybind

        if not Flag then
            return
        end

        self.KeybindRegistry[Flag] = nil
        self:RefreshKeybindLists()
    end

    Library.GetKeybindListEntries = function(self)
        local Entries = { }

        for _, Keybind in next, self.KeybindRegistry do
            if self:ShouldIgnoreFlag(Keybind.Flag) then
                continue
            end

            local DisplayKey = Keybind.Value

            if type(DisplayKey) == "string" and DisplayKey ~= "" and DisplayKey ~= "None" then
                TableInsert(Entries, {
                    Name = tostring(Keybind.Name or Keybind.Flag or "Keybind"),
                    Key = DisplayKey,
                    Mode = tostring(Keybind.Mode or "Toggle"),
                    Toggled = Keybind.Toggled == true
                })
            end
        end

        table.sort(Entries, function(Left, Right)
            local LeftName = StringLower(Left.Name)
            local RightName = StringLower(Right.Name)

            if LeftName == RightName then
                return StringLower(Left.Key) < StringLower(Right.Key)
            end

            return LeftName < RightName
        end)

        return Entries
    end

    Library.RefreshKeybindLists = function(self)
        local Entries = self:GetKeybindListEntries()

        for _, KeybindList in next, self.KeybindLists do
            if type(KeybindList) == "table" and KeybindList.Refresh then
                KeybindList:Refresh(Entries)
            end
        end
    end
-- ============================================================
-- [ modulo: Colorpicker.lua ]
-- ============================================================


    Library.CreateColorpicker = function(self, Data)
        -- Alpha here is TRANSPARENCY, not opacity: 0 = solid, 1 = invisible.
        -- Every picker ships the bar: palette + hue + alpha is the default shape.
        -- Passing a number only changes the starting value; `Alpha = false` is the
        -- opt-out, for when transparency means nothing wherever the colour lands.
        local AlphaEnabled = Data.Alpha ~= false

        local Colorpicker = {
            Flag = Data.Flag,

            Hue = 0,
            Saturation = 0,
            Value = 0,
            Alpha = AlphaEnabled and MathClamp(tonumber(Data.Alpha) or 0, 0, 1) or 0,
            HasAlpha = AlphaEnabled,

            Color = Color3.fromRGB(0, 0, 0),
            Hex = "#000000",

            IsOpen = false 
        }

        local Items = { } do 
            Items["ColorpickerButton"] = Instances:Create("TextButton", {
                Parent = Data.Parent.Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = FromRGB(0, 0, 0),
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "",
                AutoButtonColor = false,
                Size = UDim2.new(0, 20, 0, 16),
                BorderSizePixel = 0,
                TextSize = 14,
                BackgroundColor3 = FromRGB(255, 255, 255)
            })
            
            Instances:Create("UICorner", {
                Parent = Items["ColorpickerButton"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 6)
            })
            
            Instances:Create("UIStroke", {
                Parent = Items["ColorpickerButton"].Instance,
                Name = "\0",
                Color = Library.Theme["Outline"],
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            }):AddToTheme({Color = 'Outline'})
            
            Items["Glow"] = Instances:Create("ImageLabel", {
                Parent = Items["ColorpickerButton"].Instance,
                Name = "\0",
                ImageColor3 = FromRGB(255, 255, 255),
                ScaleType = Enum.ScaleType.Slice,
                ImageTransparency = 0.800000011920929,
                BorderColor3 = FromRGB(0, 0, 0),
                Size = UDim2.new(1, 25, 1, 25),
                AnchorPoint = Vector2New(0.5, 0.5),
                Image = "http://www.roblox.com/asset/?id=18245826428",
                BackgroundTransparency = 1,
                Position = UDim2.new(0.5, 0, 0.5, 0),
                ZIndex = 2,
                BorderSizePixel = 0,
                SliceCenter = RectNew(Vector2New(21, 21), Vector2New(79, 79))
            })            

            Items["ColorpickerWindow"] = Instances:Create("TextButton", {
                Parent = Library.UnusedHolder.Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = FromRGB(0, 0, 0),
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "",
                AutoButtonColor = false,
                Position = UDim2.new(0, 94, 0, 60),
                Size = UDim2.new(0, AlphaEnabled and 182 or 160, 0, AlphaEnabled and 182 or 160),
                BorderSizePixel = 0,
                TextSize = 14,
                BackgroundColor3 = Library.Theme["Background"]
            }):AddToTheme({BackgroundColor3 = 'Background'})
            
            Instances:Create("UICorner", {
                Parent = Items["ColorpickerWindow"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 6)
            })
            
            Items["Palette"] = Instances:Create("TextButton", {
                Parent = Items["ColorpickerWindow"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = FromRGB(0, 0, 0),
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "",
                AutoButtonColor = false,
                Position = UDim2.new(0, 8, 0, 8),
                Size = UDim2.new(1, AlphaEnabled and -62 or -40, 1, AlphaEnabled and -38 or -16),
                BorderSizePixel = 0,
                TextSize = 14,
                BackgroundColor3 = FromRGB(255, 255, 255)
            })
            
            Instances:Create("UICorner", {
                Parent = Items["Palette"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 5)
            })
            
            Items["Saturation"] = Instances:Create("Frame", {
                Parent = Items["Palette"].Instance,
                Name = "\0",
                BorderColor3 = FromRGB(0, 0, 0),
                Size = UDim2.new(1, 1, 1, 0),
                BorderSizePixel = 0
            })
            
            Instances:Create("UIGradient", {
                Parent = Items["Saturation"].Instance,
                Name = "\0",
                Transparency = NumSequence{NumSequenceKeypoint(0, 1), NumSequenceKeypoint(1, 0)}
            })
            
            Instances:Create("UICorner", {
                Parent = Items["Saturation"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 5)
            })
            
            Items["Value"] = Instances:Create("Frame", {
                Parent = Items["Palette"].Instance,
                Name = "\0",
                BorderColor3 = FromRGB(0, 0, 0),
                Size = UDim2.new(1, 1, 1, 1),
                BorderSizePixel = 0,
                BackgroundColor3 = FromRGB(0, 0, 0)
            })
            
            Instances:Create("UIGradient", {
                Parent = Items["Value"].Instance,
                Name = "\0",
                Rotation = 90,
                Transparency = NumSequence{NumSequenceKeypoint(0, 1), NumSequenceKeypoint(1, 0)}
            })
            
            Instances:Create("UICorner", {
                Parent = Items["Value"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 5)
            })
            
            Items["PaletteDragger"] = Instances:Create("Frame", {
                Parent = Items["Palette"].Instance,
                Name = "\0",
                BorderColor3 = FromRGB(0, 0, 0),
                Size = UDim2.new(0, 5, 0, 5),
                BorderSizePixel = 0
            })
            
            Instances:Create("UIStroke", {
                Parent = Items["PaletteDragger"].Instance,
                Name = "\0"
            })
            
            Instances:Create("UICorner", {
                Parent = Items["PaletteDragger"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(1, 0)
            })
            
            Items["Hue"] = Instances:Create("TextButton", {
                Parent = Items["ColorpickerWindow"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = FromRGB(0, 0, 0),
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "",
                AutoButtonColor = false,
                AnchorPoint = Vector2New(1, 0),
                Position = UDim2.new(1, AlphaEnabled and -30 or -8, 0, 8),
                Size = UDim2.new(0, 15, 1, AlphaEnabled and -38 or -16),
                BorderSizePixel = 0,
                TextSize = 14
            })
            
            Instances:Create("UIGradient", {
                Parent = Items["Hue"].Instance,
                Name = "\0",
                Rotation = 90,
                Color = RGBSequence{RGBSequenceKeypoint(0, FromRGB(255, 0, 0)), RGBSequenceKeypoint(0.17, FromRGB(255, 255, 0)), RGBSequenceKeypoint(0.33, FromRGB(0, 255, 0)), RGBSequenceKeypoint(0.5, FromRGB(0, 255, 255)), RGBSequenceKeypoint(0.67, FromRGB(0, 0, 255)), RGBSequenceKeypoint(0.83, FromRGB(255, 0, 255)), RGBSequenceKeypoint(1, FromRGB(255, 0, 0))}
            })
            
            Instances:Create("UICorner", {
                Parent = Items["Hue"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 6)
            })
            
            Items["HueDragger"] = Instances:Create("Frame", {
                Parent = Items["Hue"].Instance,
                Name = "\0",
                BackgroundTransparency = 1,
                BorderColor3 = FromRGB(0, 0, 0),
                Size = UDim2.new(0, 15, 0, 15),
                BorderSizePixel = 0
            })
            
            Instances:Create("UICorner", {
                Parent = Items["HueDragger"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(1, 0)
            })
            
            Instances:Create("UIStroke", {
                Parent = Items["HueDragger"].Instance,
                Name = "\0"
            })

            if AlphaEnabled then
                -- The bar is only the hit area; the two layers below draw it.
                -- Kept transparent so it does not paint over them.
                Items["Alpha"] = Instances:Create("TextButton", {
                    Parent = Items["ColorpickerWindow"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = FromRGB(0, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    AnchorPoint = Vector2New(1, 0),
                    Position = UDim2.new(1, -8, 0, 8),
                    Size = UDim2.new(0, 15, 1, AlphaEnabled and -38 or -16),
                    BorderSizePixel = 0,
                    TextSize = 14,
                    BackgroundTransparency = 1,
                    BackgroundColor3 = FromRGB(255, 255, 255)
                })

                -- Layer 1, the backdrop. Without it the transparent half of the bar
                -- falls straight onto the menu background and disappears, which is
                -- exactly why the bar went unnoticed at first. The light/dark gradient
                -- keeps contrast against any chosen colour, light or dark.
                Items["AlphaBackdrop"] = Instances:Create("Frame", {
                    Parent = Items["Alpha"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = FromRGB(215, 215, 215)
                })

                Instances:Create("UIGradient", {
                    Parent = Items["AlphaBackdrop"].Instance,
                    Name = "\0",
                    Rotation = 45,
                    Color = RGBSequence{RGBSequenceKeypoint(0, FromRGB(235, 235, 235)), RGBSequenceKeypoint(0.5, FromRGB(120, 120, 120)), RGBSequenceKeypoint(1, FromRGB(235, 235, 235))}
                })

                Instances:Create("UICorner", {
                    Parent = Items["AlphaBackdrop"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })

                -- Layer 2, the chosen colour going from solid (top) to transparent
                -- (bottom). The transparency comes from the gradient and not from
                -- BackgroundTransparency: the open/close fade sweeps every descendant
                -- touching that property and would wipe the effect out.
                Items["AlphaFill"] = Instances:Create("Frame", {
                    Parent = Items["Alpha"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = FromRGB(255, 255, 255)
                })

                Instances:Create("UIGradient", {
                    Parent = Items["AlphaFill"].Instance,
                    Name = "\0",
                    Rotation = 90,
                    Transparency = NumSequence{NumSequenceKeypoint(0, 0), NumSequenceKeypoint(1, 1)}
                })

                Instances:Create("UICorner", {
                    Parent = Items["AlphaFill"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["Alpha"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})

                Items["AlphaDragger"] = Instances:Create("Frame", {
                    Parent = Items["Alpha"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0, 15, 0, 15),
                    BorderSizePixel = 0
                })

                Instances:Create("UICorner", {
                    Parent = Items["AlphaDragger"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(1, 0)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["AlphaDragger"].Instance,
                    Name = "\0"
                })

                -- Without a number on screen a value cannot be reproduced: for ESP
                -- someone wants 0.35 again in the next game, not "roughly there".
                Items["AlphaReadout"] = Instances:Create("TextLabel", {
                    Parent = Items["ColorpickerWindow"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    Text = "#000000  -  alpha 0.00",
                    TextSize = 12,
                    TextColor3 = Library.Theme["Text"],
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 8, 1, -26),
                    Size = UDim2.new(1, -16, 0, 18)
                }):AddToTheme({TextColor3 = 'Text'})
            end
        end

        function Colorpicker:Get()
            return Colorpicker.Color, Colorpicker.Alpha
        end

        function Colorpicker:Update()
            local Hue, Saturation, Value = Colorpicker.Hue, Colorpicker.Saturation, Colorpicker.Value
            Colorpicker.Color = FromHSV(Hue, Saturation, Value)
            Colorpicker.HexValue = Colorpicker.Color:ToHex()

            Library.Flags[Colorpicker.Flag] = {
                Color = Colorpicker.Color,
                HexValue = Colorpicker.HexValue,
                Alpha = Colorpicker.Alpha
            }

            Items["ColorpickerButton"]:Tween(nil, {BackgroundColor3 = Colorpicker.Color, BackgroundTransparency = Colorpicker.Alpha})
            Items["Glow"]:Tween(nil, {ImageColor3 = Colorpicker.Color, ImageTransparency = 0.8 + (0.2 * Colorpicker.Alpha)})
            Items["Palette"]:Tween(nil, {BackgroundColor3 = FromHSV(Hue, 1, 1)})

            if Items["AlphaFill"] then
                Items["AlphaFill"]:Tween(nil, {BackgroundColor3 = Colorpicker.Color})
            end

            -- Shows the raw alpha, the same number that reaches the callback and
            -- the config. A percentage would force a conversion in the reader's head.
            if Items["AlphaReadout"] then
                Items["AlphaReadout"].Instance.Text = string.format(
                    "#%s  -  alpha %.2f", Colorpicker.HexValue, Colorpicker.Alpha
                )
            end

            if Data.Callback then
                Library:SafeCall(Data.Callback, Colorpicker.Color, Colorpicker.Alpha)
            end
        end

        local SlidingPalette = false
        local PaletteChanged
        
        function Colorpicker:SlidePalette(Input)
            if not Input or not SlidingPalette then
                return
            end

            local ValueX = MathClamp(1 - (Input.Position.X - Items["Palette"].Instance.AbsolutePosition.X) / Items["Palette"].Instance.AbsoluteSize.X, 0, 1)
            local ValueY = MathClamp(1 - (Input.Position.Y - Items["Palette"].Instance.AbsolutePosition.Y) / Items["Palette"].Instance.AbsoluteSize.Y, 0, 1)

            Colorpicker.Saturation = ValueX
            Colorpicker.Value = ValueY

            local SlideX = MathClamp((Input.Position.X - Items["Palette"].Instance.AbsolutePosition.X) / Items["Palette"].Instance.AbsoluteSize.X, 0, 0.955)
            local SlideY = MathClamp((Input.Position.Y - Items["Palette"].Instance.AbsolutePosition.Y) / Items["Palette"].Instance.AbsoluteSize.Y, 0, 0.955)

            Items["PaletteDragger"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(SlideX, 0, SlideY, 0)})
            Colorpicker:Update()
        end
        
        local SlidingHue = false
        local HueChanged

        function Colorpicker:SlideHue(Input)
            if not Input or not SlidingHue then
                return
            end
            
            local ValueY = MathClamp((Input.Position.Y - Items["Hue"].Instance.AbsolutePosition.Y) / Items["Hue"].Instance.AbsoluteSize.Y, 0, 1)

            Colorpicker.Hue = ValueY

            local SlideY = MathClamp((Input.Position.Y - Items["Hue"].Instance.AbsolutePosition.Y) / Items["Hue"].Instance.AbsoluteSize.Y, 0, 0.91)

            Items["HueDragger"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, SlideY, 0)})
            Colorpicker:Update()
        end

        local SlidingAlpha = false
        local AlphaChanged

        function Colorpicker:SlideAlpha(Input)
            if not Input or not SlidingAlpha or not Items["Alpha"] then
                return
            end

            local ValueY = MathClamp((Input.Position.Y - Items["Alpha"].Instance.AbsolutePosition.Y) / Items["Alpha"].Instance.AbsoluteSize.Y, 0, 1)

            Colorpicker.Alpha = ValueY

            local SlideY = MathClamp(ValueY, 0, 0.91)

            Items["AlphaDragger"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, SlideY, 0)})
            Colorpicker:Update()
        end

        local Debounce = false
        local RenderStepped  

        function Colorpicker:SetOpen(Bool)
            if Debounce then 
                return
            end

            Colorpicker.IsOpen = Bool

            Debounce = true 

            if Colorpicker.IsOpen then 
                Items["ColorpickerWindow"].Instance.Visible = true
                Items["ColorpickerWindow"].Instance.Parent = Library.Holder.Instance
                
                RenderStepped = RunService.RenderStepped:Connect(function()
                    Items["ColorpickerWindow"].Instance.Position = UDim2.new(
                        0, 
                        Items["ColorpickerButton"].Instance.AbsolutePosition.X, 
                        0, 
                        Items["ColorpickerButton"].Instance.AbsolutePosition.Y + Items["ColorpickerButton"].Instance.AbsoluteSize.Y + 5
                    )
                end)

                for Index, Value in Library.OpenFrames do 
                        if Value ~= Colorpicker then
                            Value:SetOpen(false)
                        end
                    end

                Library.OpenFrames[Colorpicker] = Colorpicker 
            else
                if Library.OpenFrames[Colorpicker] then 
                    Library.OpenFrames[Colorpicker] = nil
                end

                if RenderStepped then 
                    RenderStepped:Disconnect()
                    RenderStepped = nil
                end
            end

            local Descendants = Items["ColorpickerWindow"].Instance:GetDescendants()
            TableInsert(Descendants, Items["ColorpickerWindow"].Instance)

            local NewTween

            for Index, Value in Descendants do 
                local TransparencyProperty = Tween:GetProperty(Value)

                if not TransparencyProperty then
                    continue 
                end

                if not Value.ClassName:find("UI") then 
                    Value.ZIndex = (Colorpicker.IsOpen and Data.Section.IsSettings and 9) or (Colorpicker.IsOpen and not Data.Section.IsSettings and 3) or 1
                end

                if type(TransparencyProperty) == "table" then 
                    for _, Property in TransparencyProperty do 
                        NewTween = Tween:FadeItem(Value, Property, Bool, Library.FadeSpeed)
                    end
                else
                    NewTween = Tween:FadeItem(Value, TransparencyProperty, Bool, Library.FadeSpeed)
                end
            end
            
            -- Tracked + one-shot: avoids touching Items["ColorpickerWindow"] after Unload
            local fadeConn
            fadeConn = Library:Connect(NewTween.Tween.Completed, function()
                if fadeConn and fadeConn.Connection then
                    fadeConn.Connection:Disconnect()
                end
                Debounce = false
                if not Items["ColorpickerWindow"] then
                    return
                end
                Items["ColorpickerWindow"].Instance.Visible = Colorpicker.IsOpen
                task.wait(0.2)
                if Items["ColorpickerWindow"] and Library.UnusedHolder and Library.Holder then
                    Items["ColorpickerWindow"].Instance.Parent = not Colorpicker.IsOpen and Library.UnusedHolder.Instance or Library.Holder.Instance
                end
            end)
        end

        function Colorpicker:Set(Color, Alpha)
            if type(Color) == "table" then
                Color = FromRGB(Color[1], Color[2], Color[3])
            elseif type(Color) == "string" then
                Color = FromHex(Color)
            end

            if type(Alpha) == "number" then
                Colorpicker.Alpha = MathClamp(Alpha, 0, 1)
            end

            Colorpicker.Hue, Colorpicker.Saturation, Colorpicker.Value = Color:ToHSV()

            local PaletteValueX = MathClamp(1 - Colorpicker.Saturation, 0, 0.955)
            local PaletteValueY = MathClamp(1 - Colorpicker.Value, 0, 0.955)
                
            local HuePositionY = MathClamp(Colorpicker.Hue, 0, 0.955)

            Items["PaletteDragger"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(PaletteValueX, 0, PaletteValueY, 0)})
            Items["HueDragger"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, HuePositionY, 0)})

            if Items["AlphaDragger"] then
                Items["AlphaDragger"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, MathClamp(Colorpicker.Alpha, 0, 0.955), 0)})
            end

            Colorpicker:Update()
        end

        Items["ColorpickerButton"]:Connect("MouseButton1Down", function()
            Colorpicker:SetOpen(not Colorpicker.IsOpen)
        end)

        Items["Palette"]:Connect("InputBegan", function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                SlidingPalette = true 

                Colorpicker:SlidePalette(Input)

                if PaletteChanged then
                    return
                end

                PaletteChanged = Input.Changed:Connect(function()
                    if Input.UserInputState == Enum.UserInputState.End then
                        SlidingPalette = false

                        PaletteChanged:Disconnect()
                        PaletteChanged = nil
                    end
                end)
            end
        end)

        Items["Hue"]:Connect("InputBegan", function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                SlidingHue = true 

                Colorpicker:SlideHue(Input)

                if HueChanged then
                    return
                end

                HueChanged = Input.Changed:Connect(function()
                    if Input.UserInputState == Enum.UserInputState.End then
                        SlidingHue = false

                        HueChanged:Disconnect()
                        HueChanged = nil
                    end
                end)
            end
        end)

        if Items["Alpha"] then
            Items["Alpha"]:Connect("InputBegan", function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    SlidingAlpha = true

                    Colorpicker:SlideAlpha(Input)

                    if AlphaChanged then
                        return
                    end

                    AlphaChanged = Input.Changed:Connect(function()
                        if Input.UserInputState == Enum.UserInputState.End then
                            SlidingAlpha = false

                            AlphaChanged:Disconnect()
                            AlphaChanged = nil
                        end
                    end)
                end
            end)
        end

        Library:Connect(UserInputService.InputChanged, function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                if SlidingPalette then 
                    Colorpicker:SlidePalette(Input)
                end

                if SlidingHue then
                    Colorpicker:SlideHue(Input)
                end

                if SlidingAlpha then
                    Colorpicker:SlideAlpha(Input)
                end
            end
        end)

        Library:Connect(UserInputService.InputBegan, function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                if not Colorpicker.IsOpen then
                    return
                end

                if Library:IsMouseOverFrame(Items["ColorpickerWindow"]) then
                    return
                end

                Colorpicker:SetOpen(false)
            end
        end)

        if Data.Default then
            Colorpicker:Set(Data.Default)
        elseif AlphaEnabled and Colorpicker.Alpha > 0 then
            -- No default colour but a starting alpha: needs a Set to place the
            -- dragger correctly and publish the alpha into the flag.
            Colorpicker:Set(Colorpicker.Color)
        end

        -- Config calls this as SetFunction(Value.Color, Value.Alpha).
        Library.SetFlags[Colorpicker.Flag] = function(Value, Alpha)
            Colorpicker:Set(Value, Alpha)
        end

        return Colorpicker, Items 
    end
-- ============================================================
-- [ modulo: Keybind.lua ]
-- ============================================================


    Library.CreateKeybind = function(self, Data)
        local Keybind = {
            Flag = Data.Flag,
            Name = Data.Name or Data.name or Data.DisplayName or Data.displayname or Data.Flag or "Keybind",

            Value = "",
            Key = "",
            Mode = "",
            
            Toggled = false,
            Picking = false,
            IsOpen = false 
        }

        local Items = { } do 
            Items["KeyButton"] = Instances:Create("TextButton", {
                Parent = Data.Parent.Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = Library.Theme["Text"],
                TextTransparency = 0.5,
                Text = "[C]",
                AutoButtonColor = false,
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                BorderColor3 = FromRGB(0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                TextSize = 16
            }):AddToTheme({TextColor3 = 'Text'})      
            
            Items["KeybindWindow"] = Instances:Create("TextButton", {
                Parent = Library.UnusedHolder.Instance,
                Name = "\0",
                Visible = false,
                FontFace = Library.Font,
                TextColor3 = FromRGB(0, 0, 0),
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "",
                AutoButtonColor = false,
                Position = UDim2.new(0, 10, 0, 10),
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.XY,
                TextSize = 14,
                BackgroundColor3 = Library.Theme["Background"]
            }):AddToTheme({BackgroundColor3 = 'Background'})
            
            Instances:Create("UICorner", {
                Parent = Items["KeybindWindow"].Instance,
                Name = "\0",
                CornerRadius = UDimNew(0, 6)
            })
            
            Items["Toggle"] = Instances:Create("TextButton", {
                Parent = Items["KeybindWindow"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = Library.Theme["Text"],
                BorderColor3 = FromRGB(0, 0, 0),
                Text = "Toggle",
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 0, 15),
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.X,
                TextSize = 14
            }):AddToTheme({TextColor3 = 'Text'})
            
            Instances:Create("UIListLayout", {
                Parent = Items["KeybindWindow"].Instance,
                Name = "\0",
                Padding = UDimNew(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder
            })
            
            Instances:Create("UIPadding", {
                Parent = Items["KeybindWindow"].Instance,
                Name = "\0",
                PaddingTop = UDimNew(0, 10),
                PaddingBottom = UDimNew(0, 10),
                PaddingRight = UDimNew(0, 10),
                PaddingLeft = UDimNew(0, 10)
            })
            
            Items["Hold"] = Instances:Create("TextButton", {
                Parent = Items["KeybindWindow"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = Library.Theme["Text"],
                TextTransparency = 0.5,
                Text = "Hold",
                AutoButtonColor = false,
                Size = UDim2.new(0, 0, 0, 15),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                BorderColor3 = FromRGB(0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                TextSize = 14
            }):AddToTheme({TextColor3 = 'Text'})
            
            Items["Always"] = Instances:Create("TextButton", {
                Parent = Items["KeybindWindow"].Instance,
                Name = "\0",
                FontFace = Library.Font,
                TextColor3 = Library.Theme["Text"],
                TextTransparency = 0.5,
                Text = "Always",
                AutoButtonColor = false,
                Size = UDim2.new(0, 0, 0, 15),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                BorderColor3 = FromRGB(0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                TextSize = 14
            }):AddToTheme({TextColor3 = 'Text'})
        end

        local Modes = {
            Toggle = Items["Toggle"],
            Hold = Items["Hold"],
            Always = Items["Always"]
        }

        local Debounce = false
        local RenderStepped  

        function Keybind:SetOpen(Bool)
            if Debounce then 
                return
            end

            Keybind.IsOpen = Bool

            Debounce = true 

            if Keybind.IsOpen then 
                Items["KeybindWindow"].Instance.Visible = true
                Items["KeybindWindow"].Instance.Parent = Library.Holder.Instance
                
                RenderStepped = RunService.RenderStepped:Connect(function()
                    Items["KeybindWindow"].Instance.Position = UDim2.new(
                        0, 
                        Items["KeyButton"].Instance.AbsolutePosition.X, 
                        0, 
                        Items["KeyButton"].Instance.AbsolutePosition.Y + Items["KeyButton"].Instance.AbsoluteSize.Y + 5
                    )
                end)

                for Index, Value in Library.OpenFrames do 
                    if Value ~= Keybind then
                        Value:SetOpen(false)
                    end
                end

                Library.OpenFrames[Keybind] = Keybind 
            else
                if Library.OpenFrames[Keybind] then 
                    Library.OpenFrames[Keybind] = nil
                end

                if RenderStepped then 
                    RenderStepped:Disconnect()
                    RenderStepped = nil
                end
            end

            local Descendants = Items["KeybindWindow"].Instance:GetDescendants()
            TableInsert(Descendants, Items["KeybindWindow"].Instance)

            local NewTween

            for Index, Value in Descendants do 
                local TransparencyProperty = Tween:GetProperty(Value)

                if not TransparencyProperty then
                    continue 
                end

                if not Value.ClassName:find("UI") then 
                    Value.ZIndex = Keybind.IsOpen and 4 or 1
                end

                if type(TransparencyProperty) == "table" then 
                    for _, Property in TransparencyProperty do 
                        NewTween = Tween:FadeItem(Value, Property, Bool, Library.FadeSpeed)
                    end
                else
                    NewTween = Tween:FadeItem(Value, TransparencyProperty, Bool, Library.FadeSpeed)
                end
            end
            
            NewTween.Tween.Completed:Connect(function()
                Debounce = false
                if Items["KeybindWindow"] and Items["KeybindWindow"].Instance then
                    Items["KeybindWindow"].Instance.Visible = Keybind.IsOpen
                end
                task.wait(0.2)
                if Items["KeybindWindow"] and Items["KeybindWindow"].Instance and Library.UnusedHolder and Library.Holder then
                    pcall(function()
                        Items["KeybindWindow"].Instance.Parent = not Keybind.IsOpen and Library.UnusedHolder.Instance or Library.Holder.Instance
                    end)
                end
            end)
        end

        function Keybind:SetMode(Mode)
            if not Modes[Mode] then
                return
            end

            Keybind.Mode = Mode

            for Index, Value in Modes do 
                if Index == Mode then
                    Value:Tween(nil, {TextTransparency = 0})
                else
                    Value:Tween(nil, {TextTransparency = 0.5})
                end
            end

            Library.Flags[Keybind.Flag] = {
                Mode = Keybind.Mode,
                Key = Keybind.Key,
                Toggled = Keybind.Toggled
            }

            if Data.Callback then 
                Library:SafeCall(Data.Callback, Keybind.Toggled)
            end

            Library:RefreshKeybindLists()
        end

        function Keybind:Press(Bool)
            if Keybind.Mode == "Toggle" then 
                Keybind.Toggled = not Keybind.Toggled
            elseif Keybind.Mode == "Hold" then 
                Keybind.Toggled = Bool
            elseif Keybind.Mode == "Always" then 
                Keybind.Toggled = true
            end

            Library.Flags[Keybind.Flag] = {
                Mode = Keybind.Mode,
                Key = Keybind.Key,
                Toggled = Keybind.Toggled
            }

            if Data.Callback then 
                Library:SafeCall(Data.Callback, Keybind.Toggled)
            end

            Library:RefreshKeybindLists()
        end

        function Keybind:Get()
            return Keybind.Key, Keybind.Mode, Keybind.Toggled
        end

        function Keybind:Set(Key)
            if StringFind(tostring(Key), "Enum") then 
                Keybind.Key = tostring(Key)

                Key = Key.Name == "Backspace" and "None" or Key.Name

                local KeyString = Keys[Keybind.Key] or StringGSub(Key, "Enum.", "") or "None"
                local TextToDisplay = StringGSub(StringGSub(KeyString, "KeyCode.", ""), "UserInputType.", "") or "None"

                Keybind.Value = TextToDisplay
                Items["KeyButton"].Instance.Text = "["..TextToDisplay.."]"

                Library.Flags[Keybind.Flag] = {
                    Mode = Keybind.Mode,
                    Key = Keybind.Key,
                    Toggled = Keybind.Toggled
                }

                if Data.Callback then 
                    Library:SafeCall(Data.Callback, Keybind.Toggled)
                end
            elseif type(Key) == "table" then
                local RealKey = Key.Key == "Backspace" and "None" or Key.Key
                Keybind.Key = tostring(Key.Key)

                if Key.Mode then
                    Keybind.Mode = Key.Mode
                    Keybind:SetMode(Key.Mode)
                else
                    Keybind.Mode = "Toggle"
                    Keybind:SetMode("Toggle")
                end

                local KeyString = Keys[Keybind.Key] or StringGSub(tostring(RealKey), "Enum.", "") or RealKey
                local TextToDisplay = KeyString and StringGSub(StringGSub(KeyString, "KeyCode.", ""), "UserInputType.", "") or "None"

                TextToDisplay = StringGSub(StringGSub(KeyString, "KeyCode.", ""), "UserInputType.", "")

                Keybind.Value = TextToDisplay
                Items["KeyButton"].Instance.Text = "["..TextToDisplay.."]"

                if Data.Callback then 
                    Library:SafeCall(Data.Callback, Keybind.Toggled)
                end
            elseif TableFind({"Toggle", "Hold", "Always"}, Key) then
                Keybind.Mode = Key
                Keybind:SetMode(Key)

                if Data.Callback then 
                    Library:SafeCall(Data.Callback, Keybind.Toggled)
                end
            end

            Library:RefreshKeybindLists()
            Keybind.Picking = false
        end

        function Keybind:StartPicking()
            if Keybind.Picking then return end
            Keybind.Picking = true

            Items["KeyButton"].Instance.Text = "..."

            -- Snapshot which mouse buttons / inputs are currently held, so the
            -- input that opened the picker (e.g. the right-click on a toggle)
            -- doesn't get captured as the bind. We only accept an input once
            -- it has BEGAN AFTER any currently-held inputs are released.
            local heldUITypes = {}
            for _, inp in ipairs(UserInputService:GetMouseButtonsPressed()) do
                heldUITypes[inp.UserInputType] = true
            end

            local InputBegan
            local startedAt = os.clock()

            InputBegan = UserInputService.InputBegan:Connect(function(Input)
                -- Ignore the very first frame's events (the trigger click).
                if os.clock() - startedAt < 0.05 then return end
                -- Ignore any input type that was held when picker opened
                -- until it's released and pressed fresh.
                if heldUITypes[Input.UserInputType] then return end

                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    Keybind:Set(Input.KeyCode)
                else
                    Keybind:Set(Input.UserInputType)
                end

                Keybind.Picking = false
                if InputBegan then
                    InputBegan:Disconnect()
                    InputBegan = nil
                end
            end)

            -- When the trigger button is released, allow re-pressing it as a bind.
            local InputEnded
            InputEnded = UserInputService.InputEnded:Connect(function(Input)
                if heldUITypes[Input.UserInputType] then
                    heldUITypes[Input.UserInputType] = nil
                end
                if InputEnded and not next(heldUITypes) then
                    InputEnded:Disconnect()
                    InputEnded = nil
                end
            end)
        end

        Items["KeyButton"]:Connect("MouseButton1Click", function()
            Keybind:StartPicking()
        end)

        Library:Connect(UserInputService.InputBegan, function(Input)
            if Keybind.Value == "None" then
                return
            end

            if tostring(Input.KeyCode) == Keybind.Key then
                if Keybind.Mode == "Toggle" then 
                    Keybind:Press()
                elseif Keybind.Mode == "Hold" then 
                    Keybind:Press(true)
                elseif Keybind.Mode == "Always" then 
                    Keybind:Press(true)
                end
            elseif tostring(Input.UserInputType) == Keybind.Key then
                if Keybind.Mode == "Toggle" then 
                    Keybind:Press()
                elseif Keybind.Mode == "Hold" then 
                    Keybind:Press(true)
                elseif Keybind.Mode == "Always" then 
                    Keybind:Press(true)
                end
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not Keybind.IsOpen then
                    return
                end

                if Library:IsMouseOverFrame(Items["KeybindWindow"]) then
                    return
                end

                Keybind:SetOpen(false)
            end
        end)

        Library:Connect(UserInputService.InputEnded, function(Input)
            if Keybind.Value == "None" then
                return
            end

            if tostring(Input.KeyCode) == Keybind.Key then
                if Keybind.Mode == "Hold" then 
                    Keybind:Press(false)
                elseif Keybind.Mode == "Always" then 
                    Keybind:Press(true)
                end
            elseif tostring(Input.UserInputType) == Keybind.Key then
                if Keybind.Mode == "Hold" then 
                    Keybind:Press(false)
                elseif Keybind.Mode == "Always" then 
                    Keybind:Press(true)
                end
            end
        end)

        Items["KeyButton"]:Connect("MouseButton2Down", function()
            Keybind:SetOpen(not Keybind.IsOpen)
        end)

        Items["Toggle"]:Connect("MouseButton1Down", function()
            Keybind.Mode = "Toggle"
            Keybind:SetMode("Toggle")
        end)

        Items["Hold"]:Connect("MouseButton1Down", function()
            Keybind.Mode = "Hold"
            Keybind:SetMode("Hold")
        end)

        Items["Always"]:Connect("MouseButton1Down", function()
            Keybind.Mode = "Always"
            Keybind:SetMode("Always")
        end)

        if Data.Default then 
            Keybind:Set({
                Mode = Data.Mode or "Toggle",
                Key = Data.Default,
            })
        end

        Library.SetFlags[Keybind.Flag] = function(Value)
            Keybind:Set(Value)
        end

        Library:RegisterKeybind(Keybind)
        
        return Keybind, Items 
    end
-- ============================================================
-- [ modulo: Watermark.lua ]
-- ============================================================


    do 
        Library.Watermark = function(self, Name, Logo)
            local Watermark = { }

            local Items = { } do 
                Items["Watermark"] = Instances:Create("Frame", {
                    Parent = Library.Holder.Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(0.5, 0),
                    Position = UDim2.new(0.5, 0, 0, 20),
                    Size = UDim2.new(0, 0, 0, 35),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Library.Theme["Background"]
                }):AddToTheme({BackgroundColor3 = 'Background'})

                Items["Watermark"]:MakeDraggable()
                
                Instances:Create("UICorner", {
                    Parent = Items["Watermark"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })
                
                Instances:Create("UIPadding", {
                    Parent = Items["Watermark"].Instance,
                    Name = "\0",
                    PaddingRight = UDimNew(0, 8),
                    PaddingLeft = UDimNew(0, 8)
                })
                
                Items["Logo"] = Instances:Create("ImageLabel", {
                    Parent = Items["Watermark"].Instance,
                    Name = "\0",
                    ScaleType = Enum.ScaleType.Fit,
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(0, 0.5),
                    Image = Logo,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.new(0, 25, 0, 25),
                    BorderSizePixel = 0
                })
                
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Watermark"].Instance,
                    Name = "\0",
                    FontFace = Library.TitleFont or Library.Font,
                    Font = Library.TitleFontEnum or Enum.Font.GothamBold,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "Perccss in my sodaa",
                    AnchorPoint = Vector2New(0, 0.5),
                    Size = UDim2.new(0, 0, 0, 15),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 34, 0.5, -1),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 18
                }):AddToTheme({TextColor3 = 'Text'})
            end

            function Watermark:SetText(Text)
                Items["Text"].Instance.Text = tostring(Text)
            end

            function Watermark:SetVisibility(Bool)
                Items["Watermark"].Instance.Visible = Bool 
            end

            function Watermark:SetCenter()
                local CenterPosition = Items["Watermark"].Instance.AbsolutePosition
                task.wait()
                Items["Watermark"].Instance.AnchorPoint = Vector2New(0, 0)

                Items["Watermark"].Instance.Position = UDim2.new(0, CenterPosition.X, 0, CenterPosition.Y)
            end

            Watermark:SetText(Name)
            Watermark:SetCenter()

            return Watermark 
        end
-- ============================================================
-- [ modulo: KeybindList.lua ]
-- ============================================================


        Library.KeybindList = function(self, Window, Data)
            Data = Data or { }

            local KeybindList = {
                Window = Window,
                Visible = Data.Visible ~= false,
                Entries = { }
            }

            local Items = { } do
                Items["Main"] = Instances:Create("Frame", {
                    Parent = Library.Holder.Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(1, 0),
                    Position = Data.Position or self.DefaultKeybindListPosition or UDim2.new(1, -18, 0, 120),
                    Size = UDim2FromOffset(Data.Width or 220, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Library.Theme["Panel"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Visible = false,
                    ZIndex = 18
                }):AddToTheme({BackgroundColor3 = 'Panel'})

                Items["Main"]:MakeDraggable()

                Instances:Create("UICorner", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 12)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    Color = Library.Theme["OutlineSoft"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'OutlineSoft'})

                Instances:Create("UIPadding", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    PaddingTop = UDimNew(0, 12),
                    PaddingBottom = UDimNew(0, 12),
                    PaddingLeft = UDimNew(0, 12),
                    PaddingRight = UDimNew(0, 12)
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, 8),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Items["Title"] = Instances:Create("TextLabel", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 16),
                    FontFace = Library.TitleFont or Library.Font,
                    Font = Library.TitleFontEnum or Enum.Font.GothamBold,
                    Text = string.upper(tostring(Data.Title or "Keybinds")),
                    TextColor3 = Library.Theme["TextMuted"],
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 19
                }):AddToTheme({TextColor3 = 'TextMuted'})

                Items["Divider"] = Instances:Create("Frame", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    BackgroundColor3 = Library.Theme["OutlineSoft"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 1),
                    ZIndex = 19
                }):AddToTheme({BackgroundColor3 = 'OutlineSoft'})

                Items["Content"] = Instances:Create("Frame", {
                    Parent = Items["Main"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 19
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["Content"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })
            end

            function KeybindList:SetVisibility(Bool)
                KeybindList.Visible = Bool and true or false
                KeybindList:Refresh(KeybindList.Entries)
            end

            function KeybindList:SetPosition(Position)
                if Position then
                    Items["Main"].Instance.Position = Position
                end
            end

            function KeybindList:Refresh(Entries)
                Entries = Entries or Library:GetKeybindListEntries()
                KeybindList.Entries = Entries

                for _, Child in next, Items["Content"].Instance:GetChildren() do
                    if not Child:IsA("UIListLayout") then
                        Child:Destroy()
                    end
                end

                for _, Entry in next, Entries do
                    local Row = Instances:Create("Frame", {
                        Parent = Items["Content"].Instance,
                        Name = "\0",
                        BackgroundColor3 = Entry.Toggled and Library.Theme["AccentSoft"] or Library.Theme["Surface"],
                        BackgroundTransparency = Entry.Toggled and 0 or 0.08,
                        BorderColor3 = FromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Size = UDim2.new(1, 0, 0, 28),
                        ZIndex = 19
                    }):AddToTheme({BackgroundColor3 = function()
                        return Entry.Toggled and Library.Theme["AccentSoft"] or Library.Theme["Surface"]
                    end})

                    Instances:Create("UICorner", {
                        Parent = Row.Instance,
                        Name = "\0",
                        CornerRadius = UDimNew(0, 8)
                    })

                    local AccentStrip = Instances:Create("Frame", {
                        Parent = Row.Instance,
                        Name = "\0",
                        BackgroundColor3 = Library.Theme["Accent"],
                        BackgroundTransparency = Entry.Toggled and 0 or 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Position = UDim2FromOffset(8, 6),
                        Size = UDim2FromOffset(3, 16),
                        ZIndex = 20
                    }):AddToTheme({BackgroundColor3 = 'Accent'})

                    Instances:Create("UICorner", {
                        Parent = AccentStrip.Instance,
                        Name = "\0",
                        CornerRadius = UDimNew(1, 0)
                    })

                    local NameLabel = Instances:Create("TextLabel", {
                        Parent = Row.Instance,
                        Name = "\0",
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Position = UDim2FromOffset(18, 0),
                        Size = UDim2.new(1, -104, 1, 0),
                        FontFace = Library.Font,
                        Text = Entry.Name,
                        TextColor3 = Entry.Toggled and Library.Theme["Text"] or Library.Theme["Text"],
                        TextTransparency = Entry.Toggled and 0 or 0.08,
                        TextSize = 14,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 20
                    }):AddToTheme({TextColor3 = function()
                        return Library.Theme["Text"]
                    end})

                    local KeyLabel = Instances:Create("TextLabel", {
                        Parent = Row.Instance,
                        Name = "\0",
                        AnchorPoint = Vector2New(1, 0.5),
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Position = UDim2.new(1, -10, 0.5, 0),
                        Size = UDim2FromOffset(82, 14),
                        FontFace = Library.Font,
                        Text = StringFormat("[%s] %s", Entry.Key, Entry.Mode),
                        TextColor3 = Entry.Toggled and Library.Theme["Text"] or Library.Theme["TextMuted"],
                        TextTransparency = Entry.Toggled and 0.2 or 0,
                        TextSize = 12,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        ZIndex = 20
                    }):AddToTheme({TextColor3 = function()
                        return Entry.Toggled and Library.Theme["Text"] or Library.Theme["TextMuted"]
                    end})
                end

                Items["Main"].Instance.Visible = KeybindList.Visible and #Entries > 0
            end

            TableInsert(self.KeybindLists, KeybindList)
            self:RefreshKeybindLists()

            return KeybindList
        end
-- ============================================================
-- [ modulo: ToggleButton.lua ]
-- ============================================================


        Library.ToggleButton = function(self, Window, Data)
            Data = Data or { }

            local ToggleButton = { }
            local Items = { } do
                Items["Button"] = Instances:Create("ImageButton", {
                    Parent = Library.Holder.Instance,
                    Name = "\0",
                    AutoButtonColor = false,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Inline"],
                    Position = Data.Position or self.DefaultToggleButtonPosition or UDim2.new(0.5, -25, 0, 105),
                    Size = Data.Size or UDim2FromOffset(50, 50),
                    Image = "",
                    ClipsDescendants = true,
                    BackgroundTransparency = 0,
                    ZIndex = 20
                }):AddToTheme({BackgroundColor3 = 'Inline'})

                Items["Button"]:MakeDraggable()

                Instances:Create("UICorner", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 12)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})

                Items["Inner"] = Instances:Create("ImageLabel", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Library.Theme["Background"],
                    BackgroundTransparency = 0,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Image = Data.Icon or self.DefaultToggleButtonIcon or "rbxassetid://10723407389",
                    ImageColor3 = FromRGB(250, 250, 250),
                    ZIndex = 21
                }):AddToTheme({BackgroundColor3 = 'Background'})

                Instances:Create("UICorner", {
                    Parent = Items["Inner"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 10)
                })
            end

            function ToggleButton:Press()
                Window:SetOpen(not Window.IsOpen)
            end

            function ToggleButton:SetVisibility(Bool)
                Items["Button"].Instance.Visible = Bool
            end

            function ToggleButton:SetPosition(Position)
                if Position then
                    Items["Button"].Instance.Position = Position
                end
            end

            function ToggleButton:SetIcon(Icon)
                if Icon and Icon ~= "" then
                    Items["Inner"].Instance.Image = Icon
                end
            end

            local PressStart = nil

            Items["Button"]:Connect("InputBegan", function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    PressStart = Input.Position
                end
            end)

            Items["Button"]:Connect("InputEnded", function(Input)
                if not PressStart then
                    return
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end

                local DragDistance = (Input.Position - PressStart).Magnitude
                PressStart = nil

                if DragDistance <= 8 then
                    ToggleButton:Press()
                end
            end)

            ToggleButton:SetIcon(Data.Icon)
            return ToggleButton
        end
-- ============================================================
-- [ modulo: Window.lua ]
-- ============================================================


        Library.Window = function(self, Data)
            Data = Data or { }

            local HideLogo = Data.HideLogo or Data.hidelogo or Data.Logo == false or Data.logo == false

            local Window = {
                Name = Data.Name or Data.name or "Window",
                SubName = Data.SubName or Data.subname or Data.SubTitle or Data.subtitle or Data.Subtitle or "",
                Logo = (not HideLogo) and (Data.Logo or Data.logo or self.DefaultHeaderLogo or "rbxassetid://81441172534384") or nil,

                Pages = { },
                Panes = { },
                ActivePane = nil,
                FlyoutPage = nil,
                Items = { },
                SidebarGroups = { },
                SidebarGroupCount = 0,
                VisualRefreshers = { },
                IsOpen = false,
                IsMaximized = false,
                IsSidebarCollapsed = false,
                SidebarCollapseEnabled = Data.SidebarCollapseEnabled ~= false and Data.sidebarcollapseenabled ~= false,
                -- Mobile defaults (smaller widget) — overridable via Data.*
                ExpandedSidebarWidth = Data.SidebarWidth or Data.sidebarwidth or (Library:IsMobileClient() and 170 or 240),
                CollapsedSidebarWidth = Data.CollapsedSidebarWidth or Data.collapsedsidebarwidth or (Library:IsMobileClient() and 52 or 72),
                SidebarGap = Data.SidebarGap or Data.sidebargap or (Library:IsMobileClient() and 8 or 12),
                DefaultSidebarCollapsed = Data.DefaultSidebarCollapsed == true or Data.defaultsidebarcollapsed == true or Library:IsMobileClient(),
                RestorePosition = nil,
                RestoreSize = nil
            }

            local SearchIcon = Data.SearchIcon or Data.searchicon or "search"
            if self.ResolveIcon then
                SearchIcon = self:ResolveIcon(SearchIcon)
            end

            if type(SearchIcon) ~= "string" or (not SearchIcon:match("^rbxassetid://") and not SearchIcon:match("^https?://")) then
                SearchIcon = "rbxassetid://6031154871"
            end

            local HasSubtitle = Window.SubName ~= ""
            local HasLogo = type(Window.Logo) == "string" and Window.Logo ~= ""
            local HeaderLogoSize = Data.HeaderLogoSize or Data.headerlogosize or Data.LogoSize or Data.logosize or self.DefaultHeaderLogoSize or 28
            local BrandPrimary, BrandSecondary = tostring(Window.Name):match("^(%S+)%s+(.+)$")

            if type(HeaderLogoSize) ~= "number" then
                HeaderLogoSize = 28
            end

            if not BrandPrimary then
                BrandPrimary = Window.Name
                BrandSecondary = nil
            end

            local HeaderHeight = 46
            local PagesCardTop = 74
            local CompactTitle = tostring(BrandPrimary):sub(1, 1) .. (BrandSecondary and tostring(BrandSecondary):sub(1, 1) or "")
            local WindowControlCount = Window.SidebarCollapseEnabled and 4 or 3
            local WindowControlsWidth = (WindowControlCount * 30) + ((WindowControlCount - 1) * 6)
            local SubtitleRightInset = WindowControlsWidth + 68
            local ContentOffset = Window.ExpandedSidebarWidth + Window.SidebarGap

            -- Mobile: smaller window so it fits on phones/tablets without
            -- requiring the user to resize manually. Min size also smaller
            -- so user can shrink further if desired.
            local _isMobileWin = Library:IsMobileClient()
            local _winW = _isMobileWin and 560 or 960
            local _winH = _isMobileWin and 360 or 560
            local _minW = _isMobileWin and 480 or 860
            local _minH = _isMobileWin and 320 or 520

            local Items = { } do
                Items["MainFrame"] = Instances:Create("Frame", {
                    Parent = Library.Holder.Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2FromOffset(_winW, _winH),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1
                })

                Items["MainFrame"]:MakeDraggable()
                Items["MainFrame"]:MakeResizeable(Vector2New(_minW, _minH), Vector2New(9999, 9999))

                Items["Sidebar"] = Instances:Create("Frame", {
                    Parent = Items["MainFrame"].Instance,
                    Name = "\0",
                    BackgroundColor3 = Library.Theme["Panel"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0, Window.ExpandedSidebarWidth, 1, 0),
                    BorderSizePixel = 0
                }):AddToTheme({BackgroundColor3 = 'Panel'})

                Instances:Create("UICorner", {
                    Parent = Items["Sidebar"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 18)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["Sidebar"].Instance,
                    Name = "\0",
                    Color = Library.Theme["OutlineSoft"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'OutlineSoft'})

                Items["Top"] = Instances:Create("Frame", {
                    Parent = Items["Sidebar"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Position = UDim2FromOffset(16, 16),
                    Size = UDim2.new(1, -32, 0, HeaderHeight),
                    BorderSizePixel = 0
                })

                Items["TopContent"] = Instances:Create("Frame", {
                    Parent = Items["Top"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0
                })

                Items["TopContentLayout"] = Instances:Create("UIListLayout", {
                    Parent = Items["TopContent"].Instance,
                    Name = "\0",
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDimNew(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                if HasLogo then
                    Items["Logo"] = Instances:Create("ImageLabel", {
                        Parent = Items["TopContent"].Instance,
                        Name = "\0",
                        ScaleType = Enum.ScaleType.Fit,
                        ImageColor3 = Library.Theme["Text"],
                        BorderColor3 = FromRGB(0, 0, 0),
                        Image = Window.Logo,
                        BackgroundTransparency = 1,
                        Size = UDim2FromOffset(HeaderLogoSize, HeaderLogoSize),
                        BorderSizePixel = 0
                    }):AddToTheme({ImageColor3 = 'Text'})
                else
                    Items["Logo"] = Instances:Create("Frame", {
                        Parent = Items["TopContent"].Instance,
                        Name = "\0",
                        Visible = false,
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        Size = UDim2FromOffset(0, 0),
                        BorderSizePixel = 0
                    })
                end

                Items["Brand"] = Instances:Create("Frame", {
                    Parent = Items["TopContent"].Instance,
                    Name = "\0",
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0
                })

                Items["BrandLayout"] = Instances:Create("UIListLayout", {
                    Parent = Items["Brand"].Instance,
                    Name = "\0",
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDimNew(0, BrandSecondary and 12 or 0),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Items["Title"] = Instances:Create("TextLabel", {
                    Parent = Items["Brand"].Instance,
                    Name = "\0",
                    FontFace = Library.BrandFont or Library.TitleFont or Library.Font,
                    Font = Library.BrandFontEnum or Library.TitleFontEnum or Enum.Font.GothamBold,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = BrandPrimary,
                    Size = UDim2.new(0, 0, 0, 32),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    TextWrapped = false,
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 36,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Center
                }):AddToTheme({TextColor3 = 'Text'})

                if BrandSecondary then
                    Items["TitleSecondary"] = Instances:Create("TextLabel", {
                        Parent = Items["Brand"].Instance,
                        Name = "\0",
                        FontFace = Library.BrandFont or Library.TitleFont or Library.Font,
                        Font = Library.BrandFontEnum or Library.TitleFontEnum or Enum.Font.GothamBold,
                        TextColor3 = Library.Theme["Text"],
                        BorderColor3 = FromRGB(0, 0, 0),
                        Text = BrandSecondary,
                        Size = UDim2.new(0, 0, 0, 32),
                        BorderSizePixel = 0,
                        BackgroundTransparency = 1,
                        TextWrapped = false,
                        AutomaticSize = Enum.AutomaticSize.X,
                        TextSize = 36,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center
                    }):AddToTheme({TextColor3 = 'Text'})
                end

                Items["CompactBadge"] = Instances:Create("TextLabel", {
                    Parent = Items["Top"].Instance,
                    Name = "\0",
                    Visible = false,
                    FontFace = Library.BrandFont or Library.TitleFont or Library.Font,
                    Font = Library.BrandFontEnum or Library.TitleFontEnum or Enum.Font.GothamBold,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = CompactTitle ~= "" and CompactTitle or tostring(Window.Name):sub(1, 1),
                    Size = UDim2.new(0, 0, 0, 24),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.X,
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    TextSize = 22,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center
                }):AddToTheme({TextColor3 = 'Text'})

                Items["PagesCard"] = Instances:Create("Frame", {
                    Parent = Items["Sidebar"].Instance,
                    Name = "\0",
                    Position = UDim2FromOffset(8, PagesCardTop),
                    Size = UDim2.new(1, -16, 1, -(PagesCardTop + 8)),
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Surface"]
                }):AddToTheme({BackgroundColor3 = 'Surface'})

                Instances:Create("UICorner", {
                    Parent = Items["PagesCard"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 16)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["PagesCard"].Instance,
                    Name = "\0",
                    Color = Library.Theme["OutlineSoft"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'OutlineSoft'})

                Items["Pages"] = Instances:Create("ScrollingFrame", {
                    Parent = Items["PagesCard"].Instance,
                    Name = "\0",
                    Active = true,
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarImageColor3 = Library.Theme["Accent"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    ScrollBarThickness = 0,
                    Size = UDim2.new(1, -24, 1, -24),
                    BackgroundTransparency = 1,
                    Position = UDim2FromOffset(12, 12)
                }):AddToTheme({ScrollBarImageColor3 = 'Accent'})

                Instances:Create("UIListLayout", {
                    Parent = Items["Pages"].Instance,
                    Name = "\0",
                    -- Match inner-group button padding (4) so tabs across
                    -- different groups look identical to tabs in same group.
                    Padding = UDimNew(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Items["ContentShell"] = Instances:Create("Frame", {
                    Parent = Items["MainFrame"].Instance,
                    Name = "\0",
                    BackgroundColor3 = Library.Theme["Background"],
                    Position = UDim2FromOffset(ContentOffset, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, -ContentOffset, 1, 0),
                    BorderSizePixel = 0
                }):AddToTheme({BackgroundColor3 = 'Background'})

                Instances:Create("UICorner", {
                    Parent = Items["ContentShell"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 18)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["ContentShell"].Instance,
                    Name = "\0",
                    Color = Library.Theme["OutlineSoft"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'OutlineSoft'})

                Items["WindowControls"] = Instances:Create("Frame", {
                    Parent = Items["ContentShell"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(1, 0),
                    Position = UDim2.new(1, -18, 0, 12),
                    Size = UDim2FromOffset(WindowControlsWidth, 24),
                    BorderSizePixel = 0
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["WindowControls"].Instance,
                    Name = "\0",
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    Padding = UDimNew(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Items["Subtitle"] = Instances:Create("TextLabel", {
                    Parent = Items["ContentShell"].Instance,
                    Name = "\0",
                    Visible = HasSubtitle,
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["TextMuted"],
                    TextTransparency = 0,
                    Text = Window.SubName,
                    Size = UDim2.new(1, -SubtitleRightInset, 0, 22),
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2FromOffset(20, 14),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 17
                }):AddToTheme({TextColor3 = 'TextMuted'})

                local function ResolveWindowControlIcon(Name)
                    if self.ResolveIcon then
                        return self:ResolveIcon(Name)
                    end

                    return Name
                end

                local function CreateWindowControl(IconName)
                    local Button = Instances:Create("TextButton", {
                        Parent = Items["WindowControls"].Instance,
                        Name = "\0",
                        FontFace = Library.Font,
                        TextColor3 = Library.Theme["Text"],
                        TextTransparency = 1,
                        Text = "",
                        AutoButtonColor = false,
                        BackgroundColor3 = Library.Theme["Element"],
                        BackgroundTransparency = 0.06,
                        Size = UDim2FromOffset(30, 24),
                        BorderColor3 = FromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        TextSize = 14
                    }):AddToTheme({BackgroundColor3 = 'Element', TextColor3 = 'Text'})

                    Instances:Create("UICorner", {
                        Parent = Button.Instance,
                        Name = "\0",
                        CornerRadius = UDimNew(0, 8)
                    })

                    Instances:Create("UIStroke", {
                        Parent = Button.Instance,
                        Name = "\0",
                        Color = Library.Theme["OutlineSoft"],
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    }):AddToTheme({Color = 'OutlineSoft'})

                    local Icon = Instances:Create("ImageLabel", {
                        Parent = Button.Instance,
                        Name = "\0",
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        Image = ResolveWindowControlIcon(IconName),
                        ImageTransparency = 0.2,
                        AnchorPoint = Vector2New(0.5, 0.5),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        Size = UDim2FromOffset(14, 14),
                        BorderSizePixel = 0
                    }):AddToTheme({ImageColor3 = 'Text'})

                    return Button, Icon
                end

                if Window.SidebarCollapseEnabled then
                    Items["SidebarButton"], Items["SidebarToggleIcon"] = CreateWindowControl("chevrons-left")
                end

                Items["MinimizeButton"], Items["MinimizeIcon"] = CreateWindowControl("minus")
                Items["ExpandButton"], Items["ExpandIcon"] = CreateWindowControl("maximize-2")
                Items["CloseButton"], Items["CloseIcon"] = CreateWindowControl("x")

                Items["TopDivider"] = Instances:Create("Frame", {
                    Parent = Items["ContentShell"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    Position = UDim2FromOffset(20, 48),
                    Size = UDim2.new(1, -40, 0, 1),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["OutlineSoft"]
                }):AddToTheme({BackgroundColor3 = 'OutlineSoft'})

                Items["Content"] = Instances:Create("Frame", {
                    Parent = Items["ContentShell"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    Position = UDim2FromOffset(0, 58),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 1, -58),
                    BorderSizePixel = 0
                })

                -- ── Sub-tab flyout ───────────────────────────────────────
                -- With the sidebar collapsed there is no room for the inline accordion, so
                -- the sub-tabs come out in a floating panel beside the tab's icon. The
                -- SubList is reparented here (same buttons, same state) and handed back on
                -- close.
                Items["Flyout"] = Instances:Create("Frame", {
                    Parent = Items["MainFrame"].Instance,
                    Name = "\0",
                    Visible = false,
                    BackgroundColor3 = Library.Theme["Panel"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Position = UDim2FromOffset(0, 0),
                    Size = UDim2.new(0, 196, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 60
                }):AddToTheme({BackgroundColor3 = 'Panel'})

                Instances:Create("UICorner", {
                    Parent = Items["Flyout"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 14)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["Flyout"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})

                Instances:Create("UIPadding", {
                    Parent = Items["Flyout"].Instance,
                    Name = "\0",
                    PaddingTop = UDimNew(0, 10),
                    PaddingBottom = UDimNew(0, 10),
                    PaddingLeft = UDimNew(0, 10),
                    PaddingRight = UDimNew(0, 10)
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["Flyout"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Items["FlyoutTitle"] = Instances:Create("TextLabel", {
                    Parent = Items["Flyout"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["TextMuted"],
                    TextTransparency = 0.15,
                    Text = "",
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 13,
                    ZIndex = 61
                }):AddToTheme({TextColor3 = 'TextMuted'})

                -- ── Loading overlay ──────────────────────────────────────
                -- Sits on top of every Window child while the host script is
                -- adding tabs/sections. Hidden by Window:HideLoading() — or
                -- auto-fades after 4s as a safety net.
                Items["LoadingOverlay"] = Instances:Create("Frame", {
                    Parent = Items["MainFrame"].Instance,
                    Name = "\0",
                    BackgroundColor3 = Library.Theme["Panel"],
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    ZIndex = 100,
                }):AddToTheme({BackgroundColor3 = 'Panel'})

                Instances:Create("UICorner", {
                    Parent = Items["LoadingOverlay"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 12),
                })

                Items["LoadingLogo"] = Instances:Create("ImageLabel", {
                    Parent = Items["LoadingOverlay"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, -64),
                    Size = UDim2FromOffset(96, 96),
                    Image = Library.DefaultHeaderLogo or "rbxassetid://75802679174420",
                    ZIndex = 101,
                })

                Items["LoadingTitle"] = Instances:Create("TextLabel", {
                    Parent = Items["LoadingOverlay"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 8),
                    Size = UDim2FromOffset(400, 32),
                    FontFace = Library.Font,
                    Text = (Window.Name and Window.Name .. " — Loading…") or "Loading…",
                    TextColor3 = Library.Theme["TextStrong"] or Library.Theme["Text"],
                    TextSize = 22,
                    ZIndex = 101,
                }):AddToTheme({TextColor3 = 'Text'})

                Items["LoadingSub"] = Instances:Create("TextLabel", {
                    Parent = Items["LoadingOverlay"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 36),
                    Size = UDim2FromOffset(400, 18),
                    FontFace = Library.Font,
                    Text = "preparing the interface",
                    TextColor3 = Library.Theme["TextMuted"],
                    TextSize = 13,
                    TextTransparency = 0.15,
                    ZIndex = 101,
                }):AddToTheme({TextColor3 = 'TextMuted'})

                -- Tiny animated dots after the subtitle text
                task.spawn(function()
                    local dots = {"", ".", "..", "..."}
                    local i = 1
                    while Items["LoadingOverlay"] and Items["LoadingOverlay"].Instance and Items["LoadingOverlay"].Instance.Parent do
                        if Items["LoadingSub"] and Items["LoadingSub"].Instance and Items["LoadingSub"].Instance.Parent then
                            Items["LoadingSub"].Instance.Text = "preparing the interface" .. dots[i]
                        end
                        i = (i % #dots) + 1
                        task.wait(0.3)
                    end
                end)

                Window.IsLoading = true

                Window.Items = Items
            end

            function Window:GetSidebarGroup(Name)
                Name = tostring(Name or "")

                local GroupKey = Name ~= "" and Name or "__default"
                if Window.SidebarGroups[GroupKey] then
                    return Window.SidebarGroups[GroupKey]
                end

                Window.SidebarGroupCount += 1

                -- Group labels disabled: tabs render as a flat list with no
                -- "Settings" / category headers between them.
                local HasLabel = false
                local GroupItems = { } do
                    GroupItems["Group"] = Instances:Create("Frame", {
                        Parent = Items["Pages"].Instance,
                        Name = "\0",
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        Size = UDim2.new(1, 0, 0, 0),
                        BorderSizePixel = 0,
                        AutomaticSize = Enum.AutomaticSize.Y
                    })

                    GroupItems["Group"].Instance.LayoutOrder = Window.SidebarGroupCount
                    GroupItems.HasLabel = HasLabel

                    GroupItems["Layout"] = Instances:Create("UIListLayout", {
                        Parent = GroupItems["Group"].Instance,
                        Name = "\0",
                        Padding = UDimNew(0, HasLabel and 10 or 0),
                        SortOrder = Enum.SortOrder.LayoutOrder
                    })

                    GroupItems["Label"] = Instances:Create("TextLabel", {
                        Parent = GroupItems["Group"].Instance,
                        Name = "\0",
                        Visible = HasLabel,
                        FontFace = Library.Font,
                        TextColor3 = Library.Theme["TextMuted"],
                        TextTransparency = 0.05,
                        Text = Name,
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextSize = 14
                    }):AddToTheme({TextColor3 = 'TextMuted'})

                    GroupItems["Buttons"] = Instances:Create("Frame", {
                        Parent = GroupItems["Group"].Instance,
                        Name = "\0",
                        BackgroundTransparency = 1,
                        BorderColor3 = FromRGB(0, 0, 0),
                        Size = UDim2.new(1, 0, 0, 0),
                        BorderSizePixel = 0,
                        AutomaticSize = Enum.AutomaticSize.Y
                    })

                    Instances:Create("UIListLayout", {
                        Parent = GroupItems["Buttons"].Instance,
                        Name = "\0",
                        Padding = UDimNew(0, 4),
                        SortOrder = Enum.SortOrder.LayoutOrder
                    })
                end

                Window.SidebarGroups[GroupKey] = GroupItems

                if type(Window.RefreshSidebarGroupLayout) == "function" then
                    Window:RefreshSidebarGroupLayout(GroupItems)
                end

                return GroupItems
            end

            -- ══════════════════════════════════════════════════════════════
            -- Panes (tabs + sub-tabs)
            -- ══════════════════════════════════════════════════════════════
            -- A "pane" is anything occupying the content area: a tab with no children, or
            -- a sub-tab. Activation is centralised here so the accordion, the rail and the
            -- sidebar highlights stay in sync with what is on screen.

            function Window:RegisterPane(Pane)
                if type(Pane) ~= "table" then
                    return
                end

                TableInsert(Window.Panes, Pane)
                return Pane
            end

            function Window:ActivatePane(Pane, Animate)
                if type(Pane) ~= "table" or not Pane.IsPane then
                    return
                end

                -- Clicking a tab that only acts as a container opens the sub-tab that was
                -- active last (or the first one).
                if type(Pane.GetDefaultPane) == "function" then
                    Pane = Pane:GetDefaultPane() or Pane
                end

                local UseTween = Animate ~= false
                local OwnerPage = Pane.IsSubTab and Pane.Parent or Pane
                local Dirty = { }

                for _, Other in next, Window.Panes do
                    if Other ~= Pane and (Other.Active or Other.Hovered) then
                        Other.Active = false
                        Other.Hovered = false
                        Dirty[Other] = true
                    end
                end

                if not Pane.Active or Pane.Hovered then
                    Dirty[Pane] = true
                end

                Pane.Active = true
                Pane.Hovered = false
                Window.ActivePane = Pane

                if Pane.IsSubTab then
                    OwnerPage.LastActiveSub = Pane
                end

                for _, Page in next, Window.Pages do
                    local ChildActive = (Page == OwnerPage) and Pane.IsSubTab and true or false

                    if Page.ChildActive ~= ChildActive then
                        Page.ChildActive = ChildActive
                        Dirty[Page] = true
                    end
                end

                for Item in next, Dirty do
                    if type(Item.RefreshVisualState) == "function" then
                        Item:RefreshVisualState(UseTween)
                    end
                end

                for _, Page in next, Window.Pages do
                    if type(Page.SetExpanded) == "function" then
                        local ShouldExpand = (Page == OwnerPage) and Page:HasSubTabs()

                        if Page.Expanded ~= ShouldExpand then
                            Page:SetExpanded(ShouldExpand, UseTween)
                        end
                    end
                end

                if type(OwnerPage.RefreshRailThumb) == "function" then
                    OwnerPage:RefreshRailThumb(UseTween)
                end

                return Pane
            end

            -- ══════════════════════════════════════════════════════════════
            -- Flyout de sub-tabs (sidebar colapsada)
            -- ══════════════════════════════════════════════════════════════

            -- The ScreenGui uses ZIndexBehavior.Global, so the floating panel only sits in
            -- front if all its descendants rise with it.
            function Window:ApplyFlyoutZIndex(Root, Value)
                if not Root then
                    return
                end

                if Root:IsA("GuiObject") then
                    Root.ZIndex = Value
                end

                for _, Descendant in next, Root:GetDescendants() do
                    if Descendant:IsA("GuiObject") then
                        Descendant.ZIndex = Value
                    end
                end
            end

            function Window:CloseFlyout()
                local Page = Window.FlyoutPage

                if not Page then
                    return
                end

                Window.FlyoutPage = nil

                local Metrics = Library.SubTabMetrics
                local SubList = Page.Items and Page.Items["SubList"]
                local Padding = Page.Items and Page.Items["SubListPadding"]

                if SubList and SubList.Instance then
                    Window:ApplyFlyoutZIndex(SubList.Instance, 1)
                    SubList.Instance.Parent = Page.Items["SubHolder"].Instance
                end

                if Padding and Padding.Instance then
                    Padding.Instance.PaddingTop = UDimNew(0, Metrics.PadTop)
                    Padding.Instance.PaddingBottom = UDimNew(0, Metrics.PadBottom)
                    Padding.Instance.PaddingLeft = UDimNew(0, Metrics.IndentLeft)
                end

                Items["Flyout"].Instance.Visible = false

                if type(Page.RefreshSubHolder) == "function" then
                    Page:RefreshSubHolder(false)
                end
            end

            function Window:OpenFlyout(Page)
                if type(Page) ~= "table" or type(Page.HasSubTabs) ~= "function" or not Page:HasSubTabs() then
                    return
                end

                Window:CloseFlyout()
                Window.FlyoutPage = Page

                local Metrics = Library.SubTabMetrics
                local SubList = Page.Items["SubList"]
                local Padding = Page.Items["SubListPadding"]
                local Count = #Page.SubTabs

                Padding.Instance.PaddingTop = UDimNew(0, 0)
                Padding.Instance.PaddingBottom = UDimNew(0, 0)
                Padding.Instance.PaddingLeft = UDimNew(0, 0)

                SubList.Instance.LayoutOrder = 2
                SubList.Instance.Parent = Items["Flyout"].Instance
                Window:ApplyFlyoutZIndex(SubList.Instance, 61)

                Items["FlyoutTitle"].Instance.Text = tostring(Page.Name or "")

                -- AutomaticSize.Y only resolves next frame, so the height for the clamp is
                -- computed by hand.
                local FlyoutHeight = 20 + 14 + 6 + (Count * Metrics.Height) + ((Count - 1) * Metrics.Gap)
                local MainFrame = Items["MainFrame"].Instance
                local Button = Page.Items["Inactive"].Instance
                local OffsetY = Button.AbsolutePosition.Y - MainFrame.AbsolutePosition.Y - 6
                local MaxY = MathClamp(MainFrame.AbsoluteSize.Y - FlyoutHeight - 10, 10, 99999)

                Items["Flyout"].Instance.Position = UDim2FromOffset(
                    Window.CollapsedSidebarWidth + 8,
                    MathClamp(OffsetY, 10, MaxY)
                )
                Items["Flyout"].Instance.Visible = true

                if type(Page.RefreshSubHolder) == "function" then
                    Page:RefreshSubHolder(false)
                end
            end

            function Window:ToggleFlyout(Page)
                if Window.FlyoutPage == Page then
                    Window:CloseFlyout()
                    return
                end

                Window:OpenFlyout(Page)
            end

            -- Clique fora fecha o flyout.
            Library:Connect(UserInputService.InputBegan, function(Input)
                if not Window.FlyoutPage then
                    return
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end

                local Flyout = Items["Flyout"].Instance
                local Position = Input.Position
                local TopLeft = Flyout.AbsolutePosition
                local BottomRight = TopLeft + Flyout.AbsoluteSize

                local InsideFlyout = Position.X >= TopLeft.X and Position.X <= BottomRight.X
                    and Position.Y >= TopLeft.Y and Position.Y <= BottomRight.Y

                if InsideFlyout then
                    return
                end

                -- The tab's own button is handled by its own handler (toggle).
                local Button = Window.FlyoutPage.Items["Inactive"].Instance
                local ButtonTopLeft = Button.AbsolutePosition
                local ButtonBottomRight = ButtonTopLeft + Button.AbsoluteSize

                local InsideButton = Position.X >= ButtonTopLeft.X and Position.X <= ButtonBottomRight.X
                    and Position.Y >= ButtonTopLeft.Y and Position.Y <= ButtonBottomRight.Y

                if InsideButton then
                    return
                end

                Window:CloseFlyout()
            end)

            function Window:RefreshSidebarHeaderLayout()
                local Collapsed = Window.IsSidebarCollapsed
                local ShowLogo = Collapsed and HasLogo

                if Items["Logo"] then
                    Items["Logo"].Instance.Visible = ShowLogo
                    Items["Logo"].Instance.Size = ShowLogo and UDim2FromOffset(HeaderLogoSize, HeaderLogoSize) or UDim2FromOffset(0, 0)
                end

                if Items["Brand"] then
                    Items["Brand"].Instance.Visible = not Collapsed
                    Items["Brand"].Instance.AutomaticSize = (not Collapsed) and Enum.AutomaticSize.X or Enum.AutomaticSize.None
                    Items["Brand"].Instance.Size = (not Collapsed) and UDim2.new(0, 0, 1, 0) or UDim2FromOffset(0, 0)
                end

                if Items["TopContentLayout"] then
                    Items["TopContentLayout"].Instance.Padding = UDimNew(0, ShowLogo and 10 or 0)
                end

                if Items["BrandLayout"] then
                    Items["BrandLayout"].Instance.Padding = UDimNew(0, (not Collapsed and BrandSecondary) and 12 or 0)
                end

                Items["TopContent"].Instance.Visible = not Collapsed or ShowLogo
                Items["CompactBadge"].Instance.Visible = Collapsed and not HasLogo
                Items["Title"].Instance.Visible = not Collapsed

                if Items["TitleSecondary"] then
                    Items["TitleSecondary"].Instance.Visible = not Collapsed
                end
            end

            function Window:RefreshSidebarGroupLayout(GroupItems)
                if type(GroupItems) ~= "table" then
                    return
                end

                local ShowLabel = GroupItems.HasLabel and not Window.IsSidebarCollapsed

                if GroupItems["Label"] then
                    GroupItems["Label"].Instance.Visible = ShowLabel
                end

                if GroupItems["Layout"] then
                    GroupItems["Layout"].Instance.Padding = UDimNew(0, ShowLabel and 10 or 0)
                end
            end

            function Window:RefreshSidebarPageLayout(Page)
                if type(Page) ~= "table" or type(Page.Items) ~= "table" then
                    return
                end

                local PageItems = Page.Items
                local Collapsed = Window.IsSidebarCollapsed
                local IsActiveOrHovered = Page.Active or Page.Hovered

                if PageItems["Text"] then
                    PageItems["Text"].Instance.Visible = not Collapsed
                    PageItems["Text"].Instance.TextTransparency = Collapsed and 1 or (Page.Active and 0 or 0.22)
                    PageItems["Text"].Instance.Position = UDim2.new(0, 44, 0.5, 0)
                end

                if PageItems["Background"] then
                    PageItems["Background"].Instance.AnchorPoint = Collapsed and Vector2New(0.5, 0.5) or Vector2New(0, 0)
                    PageItems["Background"].Instance.Position = Collapsed and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 0, 0, 0)
                    PageItems["Background"].Instance.Size = Collapsed and UDim2FromOffset(42, 42) or UDim2.new(1, 0, 1, 0)
                end

                if PageItems["Stroke"] then
                    PageItems["Stroke"].Instance.Transparency = Collapsed and (IsActiveOrHovered and 0.25 or 1) or PageItems["Stroke"].Instance.Transparency
                end

                if PageItems["AccentBar"] then
                    PageItems["AccentBar"].Instance.Visible = not Collapsed
                end

                if PageItems["Icon"] then
                    PageItems["Icon"].Instance.AnchorPoint = Collapsed and Vector2New(0.5, 0.5) or Vector2New(0, 0.5)
                    PageItems["Icon"].Instance.Position = Collapsed and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 16, 0.5, 0)
                    PageItems["Icon"].Instance.Size = Collapsed and UDim2FromOffset(18, 18) or UDim2FromOffset(16, 16)
                end
            end

            function Window:RefreshSidebarLayout(Animate)
                local SidebarWidth = Window.IsSidebarCollapsed and Window.CollapsedSidebarWidth or Window.ExpandedSidebarWidth
                local NewContentOffset = SidebarWidth + Window.SidebarGap
                local SidebarTweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

                if Items["SidebarToggleIcon"] then
                    Items["SidebarToggleIcon"].Instance.Image = Library:ResolveIcon(Window.IsSidebarCollapsed and "chevrons-right" or "chevrons-left")
                end

                Window:RefreshSidebarHeaderLayout()

                for _, GroupItems in next, Window.SidebarGroups do
                    Window:RefreshSidebarGroupLayout(GroupItems)
                end

                for _, Page in next, Window.Pages do
                    if type(Page.RefreshVisualState) == "function" then
                        Page:RefreshVisualState(false)
                    else
                        Window:RefreshSidebarPageLayout(Page)
                    end

                    -- Collapsing the sidebar closes the inline accordion (no room for it);
                    -- expanding back reopens the active tab's.
                    if type(Page.RefreshSubHolder) == "function" then
                        Page:RefreshSubHolder(false)
                    end
                end

                if Animate then
                    Items["Sidebar"]:Tween(SidebarTweenInfo, {Size = UDim2.new(0, SidebarWidth, 1, 0)})
                    Items["ContentShell"]:Tween(SidebarTweenInfo, {
                        Position = UDim2FromOffset(NewContentOffset, 0),
                        Size = UDim2.new(1, -NewContentOffset, 1, 0)
                    })
                else
                    Items["Sidebar"].Instance.Size = UDim2.new(0, SidebarWidth, 1, 0)
                    Items["ContentShell"].Instance.Position = UDim2FromOffset(NewContentOffset, 0)
                    Items["ContentShell"].Instance.Size = UDim2.new(1, -NewContentOffset, 1, 0)
                end
            end

            function Window:SetSidebarCollapsed(Bool)
                Bool = Bool and true or false

                if Window.IsSidebarCollapsed == Bool then
                    return
                end

                Window:CloseFlyout()

                Window.IsSidebarCollapsed = Bool
                Window:RefreshSidebarLayout(true)
            end

            function Window:ToggleSidebar()
                Window:SetSidebarCollapsed(not Window.IsSidebarCollapsed)
            end

            function Window:RegisterVisualRefresher(Callback)
                if type(Callback) ~= "function" then
                    return
                end

                TableInsert(Window.VisualRefreshers, Callback)
                return Callback
            end

            function Window:RefreshVisualStates()
                for _, Callback in next, Window.VisualRefreshers do
                    Library:SafeCall(Callback)
                end
            end

            function Window:SetCenter()
                local CenterPosition = Items["MainFrame"].Instance.AbsolutePosition
                task.wait()
                Items["MainFrame"].Instance.AnchorPoint = Vector2New(0, 0)

                Items["MainFrame"].Instance.Position = UDim2.new(0, CenterPosition.X, 0, CenterPosition.Y)
            end

            function Window:SetMaximized(Bool)
                if Window.IsMaximized == Bool then
                    return
                end

                Window.IsMaximized = Bool

                if Items["ExpandIcon"] then
                    Items["ExpandIcon"].Instance.Image = self:ResolveIcon(Window.IsMaximized and "minimize-2" or "maximize-2")
                end

                if Bool then
                    Window.RestorePosition = Items["MainFrame"].Instance.Position
                    Window.RestoreSize = Items["MainFrame"].Instance.Size

                    local ScreenSize = Library.Holder.Instance.AbsoluteSize
                    local NewPosition = UDim2FromOffset(12, 12)
                    local NewSize = UDim2FromOffset(ScreenSize.X - 24, ScreenSize.Y - 24)

                    Items["MainFrame"]:Tween(TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Position = NewPosition
                    })
                    Items["MainFrame"]:Tween(TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = NewSize
                    })
                else
                    Items["MainFrame"]:Tween(TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Position = Window.RestorePosition or UDim2FromOffset(60, 60)
                    })
                    Items["MainFrame"]:Tween(TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = Window.RestoreSize or UDim2FromOffset(960, 560)
                    })
                end
            end

            function Window:ToggleMaximize()
                Window:SetMaximized(not Window.IsMaximized)
            end

            -- When the user drags a maximised window, it returns to its previous size and
            -- ends up positioned under the cursor — standard OS window behaviour
            -- (Windows/macOS). The position is set immediately (so MakeDraggable's drag
            -- maths captures the right point), but the size animates smoothly.
            Items["MainFrame"].OnDragStarted = function(Input)
                if not Window.IsMaximized then
                    return
                end

                Window.IsMaximized = false
                if Items["ExpandIcon"] then
                    Items["ExpandIcon"].Instance.Image = Window:ResolveIcon("maximize-2")
                end

                local RestoreSize = Window.RestoreSize or UDim2FromOffset(960, 560)
                local Frame = Items["MainFrame"].Instance

                local TargetWidth = RestoreSize.X.Offset
                if TargetWidth == 0 then
                    TargetWidth = Frame.AbsoluteSize.X
                end

                -- Places the window with the cursor near the centre of the title bar —
                -- instantly, so as not to break the drag delta capture.
                local AnchorOffsetX = TargetWidth * Frame.AnchorPoint.X
                local AnchorOffsetY = 20 * Frame.AnchorPoint.Y
                local NewX = Input.Position.X - (TargetWidth / 2) + AnchorOffsetX
                local NewY = Input.Position.Y - 20 + AnchorOffsetY

                Frame.Position = UDim2FromOffset(NewX, math.max(0, NewY))

                -- Tween the Size only (the position is being updated by the drag, so it cannot
                -- be animated without conflicting with MakeDraggable).
                TweenService:Create(
                    Frame,
                    TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    { Size = RestoreSize }
                ):Play()
            end

            function Window:SetOpen(Bool)
                Bool = Bool and true or false

                if Window.IsOpen == Bool then
                    return
                end

                Window.IsOpen = Bool

                if Window.IsOpen then 
                    Window:RefreshVisualStates()
                end

                Items["MainFrame"].Instance.Visible = Window.IsOpen
            end

            local function ConnectWindowControl(Button, HoverTransparency, Callback)
                Button:Connect("MouseEnter", function()
                    Button:Tween(nil, {BackgroundTransparency = HoverTransparency or 0})
                end)

                Button:Connect("MouseLeave", function()
                    Button:Tween(nil, {BackgroundTransparency = 0.06})
                end)

                Button:Connect("MouseButton1Down", Callback)
            end

            if Items["SidebarButton"] then
                ConnectWindowControl(Items["SidebarButton"], 0, function()
                    Window:ToggleSidebar()
                end)
            end

            ConnectWindowControl(Items["MinimizeButton"], 0, function()
                Window:SetOpen(false)
            end)

            ConnectWindowControl(Items["ExpandButton"], 0, function()
                Window:ToggleMaximize()
            end)

            ConnectWindowControl(Items["CloseButton"], 0, function()
                Library:Unload()
            end)

            Library:Connect(UserInputService.InputBegan, function(Input)
                if tostring(Input.KeyCode) == Library.MenuKeybind or tostring(Input.UserInputType) == Library.MenuKeybind then
                    Window:SetOpen(not Window.IsOpen)
                end
            end)

            Window:RefreshSidebarLayout(false)

            if Window.DefaultSidebarCollapsed then
                Window.IsSidebarCollapsed = true
                Window:RefreshSidebarLayout(false)
            end

            Window:SetCenter()
            task.wait()
            Window:SetOpen(true)
            return setmetatable(Window, Library)
        end
-- ============================================================
-- [ modulo: Page.lua ]
-- ============================================================


        -- ══════════════════════════════════════════════════════════════════
        -- Accordion metrics (parent tab -> sub-tabs). They live on the Library and
        -- not in locals because SubTab.lua is another module of the bundle and needs
        -- the same numbers to position the rail/thumb.
        -- ══════════════════════════════════════════════════════════════════
        Library.SubTabMetrics = {
            Height      = 30,   -- height of each sub-tab button
            Gap         = 3,    -- vertical gap between sub-tabs
            PadTop      = 4,
            PadBottom   = 6,
            RailX       = 23,   -- aligned with the parent tab icon centre (16 + 16/2)
            IndentLeft  = 34,   -- indent of the sub-tab buttons
            ThumbWidth  = 3,    -- marcador deslizante: 1px mais grosso que o rail
            ThumbHeight = 16
        }

        Library.AccordionTweenInfo = TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

        Library.GetSubHolderHeight = function(self, Count)
            local Metrics = Library.SubTabMetrics

            if type(Count) ~= "number" or Count <= 0 then
                return 0
            end

            return Metrics.PadTop + Metrics.PadBottom + (Count * Metrics.Height) + ((Count - 1) * Metrics.Gap)
        end

        Library.GetSubTabOffset = function(self, Index)
            local Metrics = Library.SubTabMetrics
            return Metrics.PadTop + ((Index - 1) * (Metrics.Height + Metrics.Gap))
        end

        -- A page's body: the ScrollingFrame with the two columns Sections go into.
        -- Shared between Page and SubTab — both are "panes" with exactly the same
        -- content.
        Library.CreatePageBody = function(self, Items)
            Items["Page"] = Instances:Create("ScrollingFrame", {
                Parent = Library.UnusedHolder.Instance,
                Name = "\0",
                Visible = false,
                Active = true,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ElasticBehavior = Enum.ElasticBehavior.Never,
                ScrollBarThickness = 0,
                ScrollBarImageColor3 = Library.Theme["Accent"],
                BackgroundTransparency = 1,
                BorderColor3 = FromRGB(0, 0, 0),
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(0, 0, 0, 0)
            }):AddToTheme({ScrollBarImageColor3 = 'Accent'})

            -- Stacked layout: Sections go one below the other, at full width. The two
            -- side-by-side columns were removed — with sub-tabs the content is shorter
            -- and the second column spent most of its time empty.
            Items["Columns"] = Instances:Create("Frame", {
                Parent = Items["Page"].Instance,
                Name = "\0",
                BackgroundTransparency = 1,
                BorderColor3 = FromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y
            })

            Instances:Create("UIPadding", {
                Parent = Items["Columns"].Instance,
                Name = "\0",
                PaddingTop = UDimNew(0, 18),
                PaddingBottom = UDimNew(0, 18),
                PaddingRight = UDimNew(0, 16),
                PaddingLeft = UDimNew(0, 16)
            })

            Instances:Create("UIListLayout", {
                Parent = Items["Columns"].Instance,
                Name = "\0",
                Padding = UDimNew(0, 14),
                SortOrder = Enum.SortOrder.LayoutOrder
            })

            -- Aliases kept: `Side` on Sections became a no-op and everything lands in the
            -- same container, so older scripts keep working.
            Items["Column"] = Items["Columns"]
            Items["LeftColumn"] = Items["Columns"]
            Items["RightColumn"] = Items["Columns"]

            return Items
        end

        Library.Page = function(self, Data)
            Data = Data or { }

            local Page = {
                Window = self,

                Name = Data.Name or Data.name or "Page",
                Icon = Data.Icon or Data.icon or "rbxassetid://72196061405823",
                Category = Data.Category or Data.category or Data.Group or Data.group or "",

                Items = { },
                SubTabs = { },
                SectionCount = 0,

                Active = false,
                ChildActive = false,
                Expanded = false,
                Hovered = false,
                IsPane = true
            }

            local SidebarGroup = Page.Window:GetSidebarGroup(Page.Category)
            local Metrics = Library.SubTabMetrics

            local Items = { } do
                -- Wrapper: groups the tab button + the sub-tab accordion. It is what goes
                -- into the sidebar's UIListLayout (which is why the reordering LayoutOrder
                -- lives here, not on the button).
                Items["Wrapper"] = Instances:Create("Frame", {
                    Parent = SidebarGroup["Buttons"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["Wrapper"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Items["Inactive"] = Instances:Create("TextButton", {
                    Parent = Items["Wrapper"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = FromRGB(0, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 42),
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    TextSize = 14
                })

                Items["Background"] = Instances:Create("Frame", {
                    Parent = Items["Inactive"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Surface"]
                }):AddToTheme({BackgroundColor3 = 'Surface'})

                Instances:Create("UICorner", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 12)
                })

                Items["Stroke"] = Instances:Create("UIStroke", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    Color = Library.Theme["OutlineSoft"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Transparency = 1
                }):AddToTheme({Color = 'OutlineSoft'})

                Items["AccentBar"] = Instances:Create("Frame", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(0, 0.5),
                    Position = UDim2.new(0, 8, 0.5, 0),
                    Size = UDim2FromOffset(3, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Accent"],
                    BackgroundTransparency = 1
                }):AddToTheme({BackgroundColor3 = 'Accent'})

                Instances:Create("UICorner", {
                    Parent = Items["AccentBar"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(1, 0)
                })

                Items["Icon"] = Instances:Create("ImageLabel", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    ScaleType = Enum.ScaleType.Fit,
                    ImageTransparency = 0.35,
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(0, 0.5),
                    Image = Page.Icon,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 16, 0.5, 0),
                    Size = UDim2FromOffset(16, 16),
                    BorderSizePixel = 0
                }):AddToTheme({ImageColor3 = 'TextMuted'})

                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["TextMuted"],
                    TextTransparency = 0.22,
                    Text = Page.Name,
                    Size = UDim2.new(0, 0, 0, 15),
                    AnchorPoint = Vector2New(0, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 44, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 16,
                    TextXAlignment = Enum.TextXAlignment.Left
                }):AddToTheme({TextColor3 = 'TextMuted'})

                -- Chevron: only appears once the tab has sub-tabs. Rotates from 0° (closed)
                -- to 90° (open).
                Items["Chevron"] = Instances:Create("ImageLabel", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    Visible = false,
                    ScaleType = Enum.ScaleType.Fit,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Image = Library:ResolveIcon("chevron-right"),
                    ImageColor3 = Library.Theme["TextMuted"],
                    ImageTransparency = 0.45,
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2New(1, 0.5),
                    Position = UDim2.new(1, -14, 0.5, 0),
                    Size = UDim2FromOffset(14, 14),
                    BorderSizePixel = 0
                }):AddToTheme({ImageColor3 = 'TextMuted'})

                -- Accordion. ClipsDescendants + an animated height = a smooth expansion.
                Items["SubHolder"] = Instances:Create("Frame", {
                    Parent = Items["Wrapper"].Instance,
                    Name = "\0",
                    Visible = false,
                    ClipsDescendants = true,
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    LayoutOrder = 2,
                    Size = UDim2.new(1, 0, 0, 0)
                })

                Items["Rail"] = Instances:Create("Frame", {
                    Parent = Items["SubHolder"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Position = UDim2FromOffset(Metrics.RailX, 6),
                    Size = UDim2.new(0, 2, 1, -14),
                    BackgroundTransparency = 0.15,
                    BackgroundColor3 = Library.Theme["OutlineSoft"]
                }):AddToTheme({BackgroundColor3 = 'OutlineSoft'})

                Instances:Create("UICorner", {
                    Parent = Items["Rail"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(1, 0)
                })

                -- The marker that slides along the rail to the active sub-tab.
                Items["RailThumb"] = Instances:Create("Frame", {
                    Parent = Items["SubHolder"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Position = UDim2FromOffset(Metrics.RailX - 1, Metrics.PadTop),
                    Size = UDim2FromOffset(Metrics.ThumbWidth, Metrics.ThumbHeight),
                    BackgroundTransparency = 1,
                    BackgroundColor3 = Library.Theme["Accent"]
                }):AddToTheme({BackgroundColor3 = 'Accent'})

                Instances:Create("UICorner", {
                    Parent = Items["RailThumb"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(1, 0)
                })

                Items["SubList"] = Instances:Create("Frame", {
                    Parent = Items["SubHolder"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y
                })

                Items["SubListPadding"] = Instances:Create("UIPadding", {
                    Parent = Items["SubList"].Instance,
                    Name = "\0",
                    PaddingTop = UDimNew(0, Metrics.PadTop),
                    PaddingBottom = UDimNew(0, Metrics.PadBottom),
                    PaddingLeft = UDimNew(0, Metrics.IndentLeft),
                    PaddingRight = UDimNew(0, 0)
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["SubList"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, Metrics.Gap),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })

                Library:CreatePageBody(Items)

                Page.Items = Items
            end

            function Page:HasSubTabs()
                return #Page.SubTabs > 0
            end

            -- If the parent tab has Sections of its own, it stays a clickable pane even
            -- with sub-tabs. If it does not, clicking it only opens the accordion and
            -- activates the first sub.
            function Page:HasOwnContent()
                return (Page.SectionCount or 0) > 0
            end

            function Page:GetDefaultPane()
                if Page:HasSubTabs() and not Page:HasOwnContent() then
                    return Page.LastActiveSub or Page.SubTabs[1]
                end

                return Page
            end

            -- Repositions/resizes the accordion. `Animate` controls whether the height
            -- tweens or snaps (used in theme refreshes and sidebar collapse, where
            -- animating would be visual noise).
            function Page:RefreshSubHolder(Animate)
                local Count = #Page.SubTabs

                if Count == 0 then
                    Items["SubHolder"].Instance.Visible = false
                    Items["SubHolder"].Instance.Size = UDim2.new(1, 0, 0, 0)
                    return
                end

                local Detached = Page.Window.FlyoutPage == Page
                local Open = Page.Expanded and not Page.Window.IsSidebarCollapsed and not Detached
                local Height = Open and Library:GetSubHolderHeight(Count) or 0

                -- Stays visible at all times: what "hides" it is the zero height plus
                -- ClipsDescendants. Toggling Visible here would cut the closing animation in
                -- half.
                Items["SubHolder"].Instance.Visible = true

                if Animate then
                    Items["SubHolder"]:Tween(Library.AccordionTweenInfo, {Size = UDim2.new(1, 0, 0, Height)})
                else
                    Items["SubHolder"].Instance.Size = UDim2.new(1, 0, 0, Height)
                end

                Page:RefreshRailThumb(Animate)
            end

            function Page:RefreshRailThumb(Animate)
                local ActiveIndex

                for Index, SubTab in next, Page.SubTabs do
                    if SubTab.Active then
                        ActiveIndex = Index
                        break
                    end
                end

                local Show = ActiveIndex ~= nil and Page.Expanded and not Page.Window.IsSidebarCollapsed
                local TargetY = Library:GetSubTabOffset(ActiveIndex or 1) + ((Metrics.Height - Metrics.ThumbHeight) / 2)
                local Goal = {
                    Position = UDim2FromOffset(Metrics.RailX - 1, TargetY),
                    BackgroundTransparency = Show and 0 or 1
                }

                if Animate then
                    Items["RailThumb"]:Tween(Library.AccordionTweenInfo, Goal)
                else
                    Items["RailThumb"].Instance.Position = Goal.Position
                    Items["RailThumb"].Instance.BackgroundTransparency = Goal.BackgroundTransparency
                end
            end

            function Page:SetExpanded(Bool, Animate)
                Bool = Bool and true or false

                if not Page:HasSubTabs() then
                    Bool = false
                end

                Page.Expanded = Bool
                Page:RefreshSubHolder(Animate)

                if Animate then
                    Items["Chevron"]:Tween(Library.AccordionTweenInfo, {Rotation = Bool and 90 or 0})
                else
                    Items["Chevron"].Instance.Rotation = Bool and 90 or 0
                end
            end

            function Page:RefreshVisualState(Animate)
                local UseTween = Animate == true
                local Collapsed = Page.Window.IsSidebarCollapsed
                local Highlighted = Page.Active or Page.ChildActive

                local TextColor = (Highlighted or Page.Hovered) and Library.Theme.Text or Library.Theme.TextMuted
                local TextTransparency = Collapsed and 1 or (Highlighted and 0 or (Page.Hovered and 0.08 or 0.22))
                local IconColor = Highlighted and Library.Theme.Accent or (Page.Hovered and Library.Theme.Text or Library.Theme.TextMuted)
                local IconTransparency = Highlighted and 0 or (Page.Hovered and 0.08 or 0.3)
                local BackgroundTransparency = Collapsed and (Highlighted and 0.04 or (Page.Hovered and 0.18 or 1)) or (Highlighted and 0.08 or (Page.Hovered and 0.35 or 1))
                local StrokeTransparency = Collapsed and (Highlighted and 0.25 or (Page.Hovered and 0.55 or 1)) or (Highlighted and 0.4 or (Page.Hovered and 0.7 or 1))
                local AccentTransparency = Collapsed and 1 or (Highlighted and 0 or 1)
                local AccentHeight = Collapsed and 0 or (Highlighted and 18 or 0)
                local ChevronColor = Highlighted and Library.Theme.Accent or Library.Theme.TextMuted
                local ChevronTransparency = Collapsed and 1 or (Highlighted and 0.1 or (Page.Hovered and 0.25 or 0.45))

                Items["Page"].Instance.Visible = Page.Active
                Items["Page"].Instance.Parent = Page.Active and Page.Window.Items["Content"].Instance or Library.UnusedHolder.Instance

                Items["Text"]:ChangeItemTheme({TextColor3 = function()
                    return (Page.Active or Page.ChildActive or Page.Hovered) and Library.Theme.Text or Library.Theme.TextMuted
                end})
                Items["Icon"]:ChangeItemTheme({ImageColor3 = function()
                    return (Page.Active or Page.ChildActive) and Library.Theme.Accent or (Page.Hovered and Library.Theme.Text or Library.Theme.TextMuted)
                end})
                Items["Chevron"]:ChangeItemTheme({ImageColor3 = function()
                    return (Page.Active or Page.ChildActive) and Library.Theme.Accent or Library.Theme.TextMuted
                end})

                if UseTween then
                    Items["Background"]:Tween(nil, {BackgroundTransparency = BackgroundTransparency})
                    Items["Stroke"]:Tween(nil, {Transparency = StrokeTransparency})
                    Items["AccentBar"]:Tween(nil, {Size = UDim2FromOffset(3, AccentHeight), BackgroundTransparency = AccentTransparency})
                    Items["Text"]:Tween(nil, {TextColor3 = TextColor, TextTransparency = TextTransparency})
                    Items["Icon"]:Tween(nil, {ImageColor3 = IconColor, ImageTransparency = IconTransparency})
                    Items["Chevron"]:Tween(nil, {ImageColor3 = ChevronColor, ImageTransparency = ChevronTransparency})
                else
                    Items["Background"].Instance.BackgroundTransparency = BackgroundTransparency
                    Items["Stroke"].Instance.Transparency = StrokeTransparency
                    Items["AccentBar"].Instance.Size = UDim2FromOffset(3, AccentHeight)
                    Items["AccentBar"].Instance.BackgroundTransparency = AccentTransparency
                    Items["Text"].Instance.TextColor3 = TextColor
                    Items["Text"].Instance.TextTransparency = TextTransparency
                    Items["Icon"].Instance.ImageColor3 = IconColor
                    Items["Icon"].Instance.ImageTransparency = IconTransparency
                    Items["Chevron"].Instance.ImageColor3 = ChevronColor
                    Items["Chevron"].Instance.ImageTransparency = ChevronTransparency
                end

                Items["Chevron"].Instance.Visible = Page:HasSubTabs() and not Collapsed

                if type(Page.Window.RefreshSidebarPageLayout) == "function" then
                    Page.Window:RefreshSidebarPageLayout(Page)
                end
            end

            -- Called by Window:ActivatePane. Decides nothing — it only applies.
            function Page:SetActive(Bool, Animate)
                Page.Active = Bool and true or false

                if Page.Active then
                    Page.Hovered = false
                end

                Page:RefreshVisualState(Animate ~= false)
            end

            -- Compat: `Page:Turn(true)` was the old activation API.
            function Page:Turn(Bool)
                if Bool then
                    Page.Window:ActivatePane(Page)
                else
                    Page:SetActive(false)
                end
            end

            function Page:Select()
                Page.Window:ActivatePane(Page)
                return Page
            end

            Items["Inactive"]:Connect("MouseButton1Down", function()
                if Page:HasSubTabs() and Page.Window.IsSidebarCollapsed then
                    Page.Window:ToggleFlyout(Page)
                    return
                end

                Page.Window:CloseFlyout()

                if Page.Active or Page.ChildActive then
                    -- Already the active tab: do not collapse the accordion (the active pane
                    -- would be left with no indication at all in the sidebar).
                    return
                end

                Page.Window:ActivatePane(Page)
            end)

            Items["Inactive"]:Connect("MouseEnter", function()
                if Page.Active or Page.ChildActive then
                    return
                end

                Page.Hovered = true
                Page:RefreshVisualState(true)
            end)

            Items["Inactive"]:Connect("MouseLeave", function()
                if Page.Active or Page.ChildActive then
                    return
                end

                Page.Hovered = false
                Page:RefreshVisualState(true)
            end)

            Items["Wrapper"].Instance.LayoutOrder = #Page.Window.Pages + 1
            TableInsert(Page.Window.Pages, Page)
            Page.Window:RegisterPane(Page)

            Page.Window:RegisterVisualRefresher(function()
                Page:RefreshVisualState(false)
                Page:RefreshSubHolder(false)
            end)

            if not Page.Window.ActivePane then
                Page.Window:ActivatePane(Page)
            end

            if type(Page.Window.RefreshSidebarPageLayout) == "function" then
                Page.Window:RefreshSidebarPageLayout(Page)
            end

            return setmetatable(Page, Library.Pages)
        end
-- ============================================================
-- [ modulo: SubTab.lua ]
-- ============================================================


        -- ══════════════════════════════════════════════════════════════════
        -- Sub-tab: um pane filho de uma Page. Renderiza como um item indentado
        -- inside the parent tab's accordion and has exactly the same content APIs
        -- as a Page (:Section, :AddSection, ...).
        -- ══════════════════════════════════════════════════════════════════
        Library.Pages.SubTab = function(self, Data)
            Data = Data or { }

            -- Creating a sub-tab from another sub-tab adds a sibling, rather than
            -- trying to nest a third level.
            local Parent = self.IsSubTab and self.Parent or self

            if not Parent or not Parent.Window then
                return
            end

            local Metrics = Library.SubTabMetrics

            local SubTab = {
                Window = Parent.Window,
                Parent = Parent,

                Name = Data.Name or Data.name or "SubTab",

                Items = { },
                SectionCount = 0,

                Active = false,
                Hovered = false,
                IsPane = true,
                IsSubTab = true
            }

            local Index = #Parent.SubTabs + 1
            local Items = { } do
                Items["Inactive"] = Instances:Create("TextButton", {
                    Parent = Parent.Items["SubList"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = FromRGB(0, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, Metrics.Height),
                    BorderSizePixel = 0,
                    LayoutOrder = Index,
                    TextSize = 14
                })

                Items["Background"] = Instances:Create("Frame", {
                    Parent = Items["Inactive"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})

                Instances:Create("UICorner", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 9)
                })

                Items["Stroke"] = Instances:Create("UIStroke", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    Color = Library.Theme["OutlineSoft"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Transparency = 1
                }):AddToTheme({Color = 'OutlineSoft'})

                -- A sub-tab is text only: the parent tab's icon plus the rail already
                -- give the hierarchy, and a second indented icon only clutters.
                local TextOffset = 12

                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["TextMuted"],
                    TextTransparency = 0.3,
                    Text = SubTab.Name,
                    Size = UDim2.new(1, -(TextOffset + 10), 0, 14),
                    AnchorPoint = Vector2New(0, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, TextOffset, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left
                }):AddToTheme({TextColor3 = 'TextMuted'})

                Library:CreatePageBody(Items)

                SubTab.Items = Items
            end

            function SubTab:HasSubTabs()
                return false
            end

            function SubTab:HasOwnContent()
                return true
            end

            function SubTab:GetDefaultPane()
                return SubTab
            end

            function SubTab:RefreshVisualState(Animate)
                local UseTween = Animate == true

                local TextColor = (SubTab.Active or SubTab.Hovered) and Library.Theme.Text or Library.Theme.TextMuted
                local TextTransparency = SubTab.Active and 0 or (SubTab.Hovered and 0.1 or 0.3)
                local BackgroundTransparency = SubTab.Active and 0.06 or (SubTab.Hovered and 0.42 or 1)
                local StrokeTransparency = SubTab.Active and 0.5 or 1

                Items["Page"].Instance.Visible = SubTab.Active
                Items["Page"].Instance.Parent = SubTab.Active and SubTab.Window.Items["Content"].Instance or Library.UnusedHolder.Instance

                Items["Text"]:ChangeItemTheme({TextColor3 = function()
                    return (SubTab.Active or SubTab.Hovered) and Library.Theme.Text or Library.Theme.TextMuted
                end})

                if UseTween then
                    Items["Background"]:Tween(nil, {BackgroundTransparency = BackgroundTransparency})
                    Items["Stroke"]:Tween(nil, {Transparency = StrokeTransparency})
                    Items["Text"]:Tween(nil, {TextColor3 = TextColor, TextTransparency = TextTransparency})
                else
                    Items["Background"].Instance.BackgroundTransparency = BackgroundTransparency
                    Items["Stroke"].Instance.Transparency = StrokeTransparency
                    Items["Text"].Instance.TextColor3 = TextColor
                    Items["Text"].Instance.TextTransparency = TextTransparency
                end
            end

            function SubTab:SetActive(Bool, Animate)
                SubTab.Active = Bool and true or false

                if SubTab.Active then
                    SubTab.Hovered = false
                    Parent.LastActiveSub = SubTab
                end

                SubTab:RefreshVisualState(Animate ~= false)
            end

            function SubTab:Turn(Bool)
                if Bool then
                    SubTab.Window:ActivatePane(SubTab)
                else
                    SubTab:SetActive(false)
                end
            end

            function SubTab:Select()
                SubTab.Window:ActivatePane(SubTab)
                return SubTab
            end

            Items["Inactive"]:Connect("MouseButton1Down", function()
                SubTab.Window:CloseFlyout()

                if SubTab.Active then
                    return
                end

                SubTab.Window:ActivatePane(SubTab)
            end)

            Items["Inactive"]:Connect("MouseEnter", function()
                if SubTab.Active then
                    return
                end

                SubTab.Hovered = true
                SubTab:RefreshVisualState(true)
            end)

            Items["Inactive"]:Connect("MouseLeave", function()
                if SubTab.Active then
                    return
                end

                SubTab.Hovered = false
                SubTab:RefreshVisualState(true)
            end)

            TableInsert(Parent.SubTabs, SubTab)
            SubTab.Window:RegisterPane(SubTab)

            SubTab.Window:RegisterVisualRefresher(function()
                SubTab:RefreshVisualState(false)
            end)

            -- The parent tab gained a chevron: its text has to truncate so it does
            -- not run underneath it.
            if Parent.Items["Text"] then
                Parent.Items["Text"].Instance.AutomaticSize = Enum.AutomaticSize.None
                Parent.Items["Text"].Instance.TextTruncate = Enum.TextTruncate.AtEnd
                Parent.Items["Text"].Instance.Size = UDim2.new(1, -76, 0, 15)
            end

            Parent:RefreshVisualState(false)

            -- If the parent was already the active pane but has no content of its
            -- own, the real content becomes this first sub-tab.
            if Parent.Active and not Parent:HasOwnContent() then
                SubTab.Window:ActivatePane(SubTab)
            elseif Parent.Active or Parent.ChildActive then
                -- The parent tab is already active (with its own content): its accordion
                -- is born open.
                Parent:SetExpanded(true, false)
            else
                Parent:RefreshSubHolder(false)
            end

            return setmetatable(SubTab, Library.Pages)
        end
-- ============================================================
-- [ modulo: Section.lua ]
-- ============================================================


        Library.Pages.Section = function(self, Data)
            Data = Data or { }

            -- Used by the accordion: a tab with content of its own stays clickable
            -- even after it gains sub-tabs.
            self.SectionCount = (self.SectionCount or 0) + 1

            local Section = {
                Window = self.Window,
                Page = self,

                Name = Data.Name or Data.name or "Section",
                -- `Side` became a no-op when the page moved to a single stacked column.
                -- Still accepted so no script breaks.
                Side = Data.Side or Data.side or 1,
                Icon = Data.Icon or Data.icon or "rbxassetid://127136375066593",

                Items = { }
            }

            local ColumnParent = Section.Page.Items["Column"] or Section.Page.Items["LeftColumn"]

            local Items = { } do
                Items["SectionOutline"] = Instances:Create("Frame", {
                    Parent = ColumnParent.Instance,
                    Name = "\0",
                    -- With everything in one container, creation order has to be explicit:
                    -- the UIListLayout breaks equal LayoutOrder ties by Name, and every Name
                    -- here is "\0".
                    LayoutOrder = self.SectionCount,
                    Size = UDim2.new(1, 0, 0, 48),
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Library.Theme["OutlineSoft"]
                }):AddToTheme({BackgroundColor3 = 'OutlineSoft'})

                Instances:Create("UICorner", {
                    Parent = Items["SectionOutline"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 16)
                })

                Items["Section"] = Instances:Create("Frame", {
                    Parent = Items["SectionOutline"].Instance,
                    Name = "\0",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, -2, 1, -2),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Surface"]
                }):AddToTheme({BackgroundColor3 = 'Surface'})

                Instances:Create("UICorner", {
                    Parent = Items["Section"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 15)
                })

                Items["Top"] = Instances:Create("Frame", {
                    Parent = Items["Section"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 0, 40),
                    BorderSizePixel = 0
                })

                -- No icon badge: a section title is text only. `Data.Icon` is still
                -- accepted (and ignored) so scripts that already pass one do not break.
                --
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Top"].Instance,
                    Name = "\0",
                    FontFace = Library.TitleFont or Library.Font,
                    TextWrapped = true,
                    TextColor3 = Library.Theme["Text"],
                    TextTransparency = 0,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = Section.Name,
                    Size = UDim2.new(0, 0, 0, 14),
                    AnchorPoint = Vector2New(0, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 16, 0.5, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left
                }):AddToTheme({TextColor3 = 'Text'})

                Instances:Create("Frame", {
                    Parent = Items["Top"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(0, 1),
                    Position = UDim2.new(0, 16, 1, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, -32, 0, 1),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["OutlineSoft"]
                }):AddToTheme({BackgroundColor3 = 'OutlineSoft'})

                Items["Content"] = Instances:Create("Frame", {
                    Parent = Items["Section"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 40),
                    Size = UDim2.new(1, 0, 0, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.Y
                })

                Instances:Create("UIPadding", {
                    Parent = Items["Content"].Instance,
                    Name = "\0",
                    PaddingTop = UDimNew(0, 12),
                    PaddingBottom = UDimNew(0, 14),
                    PaddingRight = UDimNew(0, 16),
                    PaddingLeft = UDimNew(0, 16)
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["Content"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, 8),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })                

                Section.Items = Items
            end

            return setmetatable(Section, Library.Sections)
        end
-- ============================================================
-- [ modulo: Toggle.lua ]
-- ============================================================


        Library.Sections.Toggle = function(self, Data)
            Data = Data or { }

            local Toggle = {
                Window = self.Window,
                Page = self.Page,
                Section = self,

                Name = Data.Name or Data.name or "Toggle",
                Flag = Data.Flag or Data.flag or Library:NextFlag(),
                Default = Data.Default or Data.default or false,
                Callback = Data.Callback or Data.callback or function() end,
                SkipInitialCallback = Data.SkipInitialCallback or Data.skipinitialcallback or Data.SkipCallbackOnInit or Data.skipcallbackoninit or false,

                Value = false
            }

            local Items = { } do
                -- Adaptive: a taller row on mobile for a bigger hit area
                local _isMobileToggle = Library:IsMobileClient()
                local _toggleRowY = _isMobileToggle and 28 or 20

                Items["Toggle"] = Instances:Create("TextButton", {
                    Parent = Toggle.Section.Items["Content"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = FromRGB(0, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    AnchorPoint = Vector2New(1, 0),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, _toggleRowY),
                    BorderSizePixel = 0,
                    TextSize = 14
                })
                
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Toggle"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    TextTransparency = 0.5,
                    Text = Toggle.Name,
                    Size = UDim2.new(1, -43, 0, 15),
                    AnchorPoint = Vector2New(0, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})

                Items["SubElements"] = Instances:Create("Frame", {
                    Parent = Items["Toggle"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(1, 0),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -45, 0, 0),
                    Size = UDim2.new(0, 0, 1, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X
                })

                Instances:Create("UIListLayout", {
                    Parent = Items["SubElements"].Instance,
                    Name = "\0",
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    Padding = UDimNew(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })
                
                -- Adaptive: a bigger switch on mobile (44x24) vs PC (35x18)
                local _indW = _isMobileToggle and 44 or 35
                local _indH = _isMobileToggle and 24 or 18

                Items["Indicator"] = Instances:Create("Frame", {
                    Parent = Items["Toggle"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0, _indW, 0, _indH),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})
                
                Instances:Create("UICorner", {
                    Parent = Items["Indicator"].Instance,
                    Name = "\0"
                })
                
                Instances:Create("UIStroke", {
                    Parent = Items["Indicator"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})
                
                Items["Circle"] = Instances:Create("Frame", {
                    Parent = Items["Indicator"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(0, 0.5),
                    BackgroundTransparency = 0.5,
                    Position = UDim2.new(0, 4, 0.5, 0),
                    Size = UDim2.new(0, 10, 0, 10),
                    BorderSizePixel = 0
                }):AddToTheme({BackgroundColor3 = 'TextMuted'})
                
                Instances:Create("UICorner", {
                    Parent = Items["Circle"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(1, 0)
                })
                
                Items["Glow"] = Instances:Create("ImageLabel", {
                    Parent = Items["Circle"].Instance,
                    Name = "\0",
                    ImageColor3 = Library.Theme["Accent"],
                    ScaleType = Enum.ScaleType.Slice,
                    ImageTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 25, 1, 25),
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Image = "http://www.roblox.com/asset/?id=18245826428",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    BorderSizePixel = 0,
                    SliceCenter = RectNew(Vector2New(21, 21), Vector2New(79, 79))
                }):AddToTheme({ImageColor3 = 'Accent'})                
            end

            function Toggle:Get()
                return Toggle.Value 
            end

            local function UpdateToggleLayout()
                local ToggleWidth = Items["Toggle"].Instance.AbsoluteSize.X
                if ToggleWidth <= 0 then
                    return
                end

                local IndicatorWidth = MathFloor(math.max(Items["Indicator"].Instance.AbsoluteSize.X, 35))
                local SubElementsWidth = MathFloor(math.max(Items["SubElements"].Instance.AbsoluteSize.X, 0))
                local Gap = 8
                local RightReserve = IndicatorWidth + Gap

                if SubElementsWidth > 0 then
                    Items["SubElements"].Instance.Position = UDim2.new(1, -RightReserve, 0, 0)
                    RightReserve = RightReserve + SubElementsWidth + Gap
                else
                    Items["SubElements"].Instance.Position = UDim2.new(1, -RightReserve, 0, 0)
                end

                Items["Text"].Instance.Size = UDim2FromOffset(math.max(ToggleWidth - RightReserve, 0), 15)
            end

            local function ApplyToggleVisualState(Animate)
                local UseTween = Animate == true

                if Toggle.Value then
                    Items["Circle"]:ChangeItemTheme({BackgroundColor3 = "AccentText"})
                    Items["Indicator"]:ChangeItemTheme({BackgroundColor3 = "Accent"})

                    if UseTween then
                        Items["Glow"]:Tween(nil, {ImageTransparency = 1})
                        -- Subtle bounce when switching on (Back easing gives a slight overshoot)
                        Items["Circle"]:Tween(TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            AnchorPoint = Vector2New(1, 0.5),
                            Position = UDim2.new(1, -3, 0.5, 0),
                            BackgroundTransparency = 0,
                            BackgroundColor3 = Library.Theme.AccentText
                        })
                        Items["Indicator"]:Tween(nil, {BackgroundColor3 = Library.Theme.Accent})
                        Items["Text"]:Tween(nil, {TextTransparency = 0})
                    else
                        Items["Glow"].Instance.ImageTransparency = 1
                        Items["Circle"].Instance.AnchorPoint = Vector2New(1, 0.5)
                        Items["Circle"].Instance.Position = UDim2.new(1, -3, 0.5, 0)
                        Items["Circle"].Instance.BackgroundTransparency = 0
                        Items["Circle"].Instance.BackgroundColor3 = Library.Theme.AccentText
                        Items["Indicator"].Instance.BackgroundColor3 = Library.Theme.Accent
                        Items["Text"].Instance.TextTransparency = 0
                    end
                else
                    Items["Circle"]:ChangeItemTheme({BackgroundColor3 = "TextMuted"})
                    Items["Indicator"]:ChangeItemTheme({BackgroundColor3 = "Element"})

                    if UseTween then
                        Items["Glow"]:Tween(nil, {ImageTransparency = 1})
                        Items["Circle"]:Tween(TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            AnchorPoint = Vector2New(0, 0.5),
                            Position = UDim2.new(0, 3, 0.5, 0),
                            BackgroundTransparency = 0,
                            BackgroundColor3 = Library.Theme.TextMuted
                        })
                        Items["Indicator"]:Tween(nil, {BackgroundColor3 = Library.Theme.Element})
                        Items["Text"]:Tween(nil, {TextTransparency = 0.5})
                    else
                        Items["Glow"].Instance.ImageTransparency = 1
                        Items["Circle"].Instance.AnchorPoint = Vector2New(0, 0.5)
                        Items["Circle"].Instance.Position = UDim2.new(0, 3, 0.5, 0)
                        Items["Circle"].Instance.BackgroundTransparency = 0
                        Items["Circle"].Instance.BackgroundColor3 = Library.Theme.TextMuted
                        Items["Indicator"].Instance.BackgroundColor3 = Library.Theme.Element
                        Items["Text"].Instance.TextTransparency = 0.5
                    end
                end
            end

            function Toggle:Set(Value, SuppressCallback)
                Toggle.Value = Value and true or false
                Library.Flags[Toggle.Flag] = Toggle.Value

                ApplyToggleVisualState(true)

                if not SuppressCallback and Toggle.Callback then 
                    Library:SafeCall(Toggle.Callback, Toggle.Value)
                end
            end

            Toggle.Window:RegisterVisualRefresher(function()
                ApplyToggleVisualState(false)
            end)

            function Toggle:SetVisibility(Bool)
                Items["Toggle"].Instance.Visible = Bool 
            end

            function Toggle:Colorpicker(Data)
                Data = Data or { }

                -- nil must stay nil all the way to CreateColorpicker: that is where
                -- the default is decided. An `or false` here would switch the bar off
                -- every time the field was omitted.
                local AlphaOption = Data.Alpha

                if AlphaOption == nil then
                    AlphaOption = Data.alpha
                end

                local Colorpicker = {
                    Window = Toggle.Window,
                    Page = Toggle.Page,
                    Section = Toggle.Section,

                    Flag = Data.Flag or Data.flag or Library:NextFlag(),
                    Default = Data.Default or Data.default or Color3.fromRGB(255, 255, 255),
                    Callback = Data.Callback or Data.callback or function() end,
                    Alpha = AlphaOption
                }

                local NewColorpicker, ColorpickerItems = Library:CreateColorpicker({
                    Parent = Items["SubElements"],
                    Page = Colorpicker.Page,
                    Section = Colorpicker.Section,
                    Flag = Colorpicker.Flag,
                    Default = Colorpicker.Default,
                    Callback = Colorpicker.Callback,
                    Alpha = Colorpicker.Alpha
                })

                return NewColorpicker
            end

            function Toggle:Keybind(Data)
                Data = Data or { }

                local Keybind = {
                    Window = Toggle.Window,
                    Page = Toggle.Page,
                    Section = Toggle.Section,

                    Flag = Data.Flag or Data.flag or Library:NextFlag(),
                    Default = Data.Default or Data.default or Enum.KeyCode.E,
                    Callback = Data.Callback or Data.callback or function() end,
                    Mode = Data.Mode or Data.mode or "Toggle"
                }

                local NewKeybind, KeybindItems = Library:CreateKeybind({
                    Parent = Items["SubElements"],
                    Page = Keybind.Page,
                    Section = Keybind.Section,
                    Name = Toggle.Name,
                    Flag = Keybind.Flag,
                    Default = Keybind.Default,
                    Mode = Keybind.Mode,
                    Callback = Keybind.Callback
                })

                return NewKeybind
            end

            Items["Toggle"]:Connect("MouseButton1Down", function()
                Toggle:Set(not Toggle.Value)
            end)

            -- Right-click any toggle → lazy-attach a keybind, start key picking
            -- and open the Toggle/Hold/Always mode picker. The keybind drives
            -- the toggle: pressing the bound key flips/holds the toggle state.
            Items["Toggle"]:Connect("MouseButton2Down", function()
                if not Toggle._RightClickKeybind then
                    Toggle._RightClickKeybind = Toggle:Keybind({
                        Default = Enum.KeyCode.Backspace,  -- internal lib alias for "None"
                        Mode = "Toggle",
                        Callback = function(state)
                            Toggle:Set(state == true)
                        end,
                    })
                end
                local kb = Toggle._RightClickKeybind
                if kb then
                    if kb.SetOpen then kb:SetOpen(true) end
                    if kb.StartPicking then kb:StartPicking() end
                end
            end)

            Library:Connect(Items["Toggle"].Instance:GetPropertyChangedSignal("AbsoluteSize"), UpdateToggleLayout)
            Library:Connect(Items["SubElements"].Instance:GetPropertyChangedSignal("AbsoluteSize"), UpdateToggleLayout)
            task.defer(UpdateToggleLayout)

            Toggle:Set(Toggle.Default, Toggle.SkipInitialCallback)

            Library.SetFlags[Toggle.Flag] = function(Value)
                Toggle:Set(Value)
            end

            return Toggle 
        end

-- ============================================================
-- [ modulo: Button.lua ]
-- ============================================================

        Library.Sections.Button = function(self, Data)
            Data = Data or { }

            local Button = {
                Window = self.Window,
                Page = self.Page,
                Section = self,

                Name = Data.Name or Data.name or "Button",
                Callback = Data.Callback or Data.callback or function() end
            }

            local Items = { } do 
                Items["Button"] = Instances:Create("TextButton", {
                    Parent = Button.Section.Items["Content"].Instance,
                    Name = "\0",
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 30),
                    Selectable = false,
                    Active = false,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})
                
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = Button.Name,
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Size = UDim2.new(0, 0, 0, 15),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})
                
                Instances:Create("UICorner", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })
                
                Items["Stroke"] = Instances:Create("UIStroke", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})
                
                Items["Icon"] = Instances:Create("ImageLabel", {
                    Parent = Items["Button"].Instance,
                    Name = "\0",
                    ImageColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0, 16, 0, 16),
                    AnchorPoint = Vector2New(1, 0.5),
                    Image = "rbxassetid://117716971575946",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -6, 0.5, 0),
                    ZIndex = 2,
                    BorderSizePixel = 0
                }):AddToTheme({ImageColor3 = 'Text'})                
            end 

            function Button:SetVisibility(Bool)
                Items["Button"].Instance.Visible = Bool
            end

            function Button:Press()
                local ActiveLibrary = Library
                if type(ActiveLibrary) ~= "table" or ActiveLibrary.Unloading or ActiveLibrary.Unloaded then
                    return
                end

                -- Press feedback: stroke flash + UIScale punch (cheap, 1 tween each)
                Items["Stroke"]:ChangeItemTheme({Color = "Accent"})
                Items["Stroke"]:Tween(nil, {Color = ActiveLibrary.Theme.Accent})

                local PressScale = Items["Button"].Instance:FindFirstChildOfClass("UIScale")
                if not PressScale then
                    PressScale = Instance.new("UIScale")
                    PressScale.Parent = Items["Button"].Instance
                end
                PressScale.Scale = 0.96
                TweenService:Create(PressScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

                task.wait(0.1)

                if ActiveLibrary.Unloading or ActiveLibrary.Unloaded then
                    return
                end

                ActiveLibrary:SafeCall(Button.Callback)
                Items["Stroke"]:ChangeItemTheme({Color = "Outline"})
                Items["Stroke"]:Tween(nil, {Color = ActiveLibrary.Theme.Outline})
            end

            -- Hover feedback: stroke acende sutilmente
            Items["Button"]:Connect("MouseEnter", function()
                Items["Button"]:Tween(TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme["Accent"]:Lerp(Library.Theme["Element"], 0.85)})
            end)
            Items["Button"]:Connect("MouseLeave", function()
                Items["Button"]:Tween(TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme["Element"]})
            end)

            Items["Button"]:Connect("MouseButton1Down", function()
                Button:Press()
            end)

            return Button
        end

-- ============================================================
-- [ modulo: Slider.lua ]
-- ============================================================

        Library.Sections.Slider = function(self, Data)
            Data = Data or { }

            local Slider = {
                Window = self.Window,
                Page = self.Page,
                Section = self,

                Name = Data.Name or Data.name or "Slider",
                Flag = Data.Flag or Data.flag or Library:NextFlag(),
                Min = Data.Min or Data.min or 0,
                Default = Data.Default or Data.default or 0,
                Max = Data.Max or Data.max or 100,
                Suffix = Data.Suffix or Data.suffix or "",
                Decimals = Data.Decimals or Data.decimals or 1,
                Callback = Data.Callback or Data.callback or function() end,

                Value = 0,
                Sliding = false
            }

            local Items = { } do 
                Items["Slider"] = Instances:Create("Frame", {
                    Parent = Slider.Section.Items["Content"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 0, 42),
                    BorderSizePixel = 0
                })
                
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Slider"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = Slider.Name,
                    AnchorPoint = Vector2New(0, 0.5),
                    Size = UDim2.new(0, 0, 0, 15),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0.5, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})
                
                -- Adaptive: a taller bar on mobile for a bigger hit area (touch-friendly).
                -- PC keeps 9px (precise with a mouse). Mobile 24px (finger width).
                local _isMobileSlider = Library:IsMobileClient()
                local _sliderBarY = _isMobileSlider and 24 or 9

                Items["RealSlider"] = Instances:Create("TextButton", {
                    Parent = Items["Slider"].Instance,
                    Name = "\0",
                    Active = false,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    AnchorPoint = Vector2New(1, 0.5),
                    Position = UDim2.new(1, -40, 0.5, 0),
                    Size = UDim2.new(0, 200, 0, _sliderBarY),
                    Selectable = false,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})
                
                Instances:Create("UICorner", {
                    Parent = Items["RealSlider"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })
                
                Instances:Create("UIStroke", {
                    Parent = Items["RealSlider"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})
                
                Items["Accent"] = Instances:Create("Frame", {
                    Parent = Items["RealSlider"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0.6000000238418579, 0, 1, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Accent"]
                }):AddToTheme({BackgroundColor3 = 'Accent'})
                
                Instances:Create("UICorner", {
                    Parent = Items["Accent"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })
                
                Items["Glow"] = Instances:Create("ImageLabel", {
                    Parent = Items["Accent"].Instance,
                    Name = "\0",
                    ImageColor3 = Library.Theme["Accent"],
                    ScaleType = Enum.ScaleType.Slice,
                    ImageTransparency = 0.800000011920929,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 25, 1, 25),
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Image = "http://www.roblox.com/asset/?id=18245826428",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    ZIndex = 2,
                    BorderSizePixel = 0,
                    SliceCenter = RectNew(Vector2New(21, 21), Vector2New(79, 79))
                }):AddToTheme({ImageColor3 = 'Accent'})
                
                Items["Dragger"] = Instances:Create("Frame", {
                    Parent = Items["Accent"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(0, 0.5),
                    Position = UDim2.new(1, -4, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0, 13, 0, 13),
                    BorderSizePixel = 0
                })
                
                Instances:Create("UICorner", {
                    Parent = Items["Dragger"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })
                
                Items["Glow2"] = Instances:Create("ImageLabel", {
                    Parent = Items["Dragger"].Instance,
                    Name = "\0",
                    ImageColor3 = Library.Theme["Accent"],
                    ScaleType = Enum.ScaleType.Slice,
                    ImageTransparency = 0.800000011920929,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 25, 1, 25),
                    AnchorPoint = Vector2New(0.5, 0.5),
                    Image = "http://www.roblox.com/asset/?id=18245826428",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    ZIndex = 2,
                    BorderSizePixel = 0,
                    SliceCenter = RectNew(Vector2New(21, 21), Vector2New(79, 79))
                }):AddToTheme({ImageColor3 = 'Accent'})
                
                Items["Value"] = Instances:Create("TextLabel", {
                    Parent = Items["Slider"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    TextTransparency = 0.5,
                    Text = "50%",
                    Size = UDim2.new(0, 0, 0, 15),
                    AnchorPoint = Vector2New(1, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, 0, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})                
            end

            function Slider:Get()
                return Slider.Value 
            end

            local ReservedValueWidth = 0

            local function GetSliderDisplayText(Value)
                return StringFormat("%s%s", Library:Round(Value, Slider.Decimals), Slider.Suffix)
            end

            local function RefreshReservedValueWidth()
                local CurrentText = Items["Value"].Instance.Text
                local Width = 0
                local Samples = {
                    Slider.Min,
                    Slider.Max,
                    Slider.Default,
                    Slider.Value
                }

                for _, Sample in next, Samples do
                    if Sample ~= nil then
                        Items["Value"].Instance.Text = GetSliderDisplayText(Sample)
                        Width = math.max(Width, Items["Value"].Instance.TextBounds.X)
                    end
                end

                Items["Value"].Instance.Text = CurrentText
                ReservedValueWidth = MathFloor(math.max(Width + 4, 32))
                Items["Value"].Instance.Size = UDim2FromOffset(ReservedValueWidth, 15)
            end

            local function UpdateSliderLayout()
                local SliderWidth = Items["Slider"].Instance.AbsoluteSize.X
                if SliderWidth <= 0 then
                    return
                end

                local TextWidth = MathFloor(math.max(Items["Text"].Instance.AbsoluteSize.X, Items["Text"].Instance.TextBounds.X))
                local ValueWidth = ReservedValueWidth > 0 and ReservedValueWidth or MathFloor(math.max(Items["Value"].Instance.AbsoluteSize.X, Items["Value"].Instance.TextBounds.X))
                local InlineGap = 12
                local MinimumTrackWidth = 110

                local InlineTrackWidth = SliderWidth - TextWidth - ValueWidth - (InlineGap * 2)
                local UseStackedLayout = InlineTrackWidth < MinimumTrackWidth

                if UseStackedLayout then
                    Items["Slider"].Instance.Size = UDim2.new(1, 0, 0, 42)

                    Items["Text"].Instance.AnchorPoint = Vector2New(0, 0)
                    Items["Text"].Instance.Position = UDim2.new(0, 0, 0, 0)

                    Items["Value"].Instance.AnchorPoint = Vector2New(1, 0)
                    Items["Value"].Instance.Position = UDim2.new(1, 0, 0, 0)

                    Items["RealSlider"].Instance.AnchorPoint = Vector2New(0, 0)
                    Items["RealSlider"].Instance.Position = UDim2FromOffset(0, 28)
                    Items["RealSlider"].Instance.Size = UDim2.new(1, 0, 0, 9)
                else
                    local TrackX = TextWidth + InlineGap
                    local TrackWidth = math.max(MinimumTrackWidth, InlineTrackWidth)

                    Items["Slider"].Instance.Size = UDim2.new(1, 0, 0, 20)

                    Items["Text"].Instance.AnchorPoint = Vector2New(0, 0.5)
                    Items["Text"].Instance.Position = UDim2.new(0, 0, 0.5, 0)

                    Items["Value"].Instance.AnchorPoint = Vector2New(1, 0.5)
                    Items["Value"].Instance.Position = UDim2.new(1, 0, 0.5, 0)

                    Items["RealSlider"].Instance.AnchorPoint = Vector2New(0, 0.5)
                    Items["RealSlider"].Instance.Position = UDim2.new(0, TrackX, 0.5, 0)
                    Items["RealSlider"].Instance.Size = UDim2FromOffset(TrackWidth, 9)
                end
            end

            function Slider:SetVisibility(Bool)
                Items["Slider"].Instance.Visible = Bool
            end

            function Slider:Set(Value)
                -- Stale autoload configs can pass a table here (e.g. a flag
                -- name that used to belong to a multi-select dropdown and
                -- now belongs to a slider). Coerce or fall back to Default
                -- so the entire config load doesn't blow up on one bad key.
                if type(Value) ~= "number" then
                    Value = tonumber(Value) or Slider.Default or Slider.Min
                end
                Slider.Value = Library:Round(MathClamp(Value, Slider.Min, Slider.Max), Slider.Decimals)
                Library.Flags[Slider.Flag] = Slider.Value

                Items["Value"].Instance.Text = GetSliderDisplayText(Slider.Value)

                Items["Accent"]:Tween(TweenInfo.new(Library.Tween.Time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1, 0)})

                if Slider.Callback then 
                    Library:SafeCall(Slider.Callback, Slider.Value)
                end
            end

            local InputChanged 
            
            Items["RealSlider"]:Connect("InputBegan", function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    Slider.Sliding = true

                    local SizeX = (Input.Position.X - Items["RealSlider"].Instance.AbsolutePosition.X) / Items["RealSlider"].Instance.AbsoluteSize.X
                    local Value = ((Slider.Max - Slider.Min) * SizeX) + Slider.Min

                    Slider:Set(Value)

                    if InputChanged then
                        return
                    end

                    InputChanged = Input.Changed:Connect(function()
                        if Input.UserInputState == Enum.UserInputState.End then
                            Slider.Sliding = false

                            InputChanged:Disconnect()
                            InputChanged = nil
                        end
                    end)
                end
            end)

            Library:Connect(UserInputService.InputChanged, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                    if Slider.Sliding then
                        local SizeX = (Input.Position.X - Items["RealSlider"].Instance.AbsolutePosition.X) / Items["RealSlider"].Instance.AbsoluteSize.X
                        local Value = ((Slider.Max - Slider.Min) * SizeX) + Slider.Min

                        Slider:Set(Value)
                    end
                end
            end)

            RefreshReservedValueWidth()
            Library:Connect(Items["Slider"].Instance:GetPropertyChangedSignal("AbsoluteSize"), UpdateSliderLayout)
            task.defer(UpdateSliderLayout)

            if Slider.Default then
                Slider:Set(Slider.Default)
            end

            Library.SetFlags[Slider.Flag] = function(Value)
                Slider:Set(Value)
            end

            return Slider 
        end

-- ============================================================
-- [ modulo: Dropdown.lua ]
-- ============================================================

        Library.Sections.Dropdown = function(self, Data)
            Data = Data or { }

            local Dropdown = {
                Window = self.Window,
                Page = self.Page,
                Section = self,

                Name = Data.Name or Data.name or "Dropdown",
                Flag = Data.Flag or Data.flag or Library:NextFlag(),
                Items = Data.Items or Data.items or { "One", "Two", "Three" },
                Default = Data.Default or Data.default or nil,
                Callback = Data.Callback or Data.callback or function() end,
                Multi = Data.Multi or Data.multi or false,
                -- Only meaningful with Multi. Turns the dropdown from a SET into a QUEUE:
                -- it numbers each selected item with its position, and the position is the
                -- order you clicked in.
                --
                -- The order already existed — `Dropdown.Value` is an array and a click does
                -- `TableInsert` at the end — it just never showed anywhere. Without seeing
                -- the number, building a queue was trial and error: two identical ticks do
                -- not say whether "Boss" came before or after "Quests".
                Ranked = Data.Ranked or Data.ranked or false,
                -- Search is always visible now, so the threshold became a no-op. Still
                -- accepted so it does not break scripts that already pass it.
                SearchThreshold = Data.SearchThreshold or Data.searchthreshold or 6,

                Value = { },
                Options = { },
                -- A value that arrived before the option existed in the list. Held here
                -- until a `Refresh` brings the option in. See `Set`.
                Pending = nil,
                IsOpen = false
            }

            -- Inline drawer metrics (opens below the field, pushing the section's
            -- following elements down — it is no longer a side panel).
            local DrawerPad = 8
            local DrawerGap = 6
            local SearchHeight = 30
            local SearchGap = 8
            local OptionHeight = 32
            local OptionGap = 6
            local MaxListHeight = 184 -- exactly 5 options; the rest scrolls
            local ListTop = DrawerPad + SearchHeight + SearchGap

            local HeaderHeight = 52
            local UseStackedLayout = true
            local FieldWidth = 0

            local Items = { } do
                Items["Dropdown"] = Instances:Create("Frame", {
                    Parent = Dropdown.Section.Items["Content"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 0, 52),
                    BorderSizePixel = 0
                })

                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Dropdown"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = Dropdown.Name,
                    AnchorPoint = Vector2New(0, 0),
                    Size = UDim2.new(0, 0, 0, 15),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})

                Items["RealDropdown"] = Instances:Create("TextButton", {
                    Parent = Items["Dropdown"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = FromRGB(0, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    AnchorPoint = Vector2New(0, 0),
                    Position = UDim2.new(0, 0, 0, 22),
                    Size = UDim2.new(1, 0, 0, 30),
                    BorderSizePixel = 0,
                    TextSize = 14,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})

                Instances:Create("UICorner", {
                    Parent = Items["RealDropdown"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })

                Items["Stroke"] = Instances:Create("UIStroke", {
                    Parent = Items["RealDropdown"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})

                Items["Value"] = Instances:Create("TextLabel", {
                    Parent = Items["RealDropdown"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    TextTransparency = 0.5,
                    Text = "--",
                    Size = UDim2.new(1, -40, 0, 15),
                    AnchorPoint = Vector2New(0, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextWrapped = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})

                Items["Icon"] = Instances:Create("ImageLabel", {
                    Parent = Items["RealDropdown"].Instance,
                    Name = "\0",
                    ImageColor3 = Library.Theme["Text"],
                    -- The art points down at 0°: closed = ▼, open = ▲. (It was 270°/90° — a
                    -- sideways arrow — from when the panel opened to the side instead of
                    -- below.)
                    Rotation = 0,
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(1, 0.5),
                    Image = "rbxassetid://72690112230014",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.new(0, 16, 0, 16),
                    BorderSizePixel = 0
                }):AddToTheme({ImageColor3 = 'Text'})

                Instances:Create("Frame", {
                    Parent = Items["RealDropdown"].Instance,
                    Name = "\0",
                    AnchorPoint = Vector2New(1, 0),
                    Position = UDim2.new(1, -32, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(0, 1, 1, 0),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Outline"]
                }):AddToTheme({BackgroundColor3 = 'Outline'})

                -- Drawer: a child of the Dropdown itself, right below the field.
                -- ClipsDescendants + an animated height = a smooth expansion.
                Items["OptionHolder"] = Instances:Create("Frame", {
                    Parent = Items["Dropdown"].Instance,
                    Name = "\0",
                    Visible = false,
                    Active = true,
                    AnchorPoint = Vector2New(0, 0),
                    Position = UDim2.new(0, 0, 0, 58),
                    Size = UDim2.new(1, 0, 0, 0),
                    ZIndex = 2,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    BackgroundColor3 = Library.Theme["Inline"]
                }):AddToTheme({BackgroundColor3 = 'Inline'})

                Instances:Create("UICorner", {
                    Parent = Items["OptionHolder"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 10)
                })

                Items["OptionHolderStroke"] = Instances:Create("UIStroke", {
                    Parent = Items["OptionHolder"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})

                Items["OptionList"] = Instances:Create("ScrollingFrame", {
                    Parent = Items["OptionHolder"].Instance,
                    Name = "\0",
                    Active = true,
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 0,
                    ScrollBarImageColor3 = Library.Theme["Accent"],
                    ZIndex = 3,
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Position = UDim2FromOffset(DrawerPad, ListTop),
                    Size = UDim2.new(1, -(DrawerPad * 2), 0, 0),
                    BorderSizePixel = 0
                }):AddToTheme({ScrollBarImageColor3 = 'Accent'})

                -- Search: always visible, however many options there are.
                Items["SearchFrame"] = Instances:Create("Frame", {
                    Parent = Items["OptionHolder"].Instance,
                    Name = "\0",
                    ZIndex = 3,
                    BackgroundColor3 = Library.Theme["Element"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Position = UDim2FromOffset(DrawerPad, DrawerPad),
                    Size = UDim2.new(1, -(DrawerPad * 2), 0, SearchHeight),
                    BorderSizePixel = 0
                }):AddToTheme({BackgroundColor3 = 'Element'})

                Instances:Create("UICorner", {
                    Parent = Items["SearchFrame"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 8)
                })

                Instances:Create("UIStroke", {
                    Parent = Items["SearchFrame"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})

                Items["SearchIcon"] = Instances:Create("ImageLabel", {
                    Parent = Items["SearchFrame"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Image = "rbxassetid://6031154871",
                    ImageTransparency = 0.4,
                    ZIndex = 4,
                    AnchorPoint = Vector2New(0, 0.5),
                    Position = UDim2.new(0, 10, 0.5, 0),
                    Size = UDim2FromOffset(14, 14),
                    BorderSizePixel = 0
                }):AddToTheme({ImageColor3 = 'Text'})

                Items["SearchBox"] = Instances:Create("TextBox", {
                    Parent = Items["SearchFrame"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    PlaceholderColor3 = Library.Theme["Text"],
                    TextTransparency = 0,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    PlaceholderText = "Search option",
                    Text = "",
                    ClearTextOnFocus = false,
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    ZIndex = 4,
                    Position = UDim2FromOffset(32, 0),
                    Size = UDim2.new(1, -42, 1, 0),
                    BorderSizePixel = 0,
                    TextSize = 15
                }):AddToTheme({TextColor3 = 'Text'})

                Items["EmptyLabel"] = Instances:Create("TextLabel", {
                    Parent = Items["OptionHolder"].Instance,
                    Name = "\0",
                    Visible = false,
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["TextMuted"],
                    TextTransparency = 0.25,
                    Text = "No results",
                    ZIndex = 3,
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Position = UDim2FromOffset(DrawerPad, ListTop),
                    Size = UDim2.new(1, -(DrawerPad * 2), 0, 20),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 14
                }):AddToTheme({TextColor3 = 'TextMuted'})

                Items["OptionsLayout"] = Instances:Create("UIListLayout", {
                    Parent = Items["OptionList"].Instance,
                    Name = "\0",
                    Padding = UDimNew(0, OptionGap),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })
            end

            function Dropdown:Get()
                return Dropdown.Value
            end

            local OpenTweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            local CloseTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            local ArrowTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            local TransitionId = 0

            local function GetVisibleOptionCount()
                local Count = 0

                for _, OptionData in Dropdown.Options do
                    if OptionData.Button.Instance.Visible then
                        Count += 1
                    end
                end

                return Count
            end

            local function GetListHeight()
                local Count = GetVisibleOptionCount()

                if Count <= 0 then
                    return 20
                end

                return math.min((Count * OptionHeight) + ((Count - 1) * OptionGap), MaxListHeight)
            end

            local function GetDrawerHeight()
                return ListTop + GetListHeight() + DrawerPad
            end

            -- Recomputes the position/size of the field, the drawer and the row itself.
            -- `Animate` is only used when the open/closed state changes.
            local function RefreshLayout(Animate)
                local DropdownWidth = Items["Dropdown"].Instance.AbsoluteSize.X

                if DropdownWidth > 0 then
                    local TextWidth = MathFloor(math.max(Items["Text"].Instance.AbsoluteSize.X, Items["Text"].Instance.TextBounds.X))
                    local InlineGap = 12
                    local MinimumFieldWidth = 135
                    local InlineFieldWidth = DropdownWidth - TextWidth - InlineGap

                    UseStackedLayout = InlineFieldWidth < MinimumFieldWidth
                    FieldWidth = math.max(MinimumFieldWidth, InlineFieldWidth)
                end

                if UseStackedLayout then
                    HeaderHeight = 52

                    Items["Text"].Instance.AnchorPoint = Vector2New(0, 0)
                    Items["Text"].Instance.Position = UDim2.new(0, 0, 0, 0)

                    Items["RealDropdown"].Instance.AnchorPoint = Vector2New(0, 0)
                    Items["RealDropdown"].Instance.Position = UDim2.new(0, 0, 0, 22)
                    Items["RealDropdown"].Instance.Size = UDim2.new(1, 0, 0, 30)

                    Items["OptionHolder"].Instance.AnchorPoint = Vector2New(0, 0)
                    Items["OptionHolder"].Instance.Position = UDim2.new(0, 0, 0, HeaderHeight + DrawerGap)
                else
                    HeaderHeight = 30

                    Items["Text"].Instance.AnchorPoint = Vector2New(0, 0.5)
                    Items["Text"].Instance.Position = UDim2.new(0, 0, 0, MathFloor(HeaderHeight / 2))

                    Items["RealDropdown"].Instance.AnchorPoint = Vector2New(1, 0)
                    Items["RealDropdown"].Instance.Position = UDim2.new(1, 0, 0, 0)
                    Items["RealDropdown"].Instance.Size = UDim2FromOffset(FieldWidth, 30)

                    Items["OptionHolder"].Instance.AnchorPoint = Vector2New(1, 0)
                    Items["OptionHolder"].Instance.Position = UDim2.new(1, 0, 0, HeaderHeight + DrawerGap)
                end

                local DrawerHeight = Dropdown.IsOpen and GetDrawerHeight() or 0
                local RowHeight = HeaderHeight + (Dropdown.IsOpen and (DrawerGap + DrawerHeight) or 0)
                local HolderSize = UseStackedLayout
                    and UDim2.new(1, 0, 0, DrawerHeight)
                    or UDim2FromOffset(FieldWidth, DrawerHeight)

                Items["OptionList"].Instance.Size = UDim2.new(1, -(DrawerPad * 2), 0, GetListHeight())

                if Animate then
                    local Info = Dropdown.IsOpen and OpenTweenInfo or CloseTweenInfo

                    Items["OptionHolder"]:Tween(Info, {Size = HolderSize})
                    Items["Dropdown"]:Tween(Info, {Size = UDim2.new(1, 0, 0, RowHeight)})
                else
                    Items["OptionHolder"].Instance.Size = HolderSize
                    Items["Dropdown"].Instance.Size = UDim2.new(1, 0, 0, RowHeight)
                end
            end

            function Dropdown:SetVisibility(Bool)
                Items["Dropdown"].Instance.Visible = Bool
            end

            local function ApplyOptionFilter()
                local Query = StringLower(Items["SearchBox"].Instance.Text or "")
                local HasQuery = StringLen(Query) > 0

                for _, OptionData in Dropdown.Options do
                    local Matches = (not HasQuery) or (StringFind(StringLower(OptionData.Name), Query, 1, true) ~= nil)
                    OptionData.Button.Instance.Visible = Matches
                end

                local IsEmpty = GetVisibleOptionCount() <= 0

                Items["EmptyLabel"].Instance.Visible = IsEmpty and Dropdown.IsOpen
                Items["OptionList"].Instance.Visible = not IsEmpty

                if Dropdown.IsOpen then
                    RefreshLayout(true)
                end
            end

            function Dropdown:SetOpen(Bool)
                Bool = Bool and true or false

                if Dropdown.IsOpen == Bool then
                    return
                end

                Dropdown.IsOpen = Bool
                TransitionId += 1

                local CurrentTransition = TransitionId

                if Dropdown.IsOpen then
                    Items["OptionHolder"].Instance.Visible = true
                    Items["Stroke"]:ChangeItemTheme({Color = "Accent"})
                    Items["Stroke"]:Tween(nil, {Color = Library.Theme.Accent})
                    Items["Icon"]:Tween(ArrowTweenInfo, {Rotation = 180})

                    for Index, Value in Library.OpenFrames do
                        if Value ~= Dropdown and not Dropdown.Section.IsSettings then
                            Value:SetOpen(false)
                        end
                    end

                    Library.OpenFrames[Dropdown] = Dropdown
                else
                    if Library.OpenFrames[Dropdown] then
                        Library.OpenFrames[Dropdown] = nil
                    end

                    Items["SearchBox"].Instance.Text = ""
                    Items["Stroke"]:ChangeItemTheme({Color = "Outline"})
                    Items["Stroke"]:Tween(nil, {Color = Library.Theme.Outline})
                    Items["Icon"]:Tween(ArrowTweenInfo, {Rotation = 0})

                    -- Hide the holder as soon as the animation ends: a zero-height frame still
                    -- draws its UIStroke, and the border becomes a thin line just below the
                    -- field.
                    task.delay(CloseTweenInfo.Time, function()
                        if CurrentTransition == TransitionId and not Dropdown.IsOpen then
                            Items["OptionHolder"].Instance.Visible = false
                        end
                    end)
                end

                Items["EmptyLabel"].Instance.Visible = Dropdown.IsOpen and GetVisibleOptionCount() <= 0
                RefreshLayout(true)
            end

            -- The field's text AND each option's label, in one place. They have to agree
            -- and used to be written from two different places (`Set` and the option
            -- click) — which even disagreed on the empty-list placeholder: one wrote
            -- "--" and the other "...".
            local function RefreshMultiText()
                if not Dropdown.Multi then
                    return
                end

                -- name -> position in the queue
                local Order = { }
                for Index, Name in Dropdown.Value do
                    Order[Name] = Index
                end

                if Dropdown.Ranked then
                    for Name, OptionData in Dropdown.Options do
                        local Rank = Order[Name]
                        OptionData.Text.Instance.Text = Rank and (Rank .. ". " .. Name) or Name
                    end
                end

                if #Dropdown.Value <= 0 then
                    Items["Value"].Instance.Text = "--"
                    return
                end

                if not Dropdown.Ranked then
                    Items["Value"].Instance.Text = TableConcat(Dropdown.Value, ", ")
                    return
                end

                local Parts = { }
                for Index, Name in Dropdown.Value do
                    Parts[Index] = Index .. ". " .. Name
                end

                Items["Value"].Instance.Text = TableConcat(Parts, "  ")
            end

            function Dropdown:Set(Option)
                if Dropdown.Multi then
                    if type(Option) ~= "table" then
                        return
                    end

                    Dropdown.Value = Option
                    Library.Flags[Dropdown.Flag] = Option

                    -- Clear before ticking: `Set` means "the selection is THIS", the same as the
                    -- single-select branch below. Without it, loading a second config only
                    -- ADDED — the previous config's ticks stayed lit on screen, disagreeing with
                    -- the real flag value.
                    for Index, OptionData in Dropdown.Options do
                        OptionData.Selected = false
                        OptionData:Toggle("Inactive")
                    end

                    -- Anything not yet in the list is ignored here but STAYS in
                    -- `Dropdown.Value` — that is where `Refresh` re-applies it from once the
                    -- list finally arrives.
                    for Index, Value in Option do
                        local OptionData = Dropdown.Options[Value]

                        if not OptionData then
                            continue
                        end

                        OptionData.Selected = true
                        OptionData:Toggle("Active")
                    end

                    RefreshMultiText()
                else
                    if not Dropdown.Options[Option] then
                        -- The option does not exist in the list yet. That is the RULE, not the
                        -- exception, during autoload: the config is applied ~0.3s after the window
                        -- is born, and lists coming from an async source (an HTTP fetch, the game's
                        -- GUI, the player's character) are still on their fallback or empty at that
                        -- moment.
                        --
                        -- The value used to be discarded here, silently, and the Callback never
                        -- ran — the user saw the config "load" with nothing changing. Now it stays
                        -- pending and `Refresh` applies it once the option appears.
                        --
                        -- The Flag is written all the same: without that, saving the config while
                        -- the list had not arrived ERASED the stored choice.
                        Dropdown.Pending = Option
                        Library.Flags[Dropdown.Flag] = Option
                        return
                    end

                    local OptionData = Dropdown.Options[Option]

                    Dropdown.Pending = nil
                    Dropdown.Value = Option
                    Library.Flags[Dropdown.Flag] = Option

                    for Index, Value in Dropdown.Options do
                        if Value ~= OptionData then
                            Value.Selected = false
                            Value:Toggle("Inactive")
                        else
                            Value.Selected = true
                            Value:Toggle("Active")
                        end
                    end

                    Items["Value"].Instance.Text = Option
                end

                if Dropdown.Callback then
                    Library:SafeCall(Dropdown.Callback, Dropdown.Value)
                end

                task.defer(RefreshLayout)
            end

            function Dropdown:Add(Option)
                local OptionButton = Instances:Create("TextButton", {
                    Parent = Items["OptionList"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = FromRGB(0, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, OptionHeight),
                    ZIndex = 4,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    TextSize = 14,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})

                Instances:Create("UICorner", {
                    Parent = OptionButton.Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })

                local OptionLiner = Instances:Create("Frame", {
                    Parent = OptionButton.Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 3, 0, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    ZIndex = 5,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Accent"]
                }):AddToTheme({BackgroundColor3 = 'Accent'})

                local OptionGlow = Instances:Create("ImageLabel", {
                    Parent = OptionLiner.Instance,
                    Name = "\0",
                    ImageColor3 = Library.Theme["Accent"],
                    ScaleType = Enum.ScaleType.Slice,
                    ImageTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 25, 1, 25),
                    AnchorPoint = Vector2New(0.5, 0.5),
                    ZIndex = 4,
                    Image = "http://www.roblox.com/asset/?id=18245826428",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    BorderSizePixel = 0,
                    SliceCenter = RectNew(Vector2New(21, 21), Vector2New(79, 79))
                }):AddToTheme({ImageColor3 = 'Accent'})

                Instances:Create("UICorner", {
                    Parent = OptionLiner.Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(1, 0)
                })

                local OptionText = Instances:Create("TextLabel", {
                    Parent = OptionButton.Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    TextTransparency = 0.5,
                    Text = Option,
                    ZIndex = 5,
                    Size = UDim2.new(1, -20, 0, 15),
                    AnchorPoint = Vector2New(0, 0.5),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0.5, 0),
                    BorderColor3 = FromRGB(0, 0, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})

                local OptionData = {
                    Button = OptionButton,
                    Name = Option,
                    Liner = OptionLiner,
                    Glow = OptionGlow,
                    Text = OptionText,
                    Selected = false
                }

                function OptionData:Toggle(Value)
                    if Value == "Active" then
                        OptionData.Button:Tween(nil, {BackgroundTransparency = 0})
                        OptionData.Liner:Tween(nil, {BackgroundTransparency = 0, Size = UDim2.new(0, 3, 1, 0)})
                        OptionData.Text:Tween(nil, {Position = UDim2.new(0, 20, 0.5 ,0), TextTransparency = 0})
                    else
                        OptionData.Button:Tween(nil, {BackgroundTransparency = 1})
                        OptionData.Liner:Tween(nil, {BackgroundTransparency = 1, Size = UDim2.new(0, 3, 0, 0)})
                        OptionData.Text:Tween(nil, {Position = UDim2.new(0, 10, 0.5 ,0), TextTransparency = 0.5})
                    end
                end

                function OptionData:Set()
                    OptionData.Selected = not OptionData.Selected

                    if Dropdown.Multi then
                        local Index = TableFind(Dropdown.Value, OptionData.Name)

                        if Index then
                            TableRemove(Dropdown.Value, Index)
                        else
                            TableInsert(Dropdown.Value, OptionData.Name)
                        end

                        OptionData:Toggle(Index and "Inactive" or "Active")

                        Library.Flags[Dropdown.Flag] = Dropdown.Value

                        -- Renumbers the WHOLE list, not just the clicked item: removing the 2nd of a
                        -- queue of 4 promotes the two below it.
                        RefreshMultiText()
                    else
                        -- A manual choice wins: discard whatever was pending from the config,
                        -- otherwise the next `Refresh` would overwrite what the user just clicked.
                        Dropdown.Pending = nil

                        if OptionData.Selected then
                            Dropdown.Value = OptionData.Name
                            Library.Flags[Dropdown.Flag] = OptionData.Name

                            OptionData.Selected = true
                            OptionData:Toggle("Active")

                            for Index, Value in Dropdown.Options do
                                if Value ~= OptionData then
                                    Value.Selected = false
                                    Value:Toggle("Inactive")
                                end
                            end

                            Items["Value"].Instance.Text = OptionData.Name
                        else
                            Dropdown.Value = nil
                            Library.Flags[Dropdown.Flag] = nil

                            OptionData.Selected = false
                            OptionData:Toggle("Inactive")

                            Items["Value"].Instance.Text = "..."
                        end
                    end

                    if Dropdown.Callback then
                        Library:SafeCall(Dropdown.Callback, Dropdown.Value)
                    end

                    -- Single-select closes the drawer on choosing; multi keeps it open so you
                    -- can tick several at once.
                    if not Dropdown.Multi then
                        Dropdown:SetOpen(false)
                    end
                end

                OptionData.Button:Connect("MouseButton1Down", function()
                    OptionData:Set()
                end)

                Dropdown.Options[OptionData.Name] = OptionData
                ApplyOptionFilter()
                return OptionData
            end

            function Dropdown:Remove(Option)
                if Dropdown.Options[Option] then
                    Dropdown.Options[Option].Button:Clean()
                    Dropdown.Options[Option] = nil
                    ApplyOptionFilter()
                end
            end

            function Dropdown:Refresh(List)
                for Index, Value in Dropdown.Options do
                    Dropdown:Remove(Value.Name)
                end

                for Index, Value in List do
                    Dropdown:Add(Value)
                end

                -- Re-applies the selection now that the list changed. Two holes this closes:
                --
                --   * the value left pending in `Set` (config applied before the list
                --     existed) finally lands;
                --   * swapping the list left the selection orphaned — `Value` still pointed
                --     at the old item, no option was ticked and the Callback was never told
                --     about the change.
                --
                -- If the option still does not exist, `Set` simply re-pends it and tries
                -- again on the next Refresh.
                local Wanted = Dropdown.Pending or Dropdown.Value

                if Dropdown.Multi then
                    if type(Wanted) == "table" then
                        Dropdown:Set(Wanted)
                    end
                elseif type(Wanted) == "string" then
                    Dropdown:Set(Wanted)
                end
            end

            Items["RealDropdown"]:Connect("MouseButton1Down", function()
                Dropdown:SetOpen(not Dropdown.IsOpen)
            end)

            Library:Connect(UserInputService.InputBegan, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    if Dropdown.IsOpen then
                        if Library:IsMouseOverFrame(Items["RealDropdown"]) then
                            return
                        end

                        if Library:IsMouseOverFrame(Items["OptionHolder"]) then
                            return
                        end

                        Dropdown:SetOpen(false)
                    end
                end
            end)

            Library:Connect(Items["SearchBox"].Instance:GetPropertyChangedSignal("Text"), ApplyOptionFilter)
            Library:Connect(Items["Dropdown"].Instance:GetPropertyChangedSignal("AbsoluteSize"), function()
                RefreshLayout(false)
            end)
            Library:Connect(Items["Text"].Instance:GetPropertyChangedSignal("AbsoluteSize"), function()
                RefreshLayout(false)
            end)

            task.defer(function()
                RefreshLayout(false)
            end)

            for Index, Value in Dropdown.Items do
                Dropdown:Add(Value)
            end

            if Dropdown.Default then
                Dropdown:Set(Dropdown.Default)
            end

            Library.SetFlags[Dropdown.Flag] = function(Value)
                Dropdown:Set(Value)
            end

            return Dropdown
        end

-- ============================================================
-- [ modulo: Label.lua ]
-- ============================================================

        Library.Sections.Label = function(self, Name)
            local Label = {
                Window = self.Window,
                Page = self.Page,
                Section = self,

                Name = Name or "Label"
            }

            local Items = { } do 
                Items["Label"] = Instances:Create("Frame", {
                    Parent = Label.Section.Items["Content"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 0, 20),
                    BorderSizePixel = 0
                })
                
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Label"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = Label.Name,
                    AnchorPoint = Vector2New(0, 0),
                    Size = UDim2.new(1, 0, 0, 15),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})
                
                Items["SubElements"] = Instances:Create("Frame", {
                    Parent = Items["Label"].Instance,
                    Name = "\0",
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(1, 0),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.new(0, 0, 1, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X
                })
                
                Instances:Create("UIListLayout", {
                    Parent = Items["SubElements"].Instance,
                    Name = "\0",
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    Padding = UDimNew(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder
                })                
            end

            local function UpdateLabelLayout()
                local LabelWidth = Items["Label"].Instance.AbsoluteSize.X
                if LabelWidth <= 0 then
                    return
                end

                local SubElementsWidth = MathFloor(math.max(Items["SubElements"].Instance.AbsoluteSize.X, 0))
                local Gap = SubElementsWidth > 0 and 8 or 0
                local TextWidth = math.max(LabelWidth - SubElementsWidth - Gap, 0)

                Items["Text"].Instance.Size = UDim2FromOffset(TextWidth, 0)

                local TextHeight = MathFloor(math.max(Items["Text"].Instance.TextBounds.Y, 15))
                local Height = math.max(TextHeight, 20)
                local TextY = TextHeight > 15 and 0 or MathFloor((Height - 15) / 2)

                Items["Text"].Instance.Position = UDim2FromOffset(0, TextY)
                Items["SubElements"].Instance.Size = UDim2.new(0, 0, 0, Height)
                Items["Label"].Instance.Size = UDim2.new(1, 0, 0, Height)
            end

            function Label:SetText(Text)
                Text = tostring(Text)
                Items["Text"].Instance.Text = Text
                task.defer(UpdateLabelLayout)
            end

            function Label:SetVisibility(Bool)
                Items["Label"].Instance.Visible = Bool
            end

            function Label:Colorpicker(Data)
                Data = Data or { }

                -- nil must stay nil all the way to CreateColorpicker: that is where
                -- the default is decided. An `or false` here would switch the bar off
                -- every time the field was omitted.
                local AlphaOption = Data.Alpha

                if AlphaOption == nil then
                    AlphaOption = Data.alpha
                end

                local Colorpicker = {
                    Window = Label.Window,
                    Page = Label.Page,
                    Section = Label.Section,

                    Flag = Data.Flag or Data.flag or Library:NextFlag(),
                    Default = Data.Default or Data.default or Color3.fromRGB(255, 255, 255),
                    Callback = Data.Callback or Data.callback or function() end,
                    Alpha = AlphaOption
                }

                local NewColorpicker, ColorpickerItems = Library:CreateColorpicker({
                    Parent = Items["SubElements"],
                    Page = Colorpicker.Page,
                    Section = Colorpicker.Section,
                    Flag = Colorpicker.Flag,
                    Default = Colorpicker.Default,
                    Callback = Colorpicker.Callback,
                    Alpha = Colorpicker.Alpha
                })

                return NewColorpicker
            end

            function Label:Keybind(Data)
                Data = Data or { }

                local Keybind = {
                    Window = Label.Window,
                    Page = Label.Page,
                    Section = Label.Section,

                    Flag = Data.Flag or Data.flag or Library:NextFlag(),
                    Default = Data.Default or Data.default or Enum.KeyCode.E,
                    Callback = Data.Callback or Data.callback or function() end,
                    Mode = Data.Mode or Data.mode or "Toggle"
                }

                local NewKeybind, KeybindItems = Library:CreateKeybind({
                    Parent = Items["SubElements"],
                    Page = Keybind.Page,
                    Section = Keybind.Section,
                    Name = Label.Name,
                    Flag = Keybind.Flag,
                    Default = Keybind.Default,
                    Mode = Keybind.Mode,
                    Callback = Keybind.Callback
                })

                return NewKeybind
            end

            Library:Connect(Items["Label"].Instance:GetPropertyChangedSignal("AbsoluteSize"), UpdateLabelLayout)
            Library:Connect(Items["SubElements"].Instance:GetPropertyChangedSignal("AbsoluteSize"), UpdateLabelLayout)
            Library:Connect(Items["Text"].Instance:GetPropertyChangedSignal("TextBounds"), UpdateLabelLayout)
            task.defer(UpdateLabelLayout)

            return Label
        end

-- ============================================================
-- [ modulo: Textbox.lua ]
-- ============================================================

        Library.Sections.Textbox = function(self, Data)
            Data = Data or { }

            local Textbox = {
                Window = self.Window,
                Page = self.Page,
                Section = self,

                Name = Data.Name or Data.name or "Textbox",
                Flag = Data.Flag or Data.flag or Library:NextFlag(),
                Default = Data.Default or Data.default or "",
                Callback = Data.Callback or Data.callback or function() end,
                Placeholder = Data.Placeholder or Data.placeholder or "Placeholder",
                Numeric = Data.Numeric or Data.numeric or false,
                Finished = Data.Finished or Data.finished or false,
                MaxLength = Data.MaxLength or Data.maxlength or Data.maxLength,

                Value = ""
            }

            local Items = { } do 
                Items["Textbox"] = Instances:Create("Frame", {
                    Parent = Textbox.Section.Items["Content"].Instance,
                    Name = "\0",
                    BackgroundTransparency = 1,
                    BorderColor3 = FromRGB(0, 0, 0),
                    Size = UDim2.new(1, 0, 0, 30),
                    BorderSizePixel = 0
                })
                
                Items["Text"] = Instances:Create("TextLabel", {
                    Parent = Items["Textbox"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = Textbox.Name,
                    AnchorPoint = Vector2New(0, 0.5),
                    Size = UDim2.new(0, 0, 0, 15),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0.5, 0),
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.X,
                    TextSize = 16
                }):AddToTheme({TextColor3 = 'Text'})
                
                Items["Background"] = Instances:Create("Frame", {
                    Parent = Items["Textbox"].Instance,
                    Name = "\0",
                    Active = true,
                    ClipsDescendants = true,
                    BorderColor3 = FromRGB(0, 0, 0),
                    AnchorPoint = Vector2New(1, 0.5),
                    Size = UDim2FromOffset(180, 30),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Selectable = true,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme["Element"]
                }):AddToTheme({BackgroundColor3 = 'Element'})
                
                Instances:Create("UICorner", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    CornerRadius = UDimNew(0, 6)
                })
                
                Instances:Create("UIStroke", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    Color = Library.Theme["Outline"],
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                }):AddToTheme({Color = 'Outline'})
                
                Instances:Create("UIPadding", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    PaddingRight = UDimNew(0, 8),
                    PaddingLeft = UDimNew(0, 8)
                })
                
                Items["Input"] = Instances:Create("TextBox", {
                    Parent = Items["Background"].Instance,
                    Name = "\0",
                    FontFace = Library.Font,
                    -- Active+Selectable MUST be true on the TextBox itself or
                    -- click-to-focus and keyboard input never fire on mobile
                    -- (and on PC the cursor wouldn't appear after clicking).
                    Active = true,
                    Selectable = true,
                    TextTransparency = 0,
                    AnchorPoint = Vector2New(0, 0.5),
                    PlaceholderColor3 = Library.Theme["TextMuted"],
                    PlaceholderText = Textbox.Placeholder,
                    TextSize = 16,
                    Size = UDim2.new(1, 0, 0, 15),
                    TextColor3 = Library.Theme["Text"],
                    BorderColor3 = FromRGB(0, 0, 0),
                    Text = "",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0.5, 0),
                    CursorPosition = -1,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left
                }):AddToTheme({TextColor3 = 'Text', PlaceholderColor3 = 'TextMuted'})
            end
            
            local function UpdateTextboxLayout()
                local TextboxWidth = Items["Textbox"].Instance.AbsoluteSize.X
                if TextboxWidth <= 0 then
                    return
                end

                local TitleWidth = MathFloor(math.max(Items["Text"].Instance.TextBounds.X, 0))
                local Gap = 12
                local MinInputWidth = 120
                local AvailableWidth = TextboxWidth - TitleWidth - Gap
                local UseStackedLayout = AvailableWidth < MinInputWidth

                if UseStackedLayout then
                    local InputWidth = math.max(TextboxWidth, 0)

                    Items["Text"].Instance.AnchorPoint = Vector2New(0, 0)
                    Items["Text"].Instance.Position = UDim2FromOffset(0, 0)
                    Items["Background"].Instance.AnchorPoint = Vector2New(1, 1)
                    Items["Background"].Instance.Position = UDim2.new(1, 0, 1, 0)
                    Items["Background"].Instance.Size = UDim2FromOffset(InputWidth, 30)
                    Items["Textbox"].Instance.Size = UDim2.new(1, 0, 0, 56)
                else
                    local InputWidth = math.min(math.max(AvailableWidth, MinInputWidth), 220)

                    Items["Text"].Instance.AnchorPoint = Vector2New(0, 0.5)
                    Items["Text"].Instance.Position = UDim2.new(0, 0, 0.5, 0)
                    Items["Background"].Instance.AnchorPoint = Vector2New(1, 0.5)
                    Items["Background"].Instance.Position = UDim2.new(1, 0, 0.5, 0)
                    Items["Background"].Instance.Size = UDim2FromOffset(InputWidth, 30)
                    Items["Textbox"].Instance.Size = UDim2.new(1, 0, 0, 30)
                end
            end

            function Textbox:Get()
                return Textbox.Value
            end

            function Textbox:SetVisibility(Bool)
                Items["Textbox"].Instance.Visible = Bool
            end

            function Textbox:Set(Value)
                Value = tostring(Value or "")

                if Textbox.MaxLength and Textbox.MaxLength > 0 and StringLen(Value) > Textbox.MaxLength then
                    Value = Value:sub(1, Textbox.MaxLength)
                end

                if Textbox.Numeric then
                    if (not tonumber(Value)) and StringLen(Value) > 0 then
                        Value = Textbox.Value
                    end
                end

                Textbox.Value = Value
                Items["Input"].Instance.Text = Value
                Library.Flags[Textbox.Flag] = Value
                task.defer(UpdateTextboxLayout)

                if Textbox.Callback then
                    Library:SafeCall(Textbox.Callback, Value)
                end
            end

            local function ClampLiveTextboxText()
                if not Textbox.MaxLength or Textbox.MaxLength <= 0 then
                    return
                end

                local CurrentText = Items["Input"].Instance.Text
                if StringLen(CurrentText) <= Textbox.MaxLength then
                    return
                end

                local ClampedText = CurrentText:sub(1, Textbox.MaxLength)
                local CursorPosition = Items["Input"].Instance.CursorPosition

                Items["Input"].Instance.Text = ClampedText

                if CursorPosition > 0 then
                    Items["Input"].Instance.CursorPosition = math.min(CursorPosition, Textbox.MaxLength + 1)
                end
            end

            Library:Connect(Items["Input"].Instance:GetPropertyChangedSignal("Text"), ClampLiveTextboxText)

            if Textbox.Finished then 
                Items["Input"]:Connect("FocusLost", function(PressedEnterQuestionMark)
                    if PressedEnterQuestionMark then
                        Textbox:Set(Items["Input"].Instance.Text)
                    end
                end)
            else
                Library:Connect(Items["Input"].Instance:GetPropertyChangedSignal("Text"), function()
                    Textbox:Set(Items["Input"].Instance.Text)
                end)
            end

            Library:Connect(Items["Textbox"].Instance:GetPropertyChangedSignal("AbsoluteSize"), UpdateTextboxLayout)
            Library:Connect(Items["Text"].Instance:GetPropertyChangedSignal("TextBounds"), UpdateTextboxLayout)
            task.defer(UpdateTextboxLayout)

            if Textbox.Default then
                Textbox:Set(Textbox.Default)
            end

            Library.SetFlags[Textbox.Flag] = function(Value)
                Textbox:Set(Value)
            end

            return Textbox
        end
    end
-- ============================================================
-- [ modulo: SettingsPage.lua ]
-- ============================================================


    Library.CreateSettingsPage = function(self, Window, Watermark)
        local SettingsPage = Window:Page({
            Name = "Settings",
            Icon = "rbxassetid://128742673777519",
            Category = "Settings"
        })

        do
            local function GetWindowKeybindList()
                return rawget(Window, "KeybindList") or rawget(Window, "BindList")
            end

            local function EnsureWindowKeybindList()
                local WindowKeybindList = GetWindowKeybindList()

                if type(WindowKeybindList) == "table" then
                    return WindowKeybindList
                end

                if type(Window.CreateKeybindList) == "function" then
                    WindowKeybindList = Window:CreateKeybindList({
                        Visible = true
                    })
                end

                return WindowKeybindList
            end

            Library:RegisterIgnoredFlags({
                "Configs",
                "ConfigName",
                "Settings_AutoExec",
                "Settings_KeybindListVisible",
                "Settings_MenuKeybind"
            })

            local InterfaceSection = SettingsPage:Section({Name = "Interface", Icon = "keyboard", Side = 2})
            local MenuBindLabel = InterfaceSection:Label("Menu Bind")

            MenuBindLabel:Keybind({
                Flag = "Settings_MenuKeybind",
                Default = Library.MenuKeybind,
                Mode = "Toggle",
                Callback = function()
                    local Current = Library.Flags["Settings_MenuKeybind"]
                    local CurrentKey = type(Current) == "table" and Current.Key or nil

                    if type(CurrentKey) ~= "string" or CurrentKey == "" or Library.MenuKeybind == CurrentKey then
                        return
                    end

                    local Success = Library:SetMenuKeybind(CurrentKey)
                    if Success and Window and Window.Notification then
                        Window:Notification("Interface", "menu bind = " .. Library:GetMenuKeybindDisplay(CurrentKey), 2)
                    end
                end
            })

            local ExistingWindowKeybindList = GetWindowKeybindList()

            InterfaceSection:Toggle({
                Name = "Keybind List",
                Flag = "Settings_KeybindListVisible",
                Default = type(ExistingWindowKeybindList) == "table" and ExistingWindowKeybindList.Visible ~= false or false,
                SkipInitialCallback = true,
                Callback = function(Value)
                    local WindowKeybindList = Value and EnsureWindowKeybindList() or GetWindowKeybindList()

                    if type(WindowKeybindList) == "table" then
                        WindowKeybindList:SetVisibility(Value)
                    end
                end
            })

            local ThemingSection = SettingsPage:Section({Name = "Theming", Icon = "rbxassetid://73803440257131", Side = 2})

            do
                -- Preset dropdown: applies every colour at once
                local presetNames = {}
                for name in pairs(Library.Themes or {}) do
                    table.insert(presetNames, name)
                end
                table.sort(presetNames)

                local colorpickerHandles = {}  -- Index -> colorpicker (to refresh the visuals)

                ThemingSection:Dropdown({
                    Name = "Preset",
                    Flag = "ThemingPreset",
                    Items = presetNames,
                    Default = Library.CurrentThemeName or "Preset",
                    Callback = function(Value)
                        if Library:ApplyThemePreset(Value) then
                            -- Refreshes the colorpickers visually to reflect the new theme
                            for Index, picker in pairs(colorpickerHandles) do
                                local newColor = Library.Theme[Index]
                                if newColor and picker.Set then
                                    pcall(picker.Set, picker, newColor)
                                end
                            end
                        end
                    end
                })

                -- Background image: a textbox for an Asset ID or URL
                ThemingSection:Textbox({
                    Name = "Background Image",
                    Flag = "BackgroundImage",
                    Placeholder = "Asset ID or rbxassetid://N",
                    Finished = true,
                    Callback = function(Text)
                        Library:SetBackgroundImage(Text, Library.BackgroundTransparency or 0.5)
                    end
                })

                ThemingSection:Slider({
                    Name = "Background Transparency",
                    Flag = "BackgroundTransparency",
                    Min = 0, Max = 1, Default = 0.5, Decimals = 0.05,
                    Callback = function(Value)
                        Library.BackgroundTransparency = Value
                        local mainFrame = Library.Holder and Library.Holder.Instance
                        local bg = mainFrame and mainFrame:FindFirstChild("VyHub_BackgroundImage")
                        if bg then bg.ImageTransparency = Value end
                    end
                })

                -- Individual colorpickers (one per theme colour)
                for Index, Value in Library.Theme do
                    local picker = ThemingSection:Label(Index):Colorpicker({
                        Flag = Index.."_ThemingThing",
                        Default = Value,
                        -- Explicit opt-out: ChangeTheme takes a colour and nothing
                        -- else, so the bar here would be a control that does nothing.
                        Alpha = false,
                        Callback = function(Value)
                            Library.Theme[Index] = Value
                            Library:ChangeTheme(Index, Value)
                        end
                    })
                    colorpickerHandles[Index] = picker
                end
            end

            local ConfigsSection = SettingsPage:Section({Name = "Configs", Icon = "rbxassetid://74885853379841", Side = 1}) do
                local ConfigName
                local ConfigSelected
                local AutoloadLabel
                local ConfigsDropdown

                local function NotifySettings(Text, Duration, Title)
                    if Window and Window.Notification then
                        Window:Notification(Title or "Settings", Text, Duration)
                    else
                        Library:Notification(Title or "Settings", Text, Duration)
                    end
                end

                -- Backwards-compat helpers for the rest of the section. Status
                -- info now flows through notifications + the AutoloadLabel only.
                local function SetConfigStatus(Text) end
                local function SetConfigFeedback(Text, Duration, Title)
                    NotifySettings(Text, Duration, Title)
                end

                local function UpdateAutoloadStatus()
                    if not AutoloadLabel then return end
                    local Name = Library:GetAutoloadConfigName()
                    if Name and Name ~= "" then
                        AutoloadLabel:SetText("Autoload • " .. Name)
                    else
                        AutoloadLabel:SetText("Autoload • off")
                    end
                end

                local function RefreshConfigs(Preferred)
                    local List = Library:RefreshConfigsList(ConfigsDropdown)

                    if Preferred and TableFind(List, Preferred) then
                        ConfigSelected = Preferred
                    elseif ConfigSelected and TableFind(List, ConfigSelected) then
                        ConfigSelected = ConfigSelected
                    else
                        ConfigSelected = List[1] or nil
                    end

                    if ConfigsDropdown.Set then
                        ConfigsDropdown:Set(ConfigSelected or "")
                    end

                    return List
                end

                -- Compact one-liner showing the current autoload. Updates on
                -- Set/Clear Autoload. No "Status: ready" clutter.
                AutoloadLabel = ConfigsSection:Label("Autoload • off")

                ConfigsSection:Toggle({
                    Name = "Auto Exec",
                    Flag = "Settings_AutoExec",
                    Default = Library:GetAutoExecEnabled(),
                    SkipInitialCallback = true,
                    Callback = function(Value)
                        local Success, Result = Library:SetAutoExecEnabled(Value)

                        if Value then
                            if Success then
                                SetConfigFeedback("auto exec armed", 3, "Auto Exec")
                            else
                                SetConfigFeedback(Result == "queue or source unavailable" and "auto exec enabled, but source is missing" or tostring(Result), 4, "Auto Exec")
                            end
                        else
                            SetConfigFeedback("auto exec disabled", 2, "Auto Exec")
                        end
                    end
                })

                ConfigsDropdown = ConfigsSection:Dropdown({
                    Name = "Configs", 
                    Flag = "Configs",
                    Items = { }, 
                    Multi = false,
                    MaxSize = 120,
                    Callback = function(Value)
                        ConfigSelected = Value
                    end
                })
    
                ConfigsSection:Textbox({
                    Name = "Config name",
                    Placeholder = "Config name",
                    Flag = "ConfigName",
                    Callback = function(Value)
                        ConfigName = Value
                    end
                })
    
                ConfigsSection:Button({
                    Name = "Create",
                    Callback = function()
                        if not ConfigName or ConfigName == "" then
                            SetConfigFeedback("enter a config name", 3, "Configs")
                            return
                        end

                        local File = ConfigName .. ".json"

                        if Library:FileExists("Configs", File) then
                            SetConfigFeedback("config already exists", 3, "Configs")
                            return
                        end

                        if Library:FileWrite("Configs", File, Library:GetConfig()) then
                            RefreshConfigs(ConfigName)
                            SetConfigFeedback("created " .. ConfigName, 3, "Configs")
                        else
                            SetConfigFeedback("failed to create config", 3, "Configs")
                        end
                    end
                })
    
                ConfigsSection:Button({
                    Name = "Load",
                    Callback = function()
                        if not ConfigSelected or ConfigSelected == "" then
                            SetConfigFeedback("select a config first", 3, "Configs")
                            return
                        end

                        local RawConfig = Library:FileRead("Configs", ConfigSelected .. ".json")
                        if type(RawConfig) ~= "string" then
                            SetConfigFeedback("failed to read config", 3, "Configs")
                            return
                        end

                        local Success = Library:LoadConfig(RawConfig)
                        if Success then
                            SetConfigFeedback("loaded " .. ConfigSelected, 3, "Configs")
                        else
                            SetConfigFeedback("failed to load config", 3, "Configs")
                        end
                    end
                })
    
                ConfigsSection:Button({
                    Name = "Save",
                    Callback = function()
                        if not ConfigSelected or ConfigSelected == "" then
                            SetConfigFeedback("select a config first", 3, "Configs")
                            return
                        end

                        if Library:FileWrite("Configs", ConfigSelected .. ".json", Library:GetConfig()) then
                            SetConfigFeedback("saved " .. ConfigSelected, 3, "Configs")
                        else
                            SetConfigFeedback("failed to save config", 3, "Configs")
                        end
                    end
                })
    
                ConfigsSection:Button({
                    Name = "Delete",
                    Callback = function()
                        if not ConfigSelected or ConfigSelected == "" then
                            SetConfigFeedback("select a config first", 3, "Configs")
                            return
                        end

                        local Name = ConfigSelected
                        if not Library:FileDelete("Configs", Name .. ".json") then
                            SetConfigFeedback("failed to delete config", 3, "Configs")
                            return
                        end

                        if Library:GetAutoloadConfigName() == Name then
                            Library:ClearAutoloadConfig()
                        end

                        RefreshConfigs()
                        UpdateAutoloadStatus()
                        SetConfigFeedback("deleted " .. Name, 3, "Configs")
                    end
                })

                ConfigsSection:Button({
                    Name = "Set Autoload",
                    Callback = function()
                        if not ConfigSelected or ConfigSelected == "" then
                            SetConfigFeedback("select a config first", 3, "Autoload")
                            return
                        end

                        local Success, Result = Library:SetAutoloadConfig(ConfigSelected)
                        if Success then
                            UpdateAutoloadStatus()
                            SetConfigFeedback("autoload = " .. ConfigSelected, 3, "Autoload")
                        else
                            SetConfigFeedback("failed to set autoload", 3, "Autoload")
                            warn("[vylib] set autoload failed:", Result)
                        end
                    end
                })

                ConfigsSection:Button({
                    Name = "Clear Autoload",
                    Callback = function()
                        local Success, Result = Library:ClearAutoloadConfig()
                        UpdateAutoloadStatus()

                        if Success then
                            SetConfigFeedback("autoload cleared", 3, "Autoload")
                        else
                            SetConfigFeedback(Result == "autoload not set" and "autoload already empty" or "failed to clear autoload", 3, "Autoload")
                        end
                    end
                })

                ConfigsSection:Button({
                    Name = "Refresh",
                    Callback = function()
                        RefreshConfigs()
                        UpdateAutoloadStatus()
                        SetConfigFeedback("config list refreshed", 2, "Configs")
                    end
                })

                RefreshConfigs()
                UpdateAutoloadStatus()
            end
        end

        return SettingsPage
    end
-- ============================================================
-- [ modulo: IconPacks.lua ]
-- ============================================================

end



-- loadstring-friendly wrappers / aliases
Library.LucideIconsUrl = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"
Library.IconPacks = Library.IconPacks or {}
Library.ActiveIconPack = "lucide"

function Library:LoadIconPack(Url, PackName)
    PackName = PackName or "lucide"

    if self.IconPacks[PackName] then
        return self.IconPacks[PackName]
    end

    local Success, Result = pcall(function()
        local Source = game:HttpGet(Url)
        local Chunk = loadstring(Source)
        if not Chunk then
            return {}
        end

        local Icons = Chunk()
        if type(Icons) ~= "table" then
            return {}
        end

        return Icons
    end)

    self.IconPacks[PackName] = Success and Result or {}
    return self.IconPacks[PackName]
end

function Library:SetIconPack(PackName)
    self.ActiveIconPack = PackName or "lucide"
end

function Library:GetIconPack(PackName)
    PackName = PackName or self.ActiveIconPack or "lucide"

    if not self.IconPacks[PackName] then
        if PackName == "lucide" then
            self:LoadIconPack(self.LucideIconsUrl, "lucide")
        else
            self.IconPacks[PackName] = {}
        end
    end

    return self.IconPacks[PackName] or {}
end

function Library:ResolveIcon(Icon, PackName)
    if not Icon or Icon == "" then
        return Icon
    end

    if typeof(Icon) ~= "string" then
        return Icon
    end

    if Icon:match("^rbxassetid://") or Icon:match("^https?://") then
        return Icon
    end

    local Icons = self:GetIconPack(PackName)
    return Icons[string.lower(Icon)] or Icon
end
-- ============================================================
-- [ modulo: Analytics.lua ]
-- ============================================================


    -- ══════════════════════════════════════════════════════════════════════
    -- Execution counter
    -- ══════════════════════════════════════════════════════════════════════
    -- One beat per execution, fired by `CreateWindow` — the single point every
    -- script in the hub passes through. That way no script has to remember to
    -- call anything, and a new script is counted from birth.
    --
    -- The name sent to the server is the window's `SubName` ("Shindo Life",
    -- "Bizarre Lineage"), which is the same name the user sees. If SubName ever
    -- changes, that script's historical series splits in two — worth remembering
    -- before renaming.
    --
    -- Three rules this must NEVER break, because it runs at everything's boot:
    --   * does not block   — `task.spawn`, and the result is ignored
    --   * does not throw   — all in pcall, an executor without HTTP just does not count
    --   * does not repeat  — once per execution, even with two CreateWindow calls

    -- Services resolved HERE, not inherited from the top of the bundle.
    --
    -- Not fussiness: the Header's `local Library do` closes before IconPacks, so
    -- every module from there down — this one included — is OUTSIDE the scope
    -- where `HttpService` and `LocalPlayer` exist. Inheriting gave nil, and the
    -- `pcall` turned that into "the counter simply does not count". Diagnosed
    -- from: `encode failed: attempt to index nil with 'JSONEncode'`.
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = game:GetService("Players").LocalPlayer

    -- The Discloud domain while there is no domain of our own. When getdzhub.xyz
    -- goes live pointing at this same app, just change it here — or set
    -- `getgenv().VyHub_ExecApi` before loading the lib, with nothing to republish.
    Library.ExecApi = "https://getdzhub.discloud.app/api/exec"
    Library.PingApi = "https://getdzhub.discloud.app/api/ping"
    Library._ExecReported = false

    -- Presence ping interval. The server counts as online anyone seen in the last
    -- 150s — two and a half pings — so one lost ping (lag, a server change) does
    -- not blink someone to offline.
    Library.PingEvery = 60

    Library.ResolveHttpRequest = function(self)
        return (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
    end

    Library.ReportExecution = function(self, ScriptName)
        if self._ExecReported then
            return false, "already reported"
        end
        self._ExecReported = true

        local Environment = (getgenv and getgenv()) or _G

        -- Escape hatch: an executor that hangs on `request`, or someone running
        -- locally who does not want to add to the production counter.
        if Environment.VyHub_NoTelemetry then
            return false, "opted out"
        end

        local Url = Environment.VyHub_ExecApi or self.ExecApi
        if type(Url) ~= "string" or Url == "" then
            return false, "no endpoint"
        end

        local Name = tostring(ScriptName or "unknown")

        -- Reason for the last failure, for diagnosis. Swallowing the error is right
        -- at runtime (the counter must never take the hub down), but swallowing it
        -- WITHOUT a trace is how an afternoon is lost asking "why is the number not
        -- going up?". Just read `Library._ExecError`.
        self._ExecError = nil

        task.spawn(function()
            local Request = self:ResolveHttpRequest()
            if not Request then
                self._ExecError = "no request function in this executor"
                return
            end

            -- Which executor people actually use. Not curiosity: it is what says where to
            -- spend time when something breaks on only one of them.
            local Executor = "Unknown"
            pcall(function()
                if identifyexecutor then
                    Executor = tostring(identifyexecutor())
                elseif getexecutorname then
                    Executor = tostring(getexecutorname())
                end
            end)

            local OkEncode, Body = pcall(function()
                return HttpService:JSONEncode({
                    script   = Name,
                    userId   = LocalPlayer and LocalPlayer.UserId or 0,
                    executor = Executor,
                })
            end)
            if not OkEncode or type(Body) ~= "string" then
                self._ExecError = "encode failed: " .. tostring(Body)
                return
            end

            local OkSend, Result = pcall(Request, {
                Url = Url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = Body,
            })
            if not OkSend then
                self._ExecError = "request failed: " .. tostring(Result)
                return
            end

            local Code = Result and (Result.StatusCode or Result.status_code)
            if Code and (Code < 200 or Code >= 300) then
                self._ExecError = "HTTP " .. tostring(Code)
            end
        end)

        return true
    end

    -- ── Presence ─────────────────────────────────────────────────────────
    -- Says "still running" every so often, and it is what lets the site show how
    -- many people are using the hub RIGHT NOW.
    --
    -- Built to be the cheapest call there is: a GET with the id in the query, no
    -- body to build, no JSON to serialize, and the server answers `204 No
    -- Content` — zero bytes back. The URL is built ONCE, outside the loop,
    -- because the only part that changes between one ping and the next is nothing.
    --
    -- It dies with the interface: the loop checks `Unloading`/`Unloaded` every
    -- round, so closing the hub removes the person from the count within 150s on
    -- its own, with nobody to notify. Someone who kills Roblox outright drops out
    -- the same way.
    Library.StartPresence = function(self)
        if self._PresenceOn then
            return false
        end
        self._PresenceOn = true

        local Environment = (getgenv and getgenv()) or _G
        if Environment.VyHub_NoTelemetry then
            return false
        end

        local Url = Environment.VyHub_PingApi or self.PingApi
        local UserId = LocalPlayer and LocalPlayer.UserId or 0
        if type(Url) ~= "string" or Url == "" or UserId <= 0 then
            return false
        end

        local Request = self:ResolveHttpRequest()
        if not Request then
            return false
        end

        local Full = Url .. "?u=" .. tostring(UserId)

        task.spawn(function()
            while not (self.Unloading or self.Unloaded) do
                pcall(Request, { Url = Full, Method = "GET" })
                -- Sliced into 1s pieces rather than one flat `task.wait(60)`: that way
                -- unloading the interface ends the thread almost immediately, instead of
                -- leaving it hanging for up to a minute.
                for _ = 1, self.PingEvery do
                    if self.Unloading or self.Unloaded then
                        break
                    end
                    task.wait(1)
                end
            end
            self._PresenceOn = false
        end)

        return true
    end
-- ============================================================
-- [ modulo: CreateWindow.lua ]
-- ============================================================


local OriginalWindowFunction = Library.Window
Library.Window = function(self, Data)
    Data = Data or {}

    if Data.HideLogo or Data.hidelogo or Data.Logo == false or Data.logo == false then
        Data.Logo = nil
        Data.logo = nil
    end

    Data.Logo = self:ResolveIcon(Data.Logo)
    Data.logo = self:ResolveIcon(Data.logo)

    if Data.WatermarkLogo then
        Data.WatermarkLogo = self:ResolveIcon(Data.WatermarkLogo)
    end

    if Data.ToggleButtonIcon then
        Data.ToggleButtonIcon = self:ResolveIcon(Data.ToggleButtonIcon)
    end

    if Data.togglebuttonicon then
        Data.togglebuttonicon = self:ResolveIcon(Data.togglebuttonicon)
    end

    if Data.MobileButtonIcon then
        Data.MobileButtonIcon = self:ResolveIcon(Data.MobileButtonIcon)
    end

    if Data.mobilebuttonicon then
        Data.mobilebuttonicon = self:ResolveIcon(Data.mobilebuttonicon)
    end

    return OriginalWindowFunction(self, Data)
end

local OriginalSectionFunction = Library.Pages.Section
Library.Pages.Section = function(self, Data)
    Data = Data or {}
    Data.Icon = Library:ResolveIcon(Data.Icon or Data.icon)
    Data.icon = Data.Icon
    return OriginalSectionFunction(self, Data)
end

Library.CreateWindow = function(self, Data)
    Data = Data or {}

    local Window = self:Window(Data)
    local Watermark
    local ToggleButton
    local KeybindList

    if Data.WatermarkEnabled then
        Watermark = self:Watermark(
            Data.WatermarkText or Data.Name or "Window",
            self:ResolveIcon(Data.WatermarkLogo or Data.Logo)
        )
        Window.Watermark = Watermark
    end

    local ToggleButtonRequested = Data.ToggleButtonEnabled or Data.togglebuttonenabled or Data.ShowToggleButton or Data.showtogglebutton or Data.MobileButtonEnabled or Data.mobilebuttonenabled
    local ToggleButtonMobileOnly = Data.ToggleButtonMobileOnly

    if ToggleButtonMobileOnly == nil then
        ToggleButtonMobileOnly = Data.togglebuttonmobileonly
    end

    if ToggleButtonMobileOnly == nil then
        ToggleButtonMobileOnly = true
    end

    if ToggleButtonRequested and (not ToggleButtonMobileOnly or self:IsMobileClient()) then
        ToggleButton = self:ToggleButton(Window, {
            Icon = Data.ToggleButtonIcon or Data.togglebuttonicon or Data.MobileButtonIcon or Data.mobilebuttonicon or self:ResolveIcon(Data.Logo) or self.DefaultToggleButtonIcon or "rbxassetid://10723407389",
            Position = Data.ToggleButtonPosition or Data.togglebuttonposition,
            Size = Data.ToggleButtonSize or Data.togglebuttonsize
        })
        Window.ToggleButton = ToggleButton
        Window.MenuButton = ToggleButton
    end

    function Window:CreateKeybindList(ListData)
        local ExistingKeybindList = rawget(Window, "KeybindList") or rawget(Window, "BindList")

        if type(ExistingKeybindList) == "table" then
            return ExistingKeybindList
        end

        Window.KeybindList = Library:KeybindList(Window, ListData or { })
        Window.BindList = Window.KeybindList

        return Window.KeybindList
    end

    if Data.KeybindListEnabled or Data.keybindlistenabled or Data.BindListEnabled or Data.bindlistenabled then
        KeybindList = Window:CreateKeybindList({
            Title = Data.KeybindListTitle or Data.keybindlisttitle,
            Position = Data.KeybindListPosition or Data.keybindlistposition,
            Width = Data.KeybindListWidth or Data.keybindlistwidth,
            Visible = Data.KeybindListVisible ~= false and Data.keybindlistvisible ~= false
        })
    end

    function Window:Notification(Title, Description, Duration)

        if not Description and Title then
            Description = Title
            Title = Window.Name or "VY HUB"
        end

        return Library:Notification(Title or Window.Name or "VY HUB", Description, Duration)
    end

    function Window:Notify(Description, Duration)
        return Library:Notification(Window.Name or "VY HUB", Description, Duration)
    end

    Window._AutoSettingsEnabled = Data.SettingsTabEnabled and true or false
    Window._AutoSettingsWatermark = Watermark

    local OriginalPage = Window.Page
    local CreatingSettings = false

    -- The LayoutOrder lives on the Wrapper (tab button + sub-tab accordion),
    -- which is the direct child of the sidebar's UIListLayout.
    local function GetTabLayoutItem(Page)
        if type(Page) ~= "table" or type(Page.Items) ~= "table" then
            return nil
        end

        return Page.Items["Wrapper"] or Page.Items["Inactive"]
    end

    local function ReorderTabs()
        local Order = 1

        for _, Value in Window.Pages do
            local LayoutItem = Value ~= Window.SettingsPage and GetTabLayoutItem(Value)

            if LayoutItem then
                LayoutItem.Instance.LayoutOrder = Order
                Order += 1
            end
        end

        local SettingsLayoutItem = Window.SettingsPage and GetTabLayoutItem(Window.SettingsPage)

        if SettingsLayoutItem then
            SettingsLayoutItem.Instance.LayoutOrder = 999999
        end
    end

    function Window:CreateSettingsPage()
        if Window.SettingsPage or CreatingSettings then
            ReorderTabs()
            return Window.SettingsPage
        end

        CreatingSettings = true
        Window.SettingsPage = Library:CreateSettingsPage(Window, Window._AutoSettingsWatermark)
        CreatingSettings = false

        ReorderTabs()
        return Window.SettingsPage
    end

    Window.AddSettingsPage = Window.CreateSettingsPage
    Window.CreateSettings = Window.CreateSettingsPage

    -- ════════════════════════════════════════════════════════════════════
    -- CreateInfoPage(opts) — builds an "Info" tab with a rich layout:
    --   • Welcome banner (avatar + name + tags)
    --   • Stats row (4 cards: Players, FPS, Ping, Uptime — auto-updating)
    --   • Credits + Key Info grid (2 cols)
    --
    -- EVERYTHING has a default: `Window:CreateInfoPage()` with no arguments
    -- already builds the whole tab (stats loop included). Pass only what you want
    -- to override.
    --
    -- opts = {
    --   tabName    = "Info" (default),
    --   tabIcon    = "info" (default),
    --   subtitle   = Library.DefaultInfoSubtitle,
    --   gameName   = Window.SubName,        -- used in Key Info's "Game:" line
    --   devMode    = false,                 -- swaps the "Live" tag for "DevMode"
    --   tags       = {"Free", "Live"},      -- chips in the right corner
    --   credits    = Library.DefaultInfoCredits,
    --   keyInfo    = {Game/Place ID/Game ID/Job ID},
    --   discordLink   = Library.DefaultDiscordLink,
    --   onCopyDiscord = function() end,     -- default: copies discordLink
    --   autoStats  = true,                  -- false disables the stats loop
    -- }
    -- Returns: page, statHandles {players, fps, ping, uptime} (each has :SetText)
    -- ════════════════════════════════════════════════════════════════════
    function Window:CreateInfoPage(opts)
        -- Shallow copy: the defaults below must not leak into the caller's table.
        local Source = type(opts) == "table" and opts or {}
        opts = {}

        for Key, Value in pairs(Source) do
            opts[Key] = Value
        end

        local GameName = opts.gameName or opts.GameName or Window.SubName

        if type(GameName) ~= "string" or GameName == "" then
            GameName = Window.Name
        end

        if opts.subtitle == nil then
            opts.subtitle = Library.DefaultInfoSubtitle
        end

        if opts.tags == nil then
            opts.tags = { "Free", opts.devMode and "DevMode" or "Live" }
        end

        if opts.credits == nil then
            opts.credits = Library.DefaultInfoCredits
        end

        if opts.keyInfo == nil then
            opts.keyInfo = {
                "Game: " .. tostring(GameName),
                "Place ID: " .. tostring(game.PlaceId),
                "Game ID: " .. tostring(game.GameId),
                "Job ID: " .. tostring(game.JobId),
            }
        end

        local DiscordLink = opts.discordLink or Library.DefaultDiscordLink

        if opts.onCopyDiscord == nil and type(DiscordLink) == "string" and DiscordLink ~= "" then
            opts.onCopyDiscord = function()
                if setclipboard then
                    setclipboard(DiscordLink)
                    Library:Notification("Discord", "Link copied!", 3)
                else
                    Library:Notification("Discord", DiscordLink, 5)
                end
            end
        end

        local UDim2New = UDim2.new
        local UDimNew = UDim.new
        local Vector2New = Vector2.new
        local page = Window:AddTab({
            Name = opts.tabName or "Info",
            Icon = opts.tabIcon or "info",
        })
        if not page then return nil, nil end

        -- Hide the default column layout (we use our own)
        local pageInst = page.Items.Page.Instance
        local columnsInst = page.Items.Columns and page.Items.Columns.Instance
        if columnsInst then columnsInst.Visible = false end

        -- Helper: creates an instance and registers it in the Library's ThemeItems, so
        -- changing the theme updates its colours automatically.
        local function themed(class, parent, props, themeMap)
            local inst = Instance.new(class)
            for k, v in pairs(props or {}) do
                inst[k] = v
            end
            inst.Parent = parent
            if themeMap then
                pcall(function() Library:AddToTheme(inst, themeMap) end)
            end
            return inst
        end

        -- Custom container inside the Page
        local container = Instance.new("Frame")
        container.Name = "InfoContainer"
        container.BackgroundTransparency = 1
        container.Size = UDim2.new(1, -20, 0, 0)
        container.Position = UDim2.new(0, 10, 0, 0)
        container.AutomaticSize = Enum.AutomaticSize.Y
        container.Parent = pageInst

        local containerLayout = Instance.new("UIListLayout")
        containerLayout.Padding = UDimNew(0, 12)
        containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
        containerLayout.Parent = container

        Instance.new("UIPadding", container).PaddingTop = UDimNew(0, 14)

        -- Helper: creates a standard card (themed background + corner + themed stroke)
        local function makeCard(parent, layoutOrder, height)
            local card = themed("Frame", parent, {
                Name = "Card",
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, height or 0),
                AutomaticSize = (height and Enum.AutomaticSize.None) or Enum.AutomaticSize.Y,
                LayoutOrder = layoutOrder,
            }, { BackgroundColor3 = "Element" })

            themed("UICorner", card, { CornerRadius = UDimNew(0, 8) })
            themed("UIStroke", card, {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, { Color = "Outline" })

            return card
        end

        local LocalPlayer = game:GetService("Players").LocalPlayer

        -- ── Welcome Banner ─────────────────────────────────────────────
        local banner = makeCard(container, 1, 88)
        local bannerPadding = Instance.new("UIPadding", banner)
        bannerPadding.PaddingLeft = UDimNew(0, 16)
        bannerPadding.PaddingRight = UDimNew(0, 16)
        bannerPadding.PaddingTop = UDimNew(0, 14)
        bannerPadding.PaddingBottom = UDimNew(0, 14)

        -- Avatar circular (themed)
        local avatar = themed("ImageLabel", banner, {
            Size = UDim2.new(0, 60, 0, 60),
            AnchorPoint = Vector2New(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BorderSizePixel = 0,
        }, { BackgroundColor3 = "Background" })
        themed("UICorner", avatar, { CornerRadius = UDimNew(1, 0) })
        pcall(function()
            local thumb = game:GetService("Players"):GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
            avatar.Image = thumb
        end)

        -- "Welcome back," small label
        themed("TextLabel", banner, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 76, 0, 8),
            Size = UDim2.new(0, 200, 0, 16),
            Text = "Welcome back,",
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Library.Font,
            TextSize = 14,
        }, { TextColor3 = "TextMuted" })

        -- Username big
        themed("TextLabel", banner, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 76, 0, 24),
            Size = UDim2.new(0, 300, 0, 24),
            Text = LocalPlayer.DisplayName or LocalPlayer.Name,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Library.Font,
            TextSize = 22,
        }, { TextColor3 = "Text" })

        -- Subtitle
        if opts.subtitle then
            themed("TextLabel", banner, {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 76, 0, 50),
                Size = UDim2.new(0, 300, 0, 14),
                Text = opts.subtitle,
                TextXAlignment = Enum.TextXAlignment.Left,
                FontFace = Library.Font,
                TextSize = 12,
            }, { TextColor3 = "TextMuted" })
        end

        -- Tags (chips na direita)
        if type(opts.tags) == "table" and #opts.tags > 0 then
            local tagsHolder = Instance.new("Frame")
            tagsHolder.BackgroundTransparency = 1
            tagsHolder.AnchorPoint = Vector2New(1, 0.5)
            tagsHolder.Position = UDim2.new(1, 0, 0.5, 0)
            tagsHolder.Size = UDim2.new(0, 0, 0, 28)
            tagsHolder.AutomaticSize = Enum.AutomaticSize.X
            tagsHolder.Parent = banner

            local tagsLayout = Instance.new("UIListLayout")
            tagsLayout.FillDirection = Enum.FillDirection.Horizontal
            tagsLayout.Padding = UDimNew(0, 6)
            tagsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            tagsLayout.Parent = tagsHolder

            for i, tagText in ipairs(opts.tags) do
                local themeBg = (i == 1) and "Accent" or "Background"
                local chip = themed("Frame", tagsHolder, {
                    Size = UDim2.new(0, 0, 0, 24),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BorderSizePixel = 0,
                }, { BackgroundColor3 = themeBg })
                themed("UICorner", chip, { CornerRadius = UDimNew(1, 0) })
                local pad = Instance.new("UIPadding", chip)
                pad.PaddingLeft = UDimNew(0, 12)
                pad.PaddingRight = UDimNew(0, 12)
                if i == 1 then
                    -- Accent tag: AccentText stays readable on the accent fill
                    themed("TextLabel", chip, {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 0, 1, 0),
                        AutomaticSize = Enum.AutomaticSize.X,
                        Text = tagText,
                        FontFace = Library.Font,
                        TextSize = 12,
                    }, { TextColor3 = "AccentText" })
                else
                    themed("TextLabel", chip, {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 0, 1, 0),
                        AutomaticSize = Enum.AutomaticSize.X,
                        Text = tagText,
                        FontFace = Library.Font,
                        TextSize = 12,
                    }, { TextColor3 = "Text" })
                end
            end
        end

        -- ── Stats Row (4 cards) ────────────────────────────────────────
        local statsRow = Instance.new("Frame")
        statsRow.BackgroundTransparency = 1
        statsRow.Size = UDim2.new(1, 0, 0, 80)
        statsRow.LayoutOrder = 2
        statsRow.Parent = container

        local statsLayout = Instance.new("UIListLayout")
        statsLayout.FillDirection = Enum.FillDirection.Horizontal
        statsLayout.Padding = UDimNew(0, 10)
        statsLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
        statsLayout.Parent = statsRow

        local function makeStatCard(label, defaultValue)
            local card = themed("Frame", statsRow, {
                Size = UDim2.new(0.25, -8, 1, 0),
                BorderSizePixel = 0,
            }, { BackgroundColor3 = "Element" })
            themed("UICorner", card, { CornerRadius = UDimNew(0, 8) })
            themed("UIStroke", card, {}, { Color = "Outline" })

            local pad = Instance.new("UIPadding", card)
            pad.PaddingLeft = UDimNew(0, 14)
            pad.PaddingRight = UDimNew(0, 14)
            pad.PaddingTop = UDimNew(0, 12)
            pad.PaddingBottom = UDimNew(0, 12)

            themed("TextLabel", card, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Text = label,
                TextXAlignment = Enum.TextXAlignment.Left,
                FontFace = Library.Font,
                TextSize = 13,
            }, { TextColor3 = "TextMuted" })

            local val = themed("TextLabel", card, {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 22),
                Size = UDim2.new(1, 0, 0, 28),
                Text = defaultValue or "--",
                TextXAlignment = Enum.TextXAlignment.Left,
                FontFace = Library.Font,
                TextSize = 24,
            }, { TextColor3 = "Text" })

            return {
                Instance = val,
                SetText = function(_, t) val.Text = tostring(t or "--") end,
            }
        end

        local statHandles = {
            players = makeStatCard("Players", "--"),
            fps = makeStatCard("FPS", "--"),
            ping = makeStatCard("Ping", "--"),
            uptime = makeStatCard("Uptime", "0s"),
        }

        -- ── Bottom Grid (Credits + Key Info) ──────────────────────────
        local bottomRow = Instance.new("Frame")
        bottomRow.BackgroundTransparency = 1
        bottomRow.Size = UDim2.new(1, 0, 0, 0)
        bottomRow.AutomaticSize = Enum.AutomaticSize.Y
        bottomRow.LayoutOrder = 3
        bottomRow.Parent = container

        local bottomLayout = Instance.new("UIListLayout")
        bottomLayout.FillDirection = Enum.FillDirection.Horizontal
        bottomLayout.Padding = UDimNew(0, 10)
        bottomLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
        bottomLayout.Parent = bottomRow

        local function makeInfoCard(title, lines)
            local card = themed("Frame", bottomRow, {
                Size = UDim2.new(0.5, -5, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0,
            }, { BackgroundColor3 = "Element" })
            themed("UICorner", card, { CornerRadius = UDimNew(0, 8) })
            themed("UIStroke", card, {}, { Color = "Outline" })

            local pad = Instance.new("UIPadding", card)
            pad.PaddingLeft = UDimNew(0, 14)
            pad.PaddingRight = UDimNew(0, 14)
            pad.PaddingTop = UDimNew(0, 12)
            pad.PaddingBottom = UDimNew(0, 12)

            local layout = Instance.new("UIListLayout")
            layout.Padding = UDimNew(0, 6)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = card

            themed("TextLabel", card, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Text = title,
                TextXAlignment = Enum.TextXAlignment.Left,
                FontFace = Library.Font,
                TextSize = 16,
                LayoutOrder = 0,
            }, { TextColor3 = "Text" })

            for i, line in ipairs(lines or {}) do
                themed("TextLabel", card, {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 16),
                    Text = tostring(line),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    FontFace = Library.Font,
                    TextSize = 13,
                    LayoutOrder = i,
                }, { TextColor3 = "TextMuted" })
            end

            return card
        end

        makeInfoCard("Credits", opts.credits or {})
        local keyInfoCard = makeInfoCard(opts.keyInfoTitle or "Game Info", opts.keyInfo or {})

        -- Optional: Copy Discord button — uses the REAL Library.Sections.Button via a
        -- fake section pointing at the Game Info card. That way it inherits all the
        -- original button's animations (hover lerp, UIScale punch, stroke flash)
        -- without replicating them by hand.
        if type(opts.onCopyDiscord) == "function" then
            -- A wrapper mimicking the interface Library.Sections.Button expects:
            -- self.Items["Content"].Instance = the parent the button is created in
            local fakeSection = {
                Window = Window,
                Page = page,
                Section = nil,
                Items = {
                    ["Content"] = { Instance = keyInfoCard },
                },
            }
            local btn = Library.Sections.Button(fakeSection, {
                Name = "Copy Discord",
                Callback = opts.onCopyDiscord,
            })
            -- Reorder to the end of the card (after the title and rows)
            if btn and btn.Items and btn.Items["Button"] then
                btn.Items["Button"].Instance.LayoutOrder = 99
            end
        end

        -- ── Auto-stats ───────────────────────────────────────────────────
        -- Feeds the 4 cards (players/fps/ping/uptime) once a second. Every hub script
        -- used to run this same loop by hand — and with raw Connect/task.spawn, which
        -- survived :Unload(). Here it uses Library:Connect + Library:Thread, so it
        -- goes away with the lib. Pass autoStats = false to feed the cards yourself.
        if statHandles and opts.autoStats ~= false then
            local StatsPlayers = game:GetService("Players")
            local StatsRunService = game:GetService("RunService")
            local StatsLocalPlayer = StatsPlayers.LocalPlayer
            local StartClock = tick()
            local FrameCount = 0

            Library:Connect(StatsRunService.RenderStepped, function()
                FrameCount = FrameCount + 1
            end)

            Library:Thread(function()
                while task.wait(1) do
                    if Library.Unloading or Library.Unloaded then
                        break
                    end

                    local FPS = FrameCount
                    FrameCount = 0

                    local Uptime = math.round(tick() - StartClock)
                    local Minutes = math.floor(Uptime / 60)
                    local Seconds = Uptime % 60

                    local OkCount, PlayerCount = pcall(function()
                        return #StatsPlayers:GetPlayers()
                    end)

                    local Ping
                    pcall(function()
                        Ping = math.round(StatsLocalPlayer:GetNetworkPing() * 1000)
                    end)

                    statHandles.players:SetText((OkCount and PlayerCount or "?") .. "/" .. tostring(StatsPlayers.MaxPlayers or "?"))
                    statHandles.fps:SetText(tostring(FPS))
                    statHandles.ping:SetText(Ping and (Ping .. "ms") or "--")
                    statHandles.uptime:SetText((Minutes > 0 and Minutes .. "m " or "") .. Seconds .. "s")
                end
            end)
        end

        return page, statHandles
    end

    local function EnsureSettings()
        if not Window._AutoSettingsEnabled then
            ReorderTabs()
            return
        end

        Window:CreateSettingsPage()
    end

    local function WrappedPage(_, TabData)
        TabData = TabData or {}
        TabData.Icon = Library:ResolveIcon(TabData.Icon or TabData.icon)
        TabData.icon = TabData.Icon

        local Page = OriginalPage(Window, TabData)

        EnsureSettings()
        ReorderTabs()

        return Page
    end

    Window.Page = WrappedPage
    Window.CreateTab = WrappedPage
    Window.CreatePage = WrappedPage

    -- ── Loading overlay control ──────────────────────────────────────
    -- Hide the overlay once the host script finishes adding tabs/sections.
    -- Either call Window:HideLoading() manually for instant feedback, or
    -- the auto-fallback kicks in after 4s.
    function Window:HideLoading()
        if not Window.IsLoading then return end
        Window.IsLoading = false
        local items = Window.Items
        if not items or not items["LoadingOverlay"] then return end
        local TweenService = game:GetService("TweenService")
        local overlay = items["LoadingOverlay"].Instance
        local title   = items["LoadingTitle"]   and items["LoadingTitle"].Instance
        local sub     = items["LoadingSub"]     and items["LoadingSub"].Instance
        local logo    = items["LoadingLogo"]    and items["LoadingLogo"].Instance
        local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        pcall(function()
            TweenService:Create(overlay, info, { BackgroundTransparency = 1 }):Play()
            if title then TweenService:Create(title, info, { TextTransparency = 1 }):Play() end
            if sub   then TweenService:Create(sub,   info, { TextTransparency = 1 }):Play() end
            if logo  then TweenService:Create(logo,  info, { ImageTransparency = 1 }):Play() end
        end)
        task.delay(0.4, function()
            pcall(function() overlay:Destroy() end)
        end)
    end

    -- Safety net: auto-hide after 4s if the host script never calls it
    task.delay(4, function()
        if Window.IsLoading then
            Window:HideLoading()
        end
    end)

    Library:ScheduleAutoload()

    -- One beat on the execution counter. At the end on purpose: if anything above
    -- throws, the window was never born and the execution should not count. See
    -- `Library.ReportExecution` — does not block, does not throw, does not repeat.
    Library:ReportExecution(Window.SubName or Data.SubName or Data.Name)
    Library:StartPresence()

    return Window
end
-- ============================================================
-- [ modulo: Aliases.lua ]
-- ============================================================


Library.CreateTab = Library.Page
Library.Pages.CreateSection = Library.Pages.Section
Library.Pages.CreateSubTab = Library.Pages.SubTab

Library.Sections.CreateButton = Library.Sections.Button
Library.Sections.CreateToggle = Library.Sections.Toggle
Library.Sections.CreateSlider = Library.Sections.Slider
Library.Sections.CreateDropdown = Library.Sections.Dropdown
Library.Sections.CreateTextbox = Library.Sections.Textbox
Library.Sections.CreateLabel = Library.Sections.Label

local function NormalizeNamedData(NameOrData, Icon)
    if type(NameOrData) == "table" then
        local Data = {}

        for Key, Value in next, NameOrData do
            Data[Key] = Value
        end

        if Data.Title and not (Data.Name or Data.name) then
            Data.Name = Data.Title
        end

        if Data.title and not (Data.Name or Data.name) then
            Data.Name = Data.title
        end

        if Icon and not (Data.Icon or Data.icon) then
            Data.Icon = Icon
        end

        return Data
    end

    local Data = {
        Name = NameOrData
    }

    if Icon ~= nil then
        Data.Icon = Icon
    end

    return Data
end

function Library:AddTab(NameOrData, Icon)
    local Data = NormalizeNamedData(NameOrData, Icon)
    Data.Icon = self:ResolveIcon(Data.Icon or Data.icon)
    Data.icon = Data.Icon

    if self.CreateTab then
        return self:CreateTab(Data)
    end

    return self:Page(Data)
end

-- Sub-tabs are text only (no icon), which is why the signature takes none.
function Library.Pages:AddSubTab(NameOrData)
    return self:SubTab(NormalizeNamedData(NameOrData))
end

Library.Pages.AddSub = Library.Pages.AddSubTab

function Library.Pages:AddSection(NameOrData, Icon)
    local Data = NormalizeNamedData(NameOrData, Icon)
    Data.Icon = Library:ResolveIcon(Data.Icon or Data.icon)
    Data.icon = Data.Icon

    if self.CreateSection then
        return self:CreateSection(Data)
    end

    return self:Section(Data)
end

function Library.Sections:AddButton(NameOrData, Callback)
    if type(NameOrData) == "table" then
        local Data = NormalizeNamedData(NameOrData)
        return self:CreateButton(Data)
    end

    return self:CreateButton({
        Name = NameOrData,
        Callback = Callback
    })
end

function Library.Sections:AddToggle(NameOrData, FlagOrCallback, Default, Callback)
    if type(NameOrData) == "table" then
        local Data = NormalizeNamedData(NameOrData)
        return self:CreateToggle(Data)
    end

    local RealCallback = type(FlagOrCallback) == "function" and FlagOrCallback or Callback

    return self:CreateToggle({
        Name = NameOrData,
        Flag = type(FlagOrCallback) == "string" and FlagOrCallback or nil,
        Default = Default,
        Callback = RealCallback
    })
end

function Library.Sections:AddSlider(NameOrData, Min, Max, Default, Callback)
    if type(NameOrData) == "table" then
        local Data = NormalizeNamedData(NameOrData)
        return self:CreateSlider(Data)
    end

    return self:CreateSlider({
        Name = NameOrData,
        Min = Min,
        Max = Max,
        Default = Default,
        Callback = Callback
    })
end

function Library.Sections:AddDropdown(NameOrData, Items, Default, Callback)
    if type(NameOrData) == "table" then
        local Data = NormalizeNamedData(NameOrData)
        return self:CreateDropdown(Data)
    end

    return self:CreateDropdown({
        Name = NameOrData,
        Items = Items,
        Default = Default,
        Callback = Callback
    })
end

function Library.Sections:AddTextbox(NameOrData, Placeholder, Callback)
    if type(NameOrData) == "table" then
        local Data = NormalizeNamedData(NameOrData)
        return self:CreateTextbox(Data)
    end

    return self:CreateTextbox({
        Name = NameOrData,
        Placeholder = Placeholder,
        Callback = Callback
    })
end

function Library.Sections:AddLabel(TextOrData)
    if type(TextOrData) == "table" then
        local Data = NormalizeNamedData(TextOrData)
        return self:CreateLabel(Data.Name or Data.Text or Data.text or "Label")
    end

    return self:CreateLabel(TextOrData)
end

-- A colorpicker is a sub-element: it lives inside a Toggle or a Label, never
-- loose on a Section. So the shim creates the hosting Label and returns the
-- picker, which makes the call look like every other AddX. Anyone already
-- holding a Toggle keeps using `Toggle:Colorpicker(Data)`, the usual path.
function Library.Sections:Colorpicker(Data)
    Data = Data or { }

    local Host = self:CreateLabel(Data.Name or Data.name or Data.Text or Data.text or "Colorpicker")

    -- `or` will not do for Alpha: false is a valid value (the opt-out) and would
    -- be discarded as if it were absent.
    local AlphaOption = Data.Alpha

    if AlphaOption == nil then
        AlphaOption = Data.alpha
    end

    local Picker = Host:Colorpicker({
        Flag = Data.Flag or Data.flag,
        Default = Data.Default or Data.default,
        Callback = Data.Callback or Data.callback,
        Alpha = AlphaOption
    })

    -- Keeps the Label around so the text can be changed later (Picker.Label:SetText).
    if type(Picker) == "table" then
        Picker.Label = Host
    end

    return Picker
end

Library.Sections.CreateColorpicker = Library.Sections.Colorpicker

function Library.Sections:AddColorpicker(NameOrData, DefaultOrCallback, Callback)
    if type(NameOrData) == "table" then
        return self:CreateColorpicker(NormalizeNamedData(NameOrData))
    end

    local Data = {
        Name = NameOrData
    }

    -- Positional form: the default colour is optional, so the 2nd argument may be
    -- either the colour or already the callback.
    if type(DefaultOrCallback) == "function" then
        Data.Callback = DefaultOrCallback
    else
        Data.Default = DefaultOrCallback
        Data.Callback = Callback
    end

    return self:CreateColorpicker(Data)
end
-- ============================================================
-- [ modulo: Footer.lua ]
-- ============================================================


getgenv().Library = Library
return Library
