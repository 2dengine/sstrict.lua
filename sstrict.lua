local tokens =
{
  -- number
  int = "%d+%.?",
  intex = "%d+[Ee][%-%+]?%d+",
  float = "%d*%.%d+[Ii]?",
  floatex = "%d*%.%d+[Ee][%-%+]?%d+",
  hex = "0[Xx]%x+",
  hexp1 = "0[Xx]%x+%.?[Pp][%-%+]?%d+",
  hexp2 = "0[Xx]%x-%.%x+[Pp][%-%+]?%d+",
  hex64 = "0[Xx]%x+[Uu]?[Ll][Ll]",
  int64 = "%d+%.?[Uu]?[Ll][Ll]",
  -- string
  squo = "'([^\n]-)'",
  dquo = '"([^\n]-)"',
  esquo = "''",
  edquo = '""',
  mstr = "%[%[(.-)%]%]",
  mstr1 = "%[=%[(.-)%]=%]",
  mstr2 = "%[==%[(.-)%]==%]",
  mstr3 = "%[==%[(.-)%]===%]",
  -- identifier, keyword
  ident = "[_%a][_%w]*",
  -- comment
  comment = "%-%-([^\n%[][^\n]*)",
  comment2 = "%-%-(%[[^\n%[][^\n]*)",
  ecomment = "%-%-(\n)",
  mc = "%-%-%[%[(.-)%]%]",
  mc1 = "%-%-%[=%[(.-)%]=%]",
  mc2 = "%-%-%[==%[(.-)%]==%]",
  mc3 = "%-%-%[===%[(.-)%]===%]",
  -- operators
  lparen = "%(",
  rparen = "%)",
  lbrace = "%[",
  rbrace = "%]",
  lbracket = "{",
  rbracket = "}",
  assign = "=",
  comma = ",",
  colon = ":",
  semicolon = ";",
  minus = "%-",
  plus = "%+",
  hash = "#",
  percent = "%%",
  caret = "%^",
  multiply = "%*",
  divide = "/",
  lt = "<",
  gt = ">",
  dot = "%.",
  cat = "%.%.",
  arg = "%.%.%.",
  rop = "[~><=]=",
  -- space
  space = "%s",
}

