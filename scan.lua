_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')
ss.panic = false

local checked = 0
local errors = {}
local function scan(path)
  for file in lfs.dir(path) do
    if file ~= '.' and file ~= '..' then
      local full = path..'/'..file
      local attr = lfs.attributes(full)
      if attr.mode == 'directory' then
        scan(full)
      elseif attr.mode == 'file' then
        if file:match('%.lua$') then
          print(full)
          checked = checked + 1
          local ok, err = ss.parseFile(full)
          if not ok then
            print(err)
            for _, v in ipairs(err) do
              table.insert(errors, v)
            end
          end
        end
      end
    end
  end
end

print('scanning...')
scan('.')

local maxlength = 60
local function printr(v)
  if v:len() > maxlength then
    v = v:sub(-(maxlength - 4))
  end
  print('| '..v..string.rep(" ", maxlength - v:len() - 4).." |")
end
local row = "+"..string.rep("=", maxlength - 2).."+"
print(row)
printr(checked..' files scanned')
print(row)
if #errors > 0 then
  for _, v in ipairs(errors) do
    printr(v)
  end
  print(row)
end
printr(#errors.." errors found")
print(row)
assert(#errors == 0, #errors..' errors found')
