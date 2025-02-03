# Super Strict

## Introduction
Super Strict is a Lua library (compatible with Lua 5.1, 5.3 and LuaJIT 2.1.17) that finds undeclared variables and other minor mistakes in your source code.
Super Strict checks your Lua scripts during loading using static analysis.

The source code is available on [GitHub](https://github.com/2dengine/sstrict.lua) and the documentation is hosted on [2dengine.com](https://2dengine.com/doc/sstrict.html)

## Installation
Super Strict does not depend on third party modules or binaries.
Just require the "sstrict.lua" file and any subsequent calls to "require","dofile","loadfile" or "loadstring" will be checked through Super Strict.
```Lua
require('sstrict.lua')
```

## Usage
In most cases you should not run Super Script in production code.
Static analysis is CPU intensive and can potentially slow down your scripts.
A better option is to write a script that iterates and checks all of the .lua files in your project during development.
To exclude a specific Lua file from being checked place the line "--!strict" at the top of your source code.

## Examples

### Undefined and unused variables
```Lua
function foo()
  a = 5 -- undefined variable 'a'
end
function bar(a, b)
  local c = a + b -- unused variable 'c'
  return a + b
end
```

### Redefinition of variable names
```Lua
for i = 1, 10 do
  for i = 1, 10 do
    -- variable name 'i' redefinition
  end
end
```

### Empty and unnecessary code blocks
```Lua
for i = 1, 3 do
  -- empty code block error
end
function baz()
  local n = 5
  n = n - 1 -- unnecessary code block error
end
```

### Constant conditions
```Lua
if 5+5 > 11 then
  -- constant condition error in if/else statement
end
```

### Too many values in assignment
```Lua
a = 1, 2 -- too many values on the right-hand side in assignment
```

### Duplicate variables, arguments and table fields
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

sstrict.lua is not related in any way to the strict.lua library

Please support our work so we can release more free software in the future.