local ptokens = {}
for t, p in pairs(tokens) do
  local q = {}
  if not p:match("[^%%][%(%)%.%+%-%*%?%[%]%^%$]") and not p:match("%%[acdlpsuwxz]") then
    -- simple token without matching
    q[1] = p:gsub("%%(.)", "%1")
    assert(#q[1] > 0)
  else
    -- pattern-matching tokens must begin with ^
    if p:byte(1) ~= 94 then
      q[1] = '^'..p
    end
    -- include ignored characters around captures
    q[2] = p:gsub("([^%%])([%(%)])", "%1")
  end
  ptokens[t] = q
end

local lex = {}
local stx = {}
local par = {}
local api = {}

-- Tries a number of patterns and returns the longest match
-- The "longest match" is not necessarily the "longest capture" but the longest lexeme
-- @param source Source string
-- @param pattern Table of token types to Lua patterns
-- @param offset Offset index
-- @param return Token type, capture and string
function lex.pmatch(source, patterns, offset)
  local token
  local capture
  local lexeme
  local maxlen = 0
  -- try each pattern and find the longest match
  for t, p in pairs(patterns) do
    -- todo: two or more matches of the same length
    if p[2] then
      -- pattern matching
      local c = source:match(p[1], offset)
      if c then
        local l = source:match(p[2], offset)
        if #l > maxlen then
          token = t
          capture = c
          lexeme = l
          maxlen = #l
        end
      end
    else
      -- simple string comparison
      local l = p[1]
      if #l > maxlen and source:sub(offset, offset + #l - 1) == l then
        token = t
        capture = l
        lexeme = l
        maxlen = #l
      end
    end
  end
	return token, capture, lexeme
end

-- Converts source string to a list of tokens
-- @param source Source string
-- @param patterns Table of token types to Lua patterns
-- @param return List of tokens
function lex.tokenize(source, patterns)
  local found = {}
  local count = 0
  local offset = 1
  local linen = 1
  local last
  while offset <= #source do
    -- get the next lexeme
    local t, c, l = lex.pmatch(source, patterns, offset)
    if t == nil then
      local z = source:sub(offset, offset + 1)
      api.error("unexpected character in stream:"..z, linen)
      break
    end
    -- add new token or append to last
    count = count + 1
    last = { token = t, capture = c, raw = l, line = linen }
    found[count] = last
    local _, n = l:gsub("\n", "")
    linen = linen + n
    -- advance the character stream
    offset = offset + #l
  end
  return found
end

local lookup =
{
  keyword = {"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while"},
  number = {"int","intex","float","floatex","hex","hex64","int64","hexp1","hexp2"},
  string = {"squo","esquo","dquo","edquo","mstr","mstr1","mstr2","mstr3"},
  padding = {"space","comment","comment2","ecomment","mc","mc1","mc2","mc3"},
  sep = {"comma","semicolon"},

  uniop = {"not","minus","hash"},
  binop = {"and","or","plus","minus","divide","multiply","percent","caret","gt","lt","dot","cat","rop"},
  literal = {"nil","false","true","number","string","arg"},
  
  expression = {"lbracket","lparen","ident","nil","false","true","function","number","string","arg","not","minus","hash"},
  pexpression = {"colon","lparen","lbracket","string"},
  varaccess = {"lbrace","dot"},
  stat = {"ident","lparen","do","while","repeat","if","for","function","local"},
}

for k, list in pairs(lookup) do
  local t = {}
  for _, v in ipairs(list) do
    t[v] = true
  end
  lookup[k] = t
end

function stx.tableconstructor()
  local t = {}
  local c = 0
  par.expect("lbracket")
  while not par.check("rbracket") do
    local k
    if par.check("lbrace") then
      -- [exp] = exp
      par.nextsym()
      k = stx.expression()
      par.expect("rbrace")
      par.expect("assign")
      stx.expression()
    elseif par.check("ident") and par.lookahead("assign") then
      -- ident = exp
      k = par.expect("ident").capture
      par.expect("assign")
      stx.expression()
    else
      -- exp
      c = c + 1
      k = c
      stx.expression()
    end
    if k ~= nil then
      if t[k] then
        api.error("duplicate field in table constructor '"..k.."'")
      end
      t[k] = true
    end
    if par.checklist(lookup.sep) then
      par.nextsym()
    end
  end
  par.expect("rbracket")
end

function stx.call(scope)
  repeat
    -- :ident(args)
    if par.check("colon") then
      par.nextsym()
      par.expect("ident")
    end
    stx.args()
    if par.checklist(lookup.varaccess) then
      scope = stx.varaccess(scope)
    end
  until not par.checklist(lookup.pexpression)
  return scope
end

function stx.prefixexp()
  local n
  if par.check("lparen") then
    -- (exp)
    par.nextsym()
    n = stx.expression()
    par.expect("rparen")
  else
    -- ident
    local id = par.expect("ident")
    par.access(id.capture)
  end
  if par.checklist(lookup.varaccess) then
    n = stx.varaccess(n)
  end
  return n
end

function stx.functioncall()
  local n = stx.prefixexp()
  return stx.call(n)
end

function stx.args()
  if par.check("lparen") then
    -- (explist)
    par.nextsym()
    if not par.check("rparen") then
      stx.explist()
    end
    par.expect("rparen")
  elseif par.check("lbracket") then
    -- {tableconstructor}
    stx.tableconstructor()
  else
    -- "string"
    par.expect("string")
  end
  par.funccall = par.mark()
end

function stx.funcbody()
  par.push()
  par.expect("lparen")
  if par.check("arg") then
    -- (...)
    par.nextsym()
  elseif not par.check("rparen") then
    -- (namelist, ...)
    stx.namelist("argument")
    if par.check("comma") then
      par.nextsym()
      par.expect("arg")
    end
  end
  par.expect("rparen")
  par.push()
  stx.block()--false)
  par.pop()
  par.expect("end")
  par.pop()
end

function stx.term()
  local n
  if par.checklist(lookup.literal) then
    -- number
    local q = par.nextsym()
    local t = q.token
    if t == "number" then
      n = tonumber(q.capture)
    elseif t == "true" then
      n = true
    elseif t == "false" then
      n = false
    elseif t == "string" then
      n = q.capture
    end
  elseif par.check("function") then
    -- closure
    par.expect("function")
    stx.funcbody()
  elseif par.check("lparen") or par.check("ident") then
    -- expression
    n = stx.prefixexp()
    -- optional call
    if par.checklist(lookup.pexpression) then
      n = stx.call(n)
    end
  elseif par.check("lbracket") then
    -- tableconstructor
    stx.tableconstructor()
  else
    local q = par.nextsym()
    q = q and q.capture or "EOF"
    api.error("invalid expression '"..q.."'")
  end
  return n
