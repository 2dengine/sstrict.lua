# SUPERSTRICT for LUA

SUPERSTRICT finds undeclared variables and other minor mistakes in your Lua source code through static analysis.
You do not need to execute the code to detect your mistakes: SUPERSTRICT will check your code during loading.
Installation of SUPERSTRICT is SUPER easy.
Just include the "sstrict.lua" file and any subsequent calls to "require","dofile","loadfile" or "loadstring" will be checked through SUPERSTRICT.
To exclude a part of your source code from validation you can use the "--!strict" command.

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

## Thanks
grump, pgimeno, MrFariator and the rest of the Love2D community
https://love2d.org/forums/viewtopic.php?f=5&t=90074