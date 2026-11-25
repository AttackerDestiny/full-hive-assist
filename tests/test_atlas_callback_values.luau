return function(decode)
    local passed=0
    local function check(value,message) assert(value,message);passed+=1 end
    local function values(raw) return decode(function() return raw end,function() end) end
    local older={true}
    local cell={[4]=false,[5]=1,[6]={}}
    local config={Enabled=true}
    local label={[4]="Stop Everything",[5]=2,[6]={}}
    local wrappedConfig={[4]=config,[5]=3,[6]={}}
    local result=values({older,cell,label,wrappedConfig})
    check(table.find(result,older)~=nil,"Preserves original one-element state")
    check(table.find(result,cell)~=nil,"Preserves actual VM state cell for callback reconciliation")
    check(table.find(result,false)~=nil,"Exposes false wrapped values")
    check(table.find(result,"Stop Everything")~=nil,"Exposes captured label")
    check(table.find(result,config)~=nil,"Exposes captured configuration")
    check(#values({{[4]="other",[5]="unrelated",[6]={}}})==1,"Does not decode an unrelated table")
    check(#values({{[5]=1,[6]={}}})==1,"Handles missing captured values")
    check(#values(nil)==0,"Handles missing callback metadata")
    return {passed=passed}
end
