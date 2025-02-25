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

local maxlength = 0
for _, v in ipairs(errors) do
  maxlength = math.max(maxlength, v:len())
end
print(string.rep("=", maxlength + 4))
print(checked..' files scanned')
if #errors > 0 then
  print(string.rep("=", maxlength + 4))
  for _, v in ipairs(errors) do
    print(v)
  end
end
print(string.rep("=", maxlength + 4))
assert(#errors == 0, #errors..' errors found')
print('all done')
