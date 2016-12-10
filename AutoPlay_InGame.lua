

-------------------------------------------------------------------------------
-- Mostly based on Firaxis Automation_ObserverCamera.Lua
-- A set of activities for the automated oberver to do with the camera.
-------------------------------------------------------------------------------
print("Loading AutoPlay_InGame.lua ...")

include( "InstanceManager" );

local turnFromStart = 0
local bAllWar = false
local bNotifications = true

hstructure Entry
	hasVisited : boolean;
	player : number;
	id : number;
	x : number;
	y : number;
end

-- Make this an automation parameter
ms_CityViewDuration = 20.0;

local VIEW_TYPE_NONE = 0;
local VIEW_TYPE_WORLD = 1;
local VIEW_TYPE_STRATEGIC = 2;

local ms_CurrentViewStartTime = 0.0;
local ms_CurrentViewDuration = 0.0;
local ms_CurrentViewType = VIEW_TYPE_NONE;
local ms_AllowViewSwitching = true;

-- View durations.  Make these automation parameters
ms_ViewDurationMin = { 30, 30 };
ms_ViewDurationMax = { 60, 60 };

-- Chances that when the players turn starts, we look at their capital, 0 - 1
-- Make these automation parameters
local ms_ChanceToViewMajorsCapital = .75;
local ms_ChanceToViewMinorsCapital = .25;

local ms_bInitialized = false;

-- List of the visible cities
local ms_VisibleCities = {};

local VisitActivity = {};

-- Activities we can do.
VisitActivity.None		= 0;
VisitActivity.Unit		= 1;
VisitActivity.City		= 2;
VisitActivity.Plot		= 3;
VisitActivity.Combat	= 4;
VisitActivity.Wonder	= 5;
VisitActivity.District	= 6;

-- A definition of an activity
hstructure Activity
	started : boolean;
	tracking : boolean;
	lingering : boolean;
	type : number;
	startTime : number;
	duration : number;
	x : number;
	y : number;
end

-------------------------------------------------------------------------------
-- Add an object to a list of things to look at
function AddToList(objects : table , player : number, id : number)
	-- See if it is in the list already
	for _, v in ipairs(objects) do
		if (v.id == id and v.player == player) then
			return v;
		end
	end

	local o = hmake Entry { hasVisited = false };
	o.id = id;
	o.player = player;

	table.insert(objects, o);
	local nLast = #objects;
	return objects[ nLast ];
end

-------------------------------------------------------------------------------
-- Remove an object from a list of things to look at
function RemoveFromList(objects : table , player : number, id : number)

	for i, v in ipairs(objects) do
		if (v.id == id and v.player == player) then
			table.remove(objects, i);
			return;
		end
	end

end

-- The current activity
local CurrentActivity : Activity = hmake Activity { started = false, tracking = false, lingering = false, type = VisitActivity.None, startTime = 0, duration = 0, x = 0, y = 0 };

-------------------------------------------------------------------------------
function CanSeePlot(x, y)

	local pPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalObserver());
	if (pPlayerVis ~= nil) then
		return pPlayerVis:IsVisible(x, y);
	end

	return false;
end	

-------------------------------------------------------------------------------
-- What percentage is the current activity at?
function CurrentActivityPercentComplete()

	if (CurrentActivity.started == false or CurrentActivity.duration == 0) then
		return 100.0;
	end

	local elapsed = (Automation.GetTime() - CurrentActivity.startTime);

	if (elapsed >= CurrentActivity.duration) then
		return 100.0;
	end

	return (elapsed / CurrentActivity.duration) * 100.0;
	
end

-------------------------------------------------------------------------------
-- What amount of time has elapsed for the current activity?
function CurrentActivityElapsed()

	if (CurrentActivity.started == false or CurrentActivity.duration == 0) then
		return 0;
	end

	return (Automation.GetTime() - CurrentActivity.startTime);
		
end

-------------------------------------------------------------------------------
function ClearCurrentActivity()
	CurrentActivity.started = false;
	CurrentActivity.tracking = false;
	CurrentActivity.lingering = false;
	CurrentActivity.type = VisitActivity.None;
	CurrentActivity.startTime = 0;
	CurrentActivity.duration = 0;
	CurrentActivity.x = 0;
	CurrentActivity.y = 0;
end

-- Handlers for the types of activity
local ActivityHandlers = {};

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.None] = {};
ActivityHandlers[VisitActivity.None].Start = function(activity : Activity)
	

end

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.Unit] = {};
ActivityHandlers[VisitActivity.Unit].Start = function(activity : Activity)

	UI.LookAtPlot(activity.x, activity.y);

end

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.City] = {};
ActivityHandlers[VisitActivity.City].Start = function(activity : Activity)

	local iValue = Automation.GetRandomNumber(4);
	local zoom = 0.3 + (iValue * 0.1);
	UI.LookAtPlot(activity.x, activity.y, zoom);