end

function stx.expoexp()
  local a = stx.term()
  if par.check("caret") then
    local s = par.nextsym()
    local b = stx.expoexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.unaryexp()
  if par.checklist(lookup.uniop) then
    local s = par.nextsym()
    local a = stx.unaryexp()
    local ta = type(a)
    if ta == "number" and s.token == "minus" then
      a = -a
    elseif ta == "boolean" and s.token == "not" then
      a = not a
    end
    return a
  end
  return stx.expoexp()
end

function stx.muldivexp()
  local a = stx.unaryexp()
  while par.check("divide") or par.check("multiply") or par.check("percent") do
    local s = par.nextsym()
    local b = stx.unaryexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.addsubexp()
  local a = stx.muldivexp()
  while par.check("plus") or par.check("minus") do
    local s = par.nextsym()
    local b = stx.muldivexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.concatexp()
  local a = stx.addsubexp()
  if par.check("cat") then
    local s = par.nextsym()
    local b = stx.concatexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.relational()
  local a = stx.concatexp()
  while par.check("rop") or par.check("lt") or par.check("gt") do
    local s = par.nextsym()
    local b = stx.concatexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.logical()
  local a = stx.relational()
  while par.check("and") do
    local s = par.nextsym()
    local b = stx.relational()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.expression()
  local a = stx.logical()
  while par.check("or") do
    local s = par.nextsym()
    local b = stx.logical()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.explist()
  local n = {}
  while true do
    local e = stx.expression()
    table.insert(n, e or false)
    if not par.check("comma") then
      break
    end
    par.nextsym()
  end
  return n
end

function stx.varlist(kind)
  local n = {}
  while true do
    local var = par.expect("ident")
    table.insert(n, var)
    if par.checklist(lookup.varaccess) then
      var = stx.varaccess(var)
    end
    if par.check("lparen") or par.check("colon") then
      stx.call(var)
    end
    if not par.check("comma") then
      break
    end
    par.nextsym()
  end
  for _, v in ipairs(n) do
    par.access(v.capture)
  end
  return n
end

function stx.namelist(kind)
  local n = {}
  while true do
    local id = par.expect("ident")
    table.insert(n, id)
    if not (par.check("comma") and par.lookahead("ident")) then
      break
    end
    par.nextsym()
  end
  for _, v in ipairs(n) do
    par.define(v, kind, n)
  end
  return n
end

function stx.varaccess(scope)
  par.tableaccess = par.mark()
  repeat
    local n
    if par.check("lbrace") then
      -- [exp]
      par.expect("lbrace")
      n = stx.expression()
      par.expect("rbrace")
    else
      -- .ident
      par.expect("dot")
      n = par.expect("ident")
    end
    scope = n
  until not par.checklist(lookup.varaccess)
  return scope
end

function stx.assignorcall()
  -- var, var, var, ... = explist
  local lhs = stx.varlist()
  if par.check("assign") then
    par.expect("assign")
    local rhs = stx.explist()
    if #lhs < #rhs then
      api.error("too many values in assignment")
    end
  end
end

function stx.ifcondition()
  local i, l = par.mark()
  stx.expression()
  
  if par.varaccess < i then
    api.error("constant if/else condition", l)
  end

  par.expect("then")
  stx.neblock()
end

function stx.ifstatement()
  par.expect("if")
  par.push()
  stx.ifcondition()
  par.pop()
  while par.check("elseif") do
    par.nextsym()
    par.push()
    stx.ifcondition()
    par.pop()
  end
  if par.check("else") then
    par.nextsym()
    par.push()
    stx.neblock()
    par.pop()
  end
  par.expect("end")
end

function stx.doblock()
  par.push()
  par.expect("do")
  stx.neblock()
  par.expect("end")
  par.pop()
end

function stx.whileloop()
  par.push()
  local i = par.mark()
  par.expect("while")
  stx.expression()
  par.expect("do")
  if par.funccall <= i and par.tableaccess <= i then
    stx.neblock()
  else
    stx.block()
  end
  par.expect("end")
  par.pop()
end

function stx.repeatloop()
  par.push()
  par.expect("repeat")
  local i, v = par.mark()
  stx.block()--false)
  local j, w = par.mark()
  par.expect("until")
  stx.expression()

  if i == j and par.funccall <= j and par.tableaccess <= j then
    api.error("empty code block", i)
  end

  par.pop()
