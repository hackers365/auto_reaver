function split(s,re)
    local i1 = 1
    local ls = {}
    local append = table.insert
    if not re then re = '%s+' end
    if re == '' then return {s} end
    while true do
    local i2,i3 = s:find(re,i1)
    if not i2 then
    local last = s:sub(i1)
    if last ~= '' then append(ls,last) end
    if #ls == 1 and ls[1] == '' then
    return {}
    else
    return ls
    end
    end
    append(ls,s:sub(i1,i2-1))
    i1 = i3+1
    end
end

function table_slice (values,i1,i2)
    local res = {}
    local n = #values
    -- default values for range
    i1 = i1 or 1
    i2 = i2 or n
    if i2 < 0 then
    i2 = n + i2 + 1
    elseif i2 > n then
    i2 = n
    end
    if i1 < 1 or i1 > n then
    return {}
    end
    local k = 1
    for i = i1,i2 do
    res[k] = values[i]
    k = k + 1
    end
    return res
end

function extend_table(e_table, new_table)
    for i,v in pairs(new_table)
    do
        e_table[i] = v
    end
    return e_table
end
