-- Namespace
local strAddonName, tblNamespace = ...

-- LibSharedMedia
local objLSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Settings category handles
local objMalitorsPortraitFrameSettingsCategory = nil
local intMalitorsPortraitFrameSettingsCategoryID = nil

--========================================================
-- Constants / Defaults
--========================================================
local intBorderMin = 1
local intBorderMax = 32
local intFrameMinBase = 64
local intFrameMax = 800

-- 3D Camera Settings
local fltZoomMin, fltZoomMax = 0.10, 1.00
local fltCamMin, fltCamMax = 0.60, 2.50

-- Debug level
-- 0 = off
-- 1 = important lifecycle events
-- 2 = verbose camera/apply spam
local intDebugModel = 0

local tblDefaults = {
	point = "CENTER",
	relativePoint = "CENTER",
	x = 0,
	y = 0,
	width = 200,
	height = 200,
	locked = false,

	-- 3D Camera
	modelZoom = 0.6,
	camDistance = 1.0,

	-- LSM media keys (names, not file paths)
	border = "Blizzard Dialog",
	background = "Blizzard Dialog Background",

	-- Border styling
	borderWidth = intBorderMax,
	borderColor = { r = 1, g = 1, b = 1, a = 1 },

	-- Debug (0=off, 1=events, 2=verbose)
	debugLevel = 0,
}

--========================================================
-- Core Frames
--========================================================
local frmMain = nil
local frmBorder = nil
local frmModel = nil
local frmResizeButton = nil
local blnModelCameraInitialized = false
local intModelApplyToken = 0
local blnApplyModelViewQueued = false

--========================================================
-- Helpers
--========================================================
local function Clamp(_valValue, _valMinValue, _valMaxValue)
	if _valValue < _valMinValue then return _valMinValue end
	if _valValue > _valMaxValue then return _valMaxValue end
	return _valValue
end

local function Round(_valValue)
	return math.floor((_valValue or 0) + 0.5)
end

local function GetDB()
	return MalitorsPortraitFrameDB
end

local function EnsureDB()
	if not MalitorsPortraitFrameDB then
		MalitorsPortraitFrameDB = CopyTable(tblDefaults)
	end

	-- Ensure new fields exist for older saved vars
	if MalitorsPortraitFrameDB.border == nil then MalitorsPortraitFrameDB.border = tblDefaults.border end
	if MalitorsPortraitFrameDB.background == nil then MalitorsPortraitFrameDB.background = tblDefaults.background end
	if MalitorsPortraitFrameDB.borderWidth == nil then MalitorsPortraitFrameDB.borderWidth = tblDefaults.borderWidth end
	if MalitorsPortraitFrameDB.borderColor == nil then MalitorsPortraitFrameDB.borderColor = CopyTable(tblDefaults.borderColor) end
	if MalitorsPortraitFrameDB.locked == nil then MalitorsPortraitFrameDB.locked = tblDefaults.locked end
	if MalitorsPortraitFrameDB.modelZoom == nil then MalitorsPortraitFrameDB.modelZoom = tblDefaults.modelZoom end
	if MalitorsPortraitFrameDB.camDistance == nil then MalitorsPortraitFrameDB.camDistance = tblDefaults.camDistance end

	if MalitorsPortraitFrameDB.debugLevel == nil then
		MalitorsPortraitFrameDB.debugLevel = tblDefaults.debugLevel or 0
	end

	intDebugModel = tonumber(MalitorsPortraitFrameDB.debugLevel) or 0
	if intDebugModel < 0 then intDebugModel = 0 end
	if intDebugModel > 2 then intDebugModel = 2 end
end

local function GetBorderWidth()
	local intBorderWidth = (GetDB() and GetDB().borderWidth) or tblDefaults.borderWidth or intBorderMax
	intBorderWidth = Round(intBorderWidth)
	intBorderWidth = Clamp(intBorderWidth, intBorderMin, intBorderMax)
	return intBorderWidth
end

local function GetBorderColor()
	local tblBorderColor = (GetDB() and GetDB().borderColor) or tblDefaults.borderColor
	return tblBorderColor.r or 1, tblBorderColor.g or 1, tblBorderColor.b or 1, tblBorderColor.a or 1
end

local function GetModelZoom()
	local fltModelZoom = (GetDB() and GetDB().modelZoom) or tblDefaults.modelZoom
	fltModelZoom = tonumber(fltModelZoom) or tblDefaults.modelZoom
	return Clamp(fltModelZoom, fltZoomMin, fltZoomMax)
end

local function GetCamDistance()
	local fltCamDistance = (GetDB() and GetDB().camDistance) or tblDefaults.camDistance
	fltCamDistance = tonumber(fltCamDistance) or tblDefaults.camDistance
	return Clamp(fltCamDistance, fltCamMin, fltCamMax)
end

local function FetchMedia()
	local strEdgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
	local strBgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"

	if objLSM and GetDB() then
		if GetDB().border then
			strEdgeFile = objLSM:Fetch("border", GetDB().border) or strEdgeFile
		end
		if GetDB().background then
			strBgFile = objLSM:Fetch("background", GetDB().background) or strBgFile
		end
	end

	return strEdgeFile, strBgFile
end

local function EnsureModelCamera()
	if not frmModel or not frmModel.SetCamera then return end
	if blnModelCameraInitialized then return end

	frmModel:SetCamera(1)
	blnModelCameraInitialized = true
end

local function DebugCall(_strTag, _strFunctionName, ...)
	if not frmModel or not frmModel[_strFunctionName] then
		if (tonumber(intDebugModel) or 0) >= 2 then
			print("|cffff5555DBG|r", _strTag, _strFunctionName, "missing")
		end
		return
	end

	local blnOk, valError = pcall(frmModel[_strFunctionName], frmModel, ...)

	if (tonumber(intDebugModel) or 0) >= 2 then
		if blnOk then
			print("|cff00ff00DBG|r", _strTag, _strFunctionName, "OK", ...)
		else
			print("|cffff5555DBG|r", _strTag, _strFunctionName, "ERR", tostring(valError))
		end
	end
end

