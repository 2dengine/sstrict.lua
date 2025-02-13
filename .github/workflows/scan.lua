_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')

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
          assert(ss.parseFile(full))
        end
      end
    end
  end
end
print('scanning...')
scan('.')
print('all done')
