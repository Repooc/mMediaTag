local E = unpack(ElvUI)

local _G = _G
local SetPortraitTexture = SetPortraitTexture
local UnitExists = UnitExists
local tinsert = tinsert
local UF = E:GetModule("UnitFrames")

local module = mMT.Modules.Portraits
if not module then return end

local colors = {}

local bg_textures = {
	[1] = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\bg_1.tga",
	[2] = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\bg_2.tga",
	[3] = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\bg_3.tga",
	[4] = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\bg_4.tga",
	[5] = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\bg_5.tga",
	empty = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\empty.tga",
	unknown = "Interface\\Addons\\ElvUI_mMediaTag\\media\\portraits\\unknown.tga",
}

local function mirrorTexture(texture, mirror, top)
	if texture.classIcons then
		local coords = texture.classCoords
		if #coords == 8 then
			texture:SetTexCoord(unpack((mirror and { coords[5], coords[6], coords[7], coords[8], coords[1], coords[2], coords[3], coords[4] } or coords)))
		else
			texture:SetTexCoord(unpack((mirror and { coords[2], coords[1], coords[3], coords[4] } or coords)))
		end
	else
		texture:SetTexCoord(mirror and 1 or 0, mirror and 0 or 1, top and 1 or 0, top and 0 or 1)
	end
end

local function setColor(texture, color, mirror)
	if not texture or not color or not color.a or not color.b then return end

	if type(color.a) == "table" and type(color.b) == "table" then
		if E.db.mMT.portraits.general.gradient then
			local a, b = color.a, color.b
			if mirror and (E.db.mMT.portraits.general.ori == "HORIZONTAL") then
				a, b = b, a
			end
			texture:SetGradient(E.db.mMT.portraits.general.ori, a, b)
		else
			texture:SetVertexColor(color.a.r, color.a.g, color.a.b, color.a.a)
		end
	elseif color.r then
		texture:SetVertexColor(color.r, color.g, color.b, color.a)
	else
		mMT:Print("Error! - Portraits Color > ")
		mMT:DebugPrintTable(color)
	end
end

local cachedFaction = {}

local function getColor(unit)
	local defaultColor = colors.default

	if E.db.mMT.portraits.general.default then return defaultColor end

	if UnitIsPlayer(unit) or (E.Retail and UnitInPartyIsAI(unit)) then
		if E.db.mMT.portraits.general.reaction then
			local playerFaction = cachedFaction.player or select(1, UnitFactionGroup("player"))
			cachedFaction.player = playerFaction
			local unitFaction = cachedFaction[UnitGUID(unit)] or select(1, UnitFactionGroup(unit))
			cachedFaction[UnitGUID(unit)] = unitFaction

			return colors[(playerFaction == unitFaction) and "friendly" or "enemy"]
		else
			local _, class = UnitClass(unit)
			return colors[class]
		end
	else
		local reaction = UnitReaction(unit, "player")
		return colors[reaction and ((reaction <= 3) and "enemy" or (reaction == 4) and "neutral" or "friendly") or "enemy"]
	end
end

local function adjustColor(color, shift)
	return {
		r = color.r - shift,
		g = color.g - shift,
		b = color.b - shift,
		a = color.a,
	}
end

local function UpdateIconBackground(tx, unit, mirror)
	tx:SetTexture(bg_textures[E.db.mMT.portraits.general.bgstyle], "CLAMP", "CLAMP", "TRILINEAR")

	local color = E.db.mMT.portraits.shadow.classBG and getColor(unit) or E.db.mMT.portraits.shadow.background
	local bgColor = { r = 1, g = 1, b = 1, a = 1 }
	local ColorShift = E.db.mMT.portraits.shadow.bgColorShift

	if not color.r then
		bgColor.a = adjustColor(color.a, ColorShift)
		bgColor.b = adjustColor(color.b, ColorShift)
	else
		bgColor = adjustColor(color, ColorShift)
	end

	setColor(tx, bgColor, mirror)
end

