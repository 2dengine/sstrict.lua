--require("sstrict")

local function try(src, expect, msg)
  local res, err = pcall(loadstring, src)
  if type(err) ~= "string" then
    err = nil
  end
  print(err and "INVALID" or "VALID")
  print(src)
  if err then
    assert(msg and err:match(msg), err)
    print(err)
  end
  print("\n")
  assert(res == expect, err or "TEST FAILED")
end

-- undeclared
try([[local function myFunc() a = 5 end]], false, "undefined variable 'a'")
try([[a = 'undeclared']], false, "undefined variable 'a'")
try([[_G['undeclared'] = a]], false, "undefined variable 'a'")

-- var reuse
try([[local list = {1,2,3} for i, v in ipairs(list) do for i, w in ipairs(list) do end end return list]], false, "variable name 'i' redefinition")
try([[return function(a) local a = 5 return a end]], false, "variable name 'a' redefinition")
try([[return function(a) local a, b, a = 2 math.randomseed(a) end]], false, "variable name 'a' redefinition")

-- empty blocks
try([[for i = 1, 100 do end]], false, "empty code block")
try([[local list = {1,2,3} for _ in ipairs(list) do end]], false, "empty code block")
try([[while true do end]], false, "empty code block")
try([[repeat until true]], false, "empty code block")
try([[return function(a, b) end]], true)
try([[local function oops() os.clock() end]], true)
try([[local obj = {} function obj:baz() end return obj]], true)
try([[while os.clock() do end]], true)
try([[while _G['a'] do end ]], true)
try([[while _G.a do end ]], true)

-- unnecessary code block
try([[for i = 1, 100 do local z = i z = z + 1 end]], false, "unnecessary code block")
try([[return function(a,b,c) local d = 5 d = d + 1 end]], false, "unnecessary code block")
try([[return function(a,b,c) local d = a+b+c d=d+1 end]], true)
try([[return function(q) q = q + 1 end]], true)
try([[return function() io = nil end]], true)


-- unused vars
try([[local function cc() local a, b = os.clock() end]], false, "unused variable 'a'")
try([[local function cc() local a, b = os.clock() return b end]], true)

-- literals
try([[_G['q']={0x1ULL,0x1LL,0x1ull,0x1ll,1ULL,1LL,0x1p1,12.5i}]], true)
try([[_G['q']={"1 \"2\"",""}]], true)
try([[return (5+3)/3*.2]], true)
try("return [-----[ [--[boo]--] ]-----], 123, '\''", true)
try("-- ok [[ comment ]] -- ok", true)
try('--["p"]={ img="123.png" },', true)
try([=[
return function(item, other) 
  if --[[other.isSlope or]] other.isSolid then
    return "cross"
  end
end
]=], true)

try([[print("a\"b")]], true)
try([[return "\"житното зърно,"]], true)
try([[return "житното зърно,"]], true)

-- assignment values count
try([[local a,b=1,2,3 return a]], false, "too many values in assignment")
try([[local a,b,c=1,2 return a]], true)
try([[local a,b,c=unpack(_G) return a]], true)

-- constant condition
try([[if true then print('ok') end]], false, "constant if/else condition")
try([[if 2+2 > 3 then print('ok') end]], false, "constant if/else condition")
try([[local a = 0 while true do a = a + 1 end return a]], true)

-- table constructor duplicates
try([[return { ['a'] = 1, a = 1 }]], false, "duplicate field in table constructor 'a'")
try([[return { [1] = 1, 1 }]], false, "duplicate field in table constructor '1'")
try([[return { [1+2^3*4%5] = 1, 1,2,3 }]], false, "duplicate field in table constructor '3'")
try([[return { ['a' .. 4]=1, a4=1 }]], false, "duplicate field in table constructor 'a4'")
