local strAddonName, tblNamespace = ...

local tblConstants = tblNamespace.Constants
local tblHelpers = tblNamespace.Helpers
local tblState = tblNamespace.State

--========================================================
-- Helpers
--========================================================
function tblHelpers.Clamp(_valValue, _valMin, _valMax)
	if _valValue < _valMin then return _valMin end
	if _valValue > _valMax then return _valMax end
	return _valValue
end

function tblHelpers.Round(_valValue)
	return math.floor((_valValue or 0) + 0.5)
end

function tblHelpers.GetDB()
	if not tblNamespace.objDatabase then
		return nil
	end

	return tblNamespace.objDatabase.profile
end

function tblHelpers.SyncDebugLevelFromProfile()
	local tblProfile = tblHelpers.GetDB()
	local intDebugLevel = (tblProfile and tonumber(tblProfile.debugLevel)) or tblConstants.tblDefaults.profile.debugLevel or 0

	if intDebugLevel < 0 then intDebugLevel = 0 end
	if intDebugLevel > 2 then intDebugLevel = 2 end

	tblState.intDebugModel = intDebugLevel

	return intDebugLevel
end

function tblHelpers.EnsureDB()
	if not tblNamespace.objDatabase then
		tblNamespace.objDatabase = LibStub("AceDB-3.0"):New("MalitorsPortraitFrameDB", tblConstants.tblDefaults, true)
	end

	if not tblNamespace.objDatabase or not tblNamespace.objDatabase.profile then
		tblState.intDebugModel = tblConstants.tblDefaults.profile.debugLevel or 0
		return nil
	end

	tblHelpers.SyncDebugLevelFromProfile()

	return tblNamespace.objDatabase.profile
end

function tblHelpers.GetBorderWidth()
	local tblDatabase = tblHelpers.GetDB()
	local intBorderWidth = (tblDatabase and tblDatabase.borderWidth) or tblConstants.tblDefaults.profile.borderWidth or tblConstants.intBorderMax
	intBorderWidth = tblHelpers.Round(intBorderWidth)
	intBorderWidth = tblHelpers.Clamp(intBorderWidth, tblConstants.intBorderMin, tblConstants.intBorderMax)
	return intBorderWidth
end

function tblHelpers.GetBorderColor()
	local tblDefaultProfile = tblConstants.tblDefaults.profile
	local tblDatabase = tblHelpers.GetDB()
	local tblColor = (tblDatabase and tblDatabase.borderColor) or tblDefaultProfile.borderColor

	return tblColor.r or 1, tblColor.g or 1, tblColor.b or 1, tblColor.a or 1
end

function tblHelpers.GetModelZoom()
	local fltModelZoom = (tblHelpers.GetDB() and tblHelpers.GetDB().modelZoom) or tblConstants.tblDefaults.profile.modelZoom
	fltModelZoom = tonumber(fltModelZoom) or tblConstants.tblDefaults.profile.modelZoom
	return tblHelpers.Clamp(fltModelZoom, tblConstants.fltZoomMin, tblConstants.fltZoomMax)
end

function tblHelpers.GetCamDistance()
	local fltCamDistance = (tblHelpers.GetDB() and tblHelpers.GetDB().camDistance) or tblConstants.tblDefaults.profile.camDistance
	fltCamDistance = tonumber(fltCamDistance) or tblConstants.tblDefaults.profile.camDistance
	return tblHelpers.Clamp(fltCamDistance, tblConstants.fltCamMin, tblConstants.fltCamMax)
end

function tblHelpers.FetchMedia()
	local strEdgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
	local strBgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"
	local objLSM = tblState.objLSM
	local tblDatabase = tblHelpers.GetDB()

	if objLSM and tblDatabase then
		if tblDatabase.border then
			strEdgeFile = objLSM:Fetch("border", tblDatabase.border) or strEdgeFile
		end
		if tblDatabase.background then
			strBgFile = objLSM:Fetch("background", tblDatabase.background) or strBgFile
		end
	end

	return strEdgeFile, strBgFile
end

function tblHelpers.EnsureModelCamera()
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel.SetCamera then return end
	if tblState.blnModelCameraInitialized then return end

	frmModel:SetCamera(1)
	tblState.blnModelCameraInitialized = true
end

function tblHelpers.DebugCall(_strTag, _strFunctionName, ...)
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel[_strFunctionName] then
		if (tonumber(tblState.intDebugModel) or 0) >= 2 then
			print("|cffff5555DBG|r", _strTag, _strFunctionName, "missing")
		end
		return
	end

	local blnOk, valError = pcall(frmModel[_strFunctionName], frmModel, ...)

	if (tonumber(tblState.intDebugModel) or 0) >= 2 then
		if blnOk then
			print("|cff00ff00DBG|r", _strTag, _strFunctionName, "OK", ...)
		else
			print("|cffff5555DBG|r", _strTag, _strFunctionName, "ERR", tostring(valError))
		end
	end