local function DebugModelState(_strTag)
	if (tonumber(intDebugModel) or 0) <= 0 then return end
	if not frmModel then
		print("|cffff5555DBG|r", _strTag, "frmModel=nil")
		return
	end

	local strUnit = (UnitExists("target") and "target") or "player"
	local strGuid = UnitGUID(strUnit)
	local strName = UnitName(strUnit)

	local function SafeCall(_strFunctionName, ...)
		if not frmModel[_strFunctionName] then return "n/a" end
		local blnOk, valA, valB, valC, valD = pcall(frmModel[_strFunctionName], frmModel, ...)
		if not blnOk then return "ERR" end
		if valB ~= nil then
			return string.format("%s,%s,%s,%s", tostring(valA), tostring(valB), tostring(valC), tostring(valD))
		end
		return tostring(valA)
	end

	local fltDbZoom = GetModelZoom()
	local fltDbDistance = GetCamDistance()

	local valCamera = SafeCall("GetCamera")
	local valZoom = SafeCall("GetPortraitZoom")
	local valDistance = SafeCall("GetCamDistanceScale")
	local valPosition = SafeCall("GetPosition")
	local valFileID = SafeCall("GetModelFileID")
	local valFile = SafeCall("GetModelFile")
	local valModelScale = SafeCall("GetModelScale")
	local valBounds = SafeCall("GetBoundsRect")

	print("|cff00ff00DBG|r", _strTag,
		"unit=", strUnit,
		"name=", strName or "nil",
		"guid=", strGuid or "nil",
		"token=", tostring(frmModel._intApplyToken),
		"cam=", valCamera,
		"zoom=", valZoom,
		"dist=", valDistance,
		"mscale=", valModelScale,
		"bounds=", valBounds,
		"pos=", valPosition,
		"fileID=", valFileID,
		"file=", valFile,
		"DB(z,d)=", string.format("%.3f %.3f", fltDbZoom, fltDbDistance)
	)
end

local function SafeGetPosition()
	if not frmModel or not frmModel.GetPosition then return "n/a" end
	local blnOk, valA, valB, valC, valD = pcall(frmModel.GetPosition, frmModel)
	if not blnOk then return "ERR" end
	return string.format("%s,%s,%s,%s", tostring(valA), tostring(valB), tostring(valC), tostring(valD))
end

local function SafeGetFileID()
	if not frmModel or not frmModel.GetModelFileID then return "n/a" end
	local blnOk, valFileID = pcall(frmModel.GetModelFileID, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valFileID)
end

local function SafeGetModelFile()
	if not frmModel or not frmModel.GetModelFile then return "n/a" end
	local blnOk, valModelFile = pcall(frmModel.GetModelFile, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valModelFile)
end

local function SafeGetDisplayInfo()
	if not frmModel or not frmModel.GetDisplayInfo then return "n/a" end
	local blnOk, valDisplayInfo = pcall(frmModel.GetDisplayInfo, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valDisplayInfo)
end

local function SafeGetUnit()
	if not frmModel or not frmModel.GetUnit then return "n/a" end
	local blnOk, valUnit = pcall(frmModel.GetUnit, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valUnit)
end

local function DebugSnapshot(_strTag, _intToken)
	if (tonumber(intDebugModel) or 0) <= 0 then return end

	print("|cff00ff00DBG SNAP|r", _strTag,
		"token=", tostring(_intToken),
		"unit=", tostring(frmModel and frmModel._strDesiredUnit),
		"guid=", tostring(frmModel and frmModel._strDesiredGuid),
		"fileID=", SafeGetFileID(),
		"displayInfo=", SafeGetDisplayInfo(),
		"modelFile=", SafeGetModelFile(),
		"GetUnit()=", SafeGetUnit(),
		"pos=", SafeGetPosition(),
		"DBzoom=", tostring(GetModelZoom()),
		"DBdist=", tostring(GetCamDistance())
	)
end

local function PollModelIdentity(_intToken, _strLabel, _fltDuration, _fltInterval)
	if not (C_Timer and C_Timer.After) then return end
	_fltDuration = _fltDuration or 2.0
	_fltInterval = _fltInterval or 0.10

	local fltStartTime = GetTime and GetTime() or 0
	local strLastKey = nil

	local function Tick()
		if not frmModel then return end
		if frmModel._intApplyToken ~= _intToken then return end

		local fltNow = GetTime and GetTime() or 0
		if fltStartTime ~= 0 and (fltNow - fltStartTime) > _fltDuration then
			return
		end

		local strKey = SafeGetFileID() .. "|" .. SafeGetDisplayInfo() .. "|" .. SafeGetModelFile() .. "|" .. SafeGetUnit()

		if strKey ~= strLastKey then
			strLastKey = strKey
			DebugSnapshot(_strLabel, _intToken)
		end

		C_Timer.After(_fltInterval, Tick)
	end

	C_Timer.After(_fltInterval, Tick)
end

local function ApplyModelView()
	if not frmModel then return end

	if not frmModel._strDesiredUnit or not frmModel._intApplyToken then
		if (tonumber(intDebugModel) or 0) >= 1 then
			print("|cffffaa00DBG|r APPLY skipped (no desiredUnit/applyToken yet)")
		end
		return
	end

	DebugCall("Apply", "SetPortraitZoom", GetModelZoom())
	DebugCall("Apply", "SetCamDistanceScale", GetCamDistance())
end

local function ReapplyAfterDelay(_intToken, _fltDelay, _strLabel)
	if not C_Timer or not C_Timer.After then return end

	C_Timer.After(_fltDelay, function()
		if not frmModel then return end
		if frmModel._intApplyToken ~= _intToken then return end

		local strDesiredUnit = frmModel._strDesiredUnit
		if strDesiredUnit and frmModel._strDesiredGuid and UnitGUID(strDesiredUnit) ~= frmModel._strDesiredGuid then
			if (tonumber(intDebugModel) or 0) >= 1 then
				print("|cffff5555DBG|r Reapply IGNORE stale unit", _strLabel, "desired=", frmModel._strDesiredGuid, "current=", UnitGUID(strDesiredUnit))
			end
			return
		end

		if (tonumber(intDebugModel) or 0) >= 2 then
			print("|cff00ff00DBG|r Reapply", _strLabel, "delay=", _fltDelay, "token=", _intToken)
		end

		ApplyModelView()

		if (tonumber(intDebugModel) or 0) >= 2 then
			DebugSnapshot("After Reapply " .. _strLabel, _intToken)
		end
	end)
end

local function RequestApplyModelView()
	if blnApplyModelViewQueued then return end
	blnApplyModelViewQueued = true

	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			blnApplyModelViewQueued = false
			ApplyModelView()
		end)
	else
		blnApplyModelViewQueued = false
		ApplyModelView()
	end
end

local function ApplyModelViewOnceForToken(_intToken)
	if not frmModel then return end
	if not _intToken then return end

	if frmModel._intAppliedToken == _intToken then return end
	frmModel._intAppliedToken = _intToken

	ApplyModelView()
end

