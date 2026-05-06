# Super Strict

## Introduction
Super Strict is a Lua library (compatible with Lua 5.1, 5.2, 5.3 and LuaJIT) that finds undeclared variables and other minor mistakes in your source code.
Super Strict tests your Lua scripts during loading using static analysis.
Super Strict is very secure because it can be used without downloading, installing or running any pre-compiled binaries.

The source code is available on [GitHub](https://github.com/2dengine/sstrict.lua) and the documentation is hosted on [2dengine.com](https://2dengine.com/doc/sstrict.html)

## Installation
Super Strict does not depend on third party modules or binaries.
Just include the "sstrict.lua" file and any subsequent calls to "require","dofile","loadfile" or "loadstring" will be checked through Super Strict.
```Lua
require('sstrict')
```

## Usage
In most cases you should not run Super Script in production code.
Static analysis is CPU intensive and can potentially slow down your scripts.
A better option is to write a script that iterates and checks all of the .lua files in your project during development.
Here is a script that recursively scans all .lua files within a specific directory using the LuaFileSystem module:

```
local lfs = require('lfs')
local ss = require('sstrict')
local function scan(path)
  for file in lfs.dir(path) do
    if file ~= '.' and file ~= '..' then
      local full = path..'/'..file
      local attr = lfs.attributes(full)
      if attr.mode == 'directory' then
        scan(full)
      else
        if file:match('%.lua$') then
          print(full)
          assert(ss.parseFile(full))
        end
      end
    end
  end
end
print('scanning...')
scan('.')
```
To exclude a specific Lua file from being checked by SuperStrict place the line `--!strict` at the top of your source code.

## Examples

### Undefined globals
```Lua
function foo()
  a = 5 -- undefined variable 'a'
  -- _G.a = 5
end
```
Most of the time, you should keep the global variables in your Lua code to a minimum.
If you need to assign a new global variable without upsetting SuperStrict, please use the following syntax: `_G.a = {}`

### Unused variables
```Lua
function bar(a, b)
  local c = a + b -- unused variable 'c'
  return a, b
end
function buzz(a, b)
  local a, b = bar() -- unused variable 'a'
  -- local _, b = bar()
  return b
end
```
The underscore (`_`) symbol can be used to label unused variables: `local _, b = bar()`

### Redefinition of variable names
```Lua
for i = 1, 10 do
  for i = 1, 10 do -- variable name 'i' redefinition
  -- for _ = 1, 10 do
    print(i)
  end
end
```
To avoid this error, please use the underscore (`_`) symbol: `for _ = 1, 10 do`

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

### Invalid precision
```Lua
local n = .01234567890123456 -- invalid number precision: .01234567890123456
local n = 9876543210.9876543 -- invalid number precision: 9876543210.9876543
n = .0123456789012345
n = 9876543210.987654
```
Numeric precision may vary depending on how your Lua interpreter was compiled.
For 64-bit versions of Lua, the precision is about 15-16 digits.
Please note that numeric precision is determined by the total significant digits, not just digits after the decimal point.

## Continuous Integration
Super Strict provides a reusable workflow that allows you to validate all new commits pushed to your GitHub repository.
First, make sure that GitHub Actions are enabled for your repository.
Create a file in your repository titled ".github/workflows/validate.yml" and paste the following code:
```
name: Lua Validation
on: [workflow_dispatch,push]
jobs:
  lua-validation:
    uses: 2dengine/sstrict.lua/.github/workflows/validate.yml@main
    with:
      lua-version: "5.1"
```
You may need to change the "lua-version" input depending on your environment (for example, LuaJIT uses 5.1)
Lastly, go to the "Actions" tab of your repository to confirm that your code has passed the validation successfully.
Here is what the validation scan looks like:
```
1. /utils/pure/speak.lua
2. /utils/pure/oo.lua
/utils/pure/oo.lua:40: undefined variable 'global'
/utils/pure/oo.lua:41: undefined variable 'test'
3. /ux/scrollbar.lua
4. /ux/slider.lua
5. /ux/window.lua

5 files scanned

2 errors found
```
You can also trigger the validation manually by clicking on the "Run Workflow" button.


## Credits
grump, pgimeno, MrFariator and the rest of the Love2D community

sstrict.lua is not related in any way to the strict.lua library

Please support our work so we can release more free software in the future.