end

function stx.forloop()
  par.push()
  par.expect("for")
  if par.lookahead("comma") or par.lookahead("in") then
    stx.namelist("lvariable")
    par.expect("in")
    stx.explist()
  else
    local id = par.expect("ident")
    par.define(id, "variable")
    par.expect("assign")
    stx.expression()
    par.expect("comma")
    stx.expression()
    if par.check("comma") then
      par.nextsym()
      stx.expression()
    end
  end
  par.expect("do")
  stx.neblock()
  par.expect("end")
  par.pop()
end

function stx.functiondef()
  par.expect("function")
  local id = par.expect("ident")
  par.access(id.capture)
  while par.check("dot") do
    par.nextsym()
    par.tableaccess = par.mark()
    par.expect("ident")
  end
  if par.check("colon") then
    par.nextsym()
    par.inclass = par.inclass + 1
    par.push()
    local sid = { token = "ident", capture = "self", raw = "self", line = par.line }
    par.define(sid, "class")
    par.expect("ident")
    stx.funcbody()
    par.pop()
    par.inclass = par.inclass - 1
  else
    stx.funcbody()
  end
end

function stx.localdef()
  par.expect("local")
  if par.check("function") then
    par.nextsym()
    local id = par.expect("ident")
    par.define(id, "variable")
    stx.funcbody()
  else
    local lhs = stx.namelist("variable")
    if par.check("assign") then
      par.nextsym()
      local rhs = stx.explist()

      if #lhs < #rhs then
        api.error("too many values in assignment")
      end
    end
  end
end

function stx.stat()
  if par.check("ident") or par.check("lparen") then
    stx.assignorcall()
  elseif par.check("do") then
    stx.doblock()
  elseif par.check("while") then
    stx.whileloop()
  elseif par.check("repeat") then
    stx.repeatloop()
  elseif par.check("if") then
    stx.ifstatement()
  elseif par.check("for") then
    stx.forloop()
  elseif par.check("function") then
    stx.functiondef()
  elseif par.check("local") then
    stx.localdef()
  end
end

function stx.chunk()
  while not par.done() and not par.check("return") and not par.check("break") do
    if par.checklist(lookup.stat) then
      stx.stat()
    else
      break
    end
    if par.check("semicolon") then
      par.nextsym()
    end
  end
  if par.check("return") then
    par.nextsym()
    par.upvaccess[par.top] = true
    if par.checklist(lookup.expression) then
      stx.explist()
    end
  elseif par.check("break") then
    par.nextsym()
    par.upvaccess[par.top] = true
  end
  if par.check("semicolon") then
    par.nextsym()
  end
end

function stx.block()
  local i = par.mark()
  stx.chunk()
  
  if par.mark() > i and not par.upvaccess[par.top] then
    api.error("unnecessary code block")
  end
end

function stx.neblock()
  local i = par.mark()
  stx.block()

  if par.mark() == i then
    api.error("empty code block")
  end
end

function par.reset(stream)
  par.stream = stream
  par.index = 0
  par.line = 0

  par.inclass = 0
  par.funccall = 0
  par.tableaccess = 0
  par.varaccess = 0
  par.upvaccess = {}
  par.top = {}
  par.stack = { par.top }
  
  par.nextsym()
  
  par.push()
  stx.block()
  par.pop()
end

function par.done()
  return par.index > #par.stream
end

function par.nextsym()
  local old = par.stream[par.index]
  par.index = par.index + 1
  local new = par.stream[par.index]
  if new then
    par.panic = new.panic
    par.line = new.line
  end
  return old
end

function par.mark()
  par.position = par.index
  return par.index, par.line
end

function par.rewind()
  par.index = par.position - 1
  par.position = nil
  par.nextsym()
end

function par.expect(a)
  local sym = par.stream[par.index]
  if not sym then
    api.error("unexpected end of file")
  elseif sym.token ~= a then
    api.error("unexpected symbol '"..sym.capture.."'", sym.line)
  end
  par.nextsym()
  return sym
end

function par.lookahead(a)
  local s = par.stream[par.index + 1]
  return s and s.token == a
end

function par.check(a)
  local sym = par.stream[par.index]
  return sym and sym.token == a
end

function par.checklist(t)
  local sym = par.stream[par.index]
  return sym and t[ sym.token ]
end