local function ForceSetModelUnit(_blnUseTarget)
	if not frmModel then return end

	if frmModel.ClearModel then
		frmModel:ClearModel()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if not frmModel then return end

			if _blnUseTarget and UnitExists("target") then
				frmModel:SetUnit("target")
			else
				frmModel:SetUnit("player")
			end
		end)
	else
		if _blnUseTarget and UnitExists("target") then
			frmModel:SetUnit("target")
		else
			frmModel:SetUnit("player")
		end
	end
end

local function Quantize(_valValue, _valStep, _intDecimals)
	_valValue = tonumber(_valValue) or 0
	if _valStep and _valStep > 0 then
		_valValue = math.floor((_valValue / _valStep) + 0.5) * _valStep
	end
	if _intDecimals and _intDecimals > 0 then
		local intPower = 10 ^ _intDecimals
		_valValue = math.floor((_valValue * intPower) + 0.5) / intPower
	end
	return _valValue
end

local function SliderChangedGuard(_frmSlider, _valValue, _valStep, _intDecimals)
	_valValue = tonumber(_valValue)
	if not _valValue then return nil end

	local valKey

	if _valStep and _valStep > 0 then
		valKey = math.floor((_valValue / _valStep) + 0.5)
		_valValue = valKey * _valStep
	elseif _intDecimals and _intDecimals > 0 then
		local intPower = 10 ^ _intDecimals
		valKey = math.floor((_valValue * intPower) + 0.5)
		_valValue = valKey / intPower
	else
		valKey = _valValue
	end

	if _frmSlider._valLastAppliedKey ~= nil and valKey == _frmSlider._valLastAppliedKey then
		return nil
	end

	_frmSlider._valLastAppliedKey = valKey
	return _valValue
end

--========================================================
-- Frame Sizing / Backdrop / Lock
--========================================================
local function UpdateResizeBounds()
	local intBorderWidth = GetBorderWidth()
	local intMinSize = math.max(intFrameMinBase, intBorderWidth * 3)
	frmMain:SetResizeBounds(intMinSize, intMinSize, intFrameMax, intFrameMax)
end

local function ApplyBackdrop()
	local strEdgeFile, strBgFile = FetchMedia()
	local intBorderWidth = GetBorderWidth()

	UpdateResizeBounds()

	local intPad = intBorderWidth
	local intWidth, intHeight = frmMain:GetSize()
	local intMaxPad = math.floor(math.min(intWidth, intHeight) / 2) - 1
	if intMaxPad < 0 then intMaxPad = 0 end
	if intPad > intMaxPad then intPad = intMaxPad end

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
		insets = { left = intPad, right = intPad, top = intPad, bottom = intPad }
	})

	local fltRed, fltGreen, fltBlue, fltAlpha = GetBorderColor()
	frmBorder:SetBackdropBorderColor(fltRed, fltGreen, fltBlue, fltAlpha)

	frmModel:ClearAllPoints()
	frmModel:SetPoint("TOPLEFT", frmMain, "TOPLEFT", intPad, -intPad)
	frmModel:SetPoint("BOTTOMRIGHT", frmMain, "BOTTOMRIGHT", -intPad, intPad)

	frmModel:SetFrameLevel(frmMain:GetFrameLevel() + 1)
	frmBorder:SetFrameLevel(frmMain:GetFrameLevel() + 20)

	if frmResizeButton then
		frmResizeButton:SetFrameLevel(frmBorder:GetFrameLevel() + 10)
	end
end

local function ApplyLockState()
	local blnLocked = GetDB() and GetDB().locked

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
			frmResizeButton:SetFrameLevel(frmBorder:GetFrameLevel() + 10)
		end
	end
end

--========================================================
-- Frame Creation / Interaction Wiring
--========================================================
local function CreateMainFrame()
	frmMain = CreateFrame("Frame", "MalitorsPortraitFrameMainFrame", UIParent, "BackdropTemplate")
	frmMain:SetPoint(tblDefaults.point, UIParent, tblDefaults.relativePoint, tblDefaults.x, tblDefaults.y)
	frmMain:SetSize(tblDefaults.width, tblDefaults.height)

	frmMain:SetMovable(true)
	frmMain:SetResizable(true)
	frmMain:SetClampedToScreen(true)

	frmMain:EnableMouse(true)
	frmMain:RegisterForDrag("LeftButton")

	frmMain:SetFrameStrata("MEDIUM")
end

local function CreateBorderOverlay()
	frmBorder = CreateFrame("Frame", nil, frmMain, "BackdropTemplate")
	frmBorder:SetAllPoints(frmMain)
	frmBorder:EnableMouse(false)
	frmBorder:SetFrameLevel(frmMain:GetFrameLevel() + 20)
	frmBorder:SetFrameStrata(frmMain:GetFrameStrata())
end

local function CreateModel()
	frmModel = CreateFrame("PlayerModel", nil, frmMain)
	frmModel:SetFrameStrata(frmMain:GetFrameStrata())

	frmModel._blnNeedsHardReset = false
	frmModel._blnLastUseTarget = nil

	if frmModel.SetCamera then
		frmModel:SetCamera(1)
	end
	blnModelCameraInitialized = true

	frmModel._blnPendingApply = true

	frmModel:SetScript("OnModelLoaded", function()
		if not frmModel then return end
		if not frmModel._intApplyToken then return end

		frmModel._intModelLoadedToken = frmModel._intApplyToken

		DebugSnapshot("OnModelLoaded (pre-apply)", frmModel._intApplyToken)

		local strDesiredUnit = frmModel._strDesiredUnit
		if strDesiredUnit and frmModel._strDesiredGuid and UnitGUID(strDesiredUnit) ~= frmModel._strDesiredGuid then
			print("|cffff5555DBG|r OnModelLoaded IGNORE stale load", "desired=", frmModel._strDesiredGuid, "current=", UnitGUID(strDesiredUnit))
			return
		end

		if frmModel._blnNeedsHardReset then
			DebugCall("Apply", "SetPosition", 0, 0, 0)
			frmModel._blnNeedsHardReset = false
		end

		ApplyModelViewOnceForToken(frmModel._intApplyToken)

		ReapplyAfterDelay(frmModel._intApplyToken, 0.03, "postLoad0.03")
		ReapplyAfterDelay(frmModel._intApplyToken, 0.10, "postLoad0.10")
	end)

	frmModel._fnKickApplyPipeline = function(_intToken)
		if not frmModel then return end
		if not _intToken then return end

		if frmModel._intModelLoadedToken == _intToken then
			if intDebugModel then
				print("|cffffaa00DBG|r KickApplyPipeline skip (OnModelLoaded already fired) token=", _intToken)
			end
			return
		end

		if C_Timer and C_Timer.After then
			C_Timer.After(0.05, function()
				if not frmModel then return end
				if frmModel._intApplyToken ~= _intToken then return end

				if frmModel._intModelLoadedToken == _intToken then return end

				if frmModel._blnNeedsHardReset then
					DebugCall("Apply", "SetPosition", 0, 0, 0)
					frmModel._blnNeedsHardReset = false
				end

				ApplyModelViewOnceForToken(_intToken)
				ReapplyAfterDelay(_intToken, 0.15, "postSet0.15")
			end)
		end
	end
