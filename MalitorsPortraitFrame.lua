-- Namespace
local strAddonName, tblNamespace = ...

tblNamespace.strAddonName = strAddonName

-- Sub-namespaces
tblNamespace.Constants = {}
tblNamespace.Helpers = {}
tblNamespace.Core = {}
tblNamespace.Options = {}
tblNamespace.Events = {}
tblNamespace.State = {}

-- LibSharedMedia
tblNamespace.State.objLSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Settings category handles
tblNamespace.State.objSettingsCategory = nil
tblNamespace.State.intSettingsCategoryID = nil

-- Shared runtime state
tblNamespace.State.frmMain = nil
tblNamespace.State.frmBorder = nil
tblNamespace.State.frmModel = nil
tblNamespace.State.frmResizeButton = nil

tblNamespace.State.blnModelCameraInitialized = false
tblNamespace.State.intModelApplyToken = 0
tblNamespace.State.blnApplyModelViewQueued = false

-- Debug level
-- 0 = off
-- 1 = important lifecycle events
-- 2 = verbose camera/apply spam
tblNamespace.State.intDebugModel = 0