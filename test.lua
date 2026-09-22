local sstrict = require("sstrict")

local ntests = 0
local passed = 0
local errors = {}
local function try(src, expect, msg)
  ntests = ntests + 1
  local res, err = pcall(sstrict.loadstring, src)
  if res == false then
    err = tostring(err)
    err = err:match('^.+:%d+: (.+)$')
  end
  if type(err) ~= "string" then
    err = ""
  end
  if (res ~= expect) then -- or (msg and err ~= msg) then
    err = ntests..'. expected: '..tostring(expect)..' got: '..tostring(res)..'\n'..src..'\n'..err
    print(err)
    table.insert(errors, err)
  else
    passed = passed + 1
  end
end

print('unit testing super strict')

sstrict.setOptions({
  panic = true,
  warnings = true,
  lua = '5.4',
  jit = true,
})

-- undeclared
try([[local function myFunc() a = 5 end]], false, "undefined variable 'a'")
try([[a = 'undeclared']], false, "undefined variable 'a'")
try([[_G['undeclared'] = a]], false, "undefined variable 'a'")

-- var reuse
try([[local list = {1,2,3} for i, v in ipairs(list) do for i, w in ipairs(list) do end end return list]], false, "variable name 'i' redefinition")
try([[return function(a) local a = 5 return a end]], false, "variable name 'a' redefinition")
try([[return function(a) local a, b, a = 2 math.randomseed(a) end]], false, "duplicate variable 'a'")

-- empty blocks
try([[for i = 1, 100 do end]], false, "empty code block")
try([[local list = {1,2,3} for _ in ipairs(list) do end]], false, "empty code block")
try([[while true do end]], false, "empty code block")
try([[repeat until true]], false, "empty code block")

-- unnecessary code block
try([[for i = 1, 100 do local z = i z = z + 1 end]], false, "unnecessary code block")
try([[return function(a,b,c) local d = 5 d = d + 1 end]], false, "unnecessary code block")

-- unused vars
try([[local function cc() local a, _ = os.clock() end]], false, "unused variable 'a'")
try([[local function cc() local _, b = os.clock() end]], false, "unused variable 'b'")

-- assignment values count
try([[local a,b=1,2,3 return a]], false, "too many values in assignment")

-- constant condition
try([[if true then print('ok') end]], false, "constant if/else condition")
try([[if 2+2 > 3 then print('ok') end]], false, "constant if/else condition")

-- table constructor duplicates
try([[return { ['a'] = 1, a = 1 }]], false, "duplicate field 'a' in table constructor")
try([[return { [1] = 1, 1 }]], false, "duplicate field '1' in table constructor")
try([[return { [1+2^3*4%5] = 1, 1,2,3 }]], false, "duplicate field '3' in table constructor")
try([[return { ['a' .. 4]=1, a4=1 }]], false, "duplicate field 'a4' in table constructor")

try([[return .0123456789012345678]], false, "invalid number precision: .0123456789012345678")
try([[return .012345678901234567]], false, "invalid number precision: .012345678901234567")
try([[return .01234567890123456]], false, "invalid number precision: .01234567890123456")
try([[return 9876543210.9876543]], false, "invalid number precision: 9876543210.9876543")
try([[return .0123456789012345]], true)
try([[return 987654321.0123456]], true)

try([[return function(q) q = q + 1 end]], true)
try([[return function() io = nil end]], true)

-- literals
try([[_G['q']={0x1ULL,0x1LL,0x1ull,0x1ll,1ULL,1LL,0x1p1,12.5i}]], true)


sstrict.setOptions({
  panic = false,
  warnings = false,
  lua = '5.3',
  jit = false,
})

for i = 1, 10000 do
  local full = './.tests/'..i..'.lua'
  local file = io.open(full, 'r')
  if not file then
    break
  end
  local cont = file:read('*a')
  file:close()
  try(cont, true)
end

print(ntests..' tests completed')
print(passed..' tests passed')
print(#errors..' errors found')
