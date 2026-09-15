local _, HB = ...
local Settings = {}
HB.Settings = Settings
HB:RegisterModule("Settings", Settings)

local function AddLabel(parent, text, x, y, template)
  local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  label:SetPoint("TOPLEFT", x, y)
  label:SetText(text)
  return label
end

local function AddCheckBox(parent, name, text, x, y, getter, setter)
  local box = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  box:SetPoint("TOPLEFT", x, y)
  local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("LEFT", box, "RIGHT", 3, 1)
  label:SetText(text)
  box:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
  box:SetScript("OnClick", function(self)
    setter(self:GetChecked() and true or false)
    if HB.UI then HB.UI:RefreshOpenViews() end
  end)
  return box
end

local function AddSlider(parent, name, text, x, y, minimum, maximum, step, getter, setter)
  local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", x, y)
  slider:SetWidth(230)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  _G[name .. "Low"]:SetText(tostring(minimum))
  _G[name .. "High"]:SetText(tostring(maximum))
  slider:SetScript("OnShow", function(self) self:SetValue(getter()) end)
  slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value / step + 0.5) * step
    setter(value)
    _G[name .. "Text"]:SetText(text .. ": " .. value)
    if HB.UI then HB.UI:RefreshOpenViews() end
  end)
  return slider
end

local function AddEditBox(parent, name, labelText, x, y, width)
  AddLabel(parent, labelText, x, y, "GameFontNormalSmall")
  local edit = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  edit:SetSize(width, 22)
  edit:SetPoint("TOPLEFT", x + 4, y - 18)
  edit:SetAutoFocus(false)
  return edit
end

local function RemoveFromOrder(name)
  for index = #HB.profile.categoryOrder, 1, -1 do
    if HB.profile.categoryOrder[index] == name then table.remove(HB.profile.categoryOrder, index) end
  end
end

