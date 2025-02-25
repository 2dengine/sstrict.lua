_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')
ss.panic = false

local checked = 0
local nerrors = 0
local function scan(path)
  for _, file in ipairs(lfs.getDirectoryItems(path)) do
    if file ~= '.' and file ~= '..' then
      local full = path..'/'..file
      if lfs.getRealDirectory(full) ~= sav then
        local attr = lfs.getInfo(full)
        if attr and attr.type == 'directory' then
          scan(full)
        else
          if file:match('%.lua$') then
            print("scanning:"..full)
            checked = checked + 1
            local ok, err = strict.parseFile(src..full)
            if not ok then
              for _, v in ipairs(err) do
                print(v)
              end
              nerrors = nerrors + #err
            end
          end
        end
      end
    end
  end
end

print('starting scan...')
scan('')
print('scanned:'..checked)
assert(nerrors == 0, 'errors found:'..nerrors)