end

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.Plot] = {};
ActivityHandlers[VisitActivity.Plot].Start = function(activity : Activity)

	UI.LookAtPlot(activity.x, activity.y);

end

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.Combat] = {};
ActivityHandlers[VisitActivity.Combat].Start = function(activity : Activity)

	local iValue = Automation.GetRandomNumber(8);
	local zoom = 0.2 + (iValue * 0.05);
	UI.LookAtPlot(activity.x, activity.y, zoom);

end

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.Wonder] = {};
ActivityHandlers[VisitActivity.Wonder].Start = function(activity : Activity)

	local iValue = Automation.GetRandomNumber(4);
	local zoom = 0.3 + (iValue * 0.1);
	UI.LookAtPlot(activity.x, activity.y, zoom);

end

-------------------------------------------------------------------------------
ActivityHandlers[VisitActivity.District] = {};
ActivityHandlers[VisitActivity.District].Start = function(activity : Activity)

	local iValue = Automation.GetRandomNumber(8);
	local zoom = 0.2 + (iValue * 0.05);
	UI.LookAtPlot(activity.x, activity.y, zoom);

end

-------------------------------------------------------------------------------
-- Initialize the state
function Initialize()
	ms_bInitialized = true;

	CurrentActivity.started = false;
	CurrentActivity.tracking = false;
	CurrentActivity.lingering = false;
	CurrentActivity.type = VisitActivity.None;
	CurrentActivity.startTime = 0;
	CurrentActivity.duration = 0;
	CurrentActivity.x = 0;
	CurrentActivity.y = 0;

	ms_CityViewDuration = 20.0;
	ms_AllowViewSwitching = true;
	ms_CurrentViewType = VIEW_TYPE_NONE;		-- Set to none, it will check changed when a new view type is picked.
	
	-- disable view switching if specified (e.g. benchmarking)
	local force3D = Automation.GetSetParameter("CurrentTest", "Force3DView", false);
	if (force3D ~= nil and force3D == true) then
		ms_CurrentViewType = VIEW_TYPE_WORLD;
		ms_AllowViewSwitching = false;
	end

	local useView = Automation.GetSetParameter("CurrentTest", "UseView", false);
	if (useView ~= nil) then
		if (useView == "3D" or useView == "World") then 
			ms_CurrentViewType = VIEW_TYPE_WORLD;
			ms_AllowViewSwitching = false;
			UI.SetWorldRenderView( WorldRenderView.VIEW_3D );
		elseif (useView == "2D" or useView == "Strategic") then
			ms_CurrentViewType = VIEW_TYPE_STRATEGIC;
			ms_AllowViewSwitching = false;
			UI.SetWorldRenderView( WorldRenderView.VIEW_2D );
		elseif (useView == "Both" or useView == "Any") then
			ms_CurrentViewType = VIEW_TYPE_NONE;		-- Set to none, it will check changed when a new view type is picked.
			ms_AllowViewSwitching = true;
		end
	end

	local gameSeed = Automation.GetSetParameter("CurrentTest", "GameSeed");
	if (gameSeed ~= nil) then
		math.randomseed(gameSeed);
	end
end

-------------------------------------------------------------------------------
-- Uninitialize the state
function Uninitialize()
	ms_bInitialized = false;
	ms_VisibleCities = {};
end

-------------------------------------------------------------------------------
-- Clear all the visited flags in the list of things to look at.
function ClearVisitedFlag(objects : table)

	for _, v in ipairs(objects) do
		v.hasVisited = false;
	end

end

-------------------------------------------------------------------------------
-- Clear the visited flags for a player
function ClearVisitedFlagForPlayer(objects : table , player : number)

	for i, v in ipairs(objects) do
		if (v.player == player) then
			v.hasVisited = false;
		end
	end

end

-------------------------------------------------------------------------------
-- 
function GetEntryForPlayer(objects : table , player : number, id : number)

	for i, v in ipairs(objects) do
		if (v.id == id and v.player == player) then
			return v;
		end
	end

end

-------------------------------------------------------------------------------
-- Get the closest unvisited object in the list
function GetClosestUnvisited(objects : table, x, y)

	local bestDistance = 1000;
	local bestEntry = nil;

	local bHasUnvisited = false;
	for _, v in ipairs(objects) do
		if (v.hasVisited == false) then
			bHasUnvisited = true;
			local distance = Map.GetPlotDistance(x, y, v.x, v.y);
			if (distance < bestDistance) then
				bestEntry = v;
			end
		end
	end

	if (bHasUnvisited == false) then
		-- Seen everything, clear the flags
		ClearVisitedFlag(objects);
	end
	
	return bestEntry;		
end

