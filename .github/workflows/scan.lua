local lfs = require('lfs')
local sstrict = require('sstrict')

function scan(path)
  for file in lfs.dir(path) do
    if file ~= '.' and file ~= '..' then
      local full = path..'/'..file
      local attr = lfs.attributes(full)
      if attr.mode == 'directory' then
        scan(full)
      else
        if file:match('%.lua$') then
          print(full)
          sstrict.parseFile(full)
          dofile(full)
        end
      end
    end
  end
end
print('scanning...')
scan('.')
print('all done')
