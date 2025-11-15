_G.love = _G.love or {}
_G.jit = _G.jit or {}
_G.ffi = _G.ffi or {}

local lfs = require('lfs')
local ss = require('sstrict')
ss.panic = false

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
          local ok, err = ss.parseFile(full)
          local out = checked..". "..full
          local n = 0
          if not ok and err then
            for _, v in ipairs(err) do
              --print(v)
              table.insert(errors, v)
              n = n + 1
            end
          end
          if n > 0 then
            out = out..' ('..n..' errors)'
          end
          print(out)
        end
      end
    end
  end
end

scan(arg[1] or '.')

print('\n')
print(checked..' files scanned')
print('\n')
if #errors > 0 then
  for _, v in ipairs(errors) do
    print(v)
  end
  print('\n')
end
print(#errors.." errors found")
print('\n')
assert(#errors == 0, #errors..' errors found')