-------------------------------------------------------------------------------
-- Pick the best city to look at
function PickBestCity()

	wx, wy = UI.GetMapLookAtWorldTarget();
	x, y = UI.GetPlotCoordFromWorld(wx, wy);

	local closestEntry = GetClosestUnvisited(ms_VisibleCities, x, y);

	if (closestEntry ~= nil) then
		ClearCurrentActivity();
		CurrentActivity.type = VisitActivity.City;
		CurrentActivity.startTime = Automation.GetTime();
		CurrentActivity.duration = ms_CityViewDuration;
		CurrentActivity.x = closestEntry.x;
		CurrentActivity.y = closestEntry.y;

		closestEntry.hasVisited = true;
	end

end

-------------------------------------------------------------------------------
function PickBestUnit()

end

-------------------------------------------------------------------------------
function PickViewType()

	if (ms_AllowViewSwitching) then
		if ((Automation.GetTime() - ms_CurrentViewStartTime) >= ms_CurrentViewDuration or ms_CurrentViewType == VIEW_TYPE_NONE) then

			if (ms_CurrentViewType == VIEW_TYPE_WORLD) then
				ms_CurrentViewType = VIEW_TYPE_STRATEGIC;
				UI.SetWorldRenderView( WorldRenderView.VIEW_2D );
				UI.PlaySound("Set_View_2D");
			else
				ms_CurrentViewType = VIEW_TYPE_WORLD;
				UI.SetWorldRenderView( WorldRenderView.VIEW_3D );
				UI.PlaySound("Set_View_3D");
			end

			local minTime = ms_ViewDurationMin[ms_CurrentViewType];
			local maxTime = ms_ViewDurationMax[ms_CurrentViewType];

			ms_CurrentViewDuration = minTime;

			if (maxTime > minTime) then
				ms_CurrentViewDuration = ms_CurrentViewDuration + ((maxTime - minTime) * math.random());
			end

			ms_CurrentViewStartTime = Automation.GetTime();

		end
	end

end

-------------------------------------------------------------------------------
function PickBestActivity()

	CurrentActivity.started = false;

	PickBestCity();

	-- Nothing to look at?
	if (CurrentActivity.type == VisitActivity.None) then
		CurrentActivity.duration = 5.0;		-- Wait a few seconds
	end
end

-------------------------------------------------------------------------------
-- Start the current activity if it has not already
local bAutoCamera = true
function StartCurrentActivity()
	if (not bAutoCamera) or (turnFromStart < 2) then
		return
	end
	
	if (CurrentActivity.started == false) then
		CurrentActivity.startTime = Automation.GetTime();
		CurrentActivity.started = true;
		local pHandler = ActivityHandlers[CurrentActivity.type];
		if (pHandler ~= nil) then
			pHandler.Start(CurrentActivity);
		end
	end
end

-------------------------------------------------------------------------------
-- Check to see if the current activity is complete
function CheckActivityComplete()
	local bFindNewActivity = false;

	PickViewType();

	if (CurrentActivity.started == true) then
		if ((Automation.GetTime() - CurrentActivity.startTime) >= CurrentActivity.duration) then
			-- Activity complete
			bFindNewActivity = true;
		end
	else
		-- No activity, look for a new one.
		bFindNewActivity = true;
	end

	if (bFindNewActivity == true) then
		PickBestActivity();
		StartCurrentActivity();
	end
end

-------------------------------------------------------------------------------
-- The visibility of a city has changed, update our look at lists.
function OnCityVisibilityChanged(player, id, eVisibility)

	if (eVisibility == 2) then
		local o = AddToList(ms_VisibleCities, player, id);
		local pCity = CityManager.GetCity(player, id);
		if (pCity ~= nil) then
			o.x = pCity:GetX();
			o.y = pCity:GetY();
		end

		-- If we are doing nothing, force a re-think on the next pass
		if (CurrentActivity.type == VisitActivity.None) then
			CurrentActivity.duration = 0;
		end
			
	else
		RemoveFromList(ms_VisibleCities, player, id);
	end

end

Events.CityVisibilityChanged.Add( OnCityVisibilityChanged );

