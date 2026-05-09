_G.love = _G.love or {}
_G.jit = _G.jit or {}
_G.ffi = _G.ffi or {}

local lfs = require('lfs')
local ss = require('sstrict')

print('scanning...')

print('\n')

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
          local ok, err = ss.parseFile(full, false)
          print(checked..". "..full)
          if not ok and err then
            for _, v in ipairs(err) do
              print(v)
              table.insert(errors, v)
            end
          end
        end
      end
    end
  end
end

scan(arg[1] or '.')

if checked > 0 then
  print('')
  print(checked..' files scanned')
  print(#errors..' errors found')
end