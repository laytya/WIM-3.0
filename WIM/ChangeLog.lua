--[[
    This change log was meant to be viewed in game.
    You may do so by typing: /wim changelog
]]

local log = {};
local t_insert = table.insert;

local function addEntry(version, rdate, description)
    t_insert(log, {v = version, r = rdate, d = description});
end


-- ChangeLog Entries.
addEntry("3.0.5", "12/02/2008", [[
    *Fixed: Who lookups wouldn't update if already cached.
    *Fixed: Default Spamfilter wasn't working as intended.
    *Loading of skins also updates character info as well.
    *Fixed the history viewer. For real this time? (Thanks Stewart)
    *History text view loads correctly now on first click. (Thanks Stewart)
    *History text views are stripped of all colors and emoticons.
    +Added Russian translations. (Thanks Stingersoft)
    *Fixed: System message of user coming online wasn't being handled correctly.
    +Added libraries to optional dependencies to allow for disembedded addons.
    *Moved Window Alpha option from Window Settings to Display Settings.
    +Added Window Strata option to Window Settings.
    *Fixed: History viewer wasn't loading for entire realm.
    *Fixed: Tabs now honor focus as intended. (Thanks Stewart)
]]);
addEntry("3.0.4", "11/12/2008", [[
    *History frame was named incorrectly. 'WIM3_HistoryFrame' is its new name.
    *Socket only compresses large transmissions to minimize resource usage.
    *Optimized tabs.
    *Tabs scroll correctly now.
    *Location button on shortcut uses special W2W tooltip if applicable.
    *History viewer wasn't displaying realms which had non-alphanumeric characters in it.
    *Fixed bug where alerts where referencing minimap icon even though it hasn't been loaded.
    +WIM now comes packaged with LibBabble-TalentTree-3.0 and further defines class information.
    +Added W2W Talent Spec sharing.
    *Lowered options frame strata from DIALOG to MEDIUM.
    *Fixed animation crash (Caused by blizzards ScrollingMessageFrame).
    +WIM's widget API now calls UpdateSkin method of widget if available upon skin loading.
    *Long messages are now split correclty without breaking links.
    *LastTellTarget is not set correctly when receiving AFK & DND responses.
    +WIM now uses LibWho-2.0. WhoLib-1.0 is now considered depricated.
    -Removed dependencies(libs) of all Ace2 addons including Deformat.
]]);
addEntry("3.0.3", "10/23/2008", [[
    +Added Tab Management module. (Auto grouping of windows.)
    *Avoid any chances of dividing by 0 in window animation.
    *Changed window behavior priorities to: Arena, Combat, PvP, Raid, Party, Resting Other.
    *Fixed bug when running WIM on WOTLK.
    +W2W Typing notification is triggered from the default chat frame now too.
    -W2W will no longer notify user as typing if user is typing a slash command.
    *Fixed a resizing bug when using tabs. Entire tab group inherits size until removed.
    +Added ChangeLog.lua (contains release information to be used later.)
    *Corrected shaman class color.
    *Focus gain also respects Blizzard's ChatEditFrame.
    *Filters are no longer trimmed.
    +Added deDE localizations.
    +Added sound options.
    +Added some stock sound files.
]]);