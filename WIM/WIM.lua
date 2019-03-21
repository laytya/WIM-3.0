-- imports
local WIM = WIM;
local _G = _G;
local CreateFrame = CreateFrame;
local select = select;
local type = type;
local table = table;
local pairs = pairs;
local string = string;

-- set name space
setfenv(1, WIM);

-- Core information
addonTocName = "WIM";
version = "3.0.5";
beta = false; -- flags current version as beta.
debug = false; -- turn debugging on and off.

-- WOTLK check by CKKnight (we'll keep this around for now...)
isWOTLK = select(4, _G.GetBuildInfo()) >= 30000;

-- is Private Server?
isPrivateServer = not string.match(_G.GetCVar("realmList"), "worldofwarcraft.com$") and true or false;

constants = {}; -- constants such as class colors will be stored here. (includes female class names).
modules = {}; -- module table. consists of all registerd WIM modules/plugins/skins. (treated the same).
windows = {active = {whisper = {}, chat = {}, w2w = {}}}; -- table of WIM windows.
libs = {}; -- table of loaded library references.

-- default options. live data is found in WIM.db
-- modules may insert fields into this table to
-- respect their option contributions.
db_defaults = {
    enabled = true,
    showToolTips = true,
    modules = {},
};

-- WIM.env is an evironmental reference for the current instance of WIM.
-- Information is stored here such as .realm and .character.
-- View table dump for more available information.
env = {};

-- default lists - This will store lists such as friends, guildies, raid members etc.
lists = {};

-- list of all the events registered from attached modules.
local Events = {};


-- create a frame to moderate events and frame updates.
    local workerFrame = CreateFrame("Frame", "WIM_workerFrame");
    workerFrame:SetScript("OnEvent", function(self, event, ...) WIM:EventHandler(event, ...); end);
    
    -- some events we always want to listen to so data is ready upon WIM being enabled.
    workerFrame:RegisterEvent("VARIABLES_LOADED");
    workerFrame:RegisterEvent("ADDON_LOADED");


-- called when WIM is first loaded into memory but after variables are loaded.
local function initialize()
    --load cached information from the WIM_Cache saved variable.
	env.cache[env.realm] = env.cache[env.realm] or {};
        env.cache[env.realm][env.character] = env.cache[env.realm][env.character] or {};
	lists.friends = env.cache[env.realm][env.character].friendList;
	lists.guild = env.cache[env.realm][env.character].guildList;
        
        if(type(lists.friends) ~= "table") then lists.friends = {}; end
        if(type(lists.guild) ~= "table") then lists.guild = {}; end
        
        workerFrame:RegisterEvent("GUILD_ROSTER_UPDATE");
        workerFrame:RegisterEvent("FRIENDLIST_UPDATE");
        
        --querie guild roster
        if( _G.IsInGuild() ) then
            _G.GuildRoster();
        end
        
    -- import libraries.
    libs.WhoLib = _G.LibStub:GetLibrary("LibWho-2.0");
    libs.Astrolabe = _G.DongleStub("Astrolabe-0.4");
    libs.SML = _G.LibStub:GetLibrary("LibSharedMedia-3.0");
    libs.BabbleTalent = _G.LibStub:GetLibrary("LibBabble-TalentTree-3.0");
    
    isInitialized = true;
    
    RegisterPrematureSkins();
    
    --enableModules
    local moduleName, tData;
    for moduleName, tData in pairs(modules) do
        modules[moduleName].db = db;
        if(modules[moduleName].canDisable ~= false) then
            local modDB = db.modules[moduleName];
            if(modDB) then
                if(modDB.enabled == nil) then
                    modDB.enabled = modules[moduleName].enableByDefault;
                end
                EnableModule(moduleName, modDB.enabled);
            else
                if(modules[moduleName].enableByDefault) then
                    EnableModule(moduleName, true);
                end
            end
        end
    end
    -- notify all modules of current state.
    CallModuleFunction("OnStateChange", WIM.curState);
    RegisterSlashCommand("enable", function() SetEnabled(not db.enabled) end, L["Toggle WIM 'On' and 'Off'."]);
    RegisterSlashCommand("debug", function() debug = not debug; end, L["Toggle Debugging Mode 'On' and 'Off'."]);
    FRIENDLIST_UPDATE(); -- pretend event has been fired in order to get cache loaded.
    CallModuleFunction("OnInitialized");
    dPrint("WIM initialized...");
end

-- called when WIM is enabled.
-- WIM will not be enabled until WIM is initialized event is fired.
local function onEnable()
    db.enabled = true;
    
    local tEvent;
    for tEvent, _ in pairs(Events) do
        workerFrame:RegisterEvent(tEvent);
    end
    
    for _, module in pairs(modules) do
        if(type(module.OnEnableWIM) == "function") then
            module:OnEnableWIM();
        end
    end
    DisplayTutorial(L["WIM (WoW Instant Messenger)"], L["WIM is currently running. To access WIM's wide array of options type:"].." |cff69ccf0/wim|r");
    dPrint("WIM is now enabled.");
end

-- called when WIM is disabled.
local function onDisable()
    db.enabled = false;
    
    local tEvent;
    for tEvent, _ in pairs(Events) do
        workerFrame:UnregisterEvent(tEvent);
    end
    
    for _, module in pairs(modules) do
        if(type(module.OnDisableWIM) == "function") then
            module:OnDisableWIM();
        end
    end
    
    dPrint("WIM is now disabled.");
end


function SetEnabled(enabled)
    if( enabled ) then
        onEnable();
    else
        onDisable();
    end
end

-- events are passed to modules. Events do not need to be
-- unregistered. A disabled module will not receive events.
local function RegisterEvent(event)
    Events[event] = true;
    if( db and db.enabled ) then
        workerFrame:RegisterEvent(event);
    end
end

-- create a new WIM module. Will return module object.
function CreateModule(moduleName, enableByDefault)
    if(type(moduleName) == "string") then
        modules[moduleName] = {
            title = moduleName,
            enabled = false,
            enableByDefault = enableByDefault or false,
            canDisable = true,
            resources = {
                lists = lists,
                windows = windows,
                env = env,
                constants = constants,
                libs = libs,
            },
            db = db,
            db_defaults = db_defaults,
            RegisterEvent = function(self, event) RegisterEvent(event); end,
            Enable = function() EnableModule(moduleName, true) end,
            Disable = function() EnableModule(moduleName, false) end,
            dPrint = function(self, t) dPrint(t); end,
            hasWidget = false,
            RegisterWidget = function(widgetName, createFunction) RegisterWidget(widgetName, createFunction, moduleName); end
        }
        return modules[moduleName];
    else
        return nil;
    end
end

function EnableModule(moduleName, enabled)
    if(enabled == nil) then enabled = false; end
    local module = modules[moduleName];
    if(module) then
        if(module.canDisable == false and enabled == false) then
            dPrint("Module '"..moduleName.."' can not be disabled!");
            return;
        end
        if(enabled) then
            module.enabled = enabled;
            if(enabled and type(module.OnEnable) == "function") then
                module:OnEnable();
            elseif(not enabled and type(module.OnDisable) == "function") then
                module:OnDisable();
            end
            dPrint("Module '"..moduleName.."' Enabled");
        else
            if(module.hasWidget) then
                dPrint("Module '"..moduleName.."' will be disabled after restart.");
            else
                module.enabled = enabled;
                if(enabled and type(module.OnEnable) == "function") then
                    module:OnEnable();
                elseif(not enabled and type(module.OnDisable) == "function") then
                    module:OnDisable();
                end
                dPrint("Module '"..moduleName.."' Disabled");
            end
        end
        if(db) then
            db.modules[moduleName] = WIM.db.modules[moduleName] or {};
            db.modules[moduleName].enabled = enabled;
        end
    end
end

function CallModuleFunction(funName, ...)
    -- notify all enabled modules.
    dPrint("Calling Module Function: "..funName);
    local module, tData, fun;
    for module, tData in pairs(WIM.modules) do
        fun = tData[funName];
        if(type(fun) == "function" and tData.enabled) then
                dPrint(" +--"..module);
                fun(tData, ...);
        end
    end
end
--------------------------------------
--          Event Handlers          --
--------------------------------------

local function honorChatFrameEventFilter(event, msg)
    local chatFilters = _G.ChatFrame_GetMessageEventFilters(event);
    if chatFilters then 
	local filter, newmsg = false;
        for _, filterFunc in pairs(chatFilters) do
            filter, newmsg = filterFunc(msg);
            if filter then 
		return true; 
	    end 
	end 
    end 
    return false;
end


-- This is WIM's core event controler.
function WIM:EventHandler(event, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 = ...;
    -- before we do any filtering, make sure that we are not speaking to a GM.
    -- no matter what, we want to see these.
    if(not (event == "CHAT_MSG_WHISPER" and agr6 ~= "GM")) then
        -- first we will filter out
        if(honorChatFrameEventFilter(event, arg1 or "")) then
            -- ChatFrame's event filters said to block this message.
            return;
        end
        -- other filtering will take place in individual event handlers within modules.
    end
    
    if(event == "CHAT_MSG_WHISPER" and arg6 == "GM") then
        lists.gm[arg2] = true;
    end

    -- Core WIM Event Handlers.
    dPrint("Event '"..event.."' received.");
    
    local fun = WIM[event];
    if(type(fun) == "function") then
        dPrint("  +-- WIM:"..event);
        fun(WIM, ...);
    end
    
    -- Module Event Handlers
    if(db and db.enabled) then
        local module, tData;
        for module, tData in pairs(modules) do
            fun = tData[event];
            if(type(fun) == "function" and tData.enabled) then
                dPrint("  +-- "..module..":"..event);
                fun(modules[module], ...);
            end
        end
    end
end

function WIM:VARIABLES_LOADED()
    _G.WIM3_Data = _G.WIM3_Data or {};
    db = _G.WIM3_Data;
    _G.WIM3_Cache = _G.WIM3_Cache or {};
    env.cache = _G.WIM3_Cache;
    _G.WIM3_Filters = _G.WIM3_Filters or GetDefaultFilters();
    if(#_G.WIM3_Filters == 0) then
        _G.WIM3_Filters = GetDefaultFilters();
    end
    filters = _G.WIM3_Filters;
    
    _G.WIM3_History = _G.WIM3_History or {};
    history = _G.WIM3_History;
    
    -- load some environment data.
    env.realm = _G.GetCVar("realmName");
    env.character = _G.UnitName("player");
    
    -- inherrit any new default options which wheren't shown in previous releases.
    inherritTable(db_defaults, db);
    lists.gm = {};
    
    -- load previous state into memory
    curState = db.lastState;
    
    initialize();
    SetEnabled(db.enabled);
end

function WIM:FRIENDLIST_UPDATE()
    env.cache[env.realm][env.character].friendList = env.cache[env.realm][env.character].friendList or {};
    for key, _ in pairs(env.cache[env.realm][env.character].friendList) do
        env.cache[env.realm][env.character].friendList[key] = nil;
    end
	for i=1, _G.GetNumFriends() do 
		local name, junk = _G.GetFriendInfo(i);
		if(name) then
			env.cache[env.realm][env.character].friendList[name] = true; --[set place holder for quick lookup
		end
	end
    lists.friends = env.cache[env.realm][env.character].friendList;
    dPrint("Friends list updated...");
end

function WIM:GUILD_ROSTER_UPDATE()
	env.cache[env.realm][env.character].guildList = env.cache[env.realm][env.character].guildList or {};
        for key, _ in pairs(env.cache[env.realm][env.character].guildList) do
            env.cache[env.realm][env.character].guildList[key] = nil;
        end
	if(_G.IsInGuild()) then
		for i=1, _G.GetNumGuildMembers(true) do 
			local name = _G.GetGuildRosterInfo(i);
			if(name) then
				env.cache[env.realm][env.character].guildList[name] = true; --[set place holder for quick lookup
			end
		end
	end
	lists.guild = env.cache[env.realm][env.character].guildList;
        dPrint("Guild list updated...");
end

function IsGM(name)
    if(name == nil or name == "") then
		return false;
	end
	if(string.len(name) < 4) then return false; end
	if(string.sub(name, 1, 4) == "<GM>") then
		local tmp = string.gsub(name, "<GM> ", "");
		lists.gm[tmp] = 1;
		return true;
	else
		if(lists.gm[user]) then
			return true;
		else
			return false;
		end
	end
end

function IsInParty(user)
    for i=1, 4 do
        if(_G.UnitName("party"..i) == user) then
            return true;
        end
    end
    return false;
end

function IsInRaid(user)
    for i=1, 40 do
        if(_G.UnitName("raid"..i) == user) then
            return true;
        end
    end
    return false;
end

function CompareVersion(v)
    local M, m, r = string.match(v, "(%d+).(%d+).(%d+)");
    local cM, cm, cr = string.match(version, "(%d+).(%d+).(%d+)");
    M, m = M*100000, m*1000;
    cM, cm = cM*100000, cm*1000;
    local this, that = cM+cm+cr, M+m+r;
    return that - this;
end

local talentOrder = {};
function TalentsToString(talents, class)
	--passed talents in format of "#/#/#";
        -- first check that all required information is passed.
	local t1, t2, t3 = string.match(talents or "", "(%d+)/(%d+)/(%d+)");
	if(not t1 or not t2 or not t3 or not class) then
                return talents;
        end
	
        -- next check if we even have information to show.
        if(talents == "0/0/0") then return L["None"]; end
        
        local classTbl = constants.classes[class];
	if(not classTbl) then
                return talents;
        end
        
        -- clear talentOrder
        for k, _ in pairs(talentOrder) do
                talentOrder[k] = nil;
        end
        
	--calculate which order the tabs should be in; in relation to spec.
	table.insert(talentOrder, t1.."1");
        table.insert(talentOrder, t2.."2");
        table.insert(talentOrder, t3.."3");
	table.sort(talentOrder);
	
	local fVal, f = string.match(_G.tostring(talentOrder[3]), "^(%d+)(%d)$");
        local sVal, s = string.match(_G.tostring(talentOrder[2]), "^(%d+)(%d)$");
        local tVal, t = string.match(_G.tostring(talentOrder[1]), "^(%d+)(%d)$");
        
	if(_G.tonumber(fVal)*.75 <= _G.tonumber(sVal)) then
		if(_G.tonumber(fVal)*.75 <= _G.tonumber(tVal)) then
			return L["Hybrid"]..": "..talents;
		else
			return classTbl.talent[_G.tonumber(f)].."/"..classTbl.talent[_G.tonumber(s)]..": "..talents;
		end
	else
		return classTbl.talent[_G.tonumber(f)]..": "..talents;
	end
end

function GetTalentSpec()
        local talents, tabs = "", _G.GetNumTalentTabs();
        for i=1, tabs do
                local name, iconTexture, pointsSpent, background = _G.GetTalentTabInfo(i);
                talents = i==tabs and talents..pointsSpent or talents..pointsSpent.."/";
        end
        return talents ~= "" and talents or "0/0/0";
end

