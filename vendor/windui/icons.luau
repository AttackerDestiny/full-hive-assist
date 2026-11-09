-- Adapted from Footagesus/Icons (MIT): pinned Lucide data; no runtime downloads.
local IconModule = {
	IconsType = "lucide",

	New = nil,
	IconThemeTag = nil,

	Icons = {lucide = {
	["activity"] = "rbxassetid://94212016861936",
	["arrow-right"] = "rbxassetid://113692007244654",
	["check"] = "rbxassetid://93898873302694",
	["chevron-down"] = "rbxassetid://134243273101015",
	["chevrons-up-down"] = "rbxassetid://131833120209646",
	["code"] = "rbxassetid://107380207681249",
	["command"] = "rbxassetid://93648221906330",
	["copy"] = "rbxassetid://78979572434545",
	["expand"] = "rbxassetid://137492887754537",
	["eye"] = "rbxassetid://100033680381365",
	["feather"] = "rbxassetid://91872927606406",
	["hammer"] = "rbxassetid://83545120140895",
	["hexagon"] = "rbxassetid://127592089339199",
	["key"] = "rbxassetid://96510194465420",
	["lock"] = "rbxassetid://134724289526879",
	["log-out"] = "rbxassetid://84895399304975",
	["maximize"] = "rbxassetid://76045941763188",
	["minimize"] = "rbxassetid://121304296213645",
	["minus"] = "rbxassetid://118026365011536",
	["mouse-pointer-click"] = "rbxassetid://107150227368485",
	["move"] = "rbxassetid://116138709011735",
	["palette"] = "rbxassetid://86350350950064",
	["panda"] = "rbxassetid://132509022802512",
	["repeat"] = "rbxassetid://121886242955173",
	["search"] = "rbxassetid://121018724060431",
	["settings"] = "rbxassetid://80758916183665",
	["sliders-horizontal"] = "rbxassetid://85538382643347",
	["square-mouse-pointer"] = "rbxassetid://76141850603920",
	["square"] = "rbxassetid://86304921356806",
	["table-of-contents"] = "rbxassetid://135044763275414",
	["table"] = "rbxassetid://109109148250737",
	["terminal"] = "rbxassetid://106783148545356",
	["text-cursor-input"] = "rbxassetid://107551944047171",
	["toggle-right"] = "rbxassetid://90411952142550",
	["triangle-alert"] = "rbxassetid://125920361880643",
	["type"] = "rbxassetid://133543553793564",
	["user"] = "rbxassetid://81589895647169",
	["watch"] = "rbxassetid://130544621618405",
	["x"] = "rbxassetid://110786993356448",
	}},
}

local function parseIconString(iconString)
	if type(iconString) == "string" then
		local splitIndex = iconString:find(":")
		if splitIndex then
			local iconType = iconString:sub(1, splitIndex - 1)
			local iconName = iconString:sub(splitIndex + 1)
			return iconType, iconName
		end
	end
	return nil, iconString
end

function IconModule.AddIcons(packName, iconsData)
	if type(packName) ~= "string" or type(iconsData) ~= "table" then
		error("AddIcons: packName must be string, iconsData must be table")
		return
	end

	if not IconModule.Icons[packName] then
		IconModule.Icons[packName] = {
			Icons = {},
			Spritesheets = {},
		}
	end

	for iconName, iconValue in pairs(iconsData) do
		if type(iconValue) == "number" or (type(iconValue) == "string" and iconValue:match("^rbxassetid://")) then
			local imageId = iconValue
			if type(iconValue) == "number" then
				imageId = "rbxassetid://" .. tostring(iconValue)
			end

			IconModule.Icons[packName].Icons[iconName] = {
				Image = imageId,
				ImageRectSize = Vector2.new(0, 0),
				ImageRectPosition = Vector2.new(0, 0),
				Parts = nil,
			}
			IconModule.Icons[packName].Spritesheets[imageId] = imageId
		elseif type(iconValue) == "table" then
			if iconValue.Image and iconValue.ImageRectSize and iconValue.ImageRectPosition then
				local imageId = iconValue.Image
				if type(imageId) == "number" then
					imageId = "rbxassetid://" .. tostring(imageId)
				end

				IconModule.Icons[packName].Icons[iconName] = {
					Image = imageId,
					ImageRectSize = iconValue.ImageRectSize,
					ImageRectPosition = iconValue.ImageRectPosition,
					Parts = iconValue.Parts,
				}

				if not IconModule.Icons[packName].Spritesheets[imageId] then
					IconModule.Icons[packName].Spritesheets[imageId] = imageId
				end
			else
				warn("AddIcons: Invalid spritesheet data format for icon '" .. iconName .. "'")
			end
		else
			warn("AddIcons: Unsupported data type for icon '" .. iconName .. "': " .. type(iconValue))
		end
	end