end

local function CreateResizeGrip()
	frmResizeButton = CreateFrame("Button", nil, frmMain)
	frmResizeButton:SetSize(16, 16)
	frmResizeButton:SetPoint("BOTTOMRIGHT", -5, 5)
	frmResizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	frmResizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	frmResizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	frmResizeButton:SetFrameLevel(frmBorder:GetFrameLevel() + 10)

	frmResizeButton:SetScript("OnMouseDown", function(_frmSelf, _strButton)
		if _strButton == "LeftButton" then
			if GetDB() and GetDB().locked then return end
			frmMain:StartSizing("BOTTOMRIGHT")
			frmMain:SetUserPlaced(true)
		end
	end)

	frmResizeButton:SetScript("OnMouseUp", function(_frmSelf, _strButton)
		frmMain:StopMovingOrSizing()
		GetDB().width = frmMain:GetWidth()
		GetDB().height = frmMain:GetHeight()
		ApplyBackdrop()
	end)
end

local function WireFrameInteraction()
	frmMain:SetScript("OnDragStart", function(_frmSelf)
		if GetDB() and GetDB().locked then return end
		_frmSelf:StartMoving()
	end)

	frmMain:SetScript("OnDragStop", function(_frmSelf)
		_frmSelf:StopMovingOrSizing()
		local strPoint, _, strRelativePoint, intX, intY = _frmSelf:GetPoint()
		GetDB().point = strPoint
		GetDB().relativePoint = strRelativePoint
		GetDB().x = intX
		GetDB().y = intY
	end)
end

local function ApplySavedLayout()
	frmMain:ClearAllPoints()
	frmMain:SetPoint(GetDB().point, UIParent, GetDB().relativePoint, GetDB().x, GetDB().y)
	frmMain:SetSize(GetDB().width or tblDefaults.width, GetDB().height or tblDefaults.height)
end

--========================================================
-- Options Panel (Blizzard Settings)
--========================================================
local function EnsureBlizzardDropdownAPI()
	if UIDropDownMenu_Initialize ~= nil then return end

	if UIParentLoadAddOn then
		UIParentLoadAddOn("Blizzard_SharedXML")
	end
	if UIDropDownMenu_Initialize == nil and LoadAddOn then
		LoadAddOn("Blizzard_SharedXML")
	end
end

local function AttachNumericBoxToSlider(_frmSlider, _tblOptions)
	local frmBox = CreateFrame("EditBox", nil, _frmSlider:GetParent(), "InputBoxTemplate")
	frmBox:SetAutoFocus(false)
	frmBox:SetSize(_tblOptions.width or 50, 20)

	local frmAnchor = _tblOptions.anchorFrame or _frmSlider
	frmBox:SetPoint("LEFT", frmAnchor, "RIGHT", 16, 0)

	frmBox:SetFontObject("GameFontHighlightSmall")
	frmBox:SetTextColor(1, 1, 1, 1)
	frmBox:SetJustifyH("RIGHT")
	frmBox:SetTextInsets(4, 4, 0, 0)

	if not _tblOptions.decimals or _tblOptions.decimals <= 0 then
		frmBox:SetNumeric(true)
	end

	local function ClampLocal(_valValue)
		return Clamp(_valValue, _tblOptions.min, _tblOptions.max)
	end

	local function RoundToStep(_valValue)
		if not _tblOptions.step or _tblOptions.step <= 0 then return _valValue end
		return math.floor((_valValue / _tblOptions.step) + 0.5) * _tblOptions.step
	end

	local function FormatValue(_valValue)
		if _tblOptions.decimals and _tblOptions.decimals > 0 then
			return string.format("%." .. _tblOptions.decimals .. "f", _valValue)
		end
		return tostring(math.floor(_valValue + 0.5))
	end

	_frmSlider._blnSuppressOnValueChanged = false

	local function ApplyFromBox()
		local strText = frmBox:GetText()
		strText = (strText or ""):gsub(",", "."):gsub("%s+", "")
		local valValue = tonumber(strText)

		if not valValue then
			frmBox:SetText(FormatValue(_tblOptions.get()))
			frmBox:HighlightText(0, 0)
			return
		end

		valValue = ClampLocal(valValue)
		valValue = RoundToStep(valValue)

		_frmSlider._blnSuppressOnValueChanged = true
		_frmSlider:SetValue(valValue)
		_frmSlider._blnSuppressOnValueChanged = false

		_tblOptions.set(valValue)

		frmBox:SetText(FormatValue(valValue))
		frmBox:HighlightText(0, 0)
	end

	frmBox._blnJustApplied = false

	frmBox:SetScript("OnEnterPressed", function(_frmSelf)
		frmBox._blnJustApplied = true
		ApplyFromBox()
		_frmSelf:ClearFocus()
	end)

	frmBox:SetScript("OnEscapePressed", function(_frmSelf)
		_frmSelf:SetText(FormatValue(_tblOptions.get()))
		_frmSelf:HighlightText(0, 0)
		_frmSelf:ClearFocus()
	end)

	frmBox:SetScript("OnEditFocusLost", function()
		if frmBox._blnJustApplied then
			frmBox._blnJustApplied = false
			return
		end

		ApplyFromBox()
	end)

	_frmSlider._frmNumericBox = frmBox
	_frmSlider._fnNumericBoxFormat = FormatValue
	_frmSlider._fnNumericBoxRefresh = function()
		local valValue = _tblOptions.get()
		if valValue == nil then return end

		if (not _tblOptions.decimals or _tblOptions.decimals <= 0) and frmBox.SetNumber then
			frmBox:SetNumber(math.floor(valValue + 0.5))
		else
			frmBox:SetText(FormatValue(valValue))
		end
	end

	frmBox:HookScript("OnShow", function()
		if _frmSlider._fnNumericBoxRefresh then
			_frmSlider._fnNumericBoxRefresh()
		end

		local strText = frmBox:GetText()
		frmBox:SetText("")
		frmBox:SetText(strText or "")
		frmBox:SetCursorPosition(0)
	end)

	_frmSlider:HookScript("OnShow", function()
		if _frmSlider._fnNumericBoxRefresh then
			_frmSlider._fnNumericBoxRefresh()
		end
	end)

	if _frmSlider._fnNumericBoxRefresh then
		_frmSlider._fnNumericBoxRefresh()
	end

	return frmBox