end

function tblHelpers.SafeGetPosition()
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel.GetPosition then return "n/a" end
	local blnOk, valA, valB, valC, valD = pcall(frmModel.GetPosition, frmModel)
	if not blnOk then return "ERR" end
	return string.format("%s,%s,%s,%s", tostring(valA), tostring(valB), tostring(valC), tostring(valD))
end

function tblHelpers.SafeGetFileID()
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel.GetModelFileID then return "n/a" end
	local blnOk, valValue = pcall(frmModel.GetModelFileID, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valValue)
end

function tblHelpers.SafeGetModelFile()
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel.GetModelFile then return "n/a" end
	local blnOk, valValue = pcall(frmModel.GetModelFile, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valValue)
end

function tblHelpers.SafeGetDisplayInfo()
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel.GetDisplayInfo then return "n/a" end
	local blnOk, valValue = pcall(frmModel.GetDisplayInfo, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valValue)
end

function tblHelpers.SafeGetUnit()
	local frmModel = tblState.frmModel

	if not frmModel or not frmModel.GetUnit then return "n/a" end
	local blnOk, valValue = pcall(frmModel.GetUnit, frmModel)
	if not blnOk then return "ERR" end
	return tostring(valValue)
end

function tblHelpers.DebugSnapshot(_strTag, _intToken)
	local frmModel = tblState.frmModel

	if (tonumber(tblState.intDebugModel) or 0) <= 0 then return end

	print("|cff00ff00DBG SNAP|r", _strTag,
		"token=", tostring(_intToken),
		"unit=", tostring(frmModel and frmModel._desiredUnit),
		"guid=", tostring(frmModel and frmModel._desiredGUID),
		"fileID=", tblHelpers.SafeGetFileID(),
		"displayInfo=", tblHelpers.SafeGetDisplayInfo(),
		"modelFile=", tblHelpers.SafeGetModelFile(),
		"GetUnit()=", tblHelpers.SafeGetUnit(),
		"pos=", tblHelpers.SafeGetPosition()
	)
end

function tblHelpers.PollModelIdentity(_intToken, _strLabel, _fltDuration, _fltInterval)
	local frmModel = tblState.frmModel

	if not (C_Timer and C_Timer.After) then return end
	_fltDuration = _fltDuration or 2.0
	_fltInterval = _fltInterval or 0.10

	local fltStartTime = GetTime and GetTime() or 0
	local strLastKey = nil

	local function Tick()
		if not tblState.frmModel then return end
		if tblState.frmModel._applyToken ~= _intToken then return end

		local fltCurrentTime = GetTime and GetTime() or 0
		if fltStartTime ~= 0 and (fltCurrentTime - fltStartTime) > _fltDuration then
			return
		end

		local strKey = tblHelpers.SafeGetFileID() .. "|" .. tblHelpers.SafeGetDisplayInfo() .. "|" .. tblHelpers.SafeGetModelFile() .. "|" .. tblHelpers.SafeGetUnit()

		if strKey ~= strLastKey then
			strLastKey = strKey
			tblHelpers.DebugSnapshot(_strLabel, _intToken)
		end

		C_Timer.After(_fltInterval, Tick)
	end

	C_Timer.After(_fltInterval, Tick)
end

function tblHelpers.Quantize(_valValue, _valStep, _intDecimals)
	local fltValue = tonumber(_valValue) or 0

	if _valStep and _valStep > 0 then
		fltValue = math.floor((fltValue / _valStep) + 0.5) * _valStep
	end

	if _intDecimals and _intDecimals > 0 then
		local intPower = 10 ^ _intDecimals
		fltValue = math.floor((fltValue * intPower) + 0.5) / intPower
	end

	return fltValue
end

function tblHelpers.SliderChangedGuard(_frmSlider, _valValue, _valStep, _intDecimals)
	local fltValue = tonumber(_valValue)
	if not fltValue then return nil end

	local valKey

	if _valStep and _valStep > 0 then
		valKey = math.floor((fltValue / _valStep) + 0.5)
		fltValue = valKey * _valStep
	elseif _intDecimals and _intDecimals > 0 then
		local intPower = 10 ^ _intDecimals
		valKey = math.floor((fltValue * intPower) + 0.5)
		fltValue = valKey / intPower
	else
		valKey = fltValue
	end

	if _frmSlider._lastAppliedKey ~= nil and valKey == _frmSlider._lastAppliedKey then
		return nil
	end

	_frmSlider._lastAppliedKey = valKey
	return fltValue
end
