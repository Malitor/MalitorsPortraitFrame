local strAddonName, tblNamespace = ...

local tblConstants = tblNamespace.Constants
local tblHelpers = tblNamespace.Helpers
local tblCore = tblNamespace.Core
local tblState = tblNamespace.State

--========================================================
-- Core Behavior
--========================================================
function tblCore.ApplyModelView()
	local frmModel = tblState.frmModel

	if not frmModel then return end

	if not frmModel._desiredUnit or not frmModel._applyToken then
		if (tonumber(tblState.intDebugModel) or 0) >= 1 then
			print("|cffffaa00DBG|r APPLY skipped (no desiredUnit/applyToken yet)")
		end
		return
	end

	tblHelpers.DebugCall("Apply", "SetPortraitZoom", tblHelpers.GetModelZoom())
	tblHelpers.DebugCall("Apply", "SetCamDistanceScale", tblHelpers.GetCamDistance())
end

function tblCore.ReapplyAfterDelay(_intToken, _fltDelay, _strLabel)
	if not C_Timer or not C_Timer.After then return end

	C_Timer.After(_fltDelay, function()
		local frmModel = tblState.frmModel
		if not frmModel then return end
		if frmModel._applyToken ~= _intToken then return end

		if (tonumber(tblState.intDebugModel) or 0) >= 2 then
			print("|cff00ff00DBG|r Reapply", _strLabel, "delay=", _fltDelay, "token=", _intToken)
		end

		tblCore.ApplyModelView()

		if (tonumber(tblState.intDebugModel) or 0) >= 2 then
			tblHelpers.DebugSnapshot("After Reapply " .. _strLabel, _intToken)
		end
	end)
end

function tblCore.RequestApplyModelView()
	if tblState.blnApplyModelViewQueued then return end
	tblState.blnApplyModelViewQueued = true

	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			tblState.blnApplyModelViewQueued = false
			tblCore.ApplyModelView()
		end)
	else
		tblState.blnApplyModelViewQueued = false
		tblCore.ApplyModelView()
	end
end

function tblCore.ApplyModelViewOnceForToken(_intToken)
	local frmModel = tblState.frmModel

	if not frmModel then return end
	if not _intToken then return end

	if frmModel._appliedToken == _intToken then return end
	frmModel._appliedToken = _intToken

	tblCore.ApplyModelView()
end

function tblCore.RefreshFromDatabase()
	local frmMain = tblState.frmMain
	local frmModel = tblState.frmModel
	local tblDatabase = tblHelpers.GetDB()

	if not frmMain or not frmModel or not tblDatabase then return end

	-- Keep runtime debug state synced to the active profile
	tblState.intDebugModel = tonumber(tblDatabase.debugLevel) or 0
	if tblState.intDebugModel < 0 then tblState.intDebugModel = 0 end
	if tblState.intDebugModel > 2 then tblState.intDebugModel = 2 end

	-- Re-apply layout and visuals from the active profile
	tblCore.ApplySavedLayout()
	tblCore.ApplyBackdrop()
	tblCore.ApplyLockState()

	-- Re-apply model settings from the active profile
	tblCore.RequestApplyModelView()
end

function tblCore.ForceSetModelUnit(_blnUseTarget)
	local frmCurrentModel = tblState.frmModel
	if not frmCurrentModel then return end

	-- Force the engine to treat this as a real change even if it is the same unit.
	if frmCurrentModel.ClearModel then
		frmCurrentModel:ClearModel()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if not tblState.frmModel then return end

			if _blnUseTarget and UnitExists("target") then
				tblState.frmModel:SetUnit("target")
			else
				tblState.frmModel:SetUnit("player")
			end
		end)
	else
		if _blnUseTarget and UnitExists("target") then
			frmCurrentModel:SetUnit("target")
		else
			frmCurrentModel:SetUnit("player")
		end
	end
end

--========================================================
-- Frame Sizing / Backdrop / Lock
--========================================================
function tblCore.UpdateResizeBounds()
	local frmMain = tblState.frmMain
	local intBorderWidth = tblHelpers.GetBorderWidth()
	local intMinSize = math.max(tblConstants.intFrameMinBase, intBorderWidth * 3)

	frmMain:SetResizeBounds(intMinSize, intMinSize, tblConstants.intFrameMax, tblConstants.intFrameMax)
end

