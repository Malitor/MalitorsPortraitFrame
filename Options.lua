local strAddonName, tblNamespace = ...

local tblConstants = tblNamespace.Constants
local tblHelpers = tblNamespace.Helpers
local tblCore = tblNamespace.Core
local tblOptions = tblNamespace.Options
local tblState = tblNamespace.State

local objAceDBOptions = LibStub("AceDBOptions-3.0")
local objAceConfig = LibStub("AceConfig-3.0")
local objAceConfigDialog = LibStub("AceConfigDialog-3.0")

--========================================================
-- Options Panel (Blizzard Settings)
--========================================================
function tblOptions.EnsureBlizzardDropdownAPI()
	if UIDropDownMenu_Initialize ~= nil then return end

	if UIParentLoadAddOn then
		UIParentLoadAddOn("Blizzard_SharedXML")
	end
	if UIDropDownMenu_Initialize == nil and LoadAddOn then
		LoadAddOn("Blizzard_SharedXML")
	end
end

function tblOptions.AttachNumericBoxToSlider(_frmSlider, _tblOptions)
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
		return tblHelpers.Clamp(_valValue, _tblOptions.min, _tblOptions.max)
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

	_frmSlider._suppressOnValueChanged = false

	local function ApplyFromBox()
		local strText = frmBox:GetText()
		strText = (strText or ""):gsub(",", "."):gsub("%s+", "")
		local fltValue = tonumber(strText)

		if not fltValue then
			frmBox:SetText(FormatValue(_tblOptions.get()))
			frmBox:HighlightText(0, 0)
			return
		end

		fltValue = ClampLocal(fltValue)
		fltValue = RoundToStep(fltValue)

		_frmSlider._suppressOnValueChanged = true
		_frmSlider:SetValue(fltValue)
		_frmSlider._suppressOnValueChanged = false

		_tblOptions.set(fltValue)

		frmBox:SetText(FormatValue(fltValue))
		frmBox:HighlightText(0, 0)
	end

	frmBox._justApplied = false

	frmBox:SetScript("OnEnterPressed", function(_frmSelf)
		frmBox._justApplied = true
		ApplyFromBox()
		_frmSelf:ClearFocus()
	end)

	frmBox:SetScript("OnEscapePressed", function(_frmSelf)
		_frmSelf:SetText(FormatValue(_tblOptions.get()))
		_frmSelf:HighlightText(0, 0)
		_frmSelf:ClearFocus()
	end)

	frmBox:SetScript("OnEditFocusLost", function()
		if frmBox._justApplied then
			frmBox._justApplied = false
			return
		end

		ApplyFromBox()
	end)

	_frmSlider._numericBox = frmBox
	_frmSlider._numericBoxFormat = FormatValue
	_frmSlider._numericBoxRefresh = function()
		local fltValue = _tblOptions.get()
		if fltValue == nil then return end

		if (not _tblOptions.decimals or _tblOptions.decimals <= 0) and frmBox.SetNumber then
			frmBox:SetNumber(math.floor(fltValue + 0.5))
		else
			frmBox:SetText(FormatValue(fltValue))
		end
	end

	frmBox:HookScript("OnShow", function()
		if _frmSlider._numericBoxRefresh then
			_frmSlider._numericBoxRefresh()
		end

		local strCurrentText = frmBox:GetText()
		frmBox:SetText("")
		frmBox:SetText(strCurrentText or "")
		frmBox:SetCursorPosition(0)
	end)

	_frmSlider:HookScript("OnShow", function()
		if _frmSlider._numericBoxRefresh then
			_frmSlider._numericBoxRefresh()
		end
	end)

	if _frmSlider._numericBoxRefresh then
		_frmSlider._numericBoxRefresh()
	end

	return frmBox
end

function tblOptions.OpenBorderColorPicker(_fnApplyColor)
	local tblDatabase = tblHelpers.GetDB()
	local tblColor = (tblDatabase and tblDatabase.borderColor) or tblConstants.tblDefaults.profile.borderColor
	local fltRed, fltGreen, fltBlue, fltAlpha = tblColor.r or 1, tblColor.g or 1, tblColor.b or 1, tblColor.a or 1

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

	local tblPrevious = { r = fltRed, g = fltGreen, b = fltBlue, a = fltAlpha }

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
		_fnApplyColor(tblPrevious.r, tblPrevious.g, tblPrevious.b, tblPrevious.a)
	end

	ColorPickerFrame:SetupColorPickerAndShow(tblInfo)