local function SetPortraits(frame, unit, masking, mirror)
	if E.db.mMT.portraits.general.classicons and UnitIsPlayer(unit) then
		local class = select(2, UnitClass(unit))
		local coords = CLASS_ICON_TCOORDS[class]
		local style = E.db.mMT.portraits.general.classiconstyle

		if mMT.ElvUI_JiberishIcons.loaded and style ~= "BLIZZARD" then
			coords = class and mMT.ElvUI_JiberishIcons.texCoords[class]
			frame.portrait:SetTexture(mMT.ElvUI_JiberishIcons.path .. style)
		else
			frame.portrait:SetTexture("Interface\\WorldStateFrame\\Icons-Classes")
		end

		if frame.iconbg then UpdateIconBackground(frame.iconbg, unit, mirror) end

		frame.portrait.classIcons = unit
		frame.portrait.classCoords = coords

		frame.portrait:SetTexCoord(unpack(coords))

		--if coords then
		mirrorTexture(frame.portrait, mirror)
		--end
	else
		if frame.portrait.classIcons then
			frame.portrait.classIcons = nil
			frame.portrait.classCoords = nil
		end

		mirrorTexture(frame.portrait, mirror)
		SetPortraitTexture(frame.portrait, unit, true)
	end
end

local function GetOffset(size, offset)
	if offset == 0 or not offset then
		return 0
	else
		return ((size / offset) * E.perfect)
	end
end

local function UpdateTexture(portraitFrame, textureType, texture, level, color, reverse)
	if not portraitFrame[textureType] then
		portraitFrame[textureType] = portraitFrame:CreateTexture("mMT_" .. textureType, "OVERLAY", nil, level)
		portraitFrame[textureType]:SetAllPoints(portraitFrame)
	end

	local mirror = portraitFrame.settings.mirror
	portraitFrame[textureType]:SetTexture(texture, "CLAMP", "CLAMP", "TRILINEAR")
	if reverse ~= nil then mirror = reverse end
	mirrorTexture(portraitFrame[textureType], mirror, portraitFrame.textures.flipp)

	if color then setColor(portraitFrame[textureType], color, mirror) end
end

local function UpdateExtraTexture(portraitFrame, classification)
	-- Texture
	local extraTextures = portraitFrame.textures[classification].texture
	portraitFrame.extra:SetTexture(extraTextures, "CLAMP", "CLAMP", "TRILINEAR")

	-- Border
	if E.db.mMT.portraits.shadow.border then
		extraTextures = portraitFrame.textures[classification].border
		portraitFrame.extraBorder:SetTexture(extraTextures, "CLAMP", "CLAMP", "TRILINEAR")
	end

	-- Shadow
	if E.db.mMT.portraits.shadow.enable then
		extraTextures = portraitFrame.textures[classification].shadow
		portraitFrame.extraShadow:SetTexture(extraTextures, "CLAMP", "CLAMP", "TRILINEAR")
	end
end

local function CheckRareElite(frame, unit)
	local c = UnitClassification(unit) --"worldboss", "rareelite", "elite", "rare", "normal", "trivial", or "minus"

	if c == "worldboss" then c = "boss" end
	local color = colors[c]

	if color then
		UpdateExtraTexture(frame, c)
		setColor(frame.extra, color)
		if E.db.mMT.portraits.shadow.enable and frame.extraShadow then frame.extraShadow:Show() end
		if E.db.mMT.portraits.shadow.border and frame.extraBorder then frame.extraBorder:Show() end
		frame.extra:Show()
	else
		if E.db.mMT.portraits.shadow.enable and frame.extraShadow then frame.extraShadow:Hide() end
		if E.db.mMT.portraits.shadow.border and frame.extraBorder then frame.extraBorder:Hide() end
		frame.extra:Hide()
	end
end

