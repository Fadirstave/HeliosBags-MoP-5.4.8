local _, HB = ...
local Categories = {}
HB.Categories = Categories
HB:RegisterModule("Categories", Categories)

local TYPE_RULES = {
  { category = "Consumables", values = { "Consumable", "Food & Drink", "Potion", "Elixir", "Flask", "Bandage" } },
  { category = "Containers", values = { "Container", "Bag" } },
  { category = "Trade Goods", values = { "Trade Goods", "Gem", "Recipe", "Glyph" } },
}

function Categories:Initialize()
  HeliosBagsCharacterDB.recent = nil
  HeliosBagsCharacterDB.recentDataVersion = nil
  self.recent = {}
end

local function Contains(haystack, needle)
  return haystack and needle and string.find(string.lower(haystack), string.lower(needle), 1, true)
end

function Categories:MatchesSearch(item, search, category)
  search = strtrim(string.lower(search or ""))
  if search == "" then return true end
  local negative = string.sub(search, 1, 1) == "!"
  if negative then search = strtrim(string.sub(search, 2)) end
  if search == "" then return true end

  local matches = Contains(item.name, search)
    or Contains(item.type, search)
    or Contains(item.subType, search)
    or Contains(item.equipLoc, search)
    or Contains(item.link, search)
    or Contains(category, search)

  if string.sub(search, 1, 1) == ">" then
    matches = (item.itemLevel or 0) > (tonumber(string.sub(search, 2)) or 0)
  elseif string.sub(search, 1, 1) == "<" then
    matches = (item.itemLevel or 0) < (tonumber(string.sub(search, 2)) or 0)
  end

  return negative and not matches or not negative and not not matches
end

function Categories:CanBeRecent(item)
  if not item or item.empty or not item.itemID then return false end
  if item.itemID == 6948
    or Contains(item.name, "Hearthstone")
    or Contains(item.texture, "inv_misc_rune_01") then
    return false
  end
  return not HB.profile.itemOverrides[tostring(item.itemID or 0)]
end

function Categories:GetRecentQuantity(itemID)
  local record = itemID and self.recent[itemID]
  if type(record) ~= "table" then return 0 end
  local quantity = 0
  for _, batch in ipairs(record) do quantity = quantity + math.max(0, batch.quantity or 0) end
  return quantity
end

function Categories:GetCategory(item)
  if item.empty then return "Empty" end

  if item.itemID == 6948
    or Contains(item.name, "Hearthstone")
    or Contains(item.texture, "inv_misc_rune_01") then
    return "Hearthstones"
  end

  local override = HB.profile.itemOverrides[tostring(item.itemID or 0)]
  if override then return override end

  for _, name in ipairs(HB.profile.categoryOrder) do
    local rule = HB.profile.customCategories[name]
    if rule and self:MatchesSearch(item, rule) then return name end
  end

  if item.quality == 0 then return "Junk" end
  if item.type == "Quest" or item.isQuestItem then return "Quest" end
  local equipLoc = item.equipLoc or ""
  if equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG" and equipLoc ~= "INVTYPE_QUIVER" then
    return "Equipment"
  end

  for _, rule in ipairs(TYPE_RULES) do
    for _, value in ipairs(rule.values) do
      if Contains(item.type, value) or Contains(item.subType, value) then return rule.category end
    end
  end

  return "Miscellaneous"
end

function Categories:MarkRecent(itemID, quantity)
  quantity = tonumber(quantity) or 0
  if not itemID or quantity <= 0 then return end
  local record = self.recent[itemID] or {}
  local now = GetTime()
  local last = record[#record]
  if last and now - (last.acquiredAt or 0) < 0.25 then
    last.quantity = (last.quantity or 0) + quantity
  else
    record[#record + 1] = { quantity = quantity, acquiredAt = now }
  end
  self.recent[itemID] = record
end

function Categories:RemoveRecentQuantity(itemID, quantity)
  local record = itemID and self.recent[itemID]
  quantity = tonumber(quantity) or 0
  if type(record) ~= "table" or quantity <= 0 then return end
  local index = 1
  while quantity > 0 and record[index] do
    local available = math.max(0, record[index].quantity or 0)
    local removed = math.min(quantity, available)
    record[index].quantity = available - removed
    quantity = quantity - removed
    if record[index].quantity <= 0 then table.remove(record, index) else index = index + 1 end
  end
  if #record == 0 then self.recent[itemID] = nil end
end

function Categories:ClearExpiredRecent()
  local changed = false
  local now = GetTime()
  local timeout = math.max(0, tonumber(HB.profile.recentTimeout) or 15)
  for itemID, record in pairs(self.recent) do
    for index = #record, 1, -1 do
      local batch = record[index]
      if (batch.quantity or 0) <= 0 or now - (batch.acquiredAt or 0) >= timeout then
        table.remove(record, index)
        changed = true
      end
    end
    if #record == 0 then self.recent[itemID] = nil end
  end
  return changed
end
