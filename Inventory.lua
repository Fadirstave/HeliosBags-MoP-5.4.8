local _, HB = ...
local Inventory = {}
HB.Inventory = Inventory
HB:RegisterModule("Inventory", Inventory)

local BAG_FIRST, BAG_LAST = 0, 4

local function ItemIDFromLink(link)
  if not link then return nil end
  return tonumber(string.match(link, "item:(%-?%d+):"))
end

local function ReadSlot(bag, slot)
  local texture, count, locked, quality, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
  if not texture then
    return { bag = bag, slot = slot, empty = true }
  end

  itemID = itemID or ItemIDFromLink(link)
  local name, itemLink, itemQuality, itemLevel, _, itemType, itemSubType, _, equipLoc, itemTexture, sellPrice = GetItemInfo(link or itemID)
  return {
    bag = bag,
    slot = slot,
    itemID = itemID,
    name = name or link or "Loading...",
    link = itemLink or link,
    texture = itemTexture or texture,
    count = count or 1,
    locked = locked,
    quality = itemQuality or quality,
    itemLevel = itemLevel,
    type = itemType,
    subType = itemSubType,
    equipLoc = equipLoc,
    sellPrice = sellPrice,
  }
end

local function IsSellableJunk(item)
  return not item.empty
    and not item.locked
    and item.quality == 0
    and (item.sellPrice or 0) > 0
end

function Inventory:Initialize()
  self.items = {}
  self.lastBagCounts = {}
  self.hasBagBaseline = false
  self.loginBaselinePending = true
  self.loginBaselineElapsed = 0
  self.loginBaselineDriver = CreateFrame("Frame")
  self.loginBaselineDriver:SetScript("OnUpdate", function(driver, elapsed)
    self.loginBaselineElapsed = self.loginBaselineElapsed + elapsed
    if self.loginBaselineElapsed >= 2 then
      self:Scan(true)
      self.loginBaselinePending = false
      driver:Hide()
    end
  end)
  self.events = CreateFrame("Frame")
  self.events:RegisterEvent("BAG_UPDATE")
  self.events:RegisterEvent("BAG_UPDATE_COOLDOWN")
  self.events:RegisterEvent("ITEM_LOCK_CHANGED")
  self.events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.events:RegisterEvent("CHAT_MSG_LOOT")
  self.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      self.loginBaselinePending = true
      self.loginBaselineElapsed = 0
      self.loginBaselineDriver:Show()
      self:Scan(true)
    elseif event ~= "BAG_UPDATE_COOLDOWN" then
      self:Scan(self.loginBaselinePending)
    end
    if HB.UI and HB.UI.frame and HB.UI.frame:IsShown() then HB.UI:Refresh(false) end
  end)
  self.loginBaselineDriver:Show()
  self:Scan(true)
end

function Inventory:Scan(establishBaseline)
  local result = {}
  for bag = BAG_FIRST, BAG_LAST do
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do result[#result + 1] = ReadSlot(bag, slot) end
  end

  self.items = result
  self:DetectNewItems(result, establishBaseline)
  self:SaveSnapshot(result)
  return result
end

function Inventory:DetectNewItems(items, establishBaseline)
  local current = {}
  for _, item in ipairs(items) do
    if not item.empty and item.itemID then
      current[item.itemID] = (current[item.itemID] or 0) + (item.count or 1)
    end
  end

  if self.hasBagBaseline and not establishBaseline then
    for itemID, count in pairs(current) do
      local added = count - (self.lastBagCounts[itemID] or 0)
      if added > 0 then HB.Categories:MarkRecent(itemID, added) end
    end
    for itemID, oldCount in pairs(self.lastBagCounts) do
      local removed = oldCount - (current[itemID] or 0)
      if removed > 0 then HB.Categories:RemoveRecentQuantity(itemID, removed) end
    end
  end

  self.lastBagCounts = current
  self.hasBagBaseline = true
end

function Inventory:SaveSnapshot(items)
  local key = HB:GetCharacterKey()
  HB.db.characters[key] = HB.db.characters[key] or { bags = {}, updated = 0 }
  local snapshot = {}
  for _, item in ipairs(items) do
    if not item.empty then
      snapshot[#snapshot + 1] = {
        itemID = item.itemID, link = item.link, count = item.count, texture = item.texture,
        quality = item.quality, name = item.name, type = item.type, subType = item.subType,
        equipLoc = item.equipLoc, itemLevel = item.itemLevel,
      }
    end
  end
  HB.db.characters[key].bags = snapshot
  HB.db.characters[key].updated = time()
end

function Inventory:GetItems()
  return self.items
end

function Inventory:GetTotalCount(itemID)
  local total = 0
  for _, record in pairs(HB.db.characters) do
    for _, item in ipairs(record.bags or {}) do
      if item.itemID == itemID then total = total + (item.count or 1) end
    end
  end
  return total
end

function Inventory:GetJunkSummary()
  local stacks, value = 0, 0
  for _, item in ipairs(self.items) do
    if IsSellableJunk(item) then
      stacks = stacks + 1
      value = value + item.sellPrice * (item.count or 1)
    end
  end
  return stacks, value
end

function Inventory:SellJunk()
  if not MerchantFrame or not MerchantFrame:IsShown() then return 0, 0 end
  local junk, value = {}, 0
  for _, item in ipairs(self.items) do
    if IsSellableJunk(item) then
      junk[#junk + 1] = item
      value = value + item.sellPrice * (item.count or 1)
    end
  end
  table.sort(junk, function(a, b)
    if a.bag ~= b.bag then return a.bag > b.bag end
    return a.slot > b.slot
  end)
  for _, item in ipairs(junk) do UseContainerItem(item.bag, item.slot) end
  return #junk, value
end