-------------------------------------------------------------------------------
-- A players turn has started
function OnPlayerTurnActivated( player, bFirstTime )
	local pPlayer = Players[player]

	
	if (bFirstTime) then
	
		-- Look at their capital
		-- The player turn can change quickly, so see if we want to interrupt the current activity.  Do so only if we have been doing it for a while.
		if (CurrentActivity.started == false or CurrentActivity.type ~= VisitActivity.Combat or CurrentActivity.lingering == true) then	-- Don't interrupt looking at some combat, unless we are in the 'linger' time
			if (CurrentActivityPercentComplete() >= 50.0 or CurrentActivityElapsed() >= 3.0) then	-- Looking at our current activity for more than 50 percent of its duration or more than 3 seconds?

				-- We are also going to give it a chance that we don't look at the capital, so as to not bounce around too much.
				if (pPlayer:IsMajor()) then
					if (math.random() > ms_ChanceToViewMajorsCapital) then
						return;
					end
				else
					if (pPlayer:IsBarbarian() or math.random() > ms_ChanceToViewMinorsCapital) then
						return;
					end
				end

				-- Clear that we have visited their cities, so we start over
				ClearVisitedFlagForPlayer(ms_VisibleCities, player);

				-- Get their capital
				local pPlayerCities = pPlayer:GetCities();
				local pCapital = pPlayerCities:GetCapitalCity();
				if (pCapital ~= nil) then		
					-- Find it in the list.	
					local kEntry = GetEntryForPlayer(ms_VisibleCities, player, pCapital:GetID());
					if (kEntry ~= nil) then
						-- Look at it.
						ClearCurrentActivity();
						CurrentActivity.type = VisitActivity.City;
						CurrentActivity.duration = ms_CityViewDuration;
						CurrentActivity.x = kEntry.x;
						CurrentActivity.y = kEntry.y;

						kEntry.hasVisited = true;
						StartCurrentActivity();

					end
				end
			end
		end
		
		-- try to start a war, one declaration at a time
		if bAllWar and pPlayer:IsMajor() then
			kParams = {}
			kParams.WarState = WarTypes.SURPRISE_WAR
			local bStartedWar = false
			for _, player2 in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
				if player2 ~= player and not bStartedWar then
					if not pPlayer:GetDiplomacy():IsAtWarWith(player2) then
						DiplomacyManager.SendAction(player, player2, DiplomacyActionTypes.SET_WAR_STATE, kParams)
						--if pPlayer:GetDiplomacy():IsAtWarWith(player2) then
							bStartedWar = true
						--end
					end
				end
			end
		end
		
	end
end
Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );

-------------------------------------------------------------------------------
function OnCombatVisBegin(combatMembers)

	local defender = combatMembers[2];
	local bCityAttacked = defender.componentType == ComponentType.CITY	
	
	if (bCityAttacked or CurrentActivity.started == false or CurrentActivity.type ~= VisitActivity.Combat or CurrentActivity.lingering == true) then	-- Don't interrupt looking at some other combat, unless we are in the 'linger' time
		if (bCityAttacked or CurrentActivityPercentComplete() >= 50.0 or CurrentActivityElapsed() >= 3.0		-- Looking at our current activity for more than 50 percent of its duration or more than a few seconds?
			or CurrentActivity.type == VisitActivity.City) then								-- Or are we just looking at a city?
			-- We are bored with that, lets look at something new
			local attacker = combatMembers[1];
			if (attacker.componentType == ComponentType.UNIT) then
				local pUnit = UnitManager.GetUnit(attacker.playerID, attacker.componentID);
				if (pUnit ~= nil) then
					ClearCurrentActivity();

					CurrentActivity.type = VisitActivity.Combat;
					CurrentActivity.startTime = Automation.GetTime();
					CurrentActivity.duration = 20.0;		-- This will change dynamically
					CurrentActivity.x = pUnit:GetX()
					CurrentActivity.y = pUnit:GetY();
					
					if bCityAttacked then
						local pCity = CityManager.GetCity(defender.playerID, defender.componentID);
						if (pCity ~= nil) then
							StatusMessage( "BREAKING NEWS : A city is attacked !!!", 3, ReportingStatusTypes.DEFAULT )
							CurrentActivity.x = pCity:GetX()
							CurrentActivity.y = pCity:GetY();
						end
					end
					
					StartCurrentActivity();
				end			
			end
		end
	end
end
Events.CombatVisBegin.Add( OnCombatVisBegin );

-------------------------------------------------------------------------------
function OnCombatVisEnd(attacker)

	if (CurrentActivity.started == true and CurrentActivity.type == VisitActivity.Combat) then
		-- Linger for a few, then end.
		CurrentActivity.startTime = Automation.GetTime();
		CurrentActivity.duration = 2.0;
		CurrentActivity.lingering = true;		-- Signal that we don't care about being interrupted.
	end

end
Events.CombatVisEnd.Add( OnCombatVisEnd );

-------------------------------------------------------------------------------
function OnUnitActivate(owner, unitID, x, y, eReason, bVisibleToLocalPlayer)

	if (bVisibleToLocalPlayer) then
		if (eReason == EventSubTypes.FOUND_CITY) then

			ClearCurrentActivity();

			-- Look at the location
			CurrentActivity.type = VisitActivity.City;
			CurrentActivity.startTime = Automation.GetTime();
			CurrentActivity.duration = ms_CityViewDuration;
			CurrentActivity.x = x;
			CurrentActivity.y = y;

			StartCurrentActivity();
		end
	end
end
Events.UnitActivate.Add( OnUnitActivate );

-------------------------------------------------------------------------------
function OnWonderCompleted(x, y)

	if (CanSeePlot(x, y)) then
		local plot = Map.GetPlot(x, y);
		if (plot ~= nil) then
			if (CurrentActivity.started == false or CurrentActivity.lingering == true or CurrentActivity.type ~= VisitActivity.Wonder) then	-- Don't interrupt looking at some other wonder complete, unless we are in the 'linger' time
				-- Wonders are important, so interrupt anything else
				ClearCurrentActivity();

				CurrentActivity.type = VisitActivity.Wonder;
				CurrentActivity.startTime = Automation.GetTime();
				CurrentActivity.duration = 5.0;
				CurrentActivity.x = x;
				CurrentActivity.y = y;

				StartCurrentActivity();
			end
		end
	end
