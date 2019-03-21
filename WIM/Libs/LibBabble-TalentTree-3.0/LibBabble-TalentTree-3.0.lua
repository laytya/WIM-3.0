--[[
Name: LibBabble-TalentTree-3.0
Revision: $Rev: 14 $
Author(s): Pneumatus
Documentation: http://www.wowace.com/wiki/LibBabble-TalentTree-3.0
SVN: http://svn.wowace.com/wowace/trunk/LibBabble-TalentTree-3.0
Dependencies: None
License: MIT
]]

local MAJOR_VERSION = "LibBabble-TalentTree-3.0"
local MINOR_VERSION = 90000 + tonumber(("$Revision: 14 $"):match("%d+"))

-- #AUTODOC_NAMESPACE prototype

local GAME_LOCALE = GetLocale()
do
	-- LibBabble-Core-3.0 is hereby placed in the Public Domain
	-- Credits: ckknight
	local LIBBABBLE_MAJOR, LIBBABBLE_MINOR = "LibBabble-3.0", 2

	local LibBabble = LibStub:NewLibrary(LIBBABBLE_MAJOR, LIBBABBLE_MINOR)
	if LibBabble then
		local data = LibBabble.data or {}
		for k,v in pairs(LibBabble) do
			LibBabble[k] = nil
		end
		LibBabble.data = data

		local tablesToDB = {}
		for namespace, db in pairs(data) do
			for k,v in pairs(db) do
				tablesToDB[v] = db
			end
		end
		
		local function warn(message)
			local _, ret = pcall(error, message, 3)
			geterrorhandler()(ret)
		end

		local lookup_mt = { __index = function(self, key)
			local db = tablesToDB[self]
			local current_key = db.current[key]
			if current_key then
				self[key] = current_key
				return current_key
			end
			local base_key = db.base[key]
			local real_MAJOR_VERSION
			for k,v in pairs(data) do
				if v == db then
					real_MAJOR_VERSION = k
					break
				end
			end
			if not real_MAJOR_VERSION then
				real_MAJOR_VERSION = LIBBABBLE_MAJOR
			end
			if base_key then
				warn(("%s: Translation %q not found for locale %q"):format(real_MAJOR_VERSION, key, GAME_LOCALE))
				rawset(self, key, base_key)
				return base_key
			end
			warn(("%s: Translation %q not found."):format(real_MAJOR_VERSION, key))
			rawset(self, key, key)
			return key
		end }

		local function initLookup(module, lookup)
			local db = tablesToDB[module]
			for k in pairs(lookup) do
				lookup[k] = nil
			end
			setmetatable(lookup, lookup_mt)
			tablesToDB[lookup] = db
			db.lookup = lookup
			return lookup
		end

		local function initReverse(module, reverse)
			local db = tablesToDB[module]
			for k in pairs(reverse) do
				reverse[k] = nil
			end
			for k,v in pairs(db.current) do
				reverse[v] = k
			end
			tablesToDB[reverse] = db
			db.reverse = reverse
			db.reverseIterators = nil
			return reverse
		end

		local prototype = {}
		local prototype_mt = {__index = prototype}

		--[[---------------------------------------------------------------------------
		Notes:
			* If you try to access a nonexistent key, it will warn but allow the code to pass through.
		Returns:
			A lookup table for english to localized words.
		Example:
			local B = LibStub("LibBabble-Module-3.0") -- where Module is what you want.
			local BL = B:GetLookupTable()
			assert(BL["Some english word"] == "Some localized word")
			DoSomething(BL["Some english word that doesn't exist"]) -- warning!
		-----------------------------------------------------------------------------]]
		function prototype:GetLookupTable()
			local db = tablesToDB[self]

			local lookup = db.lookup
			if lookup then
				return lookup
			end
			return initLookup(self, {})
		end
		--[[---------------------------------------------------------------------------
		Notes:
			* If you try to access a nonexistent key, it will return nil.
		Returns:
			A lookup table for english to localized words.
		Example:
			local B = LibStub("LibBabble-Module-3.0") -- where Module is what you want.
			local B_has = B:GetUnstrictLookupTable()
			assert(B_has["Some english word"] == "Some localized word")
			assert(B_has["Some english word that doesn't exist"] == nil)
		-----------------------------------------------------------------------------]]
		function prototype:GetUnstrictLookupTable()
			local db = tablesToDB[self]

			return db.current
		end
		--[[---------------------------------------------------------------------------
		Notes:
			* If you try to access a nonexistent key, it will return nil.
			* This is useful for checking if the base (English) table has a key, even if the localized one does not have it registered.
		Returns:
			A lookup table for english to localized words.
		Example:
			local B = LibStub("LibBabble-Module-3.0") -- where Module is what you want.
			local B_hasBase = B:GetBaseLookupTable()
			assert(B_hasBase["Some english word"] == "Some english word")
			assert(B_hasBase["Some english word that doesn't exist"] == nil)
		-----------------------------------------------------------------------------]]
		function prototype:GetBaseLookupTable()
			local db = tablesToDB[self]

			return db.base
		end
		--[[---------------------------------------------------------------------------
		Notes:
			* If you try to access a nonexistent key, it will return nil.
			* This will return only one English word that it maps to, if there are more than one to check, see :GetReverseIterator("word")
		Returns:
			A lookup table for localized to english words.
		Example:
			local B = LibStub("LibBabble-Module-3.0") -- where Module is what you want.
			local BR = B:GetReverseLookupTable()
			assert(BR["Some localized word"] == "Some english word")
			assert(BR["Some localized word that doesn't exist"] == nil)
		-----------------------------------------------------------------------------]]
		function prototype:GetReverseLookupTable()
			local db = tablesToDB[self]

			local reverse = db.reverse
			if reverse then
				return reverse
			end
			return initReverse(self, {})
		end
		local blank = {}
		local weakVal = {__mode='v'}
		--[[---------------------------------------------------------------------------
		Arguments:
			string - the localized word to chek for.
		Returns:
			An iterator to traverse all English words that map to the given key
		Example:
			local B = LibStub("LibBabble-Module-3.0") -- where Module is what you want.
			for word in B:GetReverseIterator("Some localized word") do
				DoSomething(word)
			end
		-----------------------------------------------------------------------------]]
		function prototype:GetReverseIterator(key)
			local db = tablesToDB[self]
			local reverseIterators = db.reverseIterators
			if not reverseIterators then
				reverseIterators = setmetatable({}, weakVal)
				db.reverseIterators = reverseIterators
			elseif reverseIterators[key] then
				return pairs(reverseIterators[key])
			end
			local t
			for k,v in pairs(db.current) do
				if v == key then
					if not t then
						t = {}
					end
					t[k] = true
				end
			end
			reverseIterators[key] = t or blank
			return pairs(reverseIterators[key])
		end
		--[[---------------------------------------------------------------------------
		Returns:
			An iterator to traverse all translations English to localized.
		Example:
			local B = LibStub("LibBabble-Module-3.0") -- where Module is what you want.
			for english, localized in B:Iterate() do
				DoSomething(english, localized)
			end
		-----------------------------------------------------------------------------]]
		function prototype:Iterate()
			local db = tablesToDB[self]

			return pairs(db.current)
		end

		-- #NODOC
		-- modules need to call this to set the base table
		function prototype:SetBaseTranslations(base)
			local db = tablesToDB[self]
			local oldBase = db.base
			if oldBase then
				for k in pairs(oldBase) do
					oldBase[k] = nil
				end
				for k, v in pairs(base) do
					oldBase[k] = v
				end
				base = oldBase
			else
				db.base = base
			end
			for k,v in pairs(base) do
				if v == true then
					base[k] = k
				end
			end
		end

		local function init(module)
			local db = tablesToDB[module]
			if db.lookup then
				initLookup(module, db.lookup)
			end
			if db.reverse then
				initReverse(module, db.reverse)
			end
			db.reverseIterators = nil
		end

		-- #NODOC
		-- modules need to call this to set the current table. if current is true, use the base table.
		function prototype:SetCurrentTranslations(current)
			local db = tablesToDB[self]
			if current == true then
				db.current = db.base
			else
				local oldCurrent = db.current
				if oldCurrent then
					for k in pairs(oldCurrent) do
						oldCurrent[k] = nil
					end
					for k, v in pairs(current) do
						oldCurrent[k] = v
					end
					current = oldCurrent
				else
					db.current = current
				end
			end
			init(self)
		end

		for namespace, db in pairs(data) do
			setmetatable(db.module, prototype_mt)
			init(db.module)
		end

		-- #NODOC
		-- modules need to call this to create a new namespace.
		function LibBabble:New(namespace, minor)
			local module, oldminor = LibStub:NewLibrary(namespace, minor)
			if not module then
				return
			end

			if not oldminor then
				local db = {
					module = module,
				}
				data[namespace] = db
				tablesToDB[module] = db
			else
				for k,v in pairs(module) do
					module[k] = nil
				end
			end

			setmetatable(module, prototype_mt)

			return module
		end
	end
