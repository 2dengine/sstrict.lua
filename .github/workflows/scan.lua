_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')

local n = 0
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
          local ok, err = strict.parseFile(src..full)
          if not ok then
            print(err)
            n = n + 1
          end
        end
      end
    end
  end
end
print('scanning...')
scan('.')
assert(n == 0, n.." errors found")
print('all done')
