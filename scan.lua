_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')
ss.panic = false

local checked = 0
local nerrors = 0
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
            nerrors = nerrors + 1
          end
        end
      end
    end
  end
end

print('scanning...')
scan('.')
print("scanned:"..checked)
assert(nerrors == 0, "errors:"..nerrors)
print('all done')
