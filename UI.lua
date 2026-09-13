local _, HB = ...
local UI = {}
HB.UI = UI
HB:RegisterModule("UI", UI)

local BUTTON_LIMIT = 220

local function ApplyBackdrop(frame)
  local profile = HB.profile
  local background = profile.neutralBackground and "Interface\\Buttons\\WHITE8X8"
    or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
  frame:SetBackdrop({
    bgFile = background,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  local alpha = profile.backgroundAlpha or 0.98
  if profile.darkMode then
    if profile.neutralBackground then
      frame:SetBackdropColor(0.055, 0.055, 0.055, alpha)
    else
      frame:SetBackdropColor(0.025, 0.03, 0.04, alpha)
    end
    frame:SetBackdropBorderColor(0.16, 0.38, 0.48, 0.95)
  else
    if profile.neutralBackground then
      frame:SetBackdropColor(0.18, 0.18, 0.18, alpha)
    else
      frame:SetBackdropColor(0.16, 0.12, 0.075, alpha)
    end
    frame:SetBackdropBorderColor(0.50, 0.40, 0.24, 0.95)
  end
end

local function CreateEdgeBorder(parent, frameLevel, outset, thickness, blendMode)
  local border = CreateFrame("Frame", nil, parent)
  border:SetFrameLevel(frameLevel)
  border:SetPoint("TOPLEFT", -outset, outset)
  border:SetPoint("BOTTOMRIGHT", outset, -outset)
  border:EnableMouse(false)
  border.edges = {}

  local top = border:CreateTexture(nil, "OVERLAY")
  top:SetTexture("Interface\\Buttons\\WHITE8X8")
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(thickness)
  border.edges[#border.edges + 1] = top

  local bottom = border:CreateTexture(nil, "OVERLAY")
  bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(thickness)
  border.edges[#border.edges + 1] = bottom

  local left = border:CreateTexture(nil, "OVERLAY")
  left:SetTexture("Interface\\Buttons\\WHITE8X8")
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMLEFT")
  left:SetWidth(thickness)
  border.edges[#border.edges + 1] = left

  local right = border:CreateTexture(nil, "OVERLAY")
  right:SetTexture("Interface\\Buttons\\WHITE8X8")
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMRIGHT")
  right:SetWidth(thickness)
  border.edges[#border.edges + 1] = right

  for _, edge in ipairs(border.edges) do
    if blendMode then edge:SetBlendMode(blendMode) end
  end

  function border:SetColor(red, green, blue, alpha)
    for _, edge in ipairs(self.edges) do edge:SetVertexColor(red, green, blue, alpha) end
  end

  return border
end

local function CreateItemButton(parent, index)
  local button = CreateFrame("Button", "HeliosBagsItem" .. index, parent, "ItemButtonTemplate,SecureActionButtonTemplate")
  button:SetFrameLevel(parent:GetFrameLevel() + 5)
  button:SetNormalTexture(nil)
  local itemBorder = CreateEdgeBorder(button, button:GetFrameLevel() + 6, 0, 2)
  itemBorder:SetColor(0.38, 0.40, 0.43, 0.95)
  button.itemBorder = itemBorder
  local questTexture = button.IconQuestTexture or _G[button:GetName() .. "IconQuestTexture"]
  if not questTexture then
    questTexture = button:CreateTexture(nil, "OVERLAY")
    questTexture:SetAllPoints(button)
  end
  questTexture:Hide()
  button.questTexture = questTexture
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  local function PickupItem(self)
    if not self.item or self.item.empty or not self.item.bag or self.item.locked then return end
    PickupContainerItem(self.item.bag, self.item.slot)
  end
  button:SetScript("OnDragStart", PickupItem)
  button:SetScript("OnReceiveDrag", PickupItem)
  button:SetScript("OnEnter", function(self)
    UI.hoveredButton = self
    UI:ShowItemTooltip(self)
  end)
  button:SetScript("OnLeave", function()
    UI.hoveredButton = nil
    GameTooltip_Hide()
    if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
    if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
  end)
  button:SetScript("PostClick", function(self, mouseButton)
    if not self.item or self.item.empty or not self.item.bag then return end
    if IsModifiedClick() and self.item.link and HandleModifiedItemClick(self.item.link) then return end
    if mouseButton == "LeftButton" then
      PickupContainerItem(self.item.bag, self.item.slot)
    elseif mouseButton == "RightButton" and UI.merchantOpen then
      UseContainerItem(self.item.bag, self.item.slot)
    end
  end)
  return button
end

function UI:Initialize()
  self.search = ""
  self.layoutFrozen = false
  self.merchantOpen = false
  self.buttons = {}
  self.headers = {}
  self.rowSeparators = {}
  self:CreateFrame()
  self:HookBags()
  self:RegisterContextEvents()
end

function UI:ShowItemTooltip(button)
  if not button or not button.item or button.item.empty then return end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if button.item.bag and button.item.slot then GameTooltip:SetBagItem(button.item.bag, button.item.slot)
  elseif button.item.link then GameTooltip:SetHyperlink(button.item.link) end
  local total = HB.Inventory:GetTotalCount(button.item.itemID)
  if total > 0 then GameTooltip:AddLine("All characters: " .. total, 0.35, 0.78, 1) end
  GameTooltip:Show()
end

function UI:RegisterContextEvents()
  self.contextEvents = CreateFrame("Frame")
  self.contextEvents:RegisterEvent("MERCHANT_SHOW")
  self.contextEvents:RegisterEvent("MERCHANT_CLOSED")
  self.contextEvents:RegisterEvent("PLAYER_MONEY")
  self.contextEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.contextEvents:SetScript("OnEvent", function(_, event, key)
    if event == "MERCHANT_SHOW" then
      self.merchantOpen = true
      self:UpdateSecureItemActions()
      self:QueueBagAction("open")
      self:UpdateFooter()
    elseif event == "MERCHANT_CLOSED" then
      self.merchantOpen = false
      self:UpdateSecureItemActions()
      self.pendingBagAction = nil
      if self.bagHookDriver then self.bagHookDriver:Hide() end
      if CloseAllBags then CloseAllBags() end
      if self.frame:IsShown() then self:Hide() end
    elseif event == "PLAYER_MONEY" then
      self:UpdateMoney()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if self.secureActionsPending then self:UpdateSecureItemActions() end
      if self.recentRefreshPending and self.frame:IsShown() then
        self.recentRefreshPending = nil
        self.layoutFrozen = false
        self:Refresh(true)
      end
    end
  end)
end

function UI:SetSecureItemAction(button, item)
  if InCombatLockdown and InCombatLockdown() then
    self.secureActionsPending = true
    return
  end

  button:SetAttribute("type2", nil)
  button:SetAttribute("item2", nil)

  if item and not item.empty and not self.merchantOpen then
    local itemToken = item.itemID and ("item:" .. tostring(item.itemID)) or item.link
    if itemToken then
      button:SetAttribute("type2", "item")
      button:SetAttribute("item2", itemToken)
    end
  end
end

function UI:UpdateSecureItemActions()
  if InCombatLockdown and InCombatLockdown() then
    self.secureActionsPending = true
    return
  end
  self.secureActionsPending = false
  for _, button in ipairs(self.buttons or {}) do
    self:SetSecureItemAction(button, button.item)
  end
end

function UI:UpdateMoney()
  if not self.money then return end
  local amount = GetMoney() or 0
  if GetCoinTextureString then self.money:SetText(GetCoinTextureString(amount))
  elseif GetMoneyString then self.money:SetText(GetMoneyString(amount, true))
  else self.money:SetText(tostring(amount)) end
end

function UI:ApplyAppearance()
  if self.frame then ApplyBackdrop(self.frame) end
end

function UI:CreateFrame()
  local frame = CreateFrame("Frame", "HeliosBagsFrame", UIParent)
  self.frame = frame
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScale(HB.profile.scale)
  frame:SetSize(680, 420)
  local pos = HB.profile.position
  frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
  ApplyBackdrop(frame)
  frame:Hide()

  frame:SetScript("OnUpdate", function(_, elapsed)
    self.recentElapsed = (self.recentElapsed or 0) + elapsed
    if self.recentElapsed < 0.25 then return end
    self.recentElapsed = 0
    if HB.Categories:ClearExpiredRecent() then
      if InCombatLockdown and InCombatLockdown() then
        self.recentRefreshPending = true
      else
        self.layoutFrozen = false
        self:Refresh(true)
      end
    end
  end)

  frame:SetScript("OnDragStart", function(self)
    if not HB.profile.locked then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint(1)
    HB.profile.position = { point = point, x = x, y = y }
  end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("HeliosBags")
  self.title = title

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -3, -3)

  local options = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  options:SetSize(64, 23)
  options:SetPoint("TOPRIGHT", -39, -39)
  options:SetText("Options")
  options:SetScript("OnClick", function()
    if HB.Settings and HB.Settings.Open then HB.Settings:Open() end
  end)

  local search = CreateFrame("EditBox", "HeliosBagsSearchBox", frame, "SearchBoxTemplate")
  search:SetSize(210, 22)
  search:SetPoint("TOPLEFT", 12, -68)
  search:SetAutoFocus(false)
  search:SetScript("OnTextChanged", function(edit)
    if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(edit) end
    local value = edit:GetText() or ""
    if not edit:HasFocus() and (value == "Search" or value == SEARCH) then value = "" end
    self.search = value
    self:Refresh(true)
  end)
  search:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
  search:SetScript("OnEscapePressed", function(edit)
    edit:SetText("")
    edit:ClearFocus()
  end)
  self.searchBox = search

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("LEFT", search, "RIGHT", 12, 0)
  status:SetWidth(155)
  status:SetJustifyH("LEFT")
  self.status = status

  local money = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  money:SetPoint("BOTTOMRIGHT", -12, 10)
  money:SetWidth(170)
  money:SetJustifyH("RIGHT")
  self.money = money
  self:UpdateMoney()

  local sellJunk = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  sellJunk:SetSize(118, 23)
  sellJunk:SetPoint("BOTTOMLEFT", 12, 7)
  sellJunk:SetText("Sell Junk")
  sellJunk:RegisterForClicks("LeftButtonUp")
  sellJunk:SetScript("OnClick", function(button)
    button:SetEnabled(false)
    button:SetText("Selling...")
    local stacks, value = HB.Inventory:SellJunk()
    if stacks > 0 then
      local moneyText = GetCoinTextureString and GetCoinTextureString(value) or tostring(value)
      HB:Print("Selling " .. stacks .. " junk stack" .. (stacks == 1 and "" or "s") .. " for about " .. moneyText .. ".")
    else
      self:UpdateFooter()
    end
  end)
  sellJunk:SetScript("OnEnter", function(button)
    local stacks, value = HB.Inventory:GetJunkSummary()
    GameTooltip:SetOwner(button, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Sell all junk")
    GameTooltip:AddLine("Sells every unlocked gray-quality item in your bags.", 0.85, 0.85, 0.85, true)
    local moneyText = GetCoinTextureString and GetCoinTextureString(value) or tostring(value)
    GameTooltip:AddDoubleLine("Stacks", stacks, 0.75, 0.82, 0.90, 1, 1, 1)
    GameTooltip:AddDoubleLine("Estimated value", moneyText, 0.75, 0.82, 0.90, 1, 1, 1)
    GameTooltip:Show()
  end)
  sellJunk:SetScript("OnLeave", GameTooltip_Hide)
  sellJunk:Hide()
  self.sellJunk = sellJunk

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", 10, -98)
  content:SetSize(430, 1)
  self.content = content

  for i = 1, BUTTON_LIMIT do
    self.buttons[i] = CreateItemButton(content, i)
    self.buttons[i]:Hide()
  end
end

function UI:HookBags()
  self.bagHookDriver = CreateFrame("Frame")
  self.bagHookDriver:Hide()
  self.bagHookDriver:SetScript("OnUpdate", function(driver)
    driver:Hide()
    local action = self.pendingBagAction
    self.pendingBagAction = nil
    if CloseAllBags then CloseAllBags() end
    if action == "toggle" then
      if self.frame:IsShown() then self:Hide() else self:Show() end
    elseif action == "open" and not self.frame:IsShown() then
      self:Show()
    end
  end)

  local function Hook(name, action)
    if _G[name] then
      hooksecurefunc(name, function() self:QueueBagAction(action) end)
    end
  end

  local function HookToggle(name)
    if not _G[name] then return end
    hooksecurefunc(name, function()
      local stack = debugstack and debugstack() or ""
      if string.find(stack, "OpenAllBags", 1, true)
        or string.find(stack, "CloseAllBags", 1, true)
        or string.find(stack, "OpenBackpack", 1, true)
        or string.find(stack, "OpenBag", 1, true) then
        return
      end
      self:QueueBagAction("toggle")
    end)
  end

  HookToggle("ToggleAllBags")
  Hook("OpenAllBags", "open")
  HookToggle("ToggleBackpack")
  Hook("OpenBackpack", "open")
  HookToggle("ToggleBag")
  Hook("OpenBag", "open")
end

function UI:QueueBagAction(action)
  if action == "toggle" or not self.pendingBagAction then self.pendingBagAction = action end
  self.bagHookDriver:Show()
end

function UI:Show()
  if CloseAllBags then CloseAllBags() end
  HB.Categories:ClearExpiredRecent()
  HB.Inventory:Scan()
  self.frame:Show()
  self.layoutFrozen = false
  self:Refresh(true)
  self.layoutFrozen = true
end

function UI:Hide()
  self.frame:Hide()
  self.layoutFrozen = false
end

function UI:IsCategoryCollapsed(category)
  return self.search == "" and HB.profile.collapsedCategories[category] == true
end

function UI:ToggleCategory(category)
  if not category or self.search ~= "" then return end
  HB.profile.collapsedCategories[category] = not HB.profile.collapsedCategories[category] or nil
  self.layoutFrozen = false
  self:Refresh(true)
end

local equipmentOrder = {
  INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 4,
  INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WRIST = 6, INVTYPE_HAND = 7,
  INVTYPE_WAIST = 8, INVTYPE_LEGS = 9, INVTYPE_FEET = 10, INVTYPE_FINGER = 11,
  INVTYPE_TRINKET = 12, INVTYPE_WEAPONMAINHAND = 13, INVTYPE_2HWEAPON = 14,
  INVTYPE_WEAPONOFFHAND = 15, INVTYPE_WEAPON = 16, INVTYPE_HOLDABLE = 17,
  INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18,
  INVTYPE_SHIELD = 19, INVTYPE_TABARD = 20, INVTYPE_BODY = 21,
}

local function SortItems(a, b)
  if a.empty ~= b.empty then return not a.empty end
  local aPriority = a.itemID == 6948 and 0 or 1
  local bPriority = b.itemID == 6948 and 0 or 1
  if aPriority ~= bPriority then return aPriority < bPriority end
  if (a.type or "") ~= (b.type or "") then return (a.type or "") < (b.type or "") end
  local aEquip = equipmentOrder[a.equipLoc or ""] or 999
  local bEquip = equipmentOrder[b.equipLoc or ""] or 999
  if aEquip ~= bEquip then return aEquip < bEquip end
  if (a.subType or "") ~= (b.subType or "") then return (a.subType or "") < (b.subType or "") end
  if (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
  if (a.quality or -1) ~= (b.quality or -1) then return (a.quality or -1) > (b.quality or -1) end
  if a.name ~= b.name then return (a.name or "") < (b.name or "") end
  if (a.itemID or 0) ~= (b.itemID or 0) then return (a.itemID or 0) > (b.itemID or 0) end
  if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
  if (a.bag or 0) ~= (b.bag or 0) then return (a.bag or 0) < (b.bag or 0) end
  return (a.slot or 0) < (b.slot or 0)
end

local function CopyItemCount(item, count)
  local copy = {}
  for field, value in pairs(item) do copy[field] = value end
  copy.count = count
  return copy
end

function UI:GetCategorizedItems()
  local result = {}
  local recentRemaining = {}

  for _, item in ipairs(HB.Inventory:GetItems()) do
    if not HB.profile.categoryView then
      result[#result + 1] = { item = item, category = "All Items" }
    elseif item.empty then
      result[#result + 1] = { item = item, category = "Empty" }
    else
      local baseCategory = HB.Categories:GetCategory(item)
      local recentCount = 0
      if HB.Categories:CanBeRecent(item) then
        if recentRemaining[item.itemID] == nil then
          recentRemaining[item.itemID] = HB.Categories:GetRecentQuantity(item.itemID)
        end
        recentCount = math.min(item.count or 1, recentRemaining[item.itemID] or 0)
        recentRemaining[item.itemID] = math.max(0, (recentRemaining[item.itemID] or 0) - recentCount)
      end

      if recentCount > 0 then
        result[#result + 1] = { item = CopyItemCount(item, recentCount), category = "Recent" }
      end
      local baseCount = (item.count or 1) - recentCount
      if baseCount > 0 then
        result[#result + 1] = { item = CopyItemCount(item, baseCount), category = baseCategory }
      end
    end
  end

  return result
end

function UI:GetGroupedItems()
  local groups, order, aggregated = {}, {}, {}
  if HB.profile.categoryView then
    for _, name in ipairs(HB.profile.categoryOrder) do groups[name] = {} order[#order + 1] = name end
    for name in pairs(HB.profile.customCategories) do
      if not groups[name] then groups[name] = {} order[#order + 1] = name end
    end
  else
    groups["All Items"] = {}
    order[1] = "All Items"
  end

  for _, entry in ipairs(self:GetCategorizedItems()) do
    local item, category = entry.item, entry.category
    if (HB.profile.showEmpty or not item.empty) and HB.Categories:MatchesSearch(item, self.search, category) then
      groups[category] = groups[category] or {}
      if item.empty then
        aggregated[category] = aggregated[category] or {}
        if not aggregated[category].emptySlots then
          aggregated[category].emptySlots = { empty = true, count = 0 }
          groups[category][#groups[category] + 1] = aggregated[category].emptySlots
        end
        aggregated[category].emptySlots.count = aggregated[category].emptySlots.count + 1
      else
        aggregated[category] = aggregated[category] or {}
        local itemKey = item.link or tostring(item.itemID or item.name or #groups[category] + 1)
        local key = category .. "\031" .. itemKey
        local displayItem = aggregated[category][key]
        if not displayItem then
          displayItem = CopyItemCount(item, 0)
          displayItem.stacks = {}
          displayItem.groupKey = key
          aggregated[category][key] = displayItem
          groups[category][#groups[category] + 1] = displayItem
        end
        displayItem.count = displayItem.count + (item.count or 1)
        displayItem.stacks[#displayItem.stacks + 1] = { bag = item.bag, slot = item.slot, count = item.count or 1 }
      end
    end
  end
  for _, list in pairs(groups) do table.sort(list, SortItems) end
  return groups, order
end

function UI:RenderButton(button, item)
  button.item = item
  self:SetSecureItemAction(button, item)
  button.questTexture:Hide()
  button:SetAlpha(1)
  SetItemButtonTexture(button, item and item.texture or nil)
  SetItemButtonCount(button, item and item.count or 0)

  local icon = button.icon or button.IconTexture or _G[button:GetName() .. "IconTexture"]
  if icon then
    icon:SetDesaturated(false)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetAlpha(1)
  end

  if button.IconBorder then button.IconBorder:Hide() end
  if item and item.quality and item.quality > 1 then
    local r, g, b = GetItemQualityColor(item.quality)
    button.itemBorder:SetColor(r, g, b, 1)
  else
    button.itemBorder:SetColor(0.38, 0.40, 0.43, 0.95)
  end

  if item and not item.empty and (item.questID or item.isQuestItem) then
    if item.startsQuest then
      button.questTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\UI-Icon-QuestBang")
    else
      button.questTexture:SetTexture(TEXTURE_ITEM_QUEST_BORDER or "Interface\\ContainerFrame\\UI-Icon-QuestBorder")
    end
    button.questTexture:Show()
  end
end

function UI:UpdateFooter()
  if not self.sellJunk then return end
  local atMerchant = self.merchantOpen or (MerchantFrame and MerchantFrame:IsShown())
  if atMerchant then
    local stacks = HB.Inventory:GetJunkSummary()
    self.sellJunk:SetText(stacks > 0 and ("Sell Junk (" .. stacks .. ")") or "No Junk")
    self.sellJunk:SetEnabled(stacks > 0)
    self.sellJunk:Show()
    return
  end

  self.sellJunk:Hide()
end

function UI:GetLiveGroupedItems()
  local live = {}
  local emptyCount = 0
  local totalGroups = 0
  local totalQuantity = 0
  local grouped, order = self:GetGroupedItems()
  for _, category in ipairs(order) do
    local items = grouped[category]
    if items and #items > 0 then
      totalGroups = totalGroups + #items
      for _, item in ipairs(items) do
        totalQuantity = totalQuantity + (item.empty and 0 or item.count or 1)
        if not self:IsCategoryCollapsed(category) then
          if item.empty then
            emptyCount = item.count or 0
          else
            item.category = category
            live[item.groupKey] = item
          end
        end
      end
    end
  end
  return live, emptyCount, totalGroups, totalQuantity
end

function UI:RefreshFrozenItems()
  local live, emptyCount, totalGroups, totalQuantity = self:GetLiveGroupedItems()
  local displayed = {}

  for _, button in ipairs(self.buttons) do
    if button:IsShown() and button.groupKey then displayed[button.groupKey] = button end
  end
  for key, item in pairs(live) do
    local button = displayed[key]
    if not button or item.category ~= button.category then
      self:Refresh(true)
      return
    end
  end

  for _, button in ipairs(self.buttons) do
    if button:IsShown() then
      if button.groupKey then
        local item = live[button.groupKey]
        if item then
          self:RenderButton(button, item)
        else
          self:RenderButton(button, { empty = true, frozen = true })
        end
      elseif button.isEmptySummary then
        self:RenderButton(button, { empty = true, count = emptyCount })
      end
    end
  end
  self.status:SetText(totalGroups .. " groups  •  " .. totalQuantity .. " items")
  self:UpdateFooter()
end

function UI:GetHeader(index)
  if self.headers[index] then return self.headers[index] end
  local header = CreateFrame("Button", nil, self.content)
  header:RegisterForClicks("LeftButtonUp")
  header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  arrow:SetPoint("LEFT", 1, 0)
  arrow:SetWidth(11)
  arrow:SetJustifyH("LEFT")
  header.arrow = arrow
  local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", arrow, "RIGHT", 1, 0)
  label:SetPoint("RIGHT", header, "RIGHT", -2, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  header.label = label
  header:SetScript("OnClick", function(button) self:ToggleCategory(button.category) end)
  self.headers[index] = header
  return header
end

function UI:GetRowSeparator(index)
  if self.rowSeparators[index] then return self.rowSeparators[index] end
  local separator = self.content:CreateTexture(nil, "BACKGROUND")
  separator:SetTexture("Interface\\Buttons\\WHITE8X8")
  separator:SetVertexColor(0.35, 0.35, 0.35, 0.45)
  self.rowSeparators[index] = separator
  return separator
end

function UI:Refresh(forceLayout)
  if not self.frame:IsShown() then return end
  self:ApplyAppearance()
  if forceLayout == false and self.layoutFrozen then
    self:RefreshFrozenItems()
    return
  end

  for _, button in ipairs(self.buttons) do
    button:Hide()
    button.item = nil
    button.groupKey = nil
    button.isEmptySummary = nil
    button.category = nil
  end
  for _, header in ipairs(self.headers) do header:Hide() end
  for _, separator in ipairs(self.rowSeparators) do separator:Hide() end

  local groups, order = self:GetGroupedItems()
  local size, spacing = HB.profile.buttonSize, HB.profile.buttonSpacing
  local cell = size + spacing
  local rowGap = 7
  local headerHeight = 19
  local availableWidth = (UIParent:GetWidth() - 60) / HB.profile.scale
  local configuredColumns = math.max(4, HB.profile.sectionItemColumns)
  local screenColumns = math.max(4, math.floor((availableWidth + spacing) / cell))
  local maxColumns = HB.profile.autoLayout and math.min(configuredColumns, screenColumns) or configuredColumns
  local targetWidth = maxColumns * cell - spacing
  local xPad, y = 4, -4
  local buttonIndex, headerIndex, separatorIndex = 1, 1, 1
  local totalGroups, totalQuantity = 0, 0

  local visibleCategories = 0
  for _, category in ipairs(order) do
    local list = groups[category]
    if list and #list > 0 then
      visibleCategories = visibleCategories + 1
      totalGroups = totalGroups + #list
      for _, item in ipairs(list) do
        totalQuantity = totalQuantity + (item.empty and 0 or item.count or 1)
      end
    end
  end

  local categoryIndex = 0
  for _, category in ipairs(order) do
    local list = groups[category]
    if list and #list > 0 then
      categoryIndex = categoryIndex + 1
      local collapsed = self:IsCategoryCollapsed(category)
      local columns = math.max(1, math.min(maxColumns, #list))
      local itemRows = collapsed and 0 or math.ceil(#list / columns)
      local categoryHeight = headerHeight
      if itemRows > 0 then categoryHeight = categoryHeight + itemRows * cell - spacing end

      local header = self:GetHeader(headerIndex)
      headerIndex = headerIndex + 1
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", xPad, y)
      header:SetSize(targetWidth, headerHeight)
      header.category = category
      local categoryCount = (#list == 1 and list[1].empty and list[1].count) or #list
      header.arrow:SetText(collapsed and ">" or "v")
      header.label:SetText(category .. "  |cff8296a8" .. categoryCount .. "|r")
      header:Show()

      if not collapsed then
        for index, item in ipairs(list) do
          local button = self.buttons[buttonIndex]
          if not button then break end
          buttonIndex = buttonIndex + 1
          local col = (index - 1) % columns
          local itemRow = math.floor((index - 1) / columns)
          button:ClearAllPoints()
          button:SetPoint("TOPLEFT", xPad + col * cell, y - headerHeight - itemRow * cell)
          button:SetSize(size, size)
          button.groupKey = item.groupKey
          button.isEmptySummary = item.empty and true or nil
          button.category = category
          self:RenderButton(button, item)
          button:Show()
        end
      end

      y = y - categoryHeight
      if categoryIndex < visibleCategories then
        local separator = self:GetRowSeparator(separatorIndex)
        separatorIndex = separatorIndex + 1
        separator:ClearAllPoints()
        separator:SetPoint("TOPLEFT", xPad, y - 3)
        separator:SetSize(targetWidth, 1)
        separator:Show()
        y = y - rowGap
      end
    end
  end

  local contentHeight = math.max(1, -y + 5)
  local contentWidth = math.max(420, targetWidth + xPad)
  local frameWidth = math.max(450, contentWidth + 20)
  local frameHeight = math.max(234, contentHeight + 136)
  local availableHeight = UIParent:GetHeight() - 140
  local availableFrameWidth = UIParent:GetWidth() - 50
  local fitScale = math.min(HB.profile.scale, availableHeight / frameHeight, availableFrameWidth / frameWidth)
  fitScale = math.max(0.5, fitScale)
  self.content:SetSize(contentWidth, contentHeight)
  self.frame:SetScale(fitScale)
  self.frame:SetSize(frameWidth, frameHeight)
  self.status:SetText(totalGroups .. " groups  •  " .. totalQuantity .. " items")
  self:UpdateMoney()
  self:UpdateFooter()
  self.title:SetText("HeliosBags " .. HB.version .. " — Bags")
  self.layoutFrozen = true
end