local function UpdatePortrait(portraitFrame, force)
	if mMT.DevMode then
		mMT:Print(
			"Create Function",
			"Unit:",
			portraitFrame.unit,
			"Exists",
			UnitExists(portraitFrame.unit),
			"Parent Unit:",
			portraitFrame.parent and portraitFrame.parent.unit or "Error",
			"Parent Exists:",
			portraitFrame.parent and UnitExists(portraitFrame.parent.unit) or "Error"
		)
	end

	-- get textures
	portraitFrame.textures = mMT:GetTextures(portraitFrame.settings.texture)

	local texture, offset
	local setting = portraitFrame.settings
	local unit = force and "player" or (UnitExists(portraitFrame.unit) and portraitFrame.unit or (portraitFrame.parent.unit or "player"))
	local parent = portraitFrame.parent

	-- Portraits Frame
	if not InCombatLockdown() then
		portraitFrame:SetSize(setting.size, setting.size)
		portraitFrame:ClearAllPoints()
		portraitFrame:SetPoint(setting.point, parent, setting.relativePoint, setting.x, setting.y)

		if setting.strata ~= "AUTO" then portraitFrame:SetFrameStrata(setting.strata) end
		portraitFrame:SetFrameLevel(setting.level)
	end

	-- Portrait Texture
	texture = portraitFrame.textures.texture
	UpdateTexture(portraitFrame, "texture", texture, 4, getColor(unit))

	-- Unit Portrait
	offset = GetOffset(setting.size, portraitFrame.textures.offset)
	UpdateTexture(portraitFrame, "portrait", bg_textures.unknown, 1)
	SetPortraits(portraitFrame, unit, false, setting.mirror)
	portraitFrame.portrait:SetPoint("TOPLEFT", 0 + offset, 0 - offset)
	portraitFrame.portrait:SetPoint("BOTTOMRIGHT", 0 - offset, 0 + offset)

	-- Portrait Mask
	--texture = portraitFrame.textures.extraMask and portraitFrame.textures.mask[setting.mirror and "b" or "a"] or portraitFrame.textures.mask

	if portraitFrame.textures.extraMask then
		if setting.mirror then
			texture = portraitFrame.textures.mask.b
		else
			texture = portraitFrame.textures.mask.a
		end
	else
		texture = portraitFrame.textures.mask
	end

	if not portraitFrame.mask then
		portraitFrame.mask = portraitFrame:CreateMaskTexture()
		portraitFrame.mask:SetAllPoints(portraitFrame)
		portraitFrame.portrait:AddMaskTexture(portraitFrame.mask)
	end

	portraitFrame.mask:SetTexture(texture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Class Icon Background
	--if (E.db.mMT.portraits.general.classicons or portraitFrame.textures.flipp) and not portraitFrame.iconbg then
	local color = { r = 0, g = 0, b = 0, a = 1 }
	if E.db.mMT.portraits.general.classicons then color = (E.db.mMT.portraits.shadow.classBG and getColor(unit) or E.db.mMT.portraits.shadow.background) end
	UpdateTexture(portraitFrame, "iconbg", bg_textures[E.db.mMT.portraits.general.bgstyle], -5, color)
	portraitFrame.iconbg:AddMaskTexture(portraitFrame.mask)
	--end

	-- Portrait Shadow
	if E.db.mMT.portraits.shadow.enable then
		texture = portraitFrame.textures.shadow
		UpdateTexture(portraitFrame, "shadow", texture, -4, E.db.mMT.portraits.shadow.color)
		portraitFrame.shadow:Show()
	elseif portraitFrame.shadow then
		portraitFrame.shadow:Hide()
	end

	-- Inner Portrait Shadow
	if E.db.mMT.portraits.shadow.inner then
		texture = portraitFrame.textures.inner
		UpdateTexture(portraitFrame, "innerShadow", texture, 2, E.db.mMT.portraits.shadow.innerColor)
		portraitFrame.innerShadow:Show()
	elseif portraitFrame.innerShadow then
		portraitFrame.innerShadow:Show()
	end

	-- Portrait Border
	if E.db.mMT.portraits.shadow.border then
		texture = portraitFrame.textures.border
		UpdateTexture(portraitFrame, "border", texture, 2, E.db.mMT.portraits.shadow.borderColor)
	end

	-- Rare/Elite Texture
	if setting.extraEnable then
		-- Texture
		texture = portraitFrame.textures.rare.texture
		UpdateTexture(portraitFrame, "extra", texture, -6, E.db.mMT.portraits.shadow.borderColor, not portraitFrame.settings.mirror)

		-- Border
		if E.db.mMT.portraits.shadow.border then
			texture = portraitFrame.textures.rare.border
			UpdateTexture(portraitFrame, "extraBorder", texture, -7, E.db.mMT.portraits.shadow.borderColorRare, not portraitFrame.settings.mirror)
			portraitFrame.extraBorder:Hide()
		end

		-- Shadow
		if E.db.mMT.portraits.shadow.enable then
			texture = portraitFrame.textures.rare.shadow
			UpdateTexture(portraitFrame, "extraShadow", texture, -8, E.db.mMT.portraits.shadow.color, not portraitFrame.settings.mirror)
			portraitFrame.extraShadow:Hide()
		end

		CheckRareElite(portraitFrame, unit)
	end

	-- Corner
	if portraitFrame.textures.corner then
		texture = portraitFrame.textures.corner.texture
		UpdateTexture(portraitFrame, "corner", texture, 5, getColor(unit))

		-- Border
		if E.db.mMT.portraits.shadow.border then
			texture = portraitFrame.textures.corner.border
			UpdateTexture(portraitFrame, "cornerBorder", texture, 6, E.db.mMT.portraits.shadow.borderColor)
			portraitFrame.cornerBorder:Show()
		end

		portraitFrame.corner:Show()
	elseif portraitFrame.corner then
		portraitFrame.corner:Hide()

		if portraitFrame.cornerBorder then portraitFrame.cornerBorder:Hide() end
	end
end

local function SetCastEvents(portrait, unregistering)
	local castEvents = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP" }
	local empowerEvents = { "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }

	if unregistering then
		for _, event in pairs(castEvents) do
			portrait:UnregisterEvent(event)
		end

		if E.Retail then
			for _, event in pairs(empowerEvents) do
				portrait:UnregisterEvent(event)
			end
		end
	else
		for _, event in pairs(castEvents) do
			if portrait.isPartyFrame then
				portrait:RegisterEvent(event)
			else
				portrait:RegisterUnitEvent(event, portrait.unit)
			end
			tinsert(portrait.allEvents, event)
		end

		if E.Retail then
			for _, event in pairs(empowerEvents) do
				if portrait.isPartyFrame then
					portrait:RegisterEvent(event)
				else
					portrait:RegisterUnitEvent(event, portrait.unit)
				end
				tinsert(portrait.allEvents, event)
			end
		end
	end
end

local function SetScripts(portrait, force)
	if not portrait.isBuild then
		-- party event
		if portrait.isPartyFrame then
			-- events for all party frames
			local partyEvents = { "GROUP_ROSTER_UPDATE", "PARTY_MEMBER_ENABLE", "UNIT_MODEL_CHANGED", "UNIT_PORTRAIT_UPDATE", "UNIT_CONNECTION" }
			for _, event in ipairs(partyEvents) do
				portrait:RegisterEvent(event)
				tinsert(portrait.allEvents, event)
			end

			-- events for cast icon
			if portrait.settings.cast then
				SetCastEvents(portrait)
				portrait.castEventsSet = true
			end
		else
			-- specific events for unit
			local unitEvents = { "UNIT_MODEL_CHANGED", "UNIT_PORTRAIT_UPDATE", "UNIT_CONNECTION" }
			for _, event in ipairs(unitEvents) do
				portrait:RegisterUnitEvent(event, portrait.unit)
				tinsert(portrait.allEvents, event)
			end

			-- specific events for player and pet if player is in vehicle
			if E.Retail or E.Cata then
				if portrait.unit == "player" then
					portrait:RegisterEvent("VEHICLE_UPDATE")
					tinsert(portrait.allEvents, "VEHICLE_UPDATE")
					portrait:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", portrait.unit)
					tinsert(portrait.allEvents, "UNIT_ENTERED_VEHICLE")
					portrait:RegisterUnitEvent("UNIT_EXITED_VEHICLE", portrait.unit)
					tinsert(portrait.allEvents, "UNIT_EXITED_VEHICLE")
				end
				if portrait.unit == "pet" then
					portrait:RegisterEvent("VEHICLE_UPDATE")
					tinsert(portrait.allEvents, "VEHICLE_UPDATE")
				end
			end

			if portrait.events then
				for _, event in pairs(portrait.events) do
					portrait:RegisterUnitEvent(event)
					tinsert(portrait.allEvents, event)
				end
			end

			if portrait.unitEvents then
				for _, event in pairs(portrait.unitEvents) do
					portrait:RegisterUnitEvent(event, event == "UNIT_TARGET" and "target" or portrait.unit)
					tinsert(portrait.allEvents, event)
				end
			end

			-- events for cast icon
			if portrait.settings.cast then
				SetCastEvents(portrait)
				portrait.castEventsSet = true
			end
		end

		-- events for all units
		portrait:RegisterEvent("PLAYER_ENTERING_WORLD")
		tinsert(portrait.allEvents, "PLAYER_ENTERING_WORLD")
		portrait:RegisterEvent("PORTRAITS_UPDATED")
		tinsert(portrait.allEvents, "PORTRAITS_UPDATED")

		-- scripts to interact with mouse
		portrait:SetAttribute("unit", portrait.unit)
		portrait:SetAttribute("*type1", "target")
		portrait:SetAttribute("*type2", "togglemenu")
		portrait:SetAttribute("type3", "focus")
		portrait:SetAttribute("toggleForVehicle", true)
		portrait:SetAttribute("ping-receiver", true)
		portrait:RegisterForClicks("AnyUp")

		portrait.isBuild = true
	end

	-- update cast events
	if force then
		if portrait.settings.cast and not portrait.castEventsSet then
			SetCastEvents(portrait)
			portrait.castEventsSet = true
		elseif portrait.castEventsSet then
			SetCastEvents(portrait, true)
			portrait.castEventsSet = false
		end
	end
end

local function UpdateAllPortraits(force)
	local units = {
		"Player",
		"Target",
		"Pet",
		"Focus",
		"TargetTarget",
		"Party1",
		"Party2",
		"Party3",
		"Party4",
		"Party5",
		"Arena1",
		"Arena2",
		"Arena3",
		"Arena4",
		"Arena5",
		"Boss1",
		"Boss2",
		"Boss3",
		"Boss4",
		"Boss5",
		"Boss6",
		"Boss7",
		"Boss8",
	}
	for _, name in ipairs(units) do
		if module[name] then
			UpdatePortrait(module[name])

			-- update for demo frames
			if force then SetScripts(module[name], force) end
		end
	end
end

local function AddCastIcon(self)
	local texture = select(3, UnitCastingInfo(self.unit))

	if not texture then texture = select(3, UnitChannelInfo(self.unit)) end

	if texture then
		self.portrait:SetTexture(texture)
		if self.portrait.classIcons then
			self.portrait.classIcons = nil
			self.portrait.classCoords = nil
		end

		mirrorTexture(self.portrait, self.settings.mirror)
	end
end

local function RemovePortrait(unitPortrait)
	if unitPortrait and unitPortrait.allEvents then
		for _, event in pairs(unitPortrait.allEvents) do
			unitPortrait:UnregisterEvent(event)
		end
	end

	unitPortrait:Hide()
	unitPortrait = nil
end

local castStarted = {
	UNIT_SPELLCAST_START = true,
	UNIT_SPELLCAST_CHANNEL_START = true,
	UNIT_SPELLCAST_EMPOWER_START = true,
}

local castStoped = {
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_EMPOWER_STOP = true,
}

local function UnitEvent(self, event)
	if mMT.DevMode then mMT:Print("Script:", self.unit, self.parent.unit, "Unit Exists:", UnitExists(self.unit), UnitExists(self.parent.unit)) end

	local unit = self.unit

	if castStoped[event] then
		if self.isCasting then
			SetPortraits(self, unit, false, self.settings.mirror)
			self.isCasting = false
		end
	elseif castStarted[event] then
		if self.settings.cast or self.isCasting then
			self.empowering = (event == "UNIT_SPELLCAST_EMPOWER_START")
			self.isCasting = true

			AddCastIcon(self)
		end
	else
		if not InCombatLockdown() and self:GetAttribute("unit") ~= unit then self:SetAttribute("unit", unit) end

		SetPortraits(self, unit, false, self.settings.mirror)
		setColor(self.texture, getColor(unit), self.settings.mirror)

		if E.db.mMT.portraits.general.corner and self.textures.corner then setColor(self.corner, getColor(unit), self.settings.mirror) end

		if self.settings.extraEnable and self.extra then CheckRareElite(self, unit) end
	end
end

local function setColors(sourceColors, targetColors)
	targetColors.default = sourceColors.default
	targetColors.rare = sourceColors.rare
	targetColors.rareelite = sourceColors.rareelite
	targetColors.elite = sourceColors.elite
end

local function ConfigureColors()
	if E.db.mMT.portraits.general.eltruism and mMT.ElvUI_EltreumUI.loaded then
		colors = mMT.ElvUI_EltreumUI.colors
		setColors(E.db.mMT.portraits.colors, colors)
	elseif E.db.mMT.portraits.general.mui and mMT.ElvUI_MerathilisUI.loaded then
		if not colors.inverted then
			for i, tbl in pairs(mMT.ElvUI_MerathilisUI.colors) do
				colors[i] = { a = tbl.b, b = tbl.a }
			end
			colors.inverted = true
		end
		setColors(E.db.mMT.portraits.colors, colors)
	else
		colors = E.db.mMT.portraits.colors
	end
end

local function shouldHandleEvent(event, eventUnit, self)
	return (event == "UNIT_TARGET" and (eventUnit == "player" or eventUnit == "target" or eventUnit == "targettarget"))
		or (event == "PLAYER_TARGET_CHANGED" and (self.unit == "target" or self.unit == "targettarget"))
		or event == "PLAYER_FOCUS_CHANGED"
		or (event == "UNIT_EXITED_VEHICLE" or event == "UNIT_ENTERED_VEHICLE" or event == "VEHICLE_UPDATE")
		or eventUnit == self.unit
end

local function PartyUnitOnEnevt(self, event, eventUnit)
	if not UnitExists(self.parent.unit) then return end

	self.unit = self.parent.unit

	if eventUnit == self.unit then UnitEvent(self, event) end
end

local function OtherUnitOnEnevt(self, event, eventUnit)
	if eventUnit == "vehicle" and (self.parent.unit == "player" or self.parent.unit == "pet") then
		if self.parent.realUnit == "player" then self.unit = "pet" end

		if self.parent.realUnit == "pet" then self.unit = "player" end
	else
		self.unit = self.parent.unit
	end

	if not UnitExists(self.unit) then return end

	if shouldHandleEvent(event, eventUnit, self) or (_G.ElvUF_Player.unit == "vehicle") then UnitEvent(self, event) end
end

local function CreatePortraits(name, unit, parentFrame, unitSettings, events, unitEvents)
	if not module[name] then
		module[name] = CreateFrame("Button", "mMT_Portrait_" .. name, parentFrame, "SecureUnitButtonTemplate") -- CreatePortrait(parentFrame, unitSettings, unit)
		module[name].parent = parentFrame
		module[name].unit = unit
		module[name].isPartyFrame = (name == "Party1" or name == "Party2" or name == "Party3" or name == "Party4" or name == "Party5")
		module[name].events = events or nil
		module[name].unitEvents = unitEvents or nil
		module[name].allEvents = {}
		module[name].name = name
	end

	-- update settings
	module[name].settings = unitSettings

	-- add event function
	if module[name] and not module[name].scriptsSet then
		if module[name].isPartyFrame then
			module[name]:SetScript("OnEvent", PartyUnitOnEnevt)
		else
			module[name]:SetScript("OnEvent", OtherUnitOnEnevt)
		end

		SetScripts(module[name])
		module[name].scriptsSet = true
	end

	-- Update Portrait
	UpdatePortrait(module[name])
end

local function ToggleForceShowGroupFrames(_, group, numGroup)
	if group == "boss" or group == "arena" then
		local name = (group == "boss") and "Boss" or "Arena"

		for i = 1, numGroup do
			if module[name .. i] then UpdatePortrait(module[name .. i], true) end
		end
	end
end

local function HeaderConfig(_, header, configMode)
	if header.groups and header.groupName == "party" then
		for i = 1, #header.groups[1] do
			if module["Party" .. i] then UpdatePortrait(module["Party" .. i], true) end
		end
	end
end

function module:Initialize(force)
	-- update colors
	ConfigureColors()

	-- initialize portraits
	if E.db.mMT.portraits.general.enable then
		if _G.ElvUF_Player and E.db.mMT.portraits.player.enable then
			CreatePortraits("Player", "player", _G.ElvUF_Player, E.db.mMT.portraits.player)
		elseif module.Player then
			RemovePortrait(module.Player)
		end

		if _G.ElvUF_Target and E.db.mMT.portraits.target.enable then
			CreatePortraits("Target", "target", _G.ElvUF_Target, E.db.mMT.portraits.target, { "PLAYER_TARGET_CHANGED" })
		elseif module.Target then
			RemovePortrait(module.Target)
		end

		if _G.ElvUF_Pet and E.db.mMT.portraits.pet.enable then
			CreatePortraits("Pet", "pet", _G.ElvUF_Pet, E.db.mMT.portraits.pet)
		elseif module.Pet then
			RemovePortrait(module.Pet)
		end

		if _G.ElvUF_TargetTarget and E.db.mMT.portraits.targettarget.enable then
			CreatePortraits("TargetTarget", "targettarget", _G.ElvUF_TargetTarget, E.db.mMT.portraits.targettarget, { "PLAYER_TARGET_CHANGED" }, { "UNIT_TARGET" })
		elseif module.TargetTarget then
			RemovePortrait("TargetTarget")
		end

		if _G.ElvUF_Focus and E.db.mMT.portraits.focus.enable then
			CreatePortraits("Focus", "focus", _G.ElvUF_Focus, E.db.mMT.portraits.focus, { "PLAYER_FOCUS_CHANGED" })
		elseif module.Focus then
			RemovePortrait(module.Focus)
		end

		if _G.ElvUF_PartyGroup1UnitButton1 and E.db.mMT.portraits.party.enable then
			for i = 1, 5 do
				CreatePortraits("Party" .. i, _G["ElvUF_PartyGroup1UnitButton" .. i].unit, _G["ElvUF_PartyGroup1UnitButton" .. i], E.db.mMT.portraits.party)
			end
		elseif module.Party1 then
			for i = 1, 5 do
				RemovePortrait(module["Party" .. i])
			end
		end

		if _G.ElvUF_Boss1 and E.db.mMT.portraits.boss.enable then
			for i = 1, 8 do
				CreatePortraits("Boss" .. i, _G["ElvUF_Boss" .. i].unit, _G["ElvUF_Boss" .. i], E.db.mMT.portraits.boss, { "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_TARGETABLE_CHANGED" })
			end
		elseif module.Boss1 then
			for i = 1, 8 do
				RemovePortrait(module["Boss" .. i])
			end
		end

		if _G.ElvUF_Arena1 and E.db.mMT.portraits.arena.enable then
			for i = 1, 5 do
				CreatePortraits(
					"Arena" .. i,
					_G["ElvUF_Arena" .. i].unit,
					_G["ElvUF_Arena" .. i],
					E.db.mMT.portraits.arena,
					{ "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS" },
					{ "UNIT_NAME_UPDATE" }
				)

				if E.Retail then tinsert(module["Arena" .. i].events, "ARENA_PREP_OPPONENT_SPECIALIZATIONS") end
			end
		elseif module.Arena1 then
			for i = 1, 5 do
				RemovePortrait(module["Arena" .. i])
			end
		end

		-- update all portraits, force = update cast events
		UpdateAllPortraits(force)

		-- for demo frames - party, boss & arena
		if not module.needReloadUI then
			hooksecurefunc(UF, "ToggleForceShowGroupFrames", ToggleForceShowGroupFrames)
			hooksecurefunc(UF, "HeaderConfig", HeaderConfig)
			module.needReloadUI = true
		end
	else
		for _, unitPortrait in pairs(module) do
			if type(unitPortrait) == "table" and unitPortrait.portrait then RemovePortrait(unitPortrait) end
		end
	end

	module.loaded = E.db.mMT.portraits.general.enable
end
