# SUPERSTRICT for LUA

Super Strict is a pure Lua library that finds undeclared variables and other minor mistakes in your source code through static analysis.
You do not need to execute any code to find your mistakes: Super Strict will check the code during loading.
Just include the "sstrict.lua" file and any subsequent calls to "require","dofile","loadfile" or "loadstring" will be checked through Super Strict.
To exclude a specific Lua file from the being checked just place the "--!strict" line at the top of your source code.

## Installation
Simply include the sstrict.lua file:
```Lua
require('sstrict.lua')
```

## Undefined and unused variables
```Lua
function foo()
  a = 5 -- undefined variable 'a'
end
function bar(a, b)
  local c = a + b -- unused variable 'c'
  return a + b
end
```

## Redefinition of variable names
```Lua
for i = 1, 10 do
  for i = 1, 10 do
    -- variable name 'i' redefinition
  end
end
```

## Empty and unnecessary code blocks
```Lua
for i = 1, 3 do
  -- empty code block error
end
function baz()
  local n = 5
  n = n - 1 -- unnecessary code block error
end
```

## Constant conditions
```Lua
if 5+5 > 11 then
  -- constant condition error in if/else statement
end
```

## Too many values in assignment
```Lua
a = 1, 2 -- too many values on the right-hand side in assignment
```

## Duplicate variables, arguments and table fields
```Lua
t =
{ 
  ['a'] = 100,
  a = 100 -- duplicate field 'a' in table constructor
}
for b, b in pairs(t) do
  -- duplicate lvariable 'b'
end
c, c = 1, 2 -- duplicate variable 'c'
function foo(d, d)
  -- duplicate argument 'd'
end
```

## Credits
grump, pgimeno, MrFariator and the rest of the Love2D community
https://love2d.org/forums/viewtopic.php?f=5&t=90074

sstrict.lua is not related in any way to the strict.lua library