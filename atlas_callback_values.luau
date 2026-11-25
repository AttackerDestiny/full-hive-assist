-- Preserve callback state cells while exposing values wrapped by Atlas's VM.
return function(reader,callback)
    local raw=reader(callback)
    if type(raw)~="table" then return {} end
    local values={}
    for _,value in pairs(raw) do
        values[#values+1]=value
        if type(value)=="table" and type(rawget(value,5))=="number"
            and type(rawget(value,6))=="table" and rawget(value,4)~=nil then
            values[#values+1]=rawget(value,4)
        end
    end
    return values
end