end
Events.WonderCompleted.Add( OnWonderCompleted );

-------------------------------------------------------------------------------
function OnDistrictBuildProgressChanged(owner, districtID, cityID, x, y, districtType, era, civilization, percentComplete, appeal, isPillaged)

	if (percentComplete >= 100) then	
		if (CanSeePlot(x, y)) then
			local plot = Map.GetPlot(x, y);
			if (plot ~= nil) then
				if (CurrentActivity.started == false or CurrentActivity.lingering == true or (CurrentActivity.type ~= VisitActivity.District and CurrentActivity.type ~= VisitActivity.Combat) ) then

					ClearCurrentActivity();

					CurrentActivity.type = VisitActivity.District;
					CurrentActivity.startTime = Automation.GetTime();
					CurrentActivity.duration = 5.0;
					CurrentActivity.x = x;
					CurrentActivity.y = y;

					StartCurrentActivity();
				end
			end
		end
	end
end
Events.DistrictBuildProgressChanged.Add( OnDistrictBuildProgressChanged );

-------------------------------------------------------------------------------
function OnDistrictPillaged(owner, districtID, cityID, x, y, districtType, percentComplete, isPillaged)

	if (CanSeePlot(x, y)) then
		local plot = Map.GetPlot(x, y);
		if (plot ~= nil) then
			if (CurrentActivity.started == false or CurrentActivity.lingering == true or (CurrentActivity.type ~= VisitActivity.District and CurrentActivity.type ~= VisitActivity.Combat) ) then

				ClearCurrentActivity();

				CurrentActivity.type = VisitActivity.District;
				CurrentActivity.startTime = Automation.GetTime();
				CurrentActivity.duration = 5.0;
				CurrentActivity.x = x;
				CurrentActivity.y = y;

				StartCurrentActivity();
			end
		end
	end
end
Events.DistrictPillaged.Add( OnDistrictPillaged );

-------------------------------------------------------------------------------
-- Poll our activity.
function OnAutomationAppUpdateComplete()
	if (ms_bInitialized == true) then
		if (not Automation.IsPaused()) then
			CheckActivityComplete();
		end
	end
end

LuaEvents.AutomationAppUpdateComplete.Add( OnAutomationAppUpdateComplete );

