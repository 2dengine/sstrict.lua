lfs = require('lfs')
require('sstrict')

function scan(path)
  print('scanning:'..path)
  for file in lfs.dir(path) do
    if file ~= '.' and file ~= '..' then
      local full = path..'/'..file
      print(full)
      local attr = lfs.attributes(full)
      if attr.mode == 'directory' then
        scan(full)
      else
        if file:match('%.lua$') then
          dofile(full)
        end
      end
    end
  end
end
scan('.')
