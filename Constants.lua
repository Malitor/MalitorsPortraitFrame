local strAddonName, tblNamespace = ...

local tblConstants = tblNamespace.Constants

--========================================================
-- Constants / Defaults
--========================================================
tblConstants.intBorderMin = 1
tblConstants.intBorderMax = 32
tblConstants.intFrameMinBase = 64
tblConstants.intFrameMax = 800

-- 3D Camera Settings
tblConstants.fltZoomMin = 0.10
tblConstants.fltZoomMax = 1.00
tblConstants.fltCamMin = 0.60
tblConstants.fltCamMax = 2.50

tblConstants.tblDefaults = {
	profile = {
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
		borderWidth = tblConstants.intBorderMax,
		borderColor = { r = 1, g = 1, b = 1, a = 1 },

		-- Debug (0=off, 1=events, 2=verbose)
		debugLevel = 0,
	}
}