end

function tblOptions.RegisterProfileOptions(_valParentCategory)
	if tblState.blnProfilesRegistered then return end
	if not tblNamespace.objDatabase then return end

	local tblProfileOptions = objAceDBOptions:GetOptionsTable(tblNamespace.objDatabase)
	local valParentCategory = _valParentCategory or tblState.intSettingsCategoryID or tblState.objSettingsCategory

	objAceConfig:RegisterOptionsTable("MalitorsPortraitFrame_Profiles", tblProfileOptions)

	tblState.objProfilesPanel = objAceConfigDialog:AddToBlizOptions(
		"MalitorsPortraitFrame_Profiles",
		"Profiles",
		valParentCategory
	)

	tblState.blnProfilesRegistered = true
end

function tblOptions.RefreshOptionsControls()
	if tblState.fnRefreshOptionsControls then
		tblState.fnRefreshOptionsControls()
	end
end

function tblOptions.ApplyActiveProfileToUI()
	tblHelpers.SyncDebugLevelFromProfile()
	tblCore.ApplySavedLayout()
	tblCore.ApplyBackdrop()
	tblCore.ApplyLockState()
	tblCore.RequestApplyModelView()
	tblOptions.RefreshAllOptionsControls()
end

function tblOptions.RegisterProfileCallbacks()
	if tblState.blnProfileCallbacksRegistered then return end
	if not tblNamespace.objDatabase then return end

	tblNamespace.objDatabase:RegisterCallback("OnProfileChanged", function(...)
		tblOptions.OnProfileChanged(...)
	end)
	tblNamespace.objDatabase:RegisterCallback("OnProfileCopied", function(...)
		tblOptions.OnProfileCopied(...)
	end)
	tblNamespace.objDatabase:RegisterCallback("OnProfileReset", function(...)
		tblOptions.OnProfileReset(...)
	end)

	tblState.blnProfileCallbacksRegistered = true
end

function tblOptions.RegisterSettingsPanel(_frmPanel)
	if tblState.objSettingsCategory then
		return tblState.objSettingsCategory
	end

	if Settings and Settings.RegisterCanvasLayoutCategory then
		tblState.objSettingsCategory = Settings.RegisterCanvasLayoutCategory(_frmPanel, _frmPanel.name)
		Settings.RegisterAddOnCategory(tblState.objSettingsCategory)

		if tblState.objSettingsCategory then
			if tblState.objSettingsCategory.GetID then
				tblState.intSettingsCategoryID = tblState.objSettingsCategory:GetID()
			elseif tblState.objSettingsCategory.ID then
				tblState.intSettingsCategoryID = tblState.objSettingsCategory.ID
			elseif tblState.objSettingsCategory.categoryID then
				tblState.intSettingsCategoryID = tblState.objSettingsCategory.categoryID
			end
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(_frmPanel)
	end

	return tblState.objSettingsCategory
end

function tblOptions.RefreshAllOptionsControls()
	if not tblState.tblOptionsControls then return end

	local tblControls = tblState.tblOptionsControls

	if tblControls.chkLock then
		tblControls.chkLock:SetChecked(tblHelpers.GetDB() and tblHelpers.GetDB().locked)
	end

	if tblControls.RefreshBorderDropdown then
		tblControls.RefreshBorderDropdown()
	end

	if tblControls.frmBorderWidthSlider then
		tblControls.frmBorderWidthSlider:SetValue(tblHelpers.GetBorderWidth())
		if tblControls.frmBorderWidthSlider._numericBoxRefresh then
			tblControls.frmBorderWidthSlider._numericBoxRefresh()
		end
	end

	if tblControls.UpdateBorderColorSwatch then
		tblControls.UpdateBorderColorSwatch()
	end

	if tblControls.frmModelZoomSlider then
		tblControls.frmModelZoomSlider:SetValue(tblHelpers.GetModelZoom())
		if tblControls.frmModelZoomSlider._numericBoxRefresh then
			tblControls.frmModelZoomSlider._numericBoxRefresh()
		end
	end

	if tblControls.frmCamDistanceSlider then
		tblControls.frmCamDistanceSlider:SetValue(tblHelpers.GetCamDistance())
		if tblControls.frmCamDistanceSlider._numericBoxRefresh then
			tblControls.frmCamDistanceSlider._numericBoxRefresh()
		end
	end