end

local lib = LibStub("LibBabble-3.0"):New(MAJOR_VERSION, MINOR_VERSION)
if not lib then
	return
end

lib:SetBaseTranslations {
	-- All classes
	["Hybrid"] = true,
	-- Death Knight
	["Blood"] = true,
	["Frost"] = true,
	["Unholy"] = true,
	-- Druid
	["Balance"] = true,
	["Feral Combat"] = true,
	["Restoration"] = true,
	-- Hunter
	["Beast Mastery"] = true,
	["Marksmanship"] = true,
	["Survival"] = true,
	-- Mage
	["Arcane"] = true,
	["Fire"] = true,
	["Frost"] = true,
	-- Paladin
	["Holy"] = true,
	["Protection"] = true,
	["Retribution"] = true,
	-- Priest
	["Discipline"] = true,
	-- ["Holy"] = true, -- same as Paladin
	["Shadow"] = true,
	-- Rogue
	["Assassination"] = true,
	["Combat"] = true,
	["Subtlety"] = true,
	-- Shaman
	["Elemental"] = true,
	["Enhancement"] = true,
	-- ["Restoration"] = true, -- same as Druid
	-- Warrior
	["Arms"] = true,
	["Fury"] = true,
	-- ["Protection"] = true, -- same as Paladin
	-- Warlock
	["Affliction"] = true,
	["Demonology"] = true,
	["Destruction"] = true
}