-------------------------------------------------------------------------------
function OnAutomationGameStarted()

	ContextPtr:LookUpControl("/InGame/TopPanel"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/DiplomacyRibbon"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/LaunchBar"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/PartialScreenHooks"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/WorldTracker"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/UnitPanel"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/WorldViewIconsManager"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/WorldViewPlotMessages"):SetHide(true)
	
	Events.WonderCompleted.Add( OnWonderCompleted );
	Events.DiplomacyDeclareWar.Add( OnDiplomacyDeclareWar );
	Events.DiplomacyMakePeace.Add( OnDiplomacyMakePeace );	
	Events.DiplomacyRelationshipChanged.Add( OnDiplomacyRelationshipChanged );	
	Events.PlayerDefeat.Add( OnPlayerDefeat );	
	Events.PlayerVictory.Add( OnPlayerVictory );
	Events.PlayerEraChanged.Add( OnPlayerEraChanged );	
	Events.CityOccupationChanged.Add( OnCityOccupationChanged );	
	Events.SpyMissionUpdated.Add( OnSpyMissionUpdated );			
	Events.UnitActivate.Add( OnUnitActivate );
	
	Initialize();
end

LuaEvents.AutomationGameStarted.Add( OnAutomationGameStarted );

-------------------------------------------------------------------------------
function OnAutomationGameEnded()

	-- restore UI
	ContextPtr:LookUpControl("/InGame/TopPanel"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/DiplomacyRibbon"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/LaunchBar"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/PartialScreenHooks"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/WorldTracker"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/UnitPanel"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/WorldViewIconsManager"):SetHide(false)
	ContextPtr:LookUpControl("/InGame/WorldViewPlotMessages"):SetHide(false)
	
	Events.WonderCompleted.Remove( OnWonderCompleted );
	Events.DiplomacyDeclareWar.Remove( OnDiplomacyDeclareWar );
	Events.DiplomacyMakePeace.Remove( OnDiplomacyMakePeace );	
	Events.DiplomacyRelationshipChanged.Remove( OnDiplomacyRelationshipChanged );	
	Events.PlayerDefeat.Remove( OnPlayerDefeat );	
	Events.PlayerVictory.Remove( OnPlayerVictory );
	Events.PlayerEraChanged.Remove( OnPlayerEraChanged );	
	Events.CityOccupationChanged.Remove( OnCityOccupationChanged );	
	Events.SpyMissionUpdated.Remove( OnSpyMissionUpdated );			
	Events.UnitActivate.Remove( OnUnitActivate );
	
	Uninitialize();
end
LuaEvents.AutomationGameEnded.Add( OnAutomationGameEnded );

-------------------------------------------------------------------------------
-- New functions for AutoPlay mod
-------------------------------------------------------------------------------

function OnWonderCompleted(x, y)
	if not bNotifications then
		return
	end
	local plot = Map.GetPlot(x, y);
	if (plot ~= nil) then
		local pPlayer1Config = PlayerConfigurations[plot:GetOwner()]
		local text = tostring(Locale.Lookup(pPlayer1Config:GetCivilizationShortDescription())).." finished a Wonder"
		StatusMessage( text, 5, ReportingStatusTypes.DEFAULT )
	end
end

function OnDiplomacyDeclareWar(player1, player2)
	if not bNotifications then
		return
	end
	local pPlayer1 = Players[player1]
	local pPlayer2 = Players[player2]
	if pPlayer1:IsMajor() and pPlayer2:IsMajor() then
		local pPlayer1Config = PlayerConfigurations[player1]
		local pPlayer2Config = PlayerConfigurations[player2]
		local text = tostring(Locale.Lookup(pPlayer1Config:GetCivilizationShortDescription())).." has declared war to "..tostring(Locale.Lookup(pPlayer2Config:GetCivilizationShortDescription()))
		StatusMessage( text, 5, ReportingStatusTypes.DEFAULT )
	end
end
function OnDiplomacyMakePeace(player1, player2)
	if not bNotifications then
		return
	end
	local pPlayer1 = Players[player1]
	local pPlayer2 = Players[player2]
	if pPlayer1:IsMajor() and pPlayer2:IsMajor() then
		local pPlayer1Config = PlayerConfigurations[player1]
		local pPlayer2Config = PlayerConfigurations[player2]
		local text = tostring(Locale.Lookup(pPlayer1Config:GetCivilizationShortDescription())).." has made peace with "..tostring(Locale.Lookup(pPlayer2Config:GetCivilizationShortDescription()))
		StatusMessage( text, 5, ReportingStatusTypes.DEFAULT )
	end
end

-------------------------------------------------------------------------------
function OnDiplomacyRelationshipChanged(player1, player2)
	if not bNotifications then
		return
	end
	
end

-------------------------------------------------------------------------------
function OnPlayerDefeat(player1, player2)
	if not bNotifications then
		return
	end
	--[[
	if (IsEventEnabled("NarrationEvent_PlayerDefeated")) then

		if (PlayerManager.IsValid(player2)) then
			-- Specifically defeated by another player
			SendPlayerPlayerNarrationMessage("LOC_AUTONARRATE_PLAYER_DEFEATED_BY", player1, player2);
		else
			SendPlayerNarrationMessage("LOC_AUTONARRATE_PLAYER_DEFEATED", player1);
		end
	end
	--]]
end

-------------------------------------------------------------------------------
function OnPlayerVictory(player, victoryType)
	if not bNotifications then
		return
	end
	--[[
	if (IsEventEnabled("NarrationEvent_PlayerVictory")) then

		local victoryDef = GameInfo.Victories[victoryType];
		if (victoryDef ~= nil) then
			-- Have specific victory text?
			local textKey = "LOC_AUTONARRATE_PLAYER_" .. victoryDef.VictoryType;
			if (not Locale.HasTextKey(textKey)) then
				-- Show generic text
				textKey = "LOC_AUTONARRATE_PLAYER_VICTORY";
			end

			local pPlayerConfig = PlayerConfigurations[player];
			if (pPlayerConfig ~= nil) then
				local tMessage = {};
				tMessage.Message = Locale.Lookup(textKey, pPlayerConfig:GetCivilizationShortDescription());
				-- Show a "done" button
				tMessage.Button1Text = Locale.Lookup("LOC_AUTONARRATE_BUTTON_DONE");
				-- Stop the test 
				tMessage.Button1Func = function() 
					Automation.Pause(false);
					AutoplayManager.SetActive(false);	-- Stop the autoplay
				end 
				tMessage.ShowPortrait = true;

				LuaEvents.Automation_AddToNarrationQueue( tMessage );

				Automation.Pause(true);
			end


		end
	end
	--]]
end

-------------------------------------------------------------------------------
function OnPlayerEraChanged(player, era)
	if not bNotifications then
		return
	end
	local eraDef = GameInfo.Eras[era];
	if (eraDef ~= nil) then
		if (eraDef.Hash ~= GameConfiguration.GetStartEra()) then
			-- Have specific era text?
			local textKey = "LOC_AUTONARRATE_PLAYER_" .. eraDef.EraType;
			if (Locale.HasTextKey(textKey)) then
				--SendPlayerNarrationMessage(textKey, player);
			else
				-- Show generic text
				--SendPlayerNarrationMessage("LOC_AUTONARRATE_PLAYER_ERA_CHANGED", player);
			end
		end
	end
end

-------------------------------------------------------------------------------
function OnCityOccupationChanged(player, cityID)
	if not bNotifications then
		return
	end

end

-------------------------------------------------------------------------------
function OnSpyMissionUpdated()
	if not bNotifications then
		return
	end

end

function OnUnitActivate(owner, unitID, x, y, eReason, bVisibleToLocalPlayer)
	if not bNotifications then
		return
	end
	if (eReason == EventSubTypes.FOUND_CITY) and turnFromStart > 1 then
		local pPlayer1Config = PlayerConfigurations[owner]
		local text = tostring(Locale.Lookup(pPlayer1Config:GetCivilizationShortDescription())).." has founded a new city"
		StatusMessage( text, 5, ReportingStatusTypes.DEFAULT )
	end
end

local bIsHide = true
function OnInputHandler( pInputStruct:table )
	local uiMsg:number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		if pInputStruct:GetKey() == Keys.U then
			if bIsHide then
				bIsHide = not bIsHide
				ContextPtr:LookUpControl("/InGame/TopPanel"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/DiplomacyRibbon"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/LaunchBar"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/PartialScreenHooks"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/WorldTracker"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/UnitPanel"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/WorldViewIconsManager"):SetHide(false)
				ContextPtr:LookUpControl("/InGame/WorldViewPlotMessages"):SetHide(false)
	
			else
				bIsHide = not bIsHide
				ContextPtr:LookUpControl("/InGame/TopPanel"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/DiplomacyRibbon"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/LaunchBar"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/PartialScreenHooks"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/WorldTracker"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/UnitPanel"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/WorldViewIconsManager"):SetHide(true)
				ContextPtr:LookUpControl("/InGame/WorldViewPlotMessages"):SetHide(true)
			
			end
			StatusMessage( "Show UI = " .. tostring(not bIsHide), 2, ReportingStatusTypes.DEFAULT )
			
		elseif pInputStruct:GetKey() == Keys.I then
			bAutoCamera = not bAutoCamera
			StatusMessage( "Auto Camera = " .. tostring(bAutoCamera), 2, ReportingStatusTypes.DEFAULT )
			
		elseif pInputStruct:GetKey() == Keys.H then
			local strAutoCam = "Auto Camera = ".. tostring(bAutoCamera).." (press I to toggle)";
			local strShowUI = "Show UI = ".. tostring(not bIsHide).." (press U to toggle)";
			StatusMessage( strAutoCam, 5, ReportingStatusTypes.DEFAULT )
			StatusMessage( strShowUI, 5, ReportingStatusTypes.DEFAULT )
			
			local strStopAP = "Autoplay = ".. tostring(AutoplayManager.IsActive()).." (press Shift+A to toggle)";
			StatusMessage( strStopAP, 5, ReportingStatusTypes.DEFAULT )
			
			local strAutoWar = "Auto Declare War = ".. tostring(bAllWar).." (press Shift+W to toggle)";
			StatusMessage( strAutoWar, 5, ReportingStatusTypes.DEFAULT )
			
			local strNotifications = "Display Notifications = ".. tostring(bNotifications).." (press Shift+N to toggle)";
			StatusMessage( strNotifications, 5, ReportingStatusTypes.DEFAULT )
			
		elseif pInputStruct:GetKey() == Keys.A and pInputStruct:IsShiftDown() then
			if AutoplayManager.IsActive() then				
				AutoplayManager.SetTurns(0)
				AutoplayManager.SetReturnAsPlayer( 0 )
				AutoplayManager.SetActive(false)
				LuaEvents.AutomationGameEnded()
				StatusMessage( "Autoplay marked for deactivation, please wait for new turn...", 10, ReportingStatusTypes.DEFAULT )
			else				
				AutoplayManager.SetTurns(-1)
				AutoplayManager.SetObserveAsPlayer( tonumber(PlayerTypes.OBSERVER) )
				AutoplayManager.SetActive(true)
				LuaEvents.AutomationGameStarted()
				StatusMessage( "Autoplay reactivated...", 5, ReportingStatusTypes.DEFAULT )
			end			
		
		elseif pInputStruct:GetKey() == Keys.W and pInputStruct:IsShiftDown() then
			bAllWar = not bAllWar
			StatusMessage( "Auto Declare War = " .. tostring(bAllWar), 2, ReportingStatusTypes.DEFAULT )
			
		elseif pInputStruct:GetKey() == Keys.N and pInputStruct:IsShiftDown() then
			bNotifications = not bNotifications
			StatusMessage( "Display Notifications = " .. tostring(bNotifications), 2, ReportingStatusTypes.DEFAULT )
		end
		
		-- pInputStruct:IsShiftDown() and pInputStruct:IsAltDown()
	end
	return false;
end

function StartAutoPlay()
	ContextPtr:SetInputHandler( OnInputHandler, true )
	AutoplayManager.SetTurns(-1)
	AutoplayManager.SetReturnAsPlayer( 0 )
	AutoplayManager.SetObserveAsPlayer( tonumber(PlayerTypes.OBSERVER) )
	AutoplayManager.SetActive(true)
	
	LuaEvents.AutomationGameStarted()
	StatusMessage( "Starting Autoplay, please wait...", 5, ReportingStatusTypes.DEFAULT )
	StatusMessage( "(press H for Autoplay Help)", 5, ReportingStatusTypes.DEFAULT )
end
Events.LoadScreenClose.Add( StartAutoPlay )

local displayHelpCounter = 0
function NewTurn()
	turnFromStart = turnFromStart + 1
	
	-- get time
	local format = UserConfiguration.GetClockFormat()	
	local strTime	
	if(format == 1) then
		strTime = os.date("%H:%M")
	else
		strTime = os.date("%#I:%M %p")
	end
	
	local strTurn :string = tostring( Game.GetCurrentGameTurn() );
	local strDate :string = Calendar.MakeYearStr(Game.GetCurrentGameTurn(), GameConfiguration.GetCalendarType(), GameConfiguration.GetGameSpeedType(), false);
	local strNewTurn = "Turn " .. strTurn .. " : " .. strDate .. " : " .. strTime;
	StatusMessage( strNewTurn, 5, ReportingStatusTypes.DEFAULT )
	displayHelpCounter = displayHelpCounter + 1
	if displayHelpCounter > 9 then
		displayHelpCounter = 0		
		StatusMessage( "(press H for Autoplay Help)", 3, ReportingStatusTypes.DEFAULT )
	end
end
Events.TurnBegin.Add(NewTurn)

function CheckToStopAutoPlay()
	if not AutoplayManager.IsActive() then -- automation deactivated from the tuner maybe
		-- remove autoplay
		LuaEvents.AutomationGameEnded()
		Events.TurnBegin.Remove(NewTurn)
	end
end
--Events.PlayerTurnActivated.Add( CheckToStopAutoPlay );


-------------------------------------------------------------------------------
-- from StatusMessagePanel.lua
-------------------------------------------------------------------------------
-- =========================================================================== 
-- Status Message Manager
-- Non-interactive messages that appear in the upper-center of the screen.
-- =========================================================================== 

-- =========================================================================== 
--	CONSTANTS
-- =========================================================================== 
local DEFAULT_TIME_TO_DISPLAY	:number = 10;	-- Seconds to display the message


-- =========================================================================== 
--	VARIABLES
-- =========================================================================== 

local m_statusIM				:table = InstanceManager:new( "StatusMessageInstance", "Root", Controls.StackOfMessages );
local m_gossipIM				:table = InstanceManager:new( "GossipMessageInstance", "Root", Controls.StackOfMessages );

local PlayerConnectedChatStr	:string = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr :string	= Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerKickedChatStr		:string	= Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );

