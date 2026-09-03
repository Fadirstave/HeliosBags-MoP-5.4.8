local _, HB = ...
local Upgrades = {}
HB.Upgrades = Upgrades
HB:RegisterModule("Upgrades", Upgrades)

local SLOT_MAP = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest",
  [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrists", [10] = "Hands",
  [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
  [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged", [19] = "Tabard",
}

local ARMOR_SLOTS = {
  INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
  INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true,
  INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

local INTELLECT_SPECS = {
  [62] = true, [63] = true, [64] = true, [65] = true, [102] = true, [105] = true,
  [256] = true, [257] = true, [258] = true, [262] = true, [264] = true,
  [265] = true, [266] = true, [267] = true, [270] = true,
}

local AGILITY_SPECS = {
  [103] = true, [104] = true, [253] = true, [254] = true, [255] = true,
  [259] = true, [260] = true, [261] = true, [263] = true,
  [268] = true, [269] = true,
}

local HEALER_SPECS = { [65] = true, [105] = true, [256] = true, [257] = true, [264] = true, [270] = true }
local TANK_SPECS = { [66] = true, [73] = true, [104] = true, [250] = true, [268] = true }

local CLASS_ARMOR = {
  DEATHKNIGHT = "Plate", DRUID = "Leather", HUNTER = "Mail", MAGE = "Cloth",
  MONK = "Leather", PALADIN = "Plate", PRIEST = "Cloth", ROGUE = "Leather",
  SHAMAN = "Mail", WARLOCK = "Cloth", WARRIOR = "Plate",
}

local ARMOR_SUBCLASS = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4 }

local STAT_DESCRIPTORS = {
  { "ITEM_MOD_AGILITY_SHORT", "Agility" },
  { "ITEM_MOD_STRENGTH_SHORT", "Strength" },
  { "ITEM_MOD_INTELLECT_SHORT", "Intellect" },
  { "ITEM_MOD_STAMINA_SHORT", "Stamina" },
  { "ITEM_MOD_ATTACK_POWER_SHORT", "Attack Power" },
  { "ITEM_MOD_SPELL_POWER_SHORT", "Spell Power" },
  { "ITEM_MOD_CRIT_RATING_SHORT", "Critical Strike" },
  { "ITEM_MOD_HASTE_RATING_SHORT", "Haste" },
  { "ITEM_MOD_MASTERY_RATING_SHORT", "Mastery" },
  { "ITEM_MOD_HIT_RATING_SHORT", "Hit" },
  { "ITEM_MOD_EXPERTISE_RATING_SHORT", "Expertise" },
  { "ITEM_MOD_SPIRIT_SHORT", "Spirit" },
  { "ITEM_MOD_DODGE_RATING_SHORT", "Dodge" },
  { "ITEM_MOD_PARRY_RATING_SHORT", "Parry" },
  { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "Damage per second" },
  { "RESISTANCE0_NAME", "Armor" },
}

local function GetSpecID()
  if not GetSpecialization or not GetSpecializationInfo then return nil end
  local index = GetSpecialization()
  if not index then return nil end
  return GetSpecializationInfo(index)
end

local function GetPrimaryStat(class, specID)
  if INTELLECT_SPECS[specID] then return "ITEM_MOD_INTELLECT_SHORT" end
  if AGILITY_SPECS[specID] then return "ITEM_MOD_AGILITY_SHORT" end
  if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then return "ITEM_MOD_INTELLECT_SHORT" end
  if class == "ROGUE" or class == "HUNTER" or class == "DRUID" or class == "MONK" or class == "SHAMAN" then
    return "ITEM_MOD_AGILITY_SHORT"
  end
  return "ITEM_MOD_STRENGTH_SHORT"
end

local function GetPreferredArmor(class)
  local preferred = CLASS_ARMOR[class]
  local level = UnitLevel("player") or 90
  if level < 40 and (class == "WARRIOR" or class == "PALADIN") then preferred = "Mail" end
  if level < 40 and (class == "HUNTER" or class == "SHAMAN") then preferred = "Leather" end
  return preferred
end

local function ReadItem(link)
  if not link then return nil end
  local name, _, _, itemLevel, requiredLevel, _, itemSubType, _, equipLoc, _, _, classID, subClassID = GetItemInfo(link)
  if not name or not equipLoc or equipLoc == "" then return nil end
  return {
    link = link,
    name = name,
    itemLevel = itemLevel or 0,
    requiredLevel = requiredLevel or 0,
    itemSubType = itemSubType,
    classID = classID,
    subClassID = subClassID,
    equipLoc = equipLoc,
    stats = GetItemStats and (GetItemStats(link) or {}) or {},
  }
end

function Upgrades:GetWeight(statKey)
  if statKey == self.primaryStat then return 4 end
  if statKey == "ITEM_MOD_AGILITY_SHORT" or statKey == "ITEM_MOD_STRENGTH_SHORT" or statKey == "ITEM_MOD_INTELLECT_SHORT" then return 0 end
  if statKey == "ITEM_MOD_STAMINA_SHORT" then return 0.30 end
  if statKey == "ITEM_MOD_ATTACK_POWER_SHORT" then return self.primaryStat == "ITEM_MOD_INTELLECT_SHORT" and 0 or 1.35 end
  if statKey == "ITEM_MOD_SPELL_POWER_SHORT" then return self.primaryStat == "ITEM_MOD_INTELLECT_SHORT" and 1.35 or 0 end
  if statKey == "ITEM_MOD_CRIT_RATING_SHORT" or statKey == "ITEM_MOD_HASTE_RATING_SHORT" or statKey == "ITEM_MOD_MASTERY_RATING_SHORT" then return 1 end
  if statKey == "ITEM_MOD_HIT_RATING_SHORT" or statKey == "ITEM_MOD_EXPERTISE_RATING_SHORT" then return 0.80 end
  if statKey == "ITEM_MOD_SPIRIT_SHORT" then return HEALER_SPECS[self.specID] and 0.90 or 0 end
  if statKey == "ITEM_MOD_DODGE_RATING_SHORT" or statKey == "ITEM_MOD_PARRY_RATING_SHORT" then return TANK_SPECS[self.specID] and 0.85 or 0 end
  if statKey == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then return 3 end
  if statKey == "RESISTANCE0_NAME" then return 0.04 end
  return 0
end

function Upgrades:Score(data)
  local score = (data.itemLevel or 0) * 0.08
  for statKey, value in pairs(data.stats or {}) do
    score = score + (value or 0) * self:GetWeight(statKey)
  end
  return score
end

function Upgrades:IsAppropriate(data)
  local slots = SLOT_MAP[data.equipLoc]
  if not slots then return false end
  if data.requiredLevel > (UnitLevel("player") or 0) then return false end
  if IsUsableItem then
    local usable = IsUsableItem(data.link)
    if not usable then return false end
  end
  if ARMOR_SLOTS[data.equipLoc] and self.preferredArmor then
    if data.classID == 4 and data.subClassID and self.preferredArmorSubclass then
      if data.subClassID ~= self.preferredArmorSubclass then return false end
    elseif data.itemSubType and not string.find(string.lower(data.itemSubType), string.lower(self.preferredArmor), 1, true) then
      return false
    end
  end
  return true
end

function Upgrades:Evaluate(item)
  if not HB.profile.showUpgrades or not item or item.empty or not item.link then return nil end
  if self.cache[item.link] ~= nil then return self.cache[item.link] or nil end

  local candidate = ReadItem(item.link)
  if not candidate or not self:IsAppropriate(candidate) then
    self.cache[item.link] = false
    return nil
  end

  local slots = SLOT_MAP[candidate.equipLoc]
  local equipped, equippedSlot, equippedScore
  for _, slotID in ipairs(slots) do
    local link = GetInventoryItemLink("player", slotID)
    if not link then
      equipped = nil
      equippedSlot = slotID
      equippedScore = 0
      break
    end
    local data = ReadItem(link)
    if not data then return nil end
    local score = self:Score(data)
    if not equippedScore or score < equippedScore then
      equipped = data
      equippedSlot = slotID
      equippedScore = score
    end
  end

  local candidateScore = self:Score(candidate)
  local gain = candidateScore - (equippedScore or 0)
  local threshold = math.max(0.50, (equippedScore or 0) * 0.01)
  local result = {
    isUpgrade = gain > threshold,
    candidate = candidate,
    equipped = equipped,
    slotID = equippedSlot,
    slotName = SLOT_NAMES[equippedSlot] or "Equipment",
    candidateScore = candidateScore,
    equippedScore = equippedScore or 0,
    gain = gain,
  }
  self.cache[item.link] = result
  return result.isUpgrade and result or nil
end

function Upgrades:AddTooltip(tooltip, result)
  if not result or not result.isUpgrade then return end
  tooltip:AddLine(" ")
  tooltip:AddLine("HeliosBags: Potential upgrade", 0.25, 1, 0.35)
  if result.equipped then
    tooltip:AddLine("Compared with " .. result.equipped.link .. " (" .. result.slotName .. ")", 0.75, 0.82, 0.90, true)
  else
    tooltip:AddLine("Your " .. result.slotName .. " slot is empty.", 0.75, 0.82, 0.90)
  end

  local shown = 0
  for _, descriptor in ipairs(STAT_DESCRIPTORS) do
    local key, label = descriptor[1], descriptor[2]
    local newValue = result.candidate.stats[key] or 0
    local oldValue = result.equipped and (result.equipped.stats[key] or 0) or 0
    local difference = newValue - oldValue
    if difference ~= 0 and shown < 8 then
      local text
      if difference > 0 then text = "|cff55ff55+" .. difference .. "|r"
      else text = "|cffff7777" .. difference .. "|r" end
      tooltip:AddDoubleLine(label, text, 0.85, 0.85, 0.85, 1, 1, 1)
      shown = shown + 1
    end
  end

  local itemLevelDifference = result.candidate.itemLevel - (result.equipped and result.equipped.itemLevel or 0)
  if itemLevelDifference ~= 0 then
    local text = itemLevelDifference > 0 and ("|cff55ff55+" .. itemLevelDifference .. "|r") or ("|cffff7777" .. itemLevelDifference .. "|r")
    tooltip:AddDoubleLine("Item level", text, 0.85, 0.85, 0.85, 1, 1, 1)
  end
  tooltip:AddLine("Estimate only — verify before equipping.", 0.50, 0.55, 0.62)
end

function Upgrades:Invalidate()
  self.cache = {}
end

function Upgrades:Initialize()
  local _, class = UnitClass("player")
  self.class = class or "ROGUE"
  self.specID = GetSpecID()
  self.primaryStat = GetPrimaryStat(self.class, self.specID)
  self.preferredArmor = GetPreferredArmor(self.class)
  self.preferredArmorSubclass = ARMOR_SUBCLASS[self.preferredArmor]
  self.cache = {}
  self.events = CreateFrame("Frame")
  self.events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  self.events:RegisterEvent("PLAYER_LEVEL_UP")
  self.events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  self.events:SetScript("OnEvent", function()
    self.specID = GetSpecID()
    self.primaryStat = GetPrimaryStat(self.class, self.specID)
    self.preferredArmor = GetPreferredArmor(self.class)
    self.preferredArmorSubclass = ARMOR_SUBCLASS[self.preferredArmor]
    self:Invalidate()
    if HB.UI and HB.UI.frame and HB.UI.frame:IsShown() then HB.UI:Refresh(false) end
  end)
end
