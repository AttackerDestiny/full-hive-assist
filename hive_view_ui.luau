-- Read-only hive viewer. Snapshot reads the host's existing cache; no remotes.
return function(gui,statusFrame,viewButton,snapshot)
    local function make(class,name,parent,properties)
        local item=Instance.new(class); item.Name=name
        for key,value in pairs(properties or {}) do item[key]=value end
        item.Parent=parent
        return item
    end
    local overlay=make("TextButton","HiveOverlay",gui,{
        Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(8,11,16),
        BackgroundTransparency=0.15,BorderSizePixel=0,Text="",AutoButtonColor=false,
        Modal=true,Visible=false,ZIndex=20})
    local panel=make("Frame","HivePanel",overlay,{
        AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(360,620),BackgroundColor3=Color3.fromRGB(23,27,31),
        BorderSizePixel=0,ZIndex=21})
    FeatherTheme.panel(panel)
    local scale=make("UIScale","ResponsiveScale",panel,{Scale=1})
    FeatherTheme.brand(panel,UDim2.fromOffset(18,10),22)
    make("TextLabel","ViewLabel",panel,{Position=UDim2.new(1,-112,0,20),Size=UDim2.fromOffset(94,18),
        BackgroundTransparency=1,Text="YOUR HIVE",Font=Enum.Font.GothamBold,TextSize=11,
        TextColor3=Color3.fromRGB(158,192,235),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=22})
    local summary=make("TextLabel","Summary",panel,{Position=UDim2.fromOffset(18,40),Size=UDim2.new(1,-36,0,20),
        BackgroundTransparency=1,Text="Waiting for hive data...",Font=Enum.Font.Gotham,TextSize=13,
        TextColor3=Color3.fromRGB(166,180,197),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=22})
    FeatherTheme.draggable(panel,64,30)
    local scroll=make("ScrollingFrame","HiveScroll",panel,{Position=UDim2.fromOffset(18,70),
        Size=UDim2.new(1,-36,1,-140),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(98,117,141),
        CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=22})
    local grid=make("Frame","HiveGrid",scroll,{AnchorPoint=Vector2.new(0.5,0),
        Position=UDim2.new(0.5,0,0,6),Size=UDim2.fromOffset(232,0),BackgroundTransparency=1,ZIndex=23})
    local detail=make("TextLabel","BeeDetails",panel,{Position=UDim2.new(0,12,1,-66),Size=UDim2.new(1,-24,0,22),
        BackgroundTransparency=1,Text="Tap a bee for details",Font=Enum.Font.Gotham,TextSize=12,
        TextColor3=Color3.fromRGB(196,208,224),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=22})
    local close=make("TextButton","CloseHiveButton",panel,{AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,1,-10),Size=UDim2.fromOffset(120,30),
        BackgroundColor3=Color3.fromRGB(58,66,76),BorderSizePixel=0,Text="Close",
        Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),ZIndex=22})
    FeatherTheme.button(close,true)
    local function fit()
        local size=overlay.AbsoluteSize
        if size.X>24 and size.Y>24 then scale.Scale=math.min(1,(size.X-24)/360,(size.Y-24)/620) end
    end
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    local cards={}
    local selected
    local function newCard(key)
        local button=make("TextButton","Cell_"..key,grid,{Size=UDim2.fromOffset(44,44),
            BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=24})
        local icon=make("ImageLabel","BeeIcon",button,{Size=UDim2.fromScale(1,1),
            BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=25})
        local level=make("TextLabel","Level",button,{Position=UDim2.new(0,2,1,-17),Size=UDim2.fromOffset(30,17),
            BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),TextStrokeColor3=Color3.new(0,0,0),
            TextStrokeTransparency=0,Font=Enum.Font.GothamBold,TextSize=13,
            TextXAlignment=Enum.TextXAlignment.Left,ZIndex=27})
        local star=make("TextLabel","GiftedStar",button,{Position=UDim2.fromOffset(-2,-5),Size=UDim2.fromOffset(22,24),
            BackgroundTransparency=1,Text="★",TextColor3=Color3.fromRGB(255,224,80),
            TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=0,Font=Enum.Font.ArialBold,TextSize=23,ZIndex=28})
        local border=make("UIStroke","Outline",button,{Thickness=1,Color=Color3.fromRGB(63,74,88)})
        local card={button=button,icon=icon,level=level,star=star,border=border}
        cards[key]=card
        button.Activated:Connect(function() selected=key; detail.Text=card.description or "" end)
        return card
    end
    local lastFingerprint
    local function render()
        local stats,types,active=snapshot()
        if type(stats)~="table" or type(types)~="table" then summary.Text="Waiting for hive data..."; return end
        local cells,seen={},{}
        local maxX,maxY,giftedCount=5,1,0
        for x,column in pairs(stats.Honeycomb or {}) do
            local nx=tonumber(tostring(x):match("^x(%d+)$"))
            if nx and type(column)=="table" then
                for y,bee in pairs(column) do
                    local ny=tonumber(tostring(y):match("^y(%d+)$"))
                    if ny and type(bee)=="table" and bee.Type then
                        cells[#cells+1]={x=nx,y=ny,bee=bee}
                        maxX,maxY=math.max(maxX,nx),math.max(maxY,ny)
                    end
                end
            end
        end
        local fingerprint={tostring(stats.UnlockedCells),tostring(active and active.X),tostring(active and active.Y)}
        for _,cell in ipairs(cells) do
            fingerprint[#fingerprint+1]=cell.x..":"..cell.y..":"..cell.bee.Type..":"..tostring(cell.bee.Lvl or cell.bee.Level)..":"..table.concat(cell.bee.Traits or {},",")
        end
        table.sort(fingerprint)
        fingerprint=table.concat(fingerprint,"|")
        if lastFingerprint==fingerprint then return end
        lastFingerprint=fingerprint
        local width,height=maxX*47-3,maxY*47-3
        grid.Size=UDim2.fromOffset(width,height)
        scroll.CanvasSize=UDim2.fromOffset(0,height+12)
        for _,cell in ipairs(cells) do
            local bee=cell.bee
            local key=cell.x.."_"..cell.y
            seen[key]=true
            local card=cards[key] or newCard(key)
            local info=types[bee.Type] or {}
            local gifted=table.find(bee.Traits or {},"Gifted")~=nil
            local level=bee.Lvl or bee.Level or "?"
            if gifted then giftedCount+=1 end
            card.button.Position=UDim2.fromOffset((cell.x-1)*47,(maxY-cell.y)*47)
            card.button.BackgroundColor3=info.RarityColor3 or Color3.fromRGB(111,127,144)
            card.icon.Image=(gifted and info.GiftedThumbnail or info.Thumbnail) or info.Thumbnail or ""
            card.level.Text=tostring(level)
            card.star.Visible=gifted
            local working=active and active.X==cell.x and active.Y==cell.y
            card.border.Thickness=working and 3 or (gifted and 2 or 1)
            card.border.Color=working and Color3.fromRGB(100,208,255)
                or (gifted and Color3.fromRGB(255,224,80) or Color3.fromRGB(63,74,88))
            card.description=string.format("%s%s • Lv %s • (%d,%d)",gifted and "Gifted " or "",bee.Type,tostring(level),cell.x,cell.y)
            if selected==key then detail.Text=card.description end
        end
        for key,card in pairs(cards) do
            if not seen[key] then
                card.button:Destroy(); cards[key]=nil
                if selected==key then selected=nil; detail.Text="Tap a bee for details" end
            end
        end
        local purchases=(stats.Totals or {}).Purchases or {}
        local slots=math.max(#cells,25+(tonumber(purchases.HiveSlots) or 0))
        summary.Text=string.format("%d bees / %d slots • %d gifted",#cells,slots,giftedCount)
        if #cells==0 then detail.Text="No bees in your hive yet" end
    end
    local function refreshView()
        local ok=pcall(render)
        if not ok then summary.Text="Hive data unavailable; retrying..." end
    end
    viewButton.Activated:Connect(function()
        overlay.Visible=true; statusFrame.Visible=false
        lastFingerprint=nil;fit(); refreshView()
    end)
    close.Activated:Connect(function() overlay.Visible=false; statusFrame.Visible=true end)
    task.spawn(function()
        while gui.Parent do
            if overlay.Visible then refreshView() end
            task.wait(1)
        end
    end)
end
