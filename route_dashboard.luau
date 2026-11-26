-- Local 3D constellation. Only cached route snapshots and owned GUI are used.
local D={}
function D.layout(snapshot)
    local nodes={}
    for _,stage in ipairs(snapshot.stages or {}) do
        for index,row in ipairs(stage.gear) do
            local angle=index*2.4
            local radius=1.2+math.sqrt(index)*1.15
            nodes[#nodes+1]={row=row,stage=stage.index,
                x=math.sin(stage.index*1.35)*8+math.cos(angle)*radius,
                y=(3.5-stage.index)*10+math.sin(angle)*radius,
                z=math.sin(index*1.7+stage.index)*2.5}
        end
    end
    return nodes
end
function D.mount(gui,showWindow,snapshot,describe,openList)
    local make=FeatherTheme.make
    local run=game:GetService("RunService")
    local input=game:GetService("UserInputService")
    local overlay=make("Frame","RouteDashboard",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(4,7,12),BackgroundTransparency=0.08,Visible=false,Active=true,ZIndex=40})
    local panel=make("Frame","DashboardPanel",overlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(880,560),BackgroundColor3=Color3.fromRGB(12,16,22),BorderSizePixel=0,ZIndex=41})
    make("UICorner","Corners",panel,{CornerRadius=UDim.new(0,18)})
    make("UIStroke","Outline",panel,{Color=Color3.fromRGB(63,83,103),Transparency=.3})
    local scale=make("UIScale","Fit",panel,{Scale=1})
    local function label(name,parent,props)
        props.BackgroundTransparency=1;props.TextColor3=Color3.fromRGB(222,235,244)
        props.Font=Enum.Font.GothamMedium;props.TextSize=props.TextSize or 13;props.ZIndex=props.ZIndex or 45
        props.TextXAlignment=Enum.TextXAlignment.Left;props.TextWrapped=true
        return make("TextLabel",name,parent,props)
    end
    local heading=label("Title",panel,{Position=UDim2.fromOffset(22,14),Size=UDim2.fromOffset(540,26),Text="FEATHER  /  PROGRESSION ATLAS",TextSize=18})
    local summary=label("Summary",panel,{Position=UDim2.fromOffset(22,45),Size=UDim2.fromOffset(650,36),Text="Reading cached progression..."})
    local map=make("Frame","Constellation",panel,{Position=UDim2.fromOffset(16,92),Size=UDim2.fromOffset(555,424),BackgroundColor3=Color3.fromRGB(5,9,15),BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=42})
    make("UICorner","Corners",map,{CornerRadius=UDim.new(0,14)})
    local viewport=make("ViewportFrame","StarMap3D",map,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Ambient=Color3.fromRGB(190,210,235),LightColor=Color3.new(1,1,1),ZIndex=42})
    local camera=make("Camera","OrbitCamera",viewport,{FieldOfView=48})
    viewport.CurrentCamera=camera
    local world=make("WorldModel","LocalConstellation",viewport,{})
    local icons=make("Frame","GearNodes",map,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=44})
    local details=make("ScrollingFrame","GearDetails",panel,{Position=UDim2.fromOffset(590,92),Size=UDim2.fromOffset(272,424),BackgroundColor3=Color3.fromRGB(23,28,37),BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=43})
    make("UICorner","Corners",details,{CornerRadius=UDim.new(0,14)})
    local art=make("ImageLabel","GearImage",details,{Position=UDim2.fromOffset(82,16),Size=UDim2.fromOffset(108,108),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,Image=FeatherTheme.featherIcon,ZIndex=44})
    local preview=make("ViewportFrame","GearPreview3D",details,{Position=UDim2.fromOffset(60,8),Size=UDim2.fromOffset(150,125),BackgroundTransparency=1,Ambient=Color3.new(.85,.85,.85),LightColor=Color3.new(1,1,1),ZIndex=45})
    local previewCamera=make("Camera","Camera",preview,{FieldOfView=45});preview.CurrentCamera=previewCamera
    local previewWorld=make("WorldModel","Preview",preview,{})
    local title=label("GearName",details,{Position=UDim2.fromOffset(16,132),Size=UDim2.fromOffset(238,50),Text="Select a gear node",TextSize=19})
    local detail=label("Requirements",details,{Position=UDim2.fromOffset(16,190),Size=UDim2.new(1,-32,0,0),AutomaticSize=Enum.AutomaticSize.Y,Text="Click any star to inspect its gear and requirements.",TextYAlignment=Enum.TextYAlignment.Top})
    local legend=label("Legend",panel,{Position=UDim2.fromOffset(20,522),Size=UDim2.fromOffset(650,26),Text="CYAN  owned     VIOLET  current target     GOLD  upcoming   ·   Drag to orbit" ,TextSize=11})
    local function button(name,text,x,width,callback)
        local b=make("TextButton",name,panel,{Position=UDim2.fromOffset(x,16),Size=UDim2.fromOffset(width,28),Text=text,BackgroundColor3=Color3.fromRGB(34,44,58),TextColor3=Color3.fromRGB(225,238,250),Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0,ZIndex=46})
        make("UICorner","Corners",b,{CornerRadius=UDim.new(0,8)});b.Activated:Connect(callback)
        return b
    end
    local nodes,connections={},{}
    local selected,rotation,tilt,elapsed,lastPaint=nil,0,0,0,0
    local dragging,lastPoint=false,nil
    local currentSnapshot
    local previewModel,previewDistance
    local function geometry(source,parent)
        if typeof(source)~="Instance" or not (source:IsA("Model")or source:IsA("BasePart")or source:IsA("Accessory")or source:IsA("Folder"))then return nil end
        local ok,clone=pcall(function()return source:Clone()end)
        if not ok or not clone then return nil end
        local model=make("Model","GearModel",parent,{})
        clone.Parent=model
        local parts=0
        for _,part in ipairs(model:GetDescendants())do
            if part:IsA("LuaSourceContainer")or part:IsA("Constraint")or part:IsA("JointInstance")or part:IsA("Sound")then part:Destroy()
            elseif part:IsA("BasePart")then parts+=1;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end
        end
        if parts==0 then model:Destroy();return nil end
        local bounds,size=model:GetBoundingBox()
        model:PivotTo(CFrame.new(-bounds.Position)*model:GetPivot())
        return model,math.max(size.X,size.Y,size.Z,.1)
    end
    local function uiIdentity()
        local setter=setthreadidentity or setidentity
        if type(setter)=="function" then setter(8) end
    end
    local function choose(node)
        selected=node
        title.Text="Stage "..node.stage.." · "..node.row.id
        art.Image=node.row.icon or FeatherTheme.featherIcon
        previewWorld:ClearAllChildren();previewModel=nil
        local model,size=geometry(node.row.model,previewWorld)
        if model then previewModel=model;previewDistance=size*1.9;art.Visible=false else art.Visible=true end
        detail.Text=describe(node.row,currentSnapshot.honey)
    end
    local function color(row)
        return row.current and Color3.fromRGB(178,128,255)or row.owned==true and Color3.fromRGB(100,238,220)
            or row.shopAccess==false and Color3.fromRGB(108,123,145)or Color3.fromRGB(237,221,138)
    end
    local function renderSnapshot(data)
        currentSnapshot=data
        for _,node in ipairs(nodes)do node.button:Destroy()end
        nodes={};world:ClearAllChildren()
        summary.Text="Gear stage "..tostring(data.currentStage or (data.complete and "Complete"or"Inspecting"))
            .."  ·  "..tostring(data.currentGear or "No current gear").."\nHive: "..tostring(data.hiveStage or "Inspecting").."  ·  "..tostring(data.occupied or "?").." / "..tostring(data.capacity or "?").." slots"
        local previous
        for index,node in ipairs(D.layout(data))do
            node.position=Vector3.new(node.x,node.y,node.z);node.color=color(node.row)
            node.ball=make("Part","Star_"..index,world,{Shape=Enum.PartType.Ball,Size=Vector3.new(.45,.45,.45),Position=node.position,Anchored=true,CanCollide=false,Material=Enum.Material.Neon,Color=node.color})
            local model,size=geometry(node.row.model,world)
            if model then model:ScaleTo(model:GetScale()*1.8/size);model:PivotTo(CFrame.new(node.position))end
            if previous then
                local gap=node.position-previous
                make("Part","Connection_"..index,world,{Size=Vector3.new(.045,.045,gap.Magnitude),CFrame=CFrame.lookAt((previous+node.position)/2,node.position),Anchored=true,CanCollide=false,Material=Enum.Material.Neon,Color=Color3.fromRGB(82,124,142),Transparency=.35})
            end
            previous=node.position
            node.button=make("ImageButton","GearNode_"..index,icons,{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(31,31),BackgroundColor3=Color3.fromRGB(15,24,31),BackgroundTransparency=model and 1 or .12,Image=node.row.icon or (not model and FeatherTheme.featherIcon or ""),ScaleType=Enum.ScaleType.Fit,AutoButtonColor=false,ZIndex=44})
            make("UICorner","Round",node.button,{CornerRadius=UDim.new(1,0)})
            node.stroke=make("UIStroke","Glow",node.button,{Color=node.color,Thickness=node.row.current and 2.5 or 1,Transparency=.1})
            node.name=label("Name",node.button,{Position=UDim2.fromOffset(-48,33),Size=UDim2.fromOffset(128,30),Text=node.row.id,TextSize=10,Visible=node.row.current,ZIndex=47})
            node.name.TextXAlignment=Enum.TextXAlignment.Center
            node.button.Activated:Connect(function()choose(node)end)
            nodes[#nodes+1]=node
        end
        selected=nil
        for _,node in ipairs(nodes)do if node.row.current then choose(node);break end end
        if not selected and nodes[1]then choose(nodes[1])end
        gui:SetAttribute("FeatherRouteNodes",#nodes)
    end
    local function refresh()
        local ok,data=pcall(snapshot);uiIdentity()
        if ok and data then renderSnapshot(data)else summary.Text="Route data is loading. Press Refresh to try again."end
    end
    local refreshButton=button("RefreshRoute","Refresh",630,70,refresh)
    local listButton=button("RouteList","List",708,58,function()overlay.Visible=false;showWindow(true);if openList then openList()end end)
    local closeButton=button("CloseRoute","Close",774,82,function()overlay.Visible=false;showWindow(true)end)
    local function fit()
        local size=overlay.AbsoluteSize
        local portrait=size.X<620 and size.Y>size.X
        local width,height=portrait and 420 or 880,portrait and 760 or 560
        panel.Size=UDim2.fromOffset(width,height)
        heading.Size=UDim2.fromOffset(portrait and 390 or 540,26);heading.TextSize=portrait and 15 or 18
        summary.Size=UDim2.fromOffset(portrait and 390 or 650,44)
        map.Position=UDim2.fromOffset(portrait and 12 or 16,portrait and 128 or 92)
        map.Size=UDim2.fromOffset(portrait and 396 or 555,portrait and 350 or 424)
        details.Position=UDim2.fromOffset(portrait and 12 or 590,portrait and 490 or 92)
        details.Size=UDim2.fromOffset(portrait and 396 or 272,portrait and 214 or 424)
        art.Position=UDim2.fromOffset(portrait and 16 or 82,16)
        preview.Position=UDim2.fromOffset(portrait and 0 or 60,8)
        title.Position=UDim2.fromOffset(portrait and 154 or 16,portrait and 12 or 132)
        title.Size=UDim2.fromOffset(portrait and 226 or 238,50)
        detail.Position=UDim2.fromOffset(portrait and 154 or 16,portrait and 72 or 190)
        detail.Size=UDim2.new(1,portrait and -170 or -32,0,0)
        legend.Position=UDim2.fromOffset(20,portrait and 714 or 522)
        legend.Size=UDim2.fromOffset(portrait and 380 or 650,32)
        refreshButton.Position=UDim2.fromOffset(portrait and 14 or 630,portrait and 92 or 16)
        listButton.Position=UDim2.fromOffset(portrait and 92 or 708,portrait and 92 or 16)
        closeButton.Position=UDim2.fromOffset(portrait and 324 or 774,portrait and 92 or 16)
        if size.X>24 and size.Y>24 then scale.Scale=math.min(1,(size.X-24)/width,(size.Y-24)/height)end
    end
    connections[#connections+1]=overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    connections[#connections+1]=map.InputBegan:Connect(function(event)
        if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then dragging=true;lastPoint=event.Position end
    end)
    connections[#connections+1]=input.InputChanged:Connect(function(event)
        if dragging and (event.UserInputType==Enum.UserInputType.MouseMovement or event.UserInputType==Enum.UserInputType.Touch)then
            local p=event.Position;if lastPoint then rotation+=(p.X-lastPoint.X)*.005;tilt=math.clamp(tilt+(p.Y-lastPoint.Y)*.003,-.32,.32)end;lastPoint=p
        end
    end)
    connections[#connections+1]=input.InputEnded:Connect(function(event)
        if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then dragging=false;lastPoint=nil end
    end)
    connections[#connections+1]=run.RenderStepped:Connect(function(dt)
        if not overlay.Visible or not gui.Enabled then return end
        elapsed+=dt;lastPaint+=dt;if lastPaint<1/30 then return end;lastPaint=0
        if not dragging then rotation+=dt*.1 end
        local aspect=map.AbsoluteSize.X/math.max(1,map.AbsoluteSize.Y)
        local distance=math.max(65,36/aspect)
        camera.CFrame=CFrame.Angles(tilt,math.sin(rotation)*.22,0)*CFrame.new(0,0,distance)
        if previewModel then previewCamera.CFrame=CFrame.Angles(-.12,elapsed*.35,0)*CFrame.new(0,0,previewDistance)end
        for _,node in ipairs(nodes)do
            local p=camera.CFrame:PointToObjectSpace(node.position)
            local depth=-p.Z;local tangent=math.tan(math.rad(camera.FieldOfView/2))
            node.button.Visible=depth>0
            if depth>0 then
                node.button.Position=UDim2.fromScale(.5+p.X/(2*depth*tangent*aspect),.5-p.Y/(2*depth*tangent))
                local pulse=node.row.current and 1+math.sin(elapsed*3)*.12 or 1
                node.button.Size=UDim2.fromOffset(31*pulse,31*pulse)
                node.stroke.Transparency=node.row.current and .2+.18*math.sin(elapsed*3)or .2
                node.name.Visible=node==selected or node.row.current
            end
        end
    end)
    gui.Destroying:Connect(function()for _,connection in ipairs(connections)do connection:Disconnect()end end)
    return function()uiIdentity();overlay.Visible=true;showWindow(false);fit();refresh()end
end
return D