end

function IconModule.SetIconsType(iconType)
	IconModule.IconsType = iconType
end

function IconModule.Init(New, IconThemeTag)
	IconModule.New = New
	IconModule.IconThemeTag = IconThemeTag

	return IconModule
end

function IconModule.Icon(Icon, Type, DefaultFormat)
	DefaultFormat = DefaultFormat ~= false
	local iconType, iconName = parseIconString(Icon)

	local targetType = iconType or Type or IconModule.IconsType
	local targetName = iconName

	local iconSet = IconModule.Icons[targetType]

	if iconSet and iconSet.Icons and iconSet.Icons[targetName] then
		return {
			iconSet.Spritesheets[tostring(iconSet.Icons[targetName].Image)],
			iconSet.Icons[targetName],
		}
	elseif iconSet and iconSet[targetName] and string.find(iconSet[targetName], "rbxassetid://") then
		return DefaultFormat
				and {
					iconSet[targetName],
					{ ImageRectSize = Vector2.new(0, 0), ImageRectPosition = Vector2.new(0, 0) },
				}
			or iconSet[targetName]
	end
	return nil
end

function IconModule.GetIcon(Icon, Type)
	return IconModule.Icon(Icon, Type, false)
end

function IconModule.Icon2(Icon, Type, DefaultFormat)
	return IconModule.Icon(Icon, Type, true)
end

function IconModule.Image(IconConfig)
	local Icon = {
		Icon = IconConfig.Icon or nil,
		Type = IconConfig.Type,
		Colors = IconConfig.Colors or { (IconModule.IconThemeTag or Color3.new(1, 1, 1)), Color3.new(1, 1, 1) },
		Size = IconConfig.Size or UDim2.new(0, 24, 0, 24),

		IconFrame = nil,
	}

	local Colors = {}

	for _, color in next, Icon.Colors do
		Colors[_] = {
			ThemeTag = typeof(color) == "string" and color,
			Color = typeof(color) == "Color3" and color,
		}
	end

	local IconLabel = IconModule.Icon2(Icon.Icon, Icon.Type)
	local isrbxassetid = typeof(IconLabel) == "string" and string.find(IconLabel, "rbxassetid://")

	if IconModule.New then
		local New = IconModule.New

		local IconFrame = New("ImageLabel", {
			Size = Icon.Size,
			BackgroundTransparency = 1,
			ImageColor3 = Colors[1].Color or nil,
			ThemeTag = Colors[1].ThemeTag and {
				ImageColor3 = Colors[1].ThemeTag,
			},
			Image = isrbxassetid and IconLabel or IconLabel[1],
			ImageRectSize = isrbxassetid and nil or IconLabel[2].ImageRectSize,
			ImageRectOffset = isrbxassetid and nil or IconLabel[2].ImageRectPosition,
		})

		if not isrbxassetid and IconLabel[2].Parts then
			for _, part in next, IconLabel[2].Parts do
				local IconPartLabel = IconModule.Icon(part, Icon.Type)

				local IconPart = New("ImageLabel", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					ImageColor3 = Colors[1 + _].Color or nil,
					ThemeTag = Colors[1 + _].ThemeTag and {
						ImageColor3 = Colors[1 + _].ThemeTag,
					},
					Image = IconPartLabel[1],
					ImageRectSize = IconPartLabel[2].ImageRectSize,
					ImageRectOffset = IconPartLabel[2].ImageRectPosition,
					Parent = IconFrame,
				})
			end
		end

		Icon.IconFrame = IconFrame
	else
		local IconFrame = Instance.new("ImageLabel")
		IconFrame.Size = Icon.Size
		IconFrame.BackgroundTransparency = 1
		IconFrame.ImageColor3 = Colors[1].Color
		IconFrame.Image = isrbxassetid and IconLabel or IconLabel[1]
		IconFrame.ImageRectSize = isrbxassetid and nil or IconLabel[2].ImageRectSize
		IconFrame.ImageRectOffset = isrbxassetid and nil or IconLabel[2].ImageRectPosition

		if not isrbxassetid and IconLabel[2].Parts then
			for _, part in next, IconLabel[2].Parts do
				local IconPartLabel = IconModule.Icon(part, Icon.Type)

				local IconPart = Instance.New("ImageLabel")
				IconPart.Size = UDim2.new(1, 0, 1, 0)
				IconPart.BackgroundTransparency = 1
				IconPart.ImageColor3 = Colors[1 + _].Color
				IconPart.Image = IconPartLabel[1]
				IconPart.ImageRectSize = IconPartLabel[2].ImageRectSize
				IconPart.ImageRectOffset = IconPartLabel[2].ImageRectPosition
				IconPart.Parent = IconFrame
			end
		end

		Icon.IconFrame = IconFrame
	end

	return Icon
end

return IconModule
