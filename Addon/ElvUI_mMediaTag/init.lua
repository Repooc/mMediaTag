local E = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local L = E.Libs.ACL:GetLocale("ElvUI", E.global.general.locale)

-- Addon Name and Namespace
local addonName, addon = ...
mMT = E:NewModule(addonName, "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

--Cache Lua / WoW API
local _G = _G
local format = format
local GetAddOnMetadata = _G.GetAddOnMetadata
local C_MythicPlus_RequestMapInfo = nil
local C_MythicPlus_RequestCurrentAffixes = nil
local class = E:ClassColor(E.myclass)
local hex = E:RGBToHex(class.r, class.g, class.b)

--Constants
mMT.Version = GetAddOnMetadata(addonName, "Version")
mMT.Name =
"|CFF6559F1m|r|CFF7A4DEFM|r|CFF8845ECe|r|CFFA037E9d|r|CFFA435E8i|r|CFFB32DE6a|r|CFFBC26E5T|r|CFFCB1EE3a|r|CFFDD14E0g|r |CFFFF006C&|r |CFFFF4C00T|r|CFFFF7300o|r|CFFFF9300o|r|CFFFFA800l|r|CFFFFC900s|r"
mMT.NameShort = "|CFF6559F1m|r|CFFA037E9M|r|CFFDD14E0T|r"
mMT.Icon = "|TInterface\\Addons\\ElvUI_mMediaTag\\media\\logo\\mmt_icon_round.tga:14:14|t"
mMT.IconSquare = "|TInterface\\Addons\\ElvUI_mMediaTag\\media\\logo\\mmt_icon.tga:14:14|t"
mMT.ClassColor = {
	r = class.r,
	g = class.g,
	b = class.b,
	hex = hex,
	string = strjoin("", hex, "%s|r"),
}
mMT.ElvUI_EltreumUI = (
	IsAddOnLoaded("ElvUI_EltreumUI")
	and E.db.ElvUI_EltreumUI
	and E.db.ElvUI_EltreumUI.unitframes
	and E.db.ElvUI_EltreumUI.unitframes.gradientmode
	and E.db.ElvUI_EltreumUI.unitframes.gradientmode.enable
) or false

mMT.Media = {}
mMT.Config = {}

if E.Retail then
	C_MythicPlus_RequestMapInfo = C_MythicPlus.RequestMapInfo
	C_MythicPlus_RequestCurrentAffixes = C_MythicPlus.RequestCurrentAffixes
end

--AddonCompartment
function ElvUI_mMediaTag_OnAddonCompartmentClick()
	E:ToggleOptions("mMT")
end

function ElvUI_mMediaTag_OnAddonCompartmentOnEnter()
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT")
	GameTooltip:AddDoubleLine(mMT.Name, format("|CFFF7DC6FVer. %s|r", mMT.Version))
	GameTooltip:Show()
end

function ElvUI_mMediaTag_OnAddonCompartmentOnLeave()
	GameTooltip:Hide()
end

-- Load Settings
local function GetOptions()
	E.Options.name = format("%s + %s %s |cff99ff33%s|r", E.Options.name, mMT.IconSquare, mMT.Name, mMT.Version)

	for _, func in pairs(mMT.Config) do
		func()
	end
end

-- Initialize Addon
function mMT:Initialize()
	EP:RegisterPlugin(addonName, GetOptions)
	-- Register Events
	mMT:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- Initialize main things
	mMT:LoadCommands()
	mMT:mDockUpdateFont()
	mMT:UpdateImportantSpells()
	-- Initialize Modules
	if E.db.mMT.general.greeting then
		mMT:GreetingText()
	end

	if E.db.mMT.tooltip.enable then
		mMT:TipIcon()
	end

	if E.db.mMT.customclasscolors.enable and not mMT:Check_ElvUI_EltreumUI() then
		mMT:SetCustomColors()
	end

	if E.db.mMT.customclasscolors.emediaenable then
		mMT:SetElvUIMediaColor()
	end

	if E.db.mMT.roll.enable then
		mMT:mRoll()
	end

	if E.db.mMT.chat.enable then
		mMT:mChat()
	end

	if E.db.mMT.nameplate.bordercolor.glow or E.db.mMT.nameplate.bordercolor.border then
		mMT:mNamePlateBorderColor()
	end

	if E.db.mMT.unitframeicons.readycheck.enable then
		mMT:SetupReadyCheckIcons()
	end

	if E.db.mMT.unitframeicons.phase.enable then
		mMT:SetupPhaseIcons()
	end

	if E.db.mMT.unitframeicons.resurrection.enable then
		mMT:SetupResurrectionIcon()
	end

	if
		E.db.mMT.custombackgrounds.health.enable
		or E.db.mMT.custombackgrounds.power.enable
		or E.db.mMT.custombackgrounds.castbar.enable
	then
		mMT:CustomBackdrop()
	end

	if E.Retail then
		if E.db.mMT.interruptoncd.enable then
			mMT:mSetupCastbar()
		end

		if
			E.private.nameplates.enable and E.db.mMT.nameplate.healthmarker.enable
			or E.db.mMT.nameplate.executemarker.enable
		then
			mMT:StartNameplateTools()
		end

		if E.db.mMT.instancedifficulty.enable then
			mMT:RegisterEvent("UPDATE_INSTANCE_INFO")
			mMT:RegisterEvent("CHALLENGE_MODE_START")
			mMT:SetupInstanceDifficulty()
		end

		if E.db.mMT.roleicons.enable then
			mMT:mStartRoleSmbols()
		end

		if E.db.mMT.general.keystochat then
			mMT:RegisterEvent("CHAT_MSG_PARTY")
			mMT:RegisterEvent("CHAT_MSG_PARTY_LEADER")
			mMT:RegisterEvent("CHAT_MSG_RAID")
			mMT:RegisterEvent("CHAT_MSG_RAID_LEADER")
			mMT:RegisterEvent("CHAT_MSG_GUILD")
		end

		if E.db.mMT.nameplate.executemarker.auto or E.db.mMT.interruptoncd.enable then
			mMT:RegisterEvent("PLAYER_TALENT_UPDATE")
		end

		if
			(
				E.db.mMT.objectivetracker.enable
				or (E.db.mMT.objectivetracker.enable and E.db.mMT.objectivetracker.simple)
			)
			and E.private.skins.blizzard.enable
			and not IsAddOnLoaded("!KalielsTracker")
		then
			if not E.private.skins.blizzard.objectiveTracker then
				StaticPopupDialogs["mErrorSkin"] = {
					text = L["ElvUI skin must be enabled to activate mMediaTag Quest skins! Should it be enabled?"],
					button1 = L["Yes"],
					button2 = L["No"],
					timeout = 120,
					whileDead = true,
					hideOnEscape = false,
					preferredIndex = 3,
					OnAccept = function()
						E.private.skins.blizzard.objectiveTracker = true
						C_UI.Reload()
					end,
					OnCancel = function()
						E.db.mMT.objectivetracker.enable = false
						C_UI.Reload()
					end,
				}

				StaticPopup_Show("mErrorSkin")
			end

			mMT:InitializemOBT()
		end
	end
end

function mMT:PLAYER_ENTERING_WORLD()
	-- Change Log
	if E.db.mMT.version ~= mMT.Version then
		E:ToggleOptions()
		E.Libs.AceConfigDialog:SelectGroup("ElvUI", "mMT", "changelog")
		E.db.mMT.version = mMT.Version
	end

	-- quick setup
	if not E.db.mMT.quicksetup then
		StaticPopupDialogs["mQuickSetup"] = {
			text = format(
				L["It looks like you are using %s for the first time. Would you like to open the Quick Settings window?"],
				mMT.Name
			),
			button1 = L["Yes"],
			button2 = L["No"],
			timeout = 120,
			whileDead = true,
			hideOnEscape = false,
			preferredIndex = 3,
			OnAccept = function()
				E:ToggleOptions()
				E.Libs.AceConfigDialog:SelectGroup("ElvUI", "mMT", "setup")
				E.db.mMT.quicksetup = true
			end,
			OnCancel = function()
				E.db.mMT.quicksetup = true
			end,
		}

		StaticPopup_Show("mQuickSetup")
	end

	class = E:ClassColor(E.myclass)
	hex = E:RGBToHex(class.r, class.g, class.b)
	mMT.ClassColor = {
		r = class.r,
		g = class.g,
		b = class.b,
		hex = hex,
		string = strjoin("", hex, "%s|r"),
	}

	if E.Retail then
		C_MythicPlus_RequestMapInfo()
		C_MythicPlus_RequestCurrentAffixes()
	end

	mMT:UpdateTagSettings()
	mMT:TagDeathCount()
end

function mMT:PLAYER_TALENT_UPDATE()
	if E.db.mMT.interruptoncd.enable then
		mMT:UpdateInterruptSpell()
	end

	if E.db.mMT.nameplate.executemarker.auto then
		mMT:updateAutoRange()
	end
end

function mMT:UPDATE_INSTANCE_INFO()
	mMT:UpdateText()
	mMT:TagDeathCount()
end

function mMT:CHALLENGE_MODE_START()
	mMT:UpdateText()
end

function mMT:CHAT_MSG_PARTY(event, text)
	mMT:GetKey("PARTY", text)
end

function mMT:CHAT_MSG_PARTY_LEADER(event, text)
	mMT:GetKey("PARTY", text)
end

function mMT:CHAT_MSG_RAID(event, text)
	mMT:GetKey("RAID", text)
end

function mMT:CHAT_MSG_RAID_LEADER(event, text)
	mMT:GetKey("RAID", text)
end

function mMT:CHAT_MSG_GUILD(event, text)
	mMT:GetKey("GUILD", text)
end

E:RegisterModule(mMT:GetName())