function Settings:CreateMainPanel(parent)
  local panel = CreateFrame("Frame", "HeliosBagsOptionsPanel", parent)
  panel.name = "HeliosBags"
  self.panel = panel

  AddLabel(panel, "HeliosBags", 16, -16, "GameFontNormalLarge")
  AddLabel(panel, "Responsive bag layout for the Helios Mists of Pandaria 5.4.8 client.", 16, -43, "GameFontHighlight")

  AddCheckBox(panel, "HeliosBagsCategoryViewCheck", "Organize items into category sections", 12, -76,
    function() return HB.profile.categoryView end,
    function(value) HB.profile.categoryView = value end)
  AddCheckBox(panel, "HeliosBagsEmptySlotsCheck", "Show empty bag slots", 12, -108,
    function() return HB.profile.showEmpty end,
    function(value) HB.profile.showEmpty = value end)
  AddCheckBox(panel, "HeliosBagsLockCheck", "Lock the bag window", 12, -140,
    function() return HB.profile.locked end,
    function(value) HB.profile.locked = value end)
  AddSlider(panel, "HeliosBagsRecentTimeoutSlider", "Recent duration (seconds)", 20, -198, 5, 60, 5,
    function() return HB.profile.recentTimeout end,
    function(value)
      HB.profile.recentTimeout = value
      if HB.Categories then HB.Categories:ClearExpiredRecent() end
    end)

  AddLabel(panel, "Appearance", 334, -76, "GameFontNormalLarge")
  AddCheckBox(panel, "HeliosBagsDarkModeCheck", "Dark UI mode", 326, -104,
    function() return HB.profile.darkMode end,
    function(value)
      HB.profile.darkMode = value
      if HB.UI then HB.UI:ApplyAppearance() end
    end)
  AddCheckBox(panel, "HeliosBagsNeutralBackgroundCheck", "Use a neutral background", 326, -136,
    function() return HB.profile.neutralBackground end,
    function(value)
      HB.profile.neutralBackground = value
      if HB.UI then HB.UI:ApplyAppearance() end
    end)
  AddSlider(panel, "HeliosBagsBackgroundAlphaSlider", "Background opacity", 332, -198, 0.2, 1, 0.05,
    function() return HB.profile.backgroundAlpha end,
    function(value)
      HB.profile.backgroundAlpha = value
      if HB.UI then HB.UI:ApplyAppearance() end
    end)

  AddLabel(panel, "Flexible layout", 16, -246, "GameFontNormalLarge")
  AddCheckBox(panel, "HeliosBagsAutoLayoutCheck", "Automatically fit the configured bag width to the screen", 12, -274,
    function() return HB.profile.autoLayout end,
    function(value) HB.profile.autoLayout = value end)

  AddSlider(panel, "HeliosBagsColumnsSlider", "Bag width (items)", 20, -336, 4, 16, 1,
    function() return HB.profile.sectionItemColumns end,
    function(value) HB.profile.sectionItemColumns = value end)
  AddSlider(panel, "HeliosBagsSizeSlider", "Item size", 300, -336, 26, 48, 1,
    function() return HB.profile.buttonSize end,
    function(value) HB.profile.buttonSize = value end)
  AddSlider(panel, "HeliosBagsSpacingSlider", "Item spacing", 20, -411, 1, 10, 1,
    function() return HB.profile.buttonSpacing end,
    function(value) HB.profile.buttonSpacing = value end)
  AddSlider(panel, "HeliosBagsScaleSlider", "Window scale", 300, -411, 0.6, 1.2, 0.05,
    function() return HB.profile.scale end,
    function(value) HB.profile.scale = value end)

  local categories = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  categories:SetSize(170, 24)
  categories:SetPoint("TOPLEFT", 20, -476)
  categories:SetText("Manage categories")
  categories:SetScript("OnClick", function() self:OpenCategories() end)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(170, 24)
  reset:SetPoint("TOPLEFT", 300, -476)
  reset:SetText("Reset window position")
  reset:SetScript("OnClick", function()
    HB.profile.position = { point = "BOTTOMRIGHT", x = -42, y = 110 }
    HB.profile.bankPosition = { point = "CENTER", x = -360, y = 0 }
    HB.UI.frame:ClearAllPoints()
    HB.UI.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -42, 110)
    HB.UI.bankView.frame:ClearAllPoints()
    HB.UI.bankView.frame:SetPoint("CENTER", UIParent, "CENTER", -360, 0)
  end)

  panel.default = function()
    HB.profile.scale = 0.75
    HB.profile.autoLayout = true
    HB.profile.sectionItemColumns = 16
    HB.profile.buttonSize = 48
    HB.profile.buttonSpacing = 1
    HB.profile.showEmpty = true
    HB.profile.recentTimeout = 15
    HB.profile.categoryView = true
    HB.profile.locked = false
    HB.profile.darkMode = true
    HB.profile.neutralBackground = false
    HB.profile.backgroundAlpha = 0.98
    HB.profile.collapsedCategories = {}
    if HB.UI then HB.UI:ApplyAppearance() end
    if HB.UI then HB.UI:RefreshOpenViews() end
  end
  InterfaceOptions_AddCategory(panel, true)
end

function Settings:MoveCategory(index, direction)
  local destination = index + direction
  if destination < 1 or destination > #HB.profile.categoryOrder then return end
  local order = HB.profile.categoryOrder
  order[index], order[destination] = order[destination], order[index]
  self:RefreshCategoryRows()
  if HB.UI then HB.UI:RefreshOpenViews() end
end

function Settings:SelectCategory(name)
  if not HB.profile.customCategories[name] then return end
  self.selectedCategory = name
  self.categoryName:SetText(name)
  self.categoryRule:SetText(HB.profile.customCategories[name] or "")
end

function Settings:SaveCategory()
  local name = strtrim(self.categoryName:GetText() or "")
  local rule = strtrim(self.categoryRule:GetText() or "")
  if name == "" or rule == "" then
    HB:Print("Enter both a category name and a search rule.")
    return
  end

  if self.selectedCategory and self.selectedCategory ~= name then
    local wasCollapsed = HB.profile.collapsedCategories[self.selectedCategory]
    HB.profile.customCategories[self.selectedCategory] = nil
    HB.profile.collapsedCategories[self.selectedCategory] = nil
    if wasCollapsed then HB.profile.collapsedCategories[name] = true end
    for index, value in ipairs(HB.profile.categoryOrder) do
      if value == self.selectedCategory then HB.profile.categoryOrder[index] = name end
    end
  elseif not HB.profile.customCategories[name] then
    local insertAt = #HB.profile.categoryOrder + 1
    for index, value in ipairs(HB.profile.categoryOrder) do
      if value == "Recent" then insertAt = index break end
    end
    table.insert(HB.profile.categoryOrder, insertAt, name)
  end

  HB.profile.customCategories[name] = rule
  self.selectedCategory = name
  self:RefreshCategoryRows()
  if HB.UI then HB.UI:RefreshOpenViews() end
  HB:Print("Saved category " .. name .. ".")