function par.runop(s, a, b)
  local r
  if s == "caret" then
    r = a^b
  elseif s == "divide" then
    r = a/b
  elseif s == "multiply" then
    r = a*b
  elseif s == "percent" then
    r = a%b
  elseif s == "plus" then
    r = a+b
  elseif s == "minus" then
    r = a-b
  elseif s == "cat" then
    r = a..b
  end
  return r
end

function par.runbinop(t, a, b)
  if a and b then
    local ok, res = pcall(par.runop, t.token, a, b)
    if ok then
      return res
    end
  end
end

function par.push()
  par.top = setmetatable({}, { __index = par.top })
  table.insert(par.stack, par.top)
end

function par.pop()
  local old = table.remove(par.stack)
  for k, v in pairs(old) do
    if v.refs == 0 and k ~= "_" then
      if (v.kind == "lvariable") or (v.kind == "variable" and v.list and v.list.refs == 0) then
        api.error("unused variable '"..k.."'", v.line)
      end
    end
  end
  par.top = par.stack[#par.stack]
end

function par.define(s, k, l)
  local id = s.capture
  if id == "_" then
    return
  end
  if par.top[id] and k ~= "class" then
    api.error("variable name '"..id.."' redefinition")
  end
  s.refs = 0
  s.kind = k
  if l then
    s.list = l
    l.refs = l.refs or 0
  end
  par.top[id] = s
end

function par.access(k)
  if k == "_" then
    return
  end
  par.varaccess = par.index
  local s = par.top[k]
  if s or _G[k] then
    for i = #par.stack, 1, -1 do
      local v = par.stack[i]
      if rawget(v, k) then
        break
      end
      par.upvaccess[v] = true
    end
    if s then
      s.refs = s.refs + 1
      if s.list then
        s.list.refs = s.list.refs + 1
      end
    end
  else
    api.error("undefined variable '"..k.."'")
  end
end


function api.error(what, line)
  line = line or par.line
  local src = api.where or "?"
  if line then
    src = src..":"..line
  end
  local func = print
  if par.panic and api.panic then
    src = "\n"..src
    func = error
  end
  func(src..": "..what)
end

function api.parse(source, where)
  if not where then
    where = source
    if #where > 32 then
      where = where:sub(1, 32):gsub("%s*$", "").."..."
    end
    where = where:gsub("\n", " ")
  end
  
  api.where = where

  -- ignore first line if it starts with #
  source = source:gsub("^#[^\n]\n", "")

  -- quick hack for the string escape problem
  source = source:gsub('([^\\])\\"', '%1 ')
  source = source:gsub("([^\\])\\'", "%1 ")

  -- strip comments
  local stream = {}
  local j = 1
  local q = true
  for _, v in ipairs(lex.tokenize(source, ptokens)) do
    if v.token == "comment" and v.capture:match("%!strict") then
      q = not q
    end
    if not lookup.padding[ v.token ] then
      stream[j] = v
      v.panic = q
      j = j + 1
    end
  end

  -- merge
  for _, t in ipairs(stream) do
    local k = t.token
    if k == "ident" then
      if lookup.keyword[ t.capture ] then
        t.token = t.capture
      end
    elseif lookup.number[k] then
      t.token = "number"
    elseif lookup.string[k] then
      t.token = "string"
    end
  end

  par.reset(stream)
end

function api.parseFile(path)
  local f = io.open(path, "r")
  if f then
    local source = f:read("*all")
    f:close()
    api.parse(source, path)
    return true
  end
  return false
end

local _loadstring = loadstring
function api.loadstring(source, ...)
  api.parse(source, ...)
  return _loadstring(source, ...)
end

local _loadfile = loadfile
function api.loadfile(path, ...)
  api.parseFile(path, ...)
  return _loadfile(path, ...)
end

local _dofile = dofile
function api.dofile(path, ...)
  api.parseFile(path)
  return _dofile(path, ...)
end

local _require = require
function api.require(rpath, ...)
  local path = rpath:gsub("%.", "/")
  local list = {}
  if love and love.filesystem then
    list[1] = love.filesystem.getRequirePath()
    list[2] = love.filesystem.getSource().."/?.lua"
  end
  for q in string.gmatch(package.path..";", "([^;]+)") do
    table.insert(list, q)
  end
  for _, q in ipairs(list) do
    q = q:gsub("%?", path):gsub("\\", "/")
    if api.parseFile(q) then
      break
    end
  end
  return _require(rpath, ...)
end

api.panic = true

loadstring = api.loadstring
loadfile = api.loadfile
dofile = api.dofile
require = api.require

return api