end

local function OpenBorderColorPicker(_fnApplyColor)
	local tblBorderColor = GetDB().borderColor or tblDefaults.borderColor
	local fltRed, fltGreen, fltBlue, fltAlpha = tblBorderColor.r or 1, tblBorderColor.g or 1, tblBorderColor.b or 1, tblBorderColor.a or 1

	local function GetOpacitySlider()
		if ColorPickerFrame and ColorPickerFrame.Content and ColorPickerFrame.Content.OpacitySlider then
			return ColorPickerFrame.Content.OpacitySlider
		end
		if OpacitySliderFrame then
			return OpacitySliderFrame
		end
		return nil
	end

	local function GetPickedAlpha(_fltFallbackAlpha)
		if ColorPickerFrame and ColorPickerFrame.GetColorAlpha then
			local fltPickedAlpha = ColorPickerFrame:GetColorAlpha()
			if type(fltPickedAlpha) == "number" then
				return fltPickedAlpha
			end
		end

		local frmOpacitySlider = GetOpacitySlider()
		if frmOpacitySlider and frmOpacitySlider.GetValue then
			local fltOpacity = frmOpacitySlider:GetValue()
			if type(fltOpacity) == "number" then
				return 1 - fltOpacity
			end
		end

		if ColorPickerFrame and type(ColorPickerFrame.opacity) == "number" then
			return 1 - ColorPickerFrame.opacity
		end

		return _fltFallbackAlpha or 1
	end

	local tblPrevColor = { r = fltRed, g = fltGreen, b = fltBlue, a = fltAlpha }

	local tblInfo = {}
	tblInfo.r, tblInfo.g, tblInfo.b = fltRed, fltGreen, fltBlue
	tblInfo.hasOpacity = true
	tblInfo.opacity = fltAlpha

	tblInfo.swatchFunc = function()
		local fltNewRed, fltNewGreen, fltNewBlue = ColorPickerFrame:GetColorRGB()
		local fltNewAlpha = GetPickedAlpha(fltAlpha)
		_fnApplyColor(fltNewRed, fltNewGreen, fltNewBlue, fltNewAlpha)
	end

	tblInfo.opacityFunc = function(_fltOpacity)
		local fltNewRed, fltNewGreen, fltNewBlue = ColorPickerFrame:GetColorRGB()
		local fltNewAlpha
		if type(_fltOpacity) == "number" then
			fltNewAlpha = 1 - _fltOpacity
		else
			fltNewAlpha = GetPickedAlpha(fltAlpha)
		end
		_fnApplyColor(fltNewRed, fltNewGreen, fltNewBlue, fltNewAlpha)
	end

	tblInfo.cancelFunc = function()
		_fnApplyColor(tblPrevColor.r, tblPrevColor.g, tblPrevColor.b, tblPrevColor.a)
	end

	ColorPickerFrame:SetupColorPickerAndShow(tblInfo)
end

local function RegisterSettingsPanel(_frmPanel)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		objMalitorsPortraitFrameSettingsCategory = Settings.RegisterCanvasLayoutCategory(_frmPanel, _frmPanel.name)
		Settings.RegisterAddOnCategory(objMalitorsPortraitFrameSettingsCategory)

		if objMalitorsPortraitFrameSettingsCategory then
			if objMalitorsPortraitFrameSettingsCategory.GetID then
				intMalitorsPortraitFrameSettingsCategoryID = objMalitorsPortraitFrameSettingsCategory:GetID()
			elseif objMalitorsPortraitFrameSettingsCategory.ID then
				intMalitorsPortraitFrameSettingsCategoryID = objMalitorsPortraitFrameSettingsCategory.ID
			elseif objMalitorsPortraitFrameSettingsCategory.categoryID then
				intMalitorsPortraitFrameSettingsCategoryID = objMalitorsPortraitFrameSettingsCategory.categoryID
			end
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(_frmPanel)
	end
end

