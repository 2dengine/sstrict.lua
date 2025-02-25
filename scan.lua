_G.love = {}
_G.jit = {}
_G.ffi = {}

local lfs = require('lfs')
local ss = require('sstrict')
ss.panic = false

print('scanning...')
local maxlength = 60
local function printr(v, length)
  length = length or v:len()
  if length > maxlength then
    v = v:sub(-(maxlength - 4))
  end
  print('\t| '..v..string.rep(" ", maxlength - length - 4).." |")
end
local row = "\t+"..string.rep("=", maxlength - 2).."+"
print(row)

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
          local out = ((not err or #err == 0) and "✓" or " ")
          out = out.." "..full
          printr(out, full:len() + 2)
          if not ok then
            for _, v in ipairs(err) do
              printr(v)
              table.insert(errors, v)
            end
          end
        end
      end
    end
  end
end

scan('.')

print(row)
printr(checked..' files scanned')
print(row)
if #errors > 0 then
  for _, v in ipairs(errors) do
    printr(v)
  end
  print(row)
end
printr(#errors.." errors found")
print(row)
assert(#errors == 0, #errors..' errors found')
