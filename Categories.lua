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
  if HeliosBagsCharacterDB.recentDataVersion ~= 3 then
    HeliosBagsCharacterDB.recent = {}
    HeliosBagsCharacterDB.recentDataVersion = 3
  end
  self.recent = HeliosBagsCharacterDB.recent or {}
  for itemID, record in pairs(self.recent) do
    if type(record) ~= "table"
      or type(record.opens) ~= "number"
      or type(record.quantity) ~= "number"
      or record.opens <= 0
      or record.quantity <= 0 then
      self.recent[itemID] = nil
    end
  end
  HeliosBagsCharacterDB.recent = self.recent
end

local function Contains(haystack, needle)
  return haystack and needle and string.find(string.lower(haystack), string.lower(needle), 1, true)
end

function Categories:MatchesSearch(item, search)
  if not search or search == "" then return true end
  search = string.lower(search)
  local negative = string.sub(search, 1, 1) == "!"
  if negative then search = string.sub(search, 2) end

  local matches = Contains(item.name, search)
    or Contains(item.type, search)
    or Contains(item.subType, search)
    or Contains(item.equipLoc, search)
    or Contains(item.link, search)

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
  return type(record) == "table" and math.max(0, record.quantity or 0) or 0
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
  local record = self.recent[itemID]
  if type(record) ~= "table" then record = { quantity = 0 } end
  record.quantity = (record.quantity or 0) + quantity
  record.opens = HB.profile.recentBagOpens or 3
  self.recent[itemID] = record
end

function Categories:RemoveRecentQuantity(itemID, quantity)
  local record = itemID and self.recent[itemID]
  quantity = tonumber(quantity) or 0
  if type(record) ~= "table" or quantity <= 0 then return end
  record.quantity = math.max(0, (record.quantity or 0) - quantity)
  if record.quantity <= 0 then self.recent[itemID] = nil end
end

function Categories:OnBagOpened()
  for itemID, record in pairs(self.recent) do
    record.opens = (record.opens or 0) - 1
    if record.opens <= 0 or (record.quantity or 0) <= 0 then self.recent[itemID] = nil end
  end
end
