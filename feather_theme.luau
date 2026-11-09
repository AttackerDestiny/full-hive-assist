-- Native GUI styling and feather sticker; no downloaded/custom assets needed.
local Theme={}
Theme.featherIcon="rbxassetid://91872927606406" -- Bundled WindUI Lucide feather.
function Theme.make(class,name,parent,properties)
    local item=Instance.new(class); item.Name=name
    for key,value in pairs(properties or {}) do item[key]=value end
    item.Parent=parent
    return item
end
function Theme.panel(panel)
    panel.BackgroundColor3=Color3.new(1,1,1); panel.BorderSizePixel=0
    Theme.make("UICorner","Corner",panel,{CornerRadius=UDim.new(0,14)})
    Theme.make("UIGradient","NightGradient",panel,{Rotation=35,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(15,25,49)),
        ColorSequenceKeypoint.new(0.55,Color3.fromRGB(25,36,65)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(61,52,91))})})
    Theme.make("UIStroke","SoftOutline",panel,{Color=Color3.fromRGB(130,175,231),Transparency=0.55,Thickness=1.2})
end
function Theme.button(button,primary)
    button.BorderSizePixel=0; button.Font=Enum.Font.GothamBold; button.TextSize=13
    button.TextColor3=Color3.fromRGB(240,248,255)
    button.BackgroundColor3=primary and Color3.fromRGB(56,113,187) or Color3.fromRGB(76,51,77)
    Theme.make("UICorner","Corner",button,{CornerRadius=UDim.new(0,8)})
    Theme.make("UIStroke","SoftOutline",button,{Color=primary and Color3.fromRGB(141,200,255)
        or Color3.fromRGB(217,151,178),Transparency=0.55,Thickness=1})
    Theme.make("UIGradient","ButtonGradient",button,{Rotation=90,
        Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(192,206,240))})
end
function Theme.brand(parent,position,z)
    local brand=Theme.make("Frame","FeatherBrand",parent,{Position=position,Size=UDim2.fromOffset(156,32),
        BackgroundTransparency=1,ZIndex=z})
    Theme.make("TextLabel","BrandTitle",brand,{Size=UDim2.fromOffset(108,32),BackgroundTransparency=1,
        Text="Feather",Font=Enum.Font.GothamBold,TextSize=23,TextColor3=Color3.fromRGB(235,247,255),
        TextXAlignment=Enum.TextXAlignment.Left,ZIndex=z})
    local sticker=Theme.make("Frame","FeatherSticker",brand,{Position=UDim2.fromOffset(96,0),
        Size=UDim2.fromOffset(34,34),BackgroundTransparency=1,ZIndex=z+1})
    local function line(a,b,thickness,color)
        local delta=b-a
        local item=Theme.make("Frame","Barb",sticker,{AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2),Size=UDim2.fromOffset(delta.Magnitude,thickness),
            Rotation=math.deg(math.atan2(delta.Y,delta.X)),BackgroundColor3=color,BorderSizePixel=0,ZIndex=z+1})
        Theme.make("UICorner","Round",item,{CornerRadius=UDim.new(1,0)})
    end
    for i=1,8 do
        local t=i/9; local center=Vector2.new(23-12*t,2+27*t)
        local spread=math.sin(math.pi*t)*9
        line(center,center+Vector2.new(-spread,-6),2.8,Color3.fromRGB(232,246,255))
        line(center,center+Vector2.new(spread*0.7,-8),2.6,Color3.fromRGB(174,208,251))
    end
    line(Vector2.new(9,33),Vector2.new(23,2),1.7,Color3.fromRGB(246,250,255))
    return brand
end
function Theme.draggable(panel,headerHeight,z)
    -- Drag only the header, leaving buttons, bee cards and scrolling untouched.
    local handle=Theme.make("Frame","DragHandle",panel,{Size=UDim2.new(1,0,0,headerHeight),
        BackgroundTransparency=1,Active=true,ZIndex=z})
    local inputService=game:GetService("UserInputService")
    local held,startPointer,startPosition,startAbsolute
    local connections={}
    local function point(input) return Vector2.new(input.Position.X,input.Position.Y) end
    local function beginDrag(input)
        local kind=input.UserInputType
        if held or (kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch) then return end
        held=input; startPointer=point(input); startPosition=panel.Position; startAbsolute=panel.AbsolutePosition
    end
    local function moveDrag(input)
        if not held or not panel.Parent then return end
        if held.UserInputType==Enum.UserInputType.Touch then
            if input~=held then return end -- A second finger cannot steal the drag.
        elseif input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local delta=point(input)-startPointer
        local bounds=panel.Parent
        local origin,size=bounds.AbsolutePosition,bounds.AbsoluteSize
        local panelSize=panel.AbsoluteSize
        local target=startAbsolute+delta
        target=Vector2.new(
            math.clamp(target.X,origin.X+8,math.max(origin.X+8,origin.X+size.X-panelSize.X-8)),
            math.clamp(target.Y,origin.Y+8,math.max(origin.Y+8,origin.Y+size.Y-panelSize.Y-8)))
        delta=target-startAbsolute
        panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,
            startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
    end
    local function endDrag(input)
        if input==held or (held and held.UserInputType==Enum.UserInputType.MouseButton1
            and input.UserInputType==Enum.UserInputType.MouseButton1) then held=nil end
    end
    local function cleanup()
        held=nil
        for _,connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end
    connections[#connections+1]=handle.InputBegan:Connect(beginDrag)
    connections[#connections+1]=inputService.InputChanged:Connect(moveDrag)
    connections[#connections+1]=inputService.InputEnded:Connect(endDrag)
    connections[#connections+1]=panel.AncestryChanged:Connect(function() if not panel.Parent then cleanup() end end)
    return {Begin=beginDrag,Move=moveDrag,Finish=endDrag,Destroy=cleanup}
end
return Theme
