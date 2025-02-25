_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')
ss.panic = false

print('scanning...')
local maxlength = 60
local function printr(v, wrap)
  length = v:len()
  if wrap then
    -- thanks to rsc from https://stackoverflow.com/questions/25527048
    local chunk = maxlength - 4
    for i = 1, length, chunk do
      local out = v:sub(i, i + chunk - 1)
      print('\t| '..out..string.rep(" ", maxlength - out:len() - 4).." |")
    end
  else
    if length > maxlength then
      v = v:sub(-(maxlength - 4))
    end
    print('\t| '..v..string.rep(" ", maxlength - length - 4).." |")
  end
end
local row = "\t+"..string.rep("=", maxlength - 2).."+"
print(row)

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
          checked = checked + 1
          local ok, err = ss.parseFile(full)
          local out = checked..". "..full
          printr(out)
          if not ok and err then
            for _, v in ipairs(err) do
              printr(v, true)
              table.insert(errors, v)
            end
          end
        end
      end
    end
  end
end

scan('.')

print(row)
printr(checked..' files scanned')
print(row)
if #errors > 0 then
  for _, v in ipairs(errors) do
    printr(v, true)
  end
  print(row)
end
printr(#errors.." errors found")
print(row)
assert(#errors == 0, #errors..' errors found')