end

function tblOptions.ApplyProfileToUI()
	tblOptions.ApplyActiveProfileToUI()
end

function tblOptions.OnProfileChanged(_strEventName, _objDatabase, _strProfileKey)
	tblOptions.ApplyProfileToUI()
end

function tblOptions.OnProfileCopied(_strEventName, _objDatabase, _strProfileKey)
	tblOptions.ApplyProfileToUI()
end

function tblOptions.OnProfileReset(_strEventName, _objDatabase, _strProfileKey)
	tblOptions.ApplyProfileToUI()
end

function tblOptions.CreateOptionsPanel()
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

		local fntTitle = frmGroupBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fntTitle:SetText(_strTitleText or "")
		fntTitle:SetPoint("TOPLEFT", frmGroupBox, "TOPLEFT", 10, 16)
		fntTitle:SetDrawLayer("OVERLAY")

		return frmGroupBox
	end

	local frmPanel = CreateFrame("Frame", "MalitorsPortraitFrameOptionsPanel", UIParent)
	frmPanel.name = "Malitor's Portrait Frame"

	tblOptions.EnsureBlizzardDropdownAPI()
	tblOptions.RegisterSettingsPanel(frmPanel)
	tblOptions.RegisterProfileOptions(tblState.intSettingsCategoryID or frmPanel.name)
	tblOptions.RegisterProfileCallbacks()

	local fntTitle = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	fntTitle:SetPoint("TOPLEFT", 16, -16)
	fntTitle:SetText("Malitor's Portrait Frame")

	local fntSubtitle = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fntSubtitle:SetPoint("TOPLEFT", fntTitle, "BOTTOMLEFT", 0, -8)
	fntSubtitle:SetJustifyH("LEFT")
	fntSubtitle:SetText("Customize the portrait frame border, size, and scale.\nAdjust 3D portrait camera zoom and distance.")

	local chkLock = CreateFrame("CheckButton", nil, frmPanel, "UICheckButtonTemplate")
	chkLock:SetPoint("TOPLEFT", fntSubtitle, "BOTTOMLEFT", 0, -14)
	chkLock:SetScript("OnClick", function(_frmSelf)
		tblHelpers.GetDB().locked = _frmSelf:GetChecked() and true or false
		tblCore.ApplyLockState()
	end)

	local fntLockText = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fntLockText:SetPoint("LEFT", chkLock, "RIGHT", 4, 1)
	fntLockText:SetText("Lock")

	local frmBorderDropDown = CreateFrame("Frame", "MalitorsPortraitFrameBorderDropDown", frmPanel, "UIDropDownMenuTemplate")
	frmBorderDropDown:SetPoint("TOPLEFT", chkLock, "BOTTOMLEFT", 0, -36)
	UIDropDownMenu_SetWidth(frmBorderDropDown, 260)

	local function RefreshBorderDropdown()
		local strBorderText = (tblHelpers.GetDB() and tblHelpers.GetDB().border) or tblConstants.tblDefaults.profile.border
		UIDropDownMenu_SetText(frmBorderDropDown, strBorderText or "Unknown")
	end

	local function Border_OnClick(_objSelfArg)
		tblHelpers.GetDB().border = _objSelfArg.value
		tblCore.ApplyBackdrop()
		RefreshBorderDropdown()
	end

	UIDropDownMenu_Initialize(frmBorderDropDown, function()
		if not tblState.objLSM then
			local objInfo = UIDropDownMenu_CreateInfo()
			objInfo.text = "LibSharedMedia-3.0 not found"
			objInfo.notCheckable = true
			objInfo.isTitle = true
			UIDropDownMenu_AddButton(objInfo)
			return
		end

		local strCurrentBorder = tblHelpers.GetDB().border
		local tblBorderList = tblState.objLSM:List("border")
		table.sort(tblBorderList)

		for _, strName in ipairs(tblBorderList) do
			local objInfo = UIDropDownMenu_CreateInfo()
			objInfo.text = strName
			objInfo.value = strName
			objInfo.func = Border_OnClick
			objInfo.checked = (strName == strCurrentBorder)
			UIDropDownMenu_AddButton(objInfo)
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

	local fntBorderColorLabel = frmPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fntBorderColorLabel:SetPoint("TOPLEFT", frmBorderColorSwatch, "TOPRIGHT", 6, -2)
	fntBorderColorLabel:SetText("Border Color")

	local function UpdateBorderColorSwatch()
		local fltRed, fltGreen, fltBlue, fltAlpha = tblHelpers.GetBorderColor()
		frmBorderColorSwatch.color:SetColorTexture(fltRed, fltGreen, fltBlue, fltAlpha)
	end

	frmBorderColorSwatch:SetScript("OnClick", function()
		tblOptions.OpenBorderColorPicker(function(_fltRed, _fltGreen, _fltBlue, _fltAlpha)
			tblHelpers.GetDB().borderColor = tblHelpers.GetDB().borderColor or {}
			tblHelpers.GetDB().borderColor.r = _fltRed
			tblHelpers.GetDB().borderColor.g = _fltGreen
			tblHelpers.GetDB().borderColor.b = _fltBlue
			tblHelpers.GetDB().borderColor.a = _fltAlpha
			tblCore.ApplyBackdrop()
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
	frmBorderWidthSlider:SetMinMaxValues(tblConstants.intBorderMin, tblConstants.intBorderMax)
	frmBorderWidthSlider:SetValueStep(1)
	frmBorderWidthSlider:SetObeyStepOnDrag(true)
	_G[frmBorderWidthSlider:GetName() .. "Low"]:SetText(tostring(tblConstants.intBorderMin))
	_G[frmBorderWidthSlider:GetName() .. "High"]:SetText(tostring(tblConstants.intBorderMax))
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
		frmBorderWidthSlider:SetValue(tblHelpers.Clamp((frmBorderWidthSlider:GetValue() or tblConstants.intBorderMin) - 1, tblConstants.intBorderMin, tblConstants.intBorderMax))
	end)

	frmBorderWidthPlus:SetScript("OnClick", function()
		frmBorderWidthSlider:SetValue(tblHelpers.Clamp((frmBorderWidthSlider:GetValue() or tblConstants.intBorderMin) + 1, tblConstants.intBorderMin, tblConstants.intBorderMax))
	end)

	frmBorderWidthSlider:SetScript("OnValueChanged", function(_frmSelf, _valValue)
		if _frmSelf._suppressOnValueChanged then return end

		local intBorderWidthValue = tblHelpers.SliderChangedGuard(_frmSelf, _valValue, 1, 0)
		if intBorderWidthValue == nil then return end

		intBorderWidthValue = tblHelpers.Clamp(tblHelpers.Round(intBorderWidthValue), tblConstants.intBorderMin, tblConstants.intBorderMax)
		tblHelpers.GetDB().borderWidth = intBorderWidthValue
		tblCore.ApplyBackdrop()

		if _frmSelf._numericBox then
			if _frmSelf._numericBox.SetNumber then
				_frmSelf._numericBox:SetNumber(intBorderWidthValue)
			else
				_frmSelf._numericBox:SetText(_frmSelf._numericBoxFormat(intBorderWidthValue))
			end
		end
	end)

	tblOptions.AttachNumericBoxToSlider(frmBorderWidthSlider, {
		anchorFrame = frmBorderWidthPlus,
		width = 30,
		decimals = 0,
		min = tblConstants.intBorderMin,
		max = tblConstants.intBorderMax,
		step = 1,
		get = function()
			return tblHelpers.GetBorderWidth()
		end,
		set = function(_valValue)
			tblHelpers.GetDB().borderWidth = tblHelpers.Clamp(tblHelpers.Round(_valValue), tblConstants.intBorderMin, tblConstants.intBorderMax)
			tblCore.ApplyBackdrop()
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
	frmModelZoomSlider:SetMinMaxValues(tblConstants.fltZoomMin, tblConstants.fltZoomMax)
	frmModelZoomSlider:SetValueStep(0.1)
	frmModelZoomSlider:SetObeyStepOnDrag(true)
	_G[frmModelZoomSlider:GetName() .. "Low"]:SetText(string.format("%.2f", tblConstants.fltZoomMin))
	_G[frmModelZoomSlider:GetName() .. "High"]:SetText(string.format("%.2f", tblConstants.fltZoomMax))
	_G[frmModelZoomSlider:GetName() .. "Text"]:SetText("Model Zoom")

	frmModelZoomSlider:SetScript("OnValueChanged", function(_frmSelf, _valValue)
		if _frmSelf._suppressOnValueChanged then return end

		local fltModelZoomValue = tblHelpers.SliderChangedGuard(_frmSelf, _valValue, 0.1, 2)
		if fltModelZoomValue == nil then return end

		fltModelZoomValue = tblHelpers.Clamp(tonumber(fltModelZoomValue) or tblConstants.tblDefaults.profile.modelZoom, tblConstants.fltZoomMin, tblConstants.fltZoomMax)
		tblHelpers.GetDB().modelZoom = fltModelZoomValue
		tblCore.RequestApplyModelView()

		if _frmSelf._numericBox then
			_frmSelf._numericBox:SetText(_frmSelf._numericBoxFormat(fltModelZoomValue))
			_frmSelf._numericBox:HighlightText(0, 0)
		end
	end)

	tblOptions.AttachNumericBoxToSlider(frmModelZoomSlider, {
		width = 36,
		decimals = 2,
		min = tblConstants.fltZoomMin,
		max = tblConstants.fltZoomMax,
		step = 0.01,
		get = function()
			return tblHelpers.GetModelZoom()
		end,
		set = function(_valValue)
			tblHelpers.GetDB().modelZoom = tblHelpers.Clamp(tonumber(_valValue) or tblConstants.tblDefaults.profile.modelZoom, tblConstants.fltZoomMin, tblConstants.fltZoomMax)
			tblCore.RequestApplyModelView()
		end,
	})

	local frmCamDistanceSlider = CreateFrame("Slider", "MalitorsPortraitFrameCamDistanceSlider", frmPanel, "OptionsSliderTemplate")
	frmCamDistanceSlider:SetPoint("TOPLEFT", frmModelZoomSlider, "TOPRIGHT", 80, 0)
	frmCamDistanceSlider:SetWidth(150)
	frmCamDistanceSlider:SetMinMaxValues(tblConstants.fltCamMin, tblConstants.fltCamMax)
	frmCamDistanceSlider:SetValueStep(0.1)
	frmCamDistanceSlider:SetObeyStepOnDrag(true)
	_G[frmCamDistanceSlider:GetName() .. "Low"]:SetText(string.format("%.2f", tblConstants.fltCamMin))
	_G[frmCamDistanceSlider:GetName() .. "High"]:SetText(string.format("%.2f", tblConstants.fltCamMax))
	_G[frmCamDistanceSlider:GetName() .. "Text"]:SetText("Camera Distance")

	frmCamDistanceSlider:SetScript("OnValueChanged", function(_frmSelf, _valValue)
		if _frmSelf._suppressOnValueChanged then return end

		local fltCamDistanceValue = tblHelpers.SliderChangedGuard(_frmSelf, _valValue, 0.1, 2)
		if fltCamDistanceValue == nil then return end

		fltCamDistanceValue = tblHelpers.Clamp(tonumber(fltCamDistanceValue) or tblConstants.tblDefaults.profile.camDistance, tblConstants.fltCamMin, tblConstants.fltCamMax)
		tblHelpers.GetDB().camDistance = fltCamDistanceValue
		tblCore.RequestApplyModelView()

		if _frmSelf._numericBox then
			_frmSelf._numericBox:SetText(_frmSelf._numericBoxFormat(fltCamDistanceValue))
			_frmSelf._numericBox:HighlightText(0, 0)
		end
	end)

	tblOptions.AttachNumericBoxToSlider(frmCamDistanceSlider, {
		width = 36,
		decimals = 2,
		min = tblConstants.fltCamMin,
		max = tblConstants.fltCamMax,
		step = 0.01,
		get = function()
			return tblHelpers.GetCamDistance()
		end,
		set = function(_valValue)
			tblHelpers.GetDB().camDistance = tblHelpers.Clamp(tonumber(_valValue) or tblConstants.tblDefaults.profile.camDistance, tblConstants.fltCamMin, tblConstants.fltCamMax)
			tblCore.RequestApplyModelView()
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
		chkLock:SetChecked(tblHelpers.GetDB() and tblHelpers.GetDB().locked)

		RefreshBorderDropdown()
		frmBorderWidthSlider:SetValue(tblHelpers.GetBorderWidth())
		if frmBorderWidthSlider._numericBoxRefresh then frmBorderWidthSlider._numericBoxRefresh() end

		UpdateBorderColorSwatch()

		frmModelZoomSlider:SetValue(tblHelpers.GetModelZoom())
		frmCamDistanceSlider:SetValue(tblHelpers.GetCamDistance())
		if frmModelZoomSlider._numericBoxRefresh then frmModelZoomSlider._numericBoxRefresh() end
		if frmCamDistanceSlider._numericBoxRefresh then frmCamDistanceSlider._numericBoxRefresh() end
	end

	tblState.fnRefreshOptionsControls = tblOptions.RefreshAllOptionsControls

	local frmResetButton = CreateFrame("Button", nil, frmPanel, "UIPanelButtonTemplate")
	frmResetButton:SetSize(120, 22)
	frmResetButton:SetPoint("TOPLEFT", chkLock, "TOPRIGHT", 86, -4)
	frmResetButton:SetText("Reset")

	frmResetButton:SetScript("OnClick", function()
		if not tblNamespace.objDatabase then return end

		tblNamespace.objDatabase:ResetProfile()

		print("|cFF00FF00MalitorsPortraitFrame|r current profile reset.")
	end)

	frmPanel:HookScript("OnShow", function()
		RefreshOptionsControls()

		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				RefreshOptionsControls()
			end)
		end
	end)
	
	tblState.tblOptionsControls = {
		chkLock = chkLock,
		frmBorderWidthSlider = frmBorderWidthSlider,
		frmModelZoomSlider = frmModelZoomSlider,
		frmCamDistanceSlider = frmCamDistanceSlider,
		RefreshBorderDropdown = RefreshBorderDropdown,
		UpdateBorderColorSwatch = UpdateBorderColorSwatch,
	}

	RefreshOptionsControls()
end

--========================================================
-- Slash Commands
--========================================================
SLASH_MalitorsPortraitFrame1 = "/malpf"
SLASH_MalitorsPortraitFrame2 = "/MalitorsPortraitFrame"

SlashCmdList["MalitorsPortraitFrame"] = function(_strMessage)
	local strMessage = (_strMessage or ""):trim()
	local strLowerMessage = strMessage:lower()

	tblOptions.CreateOptionsPanel()

	if strLowerMessage:match("^debug") then
		local strArgument = strLowerMessage:match("^debug%s*(.*)$")
		strArgument = (strArgument or ""):gsub("^%s+", ""):gsub("%s+$", "")

		local intCurrent = (tblHelpers.GetDB() and tonumber(tblHelpers.GetDB().debugLevel)) or (tonumber(tblState.intDebugModel) or 0)
		if intCurrent < 0 then intCurrent = 0 end
		if intCurrent > 2 then intCurrent = 2 end

		if strArgument == "" then
			print(string.format("|cFF00FF00MalitorsPortraitFrame|r Debug level is %d (0=off, 1=events, 2=verbose)", intCurrent))
			return
		end

		local intNewLevel = intCurrent
		if strArgument == "on" then
			intNewLevel = 1
		elseif strArgument == "off" then
			intNewLevel = 0
		elseif strArgument == "verbose" then
			intNewLevel = 2
		elseif strArgument == "quiet" then
			intNewLevel = 0
		else
			local intParsed = tonumber(strArgument)
			if intParsed ~= nil then
				intNewLevel = intParsed
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

		tblState.intDebugModel = intNewLevel
		if tblHelpers.GetDB() then
			tblHelpers.GetDB().debugLevel = intNewLevel
		end

		print(string.format("|cFF00FF00MalitorsPortraitFrame|r Debug level set to %d (0=off, 1=events, 2=verbose)", intNewLevel))
		return
	end

	if strLowerMessage == "" or strLowerMessage == "options" or strLowerMessage == "config" or strLowerMessage == "settings" then
		if Settings then
			if tblState.intSettingsCategoryID and type(tblState.intSettingsCategoryID) == "number" then
				if Settings.OpenToCategory then
					Settings.OpenToCategory(tblState.intSettingsCategoryID)
					return
				end
				if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
					C_SettingsUtil.OpenSettingsPanel(tblState.intSettingsCategoryID)
					return
				end
			end

			if Settings.OpenToCategory and tblState.objSettingsCategory then
				local blnOk = pcall(Settings.OpenToCategory, tblState.objSettingsCategory)
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