if GAME_LOCALE == "enUS" then
	lib:SetCurrentTranslations(true)
elseif GAME_LOCALE == "deDE" then
	lib:SetCurrentTranslations {
	-- All classes
	["Hybrid"] = "Hybride",
	-- Death Knight
	["Blood"] = "Blut",
	["Frost"] = "Frost",
	["Unholy"] = "Unheilig",
	-- Druid
	["Balance"] = "Gleichgewicht",
	["Feral Combat"] = "Wilder Kampf",
	["Restoration"] = "Wiederherstellung",
	-- Hunter
	["Beast Mastery"] = "Tierherrschaft",
	["Marksmanship"] = "Treffsicherheit",
	["Survival"] = "Überleben",
	-- Mage
	["Arcane"] = "Arcan",
	["Fire"] = "Feuer",
	["Frost"] = "Frost",
	-- Paladin
	["Holy"] = "Heilig",
	["Protection"] = "Schutz",
	["Retribution"] = "Vergeltung",
	-- Priest
	["Discipline"] = "Disziplin",
	-- ["Holy"] = "Heilig", -- same as Paladin
	["Shadow"] = "Schatten",
	-- Rogue
	["Assassination"] = "Meucheln",
	["Combat"] = "Kampf",
	["Subtlety"] = "Täuschung",
	-- Shaman
	["Elemental"] = "Elementar",
	["Enhancement"] = "Verstärkung",
	-- ["Restoration"] = "Wiederherstellung", -- same as Druid
	-- Warrior
	["Arms"] = "Waffen",
	["Fury"] = "Furor",
	-- ["Protection"] = "Schutz", -- same as Paladin
	-- Warlock
	["Affliction"] = "Gebrechen",
	["Demonology"] = "Dämonologie",
	["Destruction"] = "Zerstörung"
}
elseif GAME_LOCALE == "frFR" then
	lib:SetCurrentTranslations {
	-- All classes
	["Hybrid"] = "Hybride",
	-- Death Knight
	["Blood"] = "Sang",
	["Frost"] = "Givre",
	["Unholy"] = "Impie",
	-- Druid
	["Balance"] = "Equilibre",
	["Feral Combat"] = "Combat farouche",
	["Restoration"] = "Restauration",
	-- Hunter
	["Beast Mastery"] = "Maîtrise des bêtes",
	["Marksmanship"] = "Précision",
	["Survival"] = "Survie",
	-- Mage
	["Arcane"] = "Arcane",
	["Fire"] = "Feu",
	["Frost"] = "Givre",
	-- Paladin
	["Holy"] = "Sacré",
	["Protection"] = "Protection",
	["Retribution"] = "Vindicte",
	-- Priest
	["Discipline"] = "Discipline",
	-- ["Holy"] = "Sacré", -- same as Paladin
	["Shadow"] = "Ombre",
	-- Rogue
	["Assassination"] = "Assassinat",
	["Combat"] = "Combat",
	["Subtlety"] = "Finesse",
	-- Shaman
	["Elemental"] = "Elémentaire",
	["Enhancement"] = "Amélioration",
	-- ["Restoration"] = "Restauration", -- same as Druid
	-- Warrior
	["Arms"] = "Armes",
	["Fury"] = "Fureur",
	-- ["Protection"] = true, -- same as Paladin
	-- Warlock
	["Affliction"] = "Affliction",
	["Demonology"] = "Démonologie",
	["Destruction"] = "Destruction",
}
elseif GAME_LOCALE == "zhTW" then
	lib:SetCurrentTranslations {
	-- All classes
	["Hybrid"] = "混合",
	-- Death Knight
	--["Blood"] = true, -- Needs translation
	--["Frost"] = true, -- Needs translation
	--["Unholy"] = true, -- Needs translation
	-- Druid
	["Balance"] = "平衡",
	["Feral Combat"] = "野性戰鬥",
	["Restoration"] = "恢復",
	-- Hunter
	["Beast Mastery"] = "野獸控制",
	["Marksmanship"] = "射擊",
	["Survival"] = "生存",
	-- Mage
	["Arcane"] = "秘法",
	["Fire"] = "火焰",
	["Frost"] = "冰霜",
	-- Paladin
	["Holy"] = "神聖",
	["Protection"] = "防護",
	["Retribution"] = "懲戒",
	-- Priest
	["Discipline"] = "戒律",
	-- ["Holy"] = "神聖", -- same as Paladin
	["Shadow"] = "暗影",
	-- Rogue
	["Assassination"] = "刺殺",
	["Combat"] = "戰鬥",
	["Subtlety"] = "敏銳",
	-- Shaman
	["Elemental"] = "元素",
	["Enhancement"] = "增強",
	-- ["Restoration"] = "恢復", -- same as Druid
	-- Warrior
	["Arms"] = "武器",
	["Fury"] = "狂怒",
	-- ["Protection"] = "防護", -- same as Paladin
	-- Warlock
	["Affliction"] = "痛苦",
	["Demonology"] = "惡魔學識",
	["Destruction"] = "毀滅"
}
elseif GAME_LOCALE == "zhCN" then
	lib:SetCurrentTranslations {
	-- All classes
	["Hybrid"] = "混合",
	-- Death Knight
	--["Blood"] = true, -- Needs translation
	--["Frost"] = true, -- Needs translation
	--["Unholy"] = true, -- Needs translation
	-- Druid
	["Balance"] = "平衡",
	["Feral Combat"] = "野性战斗",
	["Restoration"] = "恢复",
	-- Hunter
	["Beast Mastery"] = "野兽控制",
	["Marksmanship"] = "射击",
	["Survival"] = "生存技能",
	-- Mage
	["Arcane"] = "奥术",
	["Fire"] = "火焰",
	["Frost"] = "冰霜",
	-- Paladin
	["Holy"] = "神圣",
	["Protection"] = "防护",
	["Retribution"] = "惩戒",
	-- Priest
	["Discipline"] = "戒律",
	-- ["Holy"] = "神圣", -- same as Paladin
	["Shadow"] = "暗影魔法",
	-- Rogue
	["Assassination"] = "刺杀",
	["Combat"] = "战斗",
	["Subtlety"] = "敏锐",
	-- Shaman
	["Elemental"] = "元素战斗",
	["Enhancement"] = "增强",
	-- ["Restoration"] = "恢复", -- same as Druid
	-- Warrior
	["Arms"] = "武器",
	["Fury"] = "狂怒",
	-- ["Protection"] = "防护", -- same as Paladin
	-- Warlock
	["Affliction"] = "痛苦",
	["Demonology"] = "恶魔学识",
	["Destruction"] = "毁灭"
}
elseif GAME_LOCALE == "esES" then
	lib:SetCurrentTranslations {
	-- All classes
	["Hybrid"] = "Híbrido",
	-- Death Knight
	["Blood"] = "Sangre",
	["Frost"] = "Escarcha",
	["Unholy"] = "Profano",
	-- Druid
	["Balance"] = "Equilibrio",
	["Feral Combat"] = "Combate Feral",
	["Restoration"] = "Restauraci\195\179n",
	-- Hunter
	["Beast Mastery"] = "Dominio de bestias",
	["Marksmanship"] = "Punter\195\173a",
	["Survival"] = "Supervivencia",
	-- Mage
	["Arcane"] = "Arcano",
	["Fire"] = "Fuego",
	["Frost"] = "Escarcha",
	-- Paladin
	["Holy"] = "Sagrado",
	["Protection"] = "Protecci\195\179n",
	["Retribution"] = "Reprensi\195\179n",
	-- Priest
	["Discipline"] = "Disciplina",
	-- ["Holy"] = "Sagrado", -- same as Paladin
	["Shadow"] = "Sombras",
	-- Rogue
	["Assassination"] = "Asesinato",
	["Combat"] = "Combate",
	["Subtlety"] = "Sutileza",
	-- Shaman
	["Elemental"] = "Elemental",
	["Enhancement"] = "Mejora",
	-- ["Restoration"] = "Restauraci\195\179n", -- same as Druid
	-- Warrior
	["Arms"] = "Armas",
	["Fury"] = "Furia",
	-- ["Protection"] = "Protecci\195\179n", -- same as Paladin
	-- Warlock
	["Affliction"] = "Aflicci\195\179n",
	["Demonology"] = "Demonolog\195\173a",
	["Destruction"] = "Destrucci\195\179n",
}
elseif GAME_LOCALE == "koKR" then
	lib:SetCurrentTranslations {
	 -- All classes
	["Hybrid"] = "하이브리드",  -- Check
	-- Death Knight
	--["Blood"] = true, -- Needs translation
	--["Frost"] = true, -- Needs translation
	--["Unholy"] = true, -- Needs translation
	-- Druid
	["Balance"] = "조화",
	["Feral Combat"] = "야성",
	["Restoration"] = "회복",
	-- Hunter
	["Beast Mastery"] = "야수",
	["Marksmanship"] = "사격",
	["Survival"] = "생존",
	-- Mage
	["Arcane"] = "비전",
	["Fire"] = "화염",
	["Frost"] = "냉기",
	-- Paladin
	["Holy"] = "신성",
	["Protection"] = "보호",
	["Retribution"] = "징벌",
	-- Priest
	["Discipline"] = "수양",
	-- ["Holy"] = "신성", -- same as Paladin
	["Shadow"] = "암흑",
	-- Rogue
	["Assassination"] = "암살",
	["Combat"] = "전투",
	["Subtlety"] = "잠행",
	-- Shaman
	["Elemental"] = "정기",
	["Enhancement"] = "고양",
	["Restoration"] = "복원", -- not same as Druid in Korean locale
	-- Warrior
	["Arms"] = "무기",
	["Fury"] = "분노",
	["Protection"] = "방어", -- not same as Paladin in Korean locale
	-- Warlock
	["Affliction"] = "고통",
	["Demonology"] = "악마",
	["Destruction"] = "파괴"
}
elseif GAME_LOCALE == "ruRU" then
	lib:SetCurrentTranslations {
	-- All classes
	["Hybrid"] = "Гибрид",
	-- Death Knight
	["Blood"] = "Кровь",
	["Frost"] = "Лед",
	["Unholy"] = "Нечестивость",
	-- Druid
	["Balance"] = "Баланс",
	["Feral Combat"] = "Сила зверя",
	["Restoration"] = "Исцеление",
	-- Hunter
	["Beast Mastery"] = "Чувство зверя",
	["Marksmanship"] = "Стрельба",
	["Survival"] = "Выживание",
	-- Mage
	["Arcane"] = "Тайная магия",
	["Fire"] = "Огонь",
	["Frost"] = "Лед",
	-- Paladin
	["Holy"] = "Свет",
	["Protection"] = "Защита",
	["Retribution"] = "Возмездие",
	-- Priest
	["Discipline"] = "Послушание",
	--["Holy"] = "Свет", -- одинаково с Паладином
	["Shadow"] = "Темная магия",
	-- Rogue
	["Assassination"] = "Убийство",
	["Combat"] = "Бой",
	["Subtlety"] = "Скрытность",
	-- Shaman
	["Elemental"] = "Укрощение стихии",
	["Enhancement"] = "Совершенствование",
	--["Restoration"] = "Исцеление", -- одинаково с Друидом
	-- Warrior
	["Arms"] = "Оружие",
	["Fury"] = "Неистовство",
	--["Protection"] = "Защита", --  одинаково с Паладином
	-- Warlock
	["Affliction"] = "Колдовство",
	["Demonology"] = "Демонология",
	["Destruction"] = "Разрушение"
}
else
	error(("%s: Locale %q not supported"):format(MAJOR_VERSION, GAME_LOCALE))
end