local function CreateOptionsPanel()
	if MalitorsPortraitFrameOptionsPanel then return end

	local function CreateGroupBox(_frmParent, _strTitleText, _objTopLeftAnchor, _objBottomRightAnchor, _intPadLeft, _intPadTop, _intPadRight, _intPadBottom)
		local frmGroupBox = CreateFrame("Frame", nil, _frmParent, "BackdropTemplate")
		frmGroupBox:SetPoint("TOPLEFT", _objTopLeftAnchor, "TOPLEFT", -(_intPadLeft or 12), (_intPadTop or 10))
		frmGroupBox:SetPoint("BOTTOMRIGHT", _objBottomRightAnchor, "BOTTOMRIGHT", (_intPadRight or 12), -(_intPadBottom or 12))

		frmGroupBox:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frmGroupBox:SetBackdropColor(0, 0, 0, 0.25)
		frmGroupBox:SetFrameLevel(_frmParent:GetFrameLevel())

		local objLabel = frmGroupBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		objLabel:SetText(_strTitleText or "")
		objLabel:SetPoint("TOPLEFT", frmGroupBox, "TOPLEFT", 10, 16)
		objLabel:SetDrawLayer("OVERLAY")

		return frmGroupBox
	end

	local frmPanel = CreateFrame("Frame", "MalitorsPortraitFrameOptionsPanel", UIParent)
	frmPanel.name = "Malitor's Portrait Frame"

	EnsureBlizzardDropdownAPI()

	local objTitle = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	objTitle:SetPoint("TOPLEFT", 16, -16)
	objTitle:SetText("Malitor's Portrait Frame")

	local objSubtitle = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	objSubtitle:SetPoint("TOPLEFT", objTitle, "BOTTOMLEFT", 0, -8)
	objSubtitle:SetJustifyH("LEFT")
	objSubtitle:SetText("Customize the portrait frame border, size, and scale.\nAdjust 3D portrait camera zoom and distance.")

	local frmLockCheck = CreateFrame("CheckButton", nil, frmPanel, "UICheckButtonTemplate")
	frmLockCheck:SetPoint("TOPLEFT", objSubtitle, "BOTTOMLEFT", 0, -14)
	frmLockCheck:SetScript("OnClick", function(_frmSelf)
		GetDB().locked = _frmSelf:GetChecked() and true or false
		ApplyLockState()
	end)

	local objLockText = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	objLockText:SetPoint("LEFT", frmLockCheck, "RIGHT", 4, 1)
	objLockText:SetText("Lock")

	local frmBorderDropDown = CreateFrame("Frame", "MalitorsPortraitFrameBorderDropDown", frmPanel, "UIDropDownMenuTemplate")
	frmBorderDropDown:SetPoint("TOPLEFT", frmLockCheck, "BOTTOMLEFT", 0, -36)
	UIDropDownMenu_SetWidth(frmBorderDropDown, 260)

	local function RefreshBorderDropdown()
		local strBorderText = (GetDB() and GetDB().border) or tblDefaults.border
		UIDropDownMenu_SetText(frmBorderDropDown, strBorderText or "Unknown")
	end

	local function Border_OnClick(_objSelfArg)
		GetDB().border = _objSelfArg.value
		ApplyBackdrop()
		RefreshBorderDropdown()
	end

	UIDropDownMenu_Initialize(frmBorderDropDown, function()
		if not objLSM then
			local tblInfo = UIDropDownMenu_CreateInfo()
			tblInfo.text = "LibSharedMedia-3.0 not found"
			tblInfo.notCheckable = true
			tblInfo.isTitle = true
			UIDropDownMenu_AddButton(tblInfo)
			return
		end

		local strCurrentBorder = GetDB().border
		local tblBorderList = objLSM:List("border")
		table.sort(tblBorderList)

		for _, strName in ipairs(tblBorderList) do
			local tblInfo = UIDropDownMenu_CreateInfo()
			tblInfo.text = strName
			tblInfo.value = strName
			tblInfo.func = Border_OnClick
			tblInfo.checked = (strName == strCurrentBorder)
			UIDropDownMenu_AddButton(tblInfo)
		end
	end)

	local frmBorderColorSwatch = CreateFrame("Button", nil, frmPanel)
	frmBorderColorSwatch:SetSize(18, 18)
	frmBorderColorSwatch:SetPoint("TOPLEFT", frmBorderDropDown, "TOPRIGHT", 0, -4)

	frmBorderColorSwatch.border = frmBorderColorSwatch:CreateTexture(nil, "BORDER")
	frmBorderColorSwatch.border:SetAllPoints()
	frmBorderColorSwatch.border:SetColorTexture(0, 0, 0, 1)

	frmBorderColorSwatch.color = frmBorderColorSwatch:CreateTexture(nil, "ARTWORK")
	frmBorderColorSwatch.color:SetPoint("TOPLEFT", 1, -1)
	frmBorderColorSwatch.color:SetPoint("BOTTOMRIGHT", -1, 1)

	local objBorderColorLabel = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	objBorderColorLabel:SetPoint("TOPLEFT", frmBorderColorSwatch, "TOPRIGHT", 6, -2)
	objBorderColorLabel:SetText("Border Color")

	local function UpdateBorderColorSwatch()
		local fltRed, fltGreen, fltBlue, fltAlpha = GetBorderColor()
		frmBorderColorSwatch.color:SetColorTexture(fltRed, fltGreen, fltBlue, fltAlpha)
	end

	frmBorderColorSwatch:SetScript("OnClick", function()
		OpenBorderColorPicker(function(_fltNewRed, _fltNewGreen, _fltNewBlue, _fltNewAlpha)
			GetDB().borderColor = GetDB().borderColor or {}
			GetDB().borderColor.r = _fltNewRed
			GetDB().borderColor.g = _fltNewGreen
			GetDB().borderColor.b = _fltNewBlue
			GetDB().borderColor.a = _fltNewAlpha
			ApplyBackdrop()
			UpdateBorderColorSwatch()
		end)
	end)

	frmBorderColorSwatch:SetScript("OnEnter", function(_frmSelf)
		GameTooltip:SetOwner(_frmSelf, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Border Color", 1, 1, 1)
		GameTooltip:AddLine("Click to choose color (with alpha).", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)

	frmBorderColorSwatch:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local frmBorderWidthSlider = CreateFrame("Slider", "MalitorsPortraitFrameBorderWidthSlider", frmPanel, "OptionsSliderTemplate")
	frmBorderWidthSlider:SetPoint("TOPLEFT", frmBorderDropDown, "BOTTOMLEFT", 50, -26)
	frmBorderWidthSlider:SetWidth(160)
	frmBorderWidthSlider:SetMinMaxValues(intBorderMin, intBorderMax)
	frmBorderWidthSlider:SetValueStep(1)
	frmBorderWidthSlider:SetObeyStepOnDrag(true)
	_G[frmBorderWidthSlider:GetName() .. "Low"]:SetText(tostring(intBorderMin))
	_G[frmBorderWidthSlider:GetName() .. "High"]:SetText(tostring(intBorderMax))
	_G[frmBorderWidthSlider:GetName() .. "Text"]:SetText("Border Width")

	local frmBorderWidthMinus = CreateFrame("Button", nil, frmPanel, "UIPanelButtonTemplate")
	frmBorderWidthMinus:SetSize(22, 22)
	frmBorderWidthMinus:SetText("-")
	frmBorderWidthMinus:SetPoint("RIGHT", frmBorderWidthSlider, "LEFT", -6, 0)

	local frmBorderWidthPlus = CreateFrame("Button", nil, frmPanel, "UIPanelButtonTemplate")
	frmBorderWidthPlus:SetSize(22, 22)
	frmBorderWidthPlus:SetText("+")
	frmBorderWidthPlus:SetPoint("LEFT", frmBorderWidthSlider, "RIGHT", 6, 0)

	frmBorderWidthMinus:SetScript("OnClick", function()
		frmBorderWidthSlider:SetValue(Clamp((frmBorderWidthSlider:GetValue() or intBorderMin) - 1, intBorderMin, intBorderMax))
	end)

	frmBorderWidthPlus:SetScript("OnClick", function()
		frmBorderWidthSlider:SetValue(Clamp((frmBorderWidthSlider:GetValue() or intBorderMin) + 1, intBorderMin, intBorderMax))
	end)

	frmBorderWidthSlider:SetScript("OnValueChanged", function(_frmSelf, _valValue)
		if _frmSelf._blnSuppressOnValueChanged then return end

		_valValue = SliderChangedGuard(_frmSelf, _valValue, 1, 0)
		if _valValue == nil then return end

		_valValue = Clamp(Round(_valValue), intBorderMin, intBorderMax)
		GetDB().borderWidth = _valValue
		ApplyBackdrop()

		if _frmSelf._frmNumericBox then
			if _frmSelf._frmNumericBox.SetNumber then
				_frmSelf._frmNumericBox:SetNumber(_valValue)
			else
				_frmSelf._frmNumericBox:SetText(_frmSelf._fnNumericBoxFormat(_valValue))
			end
		end
	end)

	AttachNumericBoxToSlider(frmBorderWidthSlider, {
		anchorFrame = frmBorderWidthPlus,
		width = 30,
		decimals = 0,
		min = intBorderMin,
		max = intBorderMax,
		step = 1,
		get = function()
			return GetBorderWidth()
		end,
		set = function(_valValue)
			GetDB().borderWidth = Clamp(Round(_valValue), intBorderMin, intBorderMax)
			ApplyBackdrop()
		end,
	})

	local frmBorderGroupBox = CreateGroupBox(
		frmPanel,
		"Border",
		frmBorderDropDown,
		frmBorderWidthSlider,
		0, 16, 226, 26
	)

	local frmModelZoomSlider = CreateFrame("Slider", "MalitorsPortraitFrameModelZoomSlider", frmPanel, "OptionsSliderTemplate")
	frmModelZoomSlider:SetPoint("TOPLEFT", frmBorderGroupBox, "BOTTOMLEFT", 22, -56)
	frmModelZoomSlider:SetWidth(150)
	frmModelZoomSlider:SetMinMaxValues(fltZoomMin, fltZoomMax)
	frmModelZoomSlider:SetValueStep(0.1)
	frmModelZoomSlider:SetObeyStepOnDrag(true)
	_G[frmModelZoomSlider:GetName() .. "Low"]:SetText(string.format("%.2f", fltZoomMin))
	_G[frmModelZoomSlider:GetName() .. "High"]:SetText(string.format("%.2f", fltZoomMax))
	_G[frmModelZoomSlider:GetName() .. "Text"]:SetText("Model Zoom")

	frmModelZoomSlider:SetScript("OnValueChanged", function(_frmSelf, _valValue)
		if _frmSelf._blnSuppressOnValueChanged then return end

		_valValue = SliderChangedGuard(_frmSelf, _valValue, 0.1, 2)
		if _valValue == nil then return end

		_valValue = Clamp(tonumber(_valValue) or tblDefaults.modelZoom, fltZoomMin, fltZoomMax)
		GetDB().modelZoom = _valValue
		RequestApplyModelView()

		if _frmSelf._frmNumericBox then
			_frmSelf._frmNumericBox:SetText(_frmSelf._fnNumericBoxFormat(_valValue))
			_frmSelf._frmNumericBox:HighlightText(0, 0)
		end
	end)

	AttachNumericBoxToSlider(frmModelZoomSlider, {
		width = 36,
		decimals = 2,
		min = fltZoomMin,
		max = fltZoomMax,
		step = 0.01,
		get = function()
			return GetModelZoom()
		end,
		set = function(_valValue)
			GetDB().modelZoom = Clamp(tonumber(_valValue) or tblDefaults.modelZoom, fltZoomMin, fltZoomMax)
			RequestApplyModelView()
		end,
	})

	local frmCamDistanceSlider = CreateFrame("Slider", "MalitorsPortraitFrameCamDistanceSlider", frmPanel, "OptionsSliderTemplate")
	frmCamDistanceSlider:SetPoint("TOPLEFT", frmModelZoomSlider, "TOPRIGHT", 80, 0)
	frmCamDistanceSlider:SetWidth(150)
	frmCamDistanceSlider:SetMinMaxValues(fltCamMin, fltCamMax)
	frmCamDistanceSlider:SetValueStep(0.1)
	frmCamDistanceSlider:SetObeyStepOnDrag(true)
	_G[frmCamDistanceSlider:GetName() .. "Low"]:SetText(string.format("%.2f", fltCamMin))
	_G[frmCamDistanceSlider:GetName() .. "High"]:SetText(string.format("%.2f", fltCamMax))
	_G[frmCamDistanceSlider:GetName() .. "Text"]:SetText("Camera Distance")

	frmCamDistanceSlider:SetScript("OnValueChanged", function(_frmSelf, _valValue)
		if _frmSelf._blnSuppressOnValueChanged then return end

		_valValue = SliderChangedGuard(_frmSelf, _valValue, 0.1, 2)
		if _valValue == nil then return end

		_valValue = Clamp(tonumber(_valValue) or tblDefaults.camDistance, fltCamMin, fltCamMax)
		GetDB().camDistance = _valValue
		RequestApplyModelView()

		if _frmSelf._frmNumericBox then
			_frmSelf._frmNumericBox:SetText(_frmSelf._fnNumericBoxFormat(_valValue))
			_frmSelf._frmNumericBox:HighlightText(0, 0)
		end
	end)

	AttachNumericBoxToSlider(frmCamDistanceSlider, {
		width = 36,
		decimals = 2,
		min = fltCamMin,
		max = fltCamMax,
		step = 0.01,
		get = function()
			return GetCamDistance()
		end,
		set = function(_valValue)
			GetDB().camDistance = Clamp(tonumber(_valValue) or tblDefaults.camDistance, fltCamMin, fltCamMax)
			RequestApplyModelView()
		end,
	})

	local frmModelGroupBox = CreateGroupBox(
		frmPanel,
		"Character Model",
		frmModelZoomSlider,
		frmCamDistanceSlider,
		22, 26, 75, 26
	)

	local function RefreshOptionsControls()
		frmLockCheck:SetChecked(GetDB() and GetDB().locked)

		RefreshBorderDropdown()
		frmBorderWidthSlider:SetValue(GetBorderWidth())

		if frmBorderWidthSlider._fnNumericBoxRefresh then frmBorderWidthSlider._fnNumericBoxRefresh() end
		UpdateBorderColorSwatch()

		frmModelZoomSlider:SetValue(GetModelZoom())
		frmCamDistanceSlider:SetValue(GetCamDistance())

		if frmModelZoomSlider._fnNumericBoxRefresh then frmModelZoomSlider._fnNumericBoxRefresh() end
		if frmCamDistanceSlider._fnNumericBoxRefresh then frmCamDistanceSlider._fnNumericBoxRefresh() end
	end

	local frmResetButton = CreateFrame("Button", nil, frmPanel, "UIPanelButtonTemplate")
	frmResetButton:SetSize(120, 22)
	frmResetButton:SetPoint("TOPLEFT", frmLockCheck, "TOPRIGHT", 86, -4)
	frmResetButton:SetText("Reset")

	frmResetButton:SetScript("OnClick", function()
		frmMain:ClearAllPoints()
		frmMain:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		frmMain:SetSize(200, 200)

		MalitorsPortraitFrameDB = CopyTable(tblDefaults)
		MalitorsPortraitFrameDB.borderColor = CopyTable(tblDefaults.borderColor)

		ApplyBackdrop()
		ApplyLockState()
		RequestApplyModelView()
		RefreshOptionsControls()

		print("|cFF00FF00MalitorsPortraitFrame|r reset.")
	end)

	frmPanel:HookScript("OnShow", function()
		RefreshOptionsControls()

		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				RefreshOptionsControls()
			end)
		end
	end)

	RefreshOptionsControls()
	RegisterSettingsPanel(frmPanel)
end

--========================================================
-- Slash Commands
--========================================================
SLASH_MALITORSPORTRAITFRAME1 = "/malpf"
SLASH_MALITORSPORTRAITFRAME2 = "/malitorsportraitframe"

SlashCmdList["MALITORSPORTRAITFRAME"] = function(_strMessage)
	_strMessage = (_strMessage or ""):trim()
	local strLowerMessage = _strMessage:lower()

	CreateOptionsPanel()

	if strLowerMessage:match("^debug") then
		local strArg = strLowerMessage:match("^debug%s*(.*)$")
		strArg = (strArg or ""):gsub("^%s+", ""):gsub("%s+$", "")

		local intCurrentLevel = (GetDB() and tonumber(GetDB().debugLevel)) or (tonumber(intDebugModel) or 0)
		if intCurrentLevel < 0 then intCurrentLevel = 0 end
		if intCurrentLevel > 2 then intCurrentLevel = 2 end

		if strArg == "" then
			print(string.format("|cFF00FF00MalitorsPortraitFrame|r Debug level is %d (0=off, 1=events, 2=verbose)", intCurrentLevel))
			return
		end

		local intNewLevel = intCurrentLevel
		if strArg == "on" then
			intNewLevel = 1
		elseif strArg == "off" then
			intNewLevel = 0
		elseif strArg == "verbose" then
			intNewLevel = 2
		elseif strArg == "quiet" then
			intNewLevel = 0
		else
			local intParsedLevel = tonumber(strArg)
			if intParsedLevel ~= nil then
				intNewLevel = intParsedLevel
			else
				print("|cFFFF5555MalitorsPortraitFrame|r Debug usage:")
				print(" /malpf debug            (show current)")
				print(" /malpf debug on|off")
				print(" /malpf debug 0|1|2")
				print(" /malpf debug verbose    (2)")
				print(" /malpf debug quiet      (0)")
				return
			end
		end

		if intNewLevel < 0 then intNewLevel = 0 end
		if intNewLevel > 2 then intNewLevel = 2 end

		intDebugModel = intNewLevel
		if GetDB() then
			GetDB().debugLevel = intNewLevel
		end

		print(string.format("|cFF00FF00MalitorsPortraitFrame|r Debug level set to %d (0=off, 1=events, 2=verbose)", intNewLevel))
		return
	end

	if strLowerMessage == "" or strLowerMessage == "options" or strLowerMessage == "config" or strLowerMessage == "settings" then
		if Settings then
			if intMalitorsPortraitFrameSettingsCategoryID and type(intMalitorsPortraitFrameSettingsCategoryID) == "number" then
				if Settings.OpenToCategory then
					Settings.OpenToCategory(intMalitorsPortraitFrameSettingsCategoryID)
					return
				end
				if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
					C_SettingsUtil.OpenSettingsPanel(intMalitorsPortraitFrameSettingsCategoryID)
					return
				end
			end

			if Settings.OpenToCategory and objMalitorsPortraitFrameSettingsCategory then
				local blnOk = pcall(Settings.OpenToCategory, objMalitorsPortraitFrameSettingsCategory)
				if blnOk then return end
			end
		end

		if InterfaceOptionsFrame_OpenToCategory then
			InterfaceOptionsFrame_OpenToCategory("Malitor's Portrait Frame")
			InterfaceOptionsFrame_OpenToCategory("Malitor's Portrait Frame")
			return
		end

		print("|cFFFF5555MalitorsPortraitFrame|r Could not open options (no supported Settings UI found).")
		return
	end

	print("|cFF00FF00MalitorsPortraitFrame|r Commands:")
	print(" /malpf                 - open options")
	print(" /malpf options         - open options")
	print(" /malpf debug           - show debug level")
	print(" /malpf debug 0|1|2     - set debug level")
	print(" /malpf debug on|off    - set debug level to 1/0")
	print(" /malpf debug verbose   - set debug level to 2")
end

--========================================================
-- Events
--========================================================
local function OnAddonLoaded()
	EnsureDB()
	ApplySavedLayout()
	ApplyBackdrop()
	CreateOptionsPanel()
	ApplyLockState()
end

local function OnTargetChanged()
	intModelApplyToken = intModelApplyToken + 1
	frmModel._intApplyToken = intModelApplyToken
	local intMyToken = frmModel._intApplyToken

	local blnUseTarget = UnitExists("target") and true or false
	local strDesiredUnit = blnUseTarget and "target" or "player"

	frmModel._strDesiredUnit = strDesiredUnit
	frmModel._strDesiredGuid = UnitGUID(strDesiredUnit)

	if frmModel._strLastUnit ~= strDesiredUnit then
		frmModel._blnNeedsHardReset = true
	end
	frmModel._strLastUnit = strDesiredUnit

	ForceSetModelUnit(blnUseTarget)
	DebugSnapshot("TargetChanged POST SetUnit (immediate)", intMyToken)
end

local function OnEnteringWorld()
	intModelApplyToken = intModelApplyToken + 1
	frmModel._intApplyToken = intModelApplyToken
	local intMyToken = frmModel._intApplyToken

	local strDesiredUnit = "player"
	frmModel._strDesiredUnit = strDesiredUnit
	frmModel._strDesiredGuid = UnitGUID(strDesiredUnit)

	if frmModel._strLastUnit ~= strDesiredUnit then
		frmModel._blnNeedsHardReset = true
	end
	frmModel._strLastUnit = strDesiredUnit

	ForceSetModelUnit(false)
	DebugSnapshot("EnteringWorld POST SetUnit (immediate)", intMyToken)

	if frmModel and frmModel._fnKickApplyPipeline then
		frmModel._fnKickApplyPipeline(intMyToken)
	end
end

local function OnEvent(_frmSelf, _strEvent, _valArg1)
	if _strEvent == "ADDON_LOADED" and _valArg1 == strAddonName then
		OnAddonLoaded()
	elseif _strEvent == "PLAYER_TARGET_CHANGED" then
		OnTargetChanged()
	elseif _strEvent == "PLAYER_ENTERING_WORLD" then
		OnEnteringWorld()
	end
end

--========================================================
-- Boot
--========================================================
CreateMainFrame()
CreateBorderOverlay()
CreateModel()
CreateResizeGrip()
WireFrameInteraction()

ApplyBackdrop()

frmMain:RegisterEvent("ADDON_LOADED")
frmMain:RegisterEvent("PLAYER_TARGET_CHANGED")
frmMain:RegisterEvent("PLAYER_ENTERING_WORLD")
frmMain:SetScript("OnEvent", OnEvent)

