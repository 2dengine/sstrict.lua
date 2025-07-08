_G.love = {}
_G.jit = {}
_G.ffi = {}

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
          if not ok and err then
            for _, v in ipairs(err) do
              --print(v)
              table.insert(errors, v)
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

scan('.')

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
