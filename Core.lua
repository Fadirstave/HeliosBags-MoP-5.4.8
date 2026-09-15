local ADDON_NAME, HB = ...

HeliosBags = HB
HB.name = ADDON_NAME
HB.version = "1.8.1-alpha"
HB.events = CreateFrame("Frame")
HB.modules = {}
HB.moduleOrder = {}
HB.moduleErrors = {}

local defaults = {
  profile = {
    layoutVersion = 9,
    scale = 0.75,
    autoLayout = true,
    sectionItemColumns = 16,
    buttonSize = 48,
    buttonSpacing = 1,
    categoryView = true,
    showEmpty = true,
    locked = false,
    darkMode = true,
    neutralBackground = false,
    backgroundAlpha = 0.98,
    recentTimeout = 15,
    position = { point = "BOTTOMRIGHT", x = -42, y = 110 },
    bankPosition = { point = "CENTER", x = -360, y = 0 },
    categoryOrder = {
      "Hearthstones", "Quest", "Equipment", "Consumables", "Trade Goods", "Containers", "Miscellaneous", "Recent", "Junk", "Empty",
    },
    customCategories = {},
    itemOverrides = {},
    collapsedCategories = {},
  },
  characters = {},
}

local function CopyDefaults(source, target)
  if type(target) ~= "table" then target = {} end
  for key, value in pairs(source) do
    if type(value) == "table" then
      target[key] = CopyDefaults(value, target[key])
    elseif target[key] == nil then
      target[key] = value
    end
  end
  return target
end

function HB:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff58c6ffHeliosBags:|r " .. tostring(message))
end

function HB:GetCharacterKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or "Unknown"
  return name .. " - " .. realm
end

function HB:RegisterModule(name, module)
  if not self.modules[name] then
    self.moduleOrder[#self.moduleOrder + 1] = name
  end
  self.modules[name] = module
end

function HB:Initialize()
  local previousLayoutVersion = HeliosBagsDB and HeliosBagsDB.profile and HeliosBagsDB.profile.layoutVersion or 0
  HeliosBagsDB = CopyDefaults(defaults, HeliosBagsDB or {})
  HeliosBagsCharacterDB = HeliosBagsCharacterDB or {}
  self.db = HeliosBagsDB
  self.profile = self.db.profile

  if previousLayoutVersion < 4 then
    self.profile.layoutVersion = 4
    self.profile.position = { point = "BOTTOMRIGHT", x = -42, y = 110 }
    self.profile.scale = 0.75
    self.profile.autoLayout = true
    self.profile.sectionItemColumns = 12
    self.profile.buttonSize = 32
    self.profile.buttonSpacing = 3
    self.profile.showEmpty = false
    self.profile.categoryOrder = {
      "Hearthstones", "Quest", "Equipment", "Consumables", "Trade Goods", "Containers", "Miscellaneous", "Recent", "Junk", "Empty",
    }
    for name in pairs(self.profile.customCategories) do
      table.insert(self.profile.categoryOrder, 8, name)
    end
  end

  if previousLayoutVersion < 5 then
    self.profile.layoutVersion = 5
    self.profile.scale = 0.75
    self.profile.autoLayout = true
    self.profile.sectionItemColumns = 16
    self.profile.buttonSize = 48
    self.profile.buttonSpacing = 1
    self.profile.showEmpty = true
    self.profile.categoryView = true
    self.profile.locked = false
  end
  if previousLayoutVersion < 6 then
    self.profile.layoutVersion = 6
    for index = #self.profile.categoryOrder, 1, -1 do
      local name = self.profile.categoryOrder[index]
      if name == "Recent" or name == "Hearthstones" then table.remove(self.profile.categoryOrder, index) end
    end
    table.insert(self.profile.categoryOrder, 1, "Hearthstones")
    table.insert(self.profile.categoryOrder, 1, "Recent")
  end
  if previousLayoutVersion < 7 then
    self.profile.layoutVersion = 7
    for index = #self.profile.categoryOrder, 1, -1 do
      local name = self.profile.categoryOrder[index]
      if name == "Recent" or name == "Hearthstones" then table.remove(self.profile.categoryOrder, index) end
    end
    table.insert(self.profile.categoryOrder, 1, "Hearthstones")
    local junkIndex = #self.profile.categoryOrder + 1
    for index, name in ipairs(self.profile.categoryOrder) do
      if name == "Junk" then
        junkIndex = index
        break
      end
    end
    table.insert(self.profile.categoryOrder, junkIndex, "Recent")
  end
  if previousLayoutVersion < 8 then
    self.profile.layoutVersion = 8
    self.profile.recentTimeout = 15
  end
  if previousLayoutVersion < 9 then
    self.profile.layoutVersion = 9
    self.profile.bankPosition = { point = "CENTER", x = -360, y = 0 }
  end

  for _, name in ipairs(self.moduleOrder) do
    local module = self.modules[name]
    if module.Initialize then
      local ok, message = pcall(module.Initialize, module)
      if not ok then
        self.moduleErrors[name] = message
        self:Print(name .. " could not load. Use /hb debug for details.")
      end
    end
  end

  self:Print("Loaded. Use /hb or /heliosbags to open.")
end

function HB:Toggle()
  if not self.UI or not self.UI.frame then return end
  if self.UI.frame:IsShown() then self.UI:Hide() else self.UI:Show() end
end

SLASH_HELIOSBAGS1 = "/heliosbags"
SLASH_HELIOSBAGS2 = "/hb"
SlashCmdList.HELIOSBAGS = function(text)
  text = strtrim(string.lower(text or ""))
  if text == "reset" and HB.UI then
    HB.profile.position = { point = "BOTTOMRIGHT", x = -42, y = 110 }
    HB.profile.bankPosition = { point = "CENTER", x = -360, y = 0 }
    HB.UI.frame:ClearAllPoints()
    HB.UI.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -42, 110)
    HB.UI.bankView.frame:ClearAllPoints()
    HB.UI.bankView.frame:SetPoint("CENTER", UIParent, "CENTER", -360, 0)
    HB:Print("Window position reset.")
  elseif text == "debug" then
    HB:Print("Version " .. HB.version .. ", interface " .. tostring(select(4, GetBuildInfo())))
    local hasErrors = false
    for name, message in pairs(HB.moduleErrors) do
      hasErrors = true
      HB:Print(name .. " error: " .. tostring(message))
    end
    if not hasErrors then HB:Print("All modules loaded successfully.") end
  elseif text == "config" or text == "options" then
    if HB.Settings and HB.Settings.Open then HB.Settings:Open()
    else HB:Print("Settings are unavailable. Use /hb debug for details.") end
  elseif text == "categories" then
    if HB.Settings and HB.Settings.OpenCategories then HB.Settings:OpenCategories()
    else HB:Print("Category settings are unavailable. Use /hb debug for details.") end
  else
    HB:Toggle()
  end
end

HB.events:RegisterEvent("ADDON_LOADED")
HB.events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    HB:Initialize()
  end
end)