end

function Settings:DeleteCategory()
  local name = self.selectedCategory
  if not name or not HB.profile.customCategories[name] then
    HB:Print("Select a custom category first.")
    return
  end
  HB.profile.customCategories[name] = nil
  HB.profile.collapsedCategories[name] = nil
  RemoveFromOrder(name)
  self.selectedCategory = nil
  self.categoryName:SetText("")
  self.categoryRule:SetText("")
  self:RefreshCategoryRows()
  if HB.UI then HB.UI:RefreshOpenViews() end
end

function Settings:RefreshCategoryRows()
  if not self.categoryRows then return end
  for index, row in ipairs(self.categoryRows) do
    local name = HB.profile.categoryOrder[index]
    if name then
      row.name = name
      row.label:SetText((HB.profile.customCategories[name] and "* " or "") .. name)
      row.up:SetEnabled(index > 1)
      row.down:SetEnabled(index < #HB.profile.categoryOrder)
      row:Show()
    else
      row:Hide()
    end
  end
end

function Settings:CreateCategoryPanel(parent)
  local panel = CreateFrame("Frame", "HeliosBagsCategoryOptionsPanel", parent)
  panel.name = "Categories"
  panel.parent = "HeliosBags"
  self.categoryPanel = panel

  AddLabel(panel, "Category order", 16, -16, "GameFontNormalLarge")
  AddLabel(panel, "Use the arrows to change display order. Custom categories are marked with an asterisk.", 16, -43, "GameFontHighlightSmall")
  self.categoryRows = {}

  for index = 1, 16 do
    local rowIndex = index
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(330, 24)
    row:SetPoint("TOPLEFT", 16, -62 - (index - 1) * 25)

    local up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    up:SetSize(27, 22)
    up:SetPoint("LEFT")
    up:SetText("^")
    up:SetScript("OnClick", function() self:MoveCategory(rowIndex, -1) end)
    row.up = up

    local down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    down:SetSize(27, 22)
    down:SetPoint("LEFT", up, "RIGHT", 2, 0)
    down:SetText("v")
    down:SetScript("OnClick", function() self:MoveCategory(rowIndex, 1) end)
    row.down = down

    local label = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    label:SetSize(245, 22)
    label:SetPoint("LEFT", down, "RIGHT", 5, 0)
    label:SetScript("OnClick", function() self:SelectCategory(row.name) end)
    row.label = label
    self.categoryRows[index] = row
  end

  AddLabel(panel, "Add or edit a custom category", 370, -62, "GameFontNormalLarge")
  AddLabel(panel, "Rules match item names or types, such as potion, cloth, or plate.", 370, -88, "GameFontHighlightSmall")
  self.categoryName = AddEditBox(panel, "HeliosBagsCategoryName", "Category name", 370, -120, 190)
  self.categoryRule = AddEditBox(panel, "HeliosBagsCategoryRule", "Search rule", 370, -180, 190)

  local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  save:SetSize(92, 24)
  save:SetPoint("TOPLEFT", 374, -238)
  save:SetText("Save")
  save:SetScript("OnClick", function() self:SaveCategory() end)

  local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  deleteButton:SetSize(92, 24)
  deleteButton:SetPoint("LEFT", save, "RIGHT", 8, 0)
  deleteButton:SetText("Delete")
  deleteButton:SetScript("OnClick", function() self:DeleteCategory() end)

  local back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  back:SetSize(192, 24)
  back:SetPoint("TOPLEFT", 374, -294)
  back:SetText("Back to HeliosBags settings")
  back:SetScript("OnClick", function() self:Open() end)

  panel:SetScript("OnShow", function() self:RefreshCategoryRows() end)
  InterfaceOptions_AddCategory(panel, true)
end

function Settings:Initialize()
  local parent = InterfaceOptionsFramePanelContainer or UIParent
  self:CreateMainPanel(parent)
  self:CreateCategoryPanel(parent)
end

function Settings:OpenPanel(panel)
  if InterfaceAddOnsList_Update then InterfaceAddOnsList_Update() end
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

function Settings:Open() self:OpenPanel(self.panel) end
function Settings:OpenCategories() self:OpenPanel(self.categoryPanel) end