function tblCore.ApplyBackdrop()
	local frmMain = tblState.frmMain
	local frmBorder = tblState.frmBorder
	local frmModel = tblState.frmModel
	local frmResizeButton = tblState.frmResizeButton

	local strEdgeFile, strBgFile = tblHelpers.FetchMedia()
	local intBorderWidth = tblHelpers.GetBorderWidth()

	tblCore.UpdateResizeBounds()

	local intPadding = intBorderWidth
	local intFrameWidth, intFrameHeight = frmMain:GetSize()
	local intMaxPadding = math.floor(math.min(intFrameWidth, intFrameHeight) / 2) - 1
	if intMaxPadding < 0 then intMaxPadding = 0 end
	if intPadding > intMaxPadding then intPadding = intMaxPadding end

	frmMain:SetBackdrop({
		bgFile = strBgFile,
		edgeFile = nil,
		tile = true, tileSize = 32, edgeSize = 0,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	frmMain:SetBackdropColor(0, 0, 0, 0.8)

	frmBorder:SetBackdrop({
		bgFile = nil,
		edgeFile = strEdgeFile,
		tile = false, tileSize = 0, edgeSize = intBorderWidth,
		insets = { left = intPadding, right = intPadding, top = intPadding, bottom = intPadding }
	})

	local fltRed, fltGreen, fltBlue, fltAlpha = tblHelpers.GetBorderColor()
	frmBorder:SetBackdropBorderColor(fltRed, fltGreen, fltBlue, fltAlpha)

	frmModel:ClearAllPoints()
	frmModel:SetPoint("TOPLEFT", frmMain, "TOPLEFT", intPadding, -intPadding)
	frmModel:SetPoint("BOTTOMRIGHT", frmMain, "BOTTOMRIGHT", -intPadding, intPadding)

	frmModel:SetFrameLevel(frmMain:GetFrameLevel() + 1)
	frmBorder:SetFrameLevel(frmMain:GetFrameLevel() + 20)

	if frmResizeButton then
		frmResizeButton:SetFrameLevel(frmBorder:GetFrameLevel() + 10)
	end
end

function tblCore.ApplyLockState()
	local frmMain = tblState.frmMain
	local frmResizeButton = tblState.frmResizeButton
	local tblDatabase = tblHelpers.GetDB()
	local blnLocked = tblDatabase and tblDatabase.locked

	if blnLocked then
		frmMain:RegisterForDrag()
	else
		frmMain:RegisterForDrag("LeftButton")
	end

	if blnLocked then
		frmMain:SetResizable(false)
		if frmResizeButton then
			frmResizeButton:EnableMouse(false)
			frmResizeButton:Hide()
		end
	else
		frmMain:SetResizable(true)
		if frmResizeButton then
			frmResizeButton:Show()
			frmResizeButton:EnableMouse(true)
			frmResizeButton:SetFrameLevel(tblState.frmBorder:GetFrameLevel() + 10)
		end
	end
end

--========================================================
-- Frame Creation / Interaction Wiring
--========================================================
function tblCore.CreateMainFrame()
	local frmMain = CreateFrame("Frame", "MalitorsPortraitFrameMainFrame", UIParent, "BackdropTemplate")
	tblState.frmMain = frmMain

	local tblDefaults = tblConstants.tblDefaults.profile

	frmMain:SetPoint(tblDefaults.point, UIParent, tblDefaults.relativePoint, tblDefaults.x, tblDefaults.y)
	frmMain:SetSize(tblDefaults.width, tblDefaults.height)

	frmMain:SetMovable(true)
	frmMain:SetResizable(true)
	frmMain:SetClampedToScreen(true)

	frmMain:EnableMouse(true)
	frmMain:RegisterForDrag("LeftButton")

	frmMain:SetFrameStrata("MEDIUM")
end

function tblCore.CreateBorderOverlay()
	local frmBorder = CreateFrame("Frame", nil, tblState.frmMain, "BackdropTemplate")
	tblState.frmBorder = frmBorder

	frmBorder:SetAllPoints(tblState.frmMain)
	frmBorder:EnableMouse(false)
	frmBorder:SetFrameLevel(tblState.frmMain:GetFrameLevel() + 20)
	frmBorder:SetFrameStrata(tblState.frmMain:GetFrameStrata())
end

function tblCore.CreateModel()
	local frmModel = CreateFrame("PlayerModel", nil, tblState.frmMain)
	tblState.frmModel = frmModel

	frmModel:SetFrameStrata(tblState.frmMain:GetFrameStrata())
	frmModel._needsHardReset = false
	frmModel._lastUnit = nil
	frmModel._pendingApply = true
	frmModel._blnUseTarget = false
	frmModel._desiredGUID = nil
	frmModel._modelLoadedToken = nil
	frmModel._appliedToken = nil
	frmModel._applyToken = nil

	if frmModel.SetCamera then
		frmModel:SetCamera(1)
	end
	tblState.blnModelCameraInitialized = true

	frmModel:SetScript("OnModelLoaded", function()
		local frmCurrentModel = tblState.frmModel
		if not frmCurrentModel then return end
		if not frmCurrentModel._applyToken then return end

		frmCurrentModel._modelLoadedToken = frmCurrentModel._applyToken

		tblHelpers.DebugSnapshot("OnModelLoaded (pre-apply)", frmCurrentModel._applyToken)

		if frmCurrentModel._needsHardReset then
			tblHelpers.DebugCall("Apply", "SetPosition", 0, 0, 0)
			frmCurrentModel._needsHardReset = false
		end

		tblCore.ApplyModelViewOnceForToken(frmCurrentModel._applyToken)
		tblCore.ReapplyAfterDelay(frmCurrentModel._applyToken, 0.03, "postLoad0.03")
		tblCore.ReapplyAfterDelay(frmCurrentModel._applyToken, 0.10, "postLoad0.10")
	end)

	frmModel._KickApplyPipeline = function(_intToken)
		local frmCurrentModel = tblState.frmModel

		if not frmCurrentModel then return end
		if not _intToken then return end

		if frmCurrentModel._modelLoadedToken == _intToken then
			if (tonumber(tblState.intDebugModel) or 0) >= 1 then
				print("|cffffaa00DBG|r KickApplyPipeline skip (OnModelLoaded already fired) token=", _intToken)
			end
			return
		end

		if C_Timer and C_Timer.After then
			C_Timer.After(0.05, function()
				local frmDelayedModel = tblState.frmModel

				if not frmDelayedModel then return end
				if frmDelayedModel._applyToken ~= _intToken then return end
				if frmDelayedModel._modelLoadedToken == _intToken then return end

				if frmDelayedModel._needsHardReset then
					tblHelpers.DebugCall("Apply", "SetPosition", 0, 0, 0)
					frmDelayedModel._needsHardReset = false
				end

				tblCore.ApplyModelViewOnceForToken(_intToken)
				tblCore.ReapplyAfterDelay(_intToken, 0.15, "postSet0.15")
			end)
		end
	end
end

function tblCore.CreateResizeGrip()
	local frmResizeButton = CreateFrame("Button", nil, tblState.frmMain)
	tblState.frmResizeButton = frmResizeButton

	frmResizeButton:SetSize(16, 16)
	frmResizeButton:SetPoint("BOTTOMRIGHT", -5, 5)
	frmResizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	frmResizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	frmResizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	frmResizeButton:SetFrameLevel(tblState.frmBorder:GetFrameLevel() + 10)

	frmResizeButton:SetScript("OnMouseDown", function(_frmSelf, _strButton)
		if _strButton == "LeftButton" then
			if tblHelpers.GetDB() and tblHelpers.GetDB().locked then return end
			tblState.frmMain:StartSizing("BOTTOMRIGHT")
			tblState.frmMain:SetUserPlaced(true)
		end
	end)

	frmResizeButton:SetScript("OnMouseUp", function(_frmSelf, _strButton)
		tblState.frmMain:StopMovingOrSizing()
		tblHelpers.GetDB().width = tblState.frmMain:GetWidth()
		tblHelpers.GetDB().height = tblState.frmMain:GetHeight()
		tblCore.ApplyBackdrop()
	end)
end

function tblCore.WireFrameInteraction()
	local frmMain = tblState.frmMain

	frmMain:SetScript("OnDragStart", function(_frmSelf)
		if tblHelpers.GetDB() and tblHelpers.GetDB().locked then return end
		_frmSelf:StartMoving()
	end)

	frmMain:SetScript("OnDragStop", function(_frmSelf)
		_frmSelf:StopMovingOrSizing()
		local strPoint, _, strRelativePoint, intX, intY = _frmSelf:GetPoint()
		tblHelpers.GetDB().point = strPoint
		tblHelpers.GetDB().relativePoint = strRelativePoint
		tblHelpers.GetDB().x = intX
		tblHelpers.GetDB().y = intY
	end)
end

function tblCore.ApplySavedLayout()
	local frmMain = tblState.frmMain
	local tblDatabase = tblHelpers.GetDB() or {}
	local tblDefaults = tblConstants.tblDefaults.profile

	local strPoint = tblDatabase.point or tblDefaults.point
	local strRelativePoint = tblDatabase.relativePoint or tblDefaults.relativePoint
	local intX = tblDatabase.x or tblDefaults.x
	local intY = tblDatabase.y or tblDefaults.y
	local intWidth = tblDatabase.width or tblDefaults.width
	local intHeight = tblDatabase.height or tblDefaults.height

	frmMain:ClearAllPoints()
	frmMain:SetPoint(strPoint, UIParent, strRelativePoint, intX, intY)
	frmMain:SetSize(intWidth, intHeight)
end