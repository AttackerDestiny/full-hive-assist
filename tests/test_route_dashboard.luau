return function(D,P)
    local passed=0
    local function check(ok,m)assert(ok,m);passed+=1 end
    local snapshot={stages={}}
    local total=0
    for i,stage in ipairs(P.stages)do
        local group={index=i,gear={}}
        for _,name in ipairs(stage.gear)do total+=1;group.gear[#group.gear+1]={id=name,owned=total%2==0,current=total==12}end
        snapshot.stages[#snapshot.stages+1]=group
    end
    local nodes=D.layout(snapshot);local again=D.layout(snapshot)
    check(#nodes==total and total==39,"Dashboard includes the complete current route")
    local seen={}
    for i,node in ipairs(nodes)do
        check(not seen[node.row.id],"No duplicate constellation gear nodes")
        seen[node.row.id]=true
        check(node.x==node.x and node.y==node.y and node.z==node.z and math.abs(node.x)<32 and math.abs(node.y)<40 and math.abs(node.z)<1,"Finite layout fits the overview camera")
        check(node.x==again[i].x and node.y==again[i].y and node.z==again[i].z,"Refresh preserves deterministic locations")
    end
    check(nodes[12].row.current and snapshot.stages[1].gear[12].current,"Layout preserves current target metadata")
    check(#D.layout({stages={}})==0,"Loading/empty route is supported")
    for _,size in ipairs({{555,424},{396,350}})do
        local width,height=size[1],size[2];local aspect=width/height
        local distance=D.distance(nodes,aspect)
        local points={}
        for _,node in ipairs(nodes)do
            local x,y=D.project(node,distance,aspect,width,height)
            check(x>18 and x<width-18 and y>18 and y<height-18,"Fit view includes complete node hit targets")
            for _,p in ipairs(points)do
                check(math.abs(p.x-x)>38 or math.abs(p.y-y)>38,"Pulsing node hit targets do not overlap at fit zoom")
            end
            points[#points+1]={x=x,y=y}
        end
    end
    return {passed=passed}
end
