-- Minimal value objects only. No services, HTTP, game client, or remote APIs.
local V={}
local mt={}
function V.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return V.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return V.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul=function(a,b) return V.new(a.X*b,a.Y*b,a.Z*b) end
mt.__index=function(a,k) if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
V.zero=V.new(0,0,0)
local env=setmetatable({Vector3=V,Enum={RaycastFilterType={Include=1,Exclude=2},PositionAlignmentMode={OneAttachment=1},EasingStyle={Linear=1},
    PathStatus={Success=1},PathWaypointAction={Jump=1}},
    TweenInfo={new=function(...) return {...} end},RaycastParams={new=function() return {} end}}, {__index=getfenv(0)})
local nativeLoad=loadstring
env.loadstring=function(source,name)
    local chunk,err=nativeLoad(source,name)
    if chunk then setfenv(chunk,env) end
    return chunk,err
end
return env
