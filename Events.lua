local strAddonName, tblNamespace = ...

local tblHelpers = tblNamespace.Helpers
local tblCore = tblNamespace.Core
local tblOptions = tblNamespace.Options
local tblEvents = tblNamespace.Events
local tblState = tblNamespace.State

--========================================================
-- Events
--========================================================
function tblEvents.OnAddonLoaded()
	tblHelpers.EnsureDB()
	tblOptions.CreateOptionsPanel()
	tblOptions.ApplyProfileToUI()
end

function tblEvents.OnTargetChanged()
	tblState.intModelApplyToken = tblState.intModelApplyToken + 1
	tblState.frmModel._applyToken = tblState.intModelApplyToken
	local intMyToken = tblState.frmModel._applyToken

	local blnUseTarget = UnitExists("target") and true or false
	local strDesiredUnit = blnUseTarget and "target" or "player"

	tblState.frmModel._desiredUnit = strDesiredUnit
	tblState.frmModel._desiredGUID = UnitGUID(strDesiredUnit)

	if tblState.frmModel._lastUnit ~= strDesiredUnit then
		tblState.frmModel._needsHardReset = true
	end
	tblState.frmModel._lastUnit = strDesiredUnit

	-- IMPORTANT:
	-- Pass a boolean, not a unit token string.
	tblCore.ForceSetModelUnit(blnUseTarget)

	tblHelpers.DebugSnapshot("TargetChanged POST SetUnit (immediate)", intMyToken)
end

function tblEvents.OnEnteringWorld()
	tblState.intModelApplyToken = tblState.intModelApplyToken + 1
	tblState.frmModel._applyToken = tblState.intModelApplyToken
	local intMyToken = tblState.frmModel._applyToken

	tblState.frmModel._desiredUnit = "player"
	tblState.frmModel._desiredGUID = UnitGUID("player")

	if tblState.frmModel._lastUnit ~= "player" then
		tblState.frmModel._needsHardReset = true
	end
	tblState.frmModel._lastUnit = "player"

	-- IMPORTANT:
	-- Pass false so the helper uses literal "player" internally.
	tblCore.ForceSetModelUnit(false)

	tblHelpers.DebugSnapshot("EnteringWorld POST SetUnit (immediate)", intMyToken)

	if tblState.frmModel and tblState.frmModel._KickApplyPipeline then
		tblState.frmModel._KickApplyPipeline(intMyToken)
	end
end

function tblEvents.OnEvent(_frmSelf, _strEvent, _valArgument1)
	if _strEvent == "ADDON_LOADED" and _valArgument1 == tblNamespace.strAddonName then
		tblEvents.OnAddonLoaded()
	elseif _strEvent == "PLAYER_TARGET_CHANGED" then
		tblEvents.OnTargetChanged()
	elseif _strEvent == "PLAYER_ENTERING_WORLD" then
		tblEvents.OnEnteringWorld()
	end
end

--========================================================
-- Boot
--========================================================
tblCore.CreateMainFrame()
tblCore.CreateBorderOverlay()
tblCore.CreateModel()
tblCore.CreateResizeGrip()
tblCore.WireFrameInteraction()

tblCore.ApplyBackdrop()

tblState.frmMain:RegisterEvent("ADDON_LOADED")
tblState.frmMain:RegisterEvent("PLAYER_TARGET_CHANGED")
tblState.frmMain:RegisterEvent("PLAYER_ENTERING_WORLD")
tblState.frmMain:SetScript("OnEvent", tblEvents.OnEvent)
