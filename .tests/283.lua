local function cc() local a, b = os.clock() return b end

local function oops() os.clock() end

local obj = {} function obj:baz() end return obj

while os.clock() do end

while _G['a'] do end

while _G.a do end

return function(a,b,c) local d = a+b+c d=d+1 end

-- ok [[ comment ]] -- ok

--["p"]={ img="123.png" },

print("a\"b")

local a,b=1,2,3 return a

local a = 0 while true do a = a + 1 end return a