local m_kMessages :table = {};


-- =========================================================================== 
--	FUNCTIONS
-- =========================================================================== 

-- =========================================================================== 
-- =========================================================================== 
function StatusMessage( str:string, fDisplayTime:number, type:number )

	if (type == ReportingStatusTypes.DEFAULT or
		type == ReportingStatusTypes.GOSSIP) then	-- A type we handle?

		local kTypeEntry :table = m_kMessages[type];
		if (kTypeEntry == nil) then
			-- New type
			m_kMessages[type] = {
				InstanceManager = nil,
				MessageInstances= {}
			};
			kTypeEntry = m_kMessages[type];

			-- Link to the instance manager and the stack the UI displays in
			if (type == ReportingStatusTypes.GOSSIP) then
				kTypeEntry.InstanceManager	= m_gossipIM;
			else
				kTypeEntry.InstanceManager	= m_statusIM;
			end
		end

		local pInstance:table = kTypeEntry.InstanceManager:GetInstance();
		table.insert( kTypeEntry.MessageInstances, pInstance );

		local timeToDisplay:number = (fDisplayTime > 0) and fDisplayTime or DEFAULT_TIME_TO_DISPLAY;
		pInstance.StatusLabel:SetText( str );		
		pInstance.Anim:SetEndPauseTime( timeToDisplay );
		pInstance.Anim:RegisterEndCallback( function() OnEndAnim(kTypeEntry,pInstance) end );
		pInstance.Anim:SetToBeginning();
		pInstance.Anim:Play();

		Controls.StackOfMessages:CalculateSize();
		Controls.StackOfMessages:ReprocessAnchoring();
	end
end

-- ===========================================================================
function OnEndAnim( kTypeEntry:table, pInstance:table )
	pInstance.Anim:ClearEndCallback();
	Controls.StackOfMessages:CalculateSize();
	Controls.StackOfMessages:ReprocessAnchoring();
	kTypeEntry.InstanceManager:ReleaseInstance( pInstance ) 	
end

