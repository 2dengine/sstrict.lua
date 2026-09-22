--[[!
Super Strict for Lua

Copyright (c) 2021 2dengine LLC
https://2dengine.com/

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

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
  -- lua JIT extras
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
  dcolon = "::",
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
  -- binary ops
  idiv = '//',
  band = '&',
  bor = '|',
  bnot = '~',
  shl = '<<',
  shr = '>>',
  -- space
  space = "%s",
}

local lookup =
{
  keyword = {"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","goto"},

  number = {"int","intex","float","floatex","hex","hex64","int64","hexp1","hexp2"},
  string = {"squo","esquo","dquo","edquo","mstr","mstr1","mstr2","mstr3"},
  padding = {"space","comment","comment2","ecomment","mc","mc1","mc2","mc3"},
  sep = {"comma","semicolon"},

  uniop = {"not","minus","hash","bnot"},
  binop = {"and","or","plus","minus","divide","multiply","percent","caret","gt","lt","dot","cat","rop", "idiv","band","bor","bnot","shl","shr"},
  literal = {"nil","false","true","number","string","arg"},
  
  expression = {"lbracket","lparen","ident","nil","false","true","function","number","string","arg","not","minus","hash"},
  pexpression = {"colon","lparen","lbracket","string"},

  varaccess = {"lbrace","dot"},
  stat = {"ident","lparen","do","while","repeat","if","for","function","local","goto","dcolon"},
}

local ptokens = {}
local plookup = {}

local lex = {}
local stx = {}
local par = {}

--- The API module provides programmatic access to Super Strict.
-- @module api
-- @alias api
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
    elseif par.check("ident") and par.check("assign", 1) then
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
        api.warning("duplicate field '"..k.."' in table constructor")
      end
      t[k] = true
    end
    if par.checklist(plookup.sep) then
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
    if par.checklist(plookup.varaccess) then
      scope = stx.varaccess(scope)
    end
  until not par.checklist(plookup.pexpression)
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
  if par.checklist(plookup.varaccess) then
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
    -- func(explist)
    par.nextsym()
    if not par.check("rparen") then
      stx.explist()
    end
    par.expect("rparen")
  elseif par.check("lbracket") then
    -- func {tableconstructor}
    stx.tableconstructor()
  else
    -- func "string"
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
  if par.checklist(plookup.literal) then
    -- number
    local q = par.nextsym()
    local t = q.token
    if t == "number" then
      n = tonumber(q.capture)
      -- check if the number is too large
      if n and n + 1 == n then
        api.warning("invalid number value: "..q.capture)
      end
      -- check for too much precision
      local int, frac = q.capture:match("^%-?([0-9]*)%.([0-9]*)$")
      if int and frac then
        if #int + #frac > api.precision then
          api.warning("invalid number precision: "..q.capture)
        end
      end

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
    if par.checklist(plookup.pexpression) then
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
    local b = stx.unaryexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.unaryexp()
  if par.checklist(plookup.uniop) then
    local s = par.nextsym()
    local a = stx.unaryexp()
    local ta = type(a)
    if ta == "number" and s.token == "minus" then
      a = -a
    elseif ta == "boolean" and s.token == "not" then
      a = not a
    elseif ta == "number" and s.token == "bxor" then
      a = '~'..a
    end
    return a
  end
  return stx.expoexp()
end

function stx.bitop()
  local a = stx.unaryexp()
  while par.check("idiv") or par.check("band") or par.check("bor") or par.check("bxor") or par.check("shl") or par.check("shr") do
    local s = par.nextsym()
    local b = stx.unaryexp()
    a = par.runbinop(s, a, b)
  end
  return a
end

function stx.muldivexp()
  local a = stx.bitop()
  while par.check("divide") or par.check("multiply") or par.check("percent") do
    local s = par.nextsym()
    local b = stx.bitop()
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

function stx.namelist(kind)
  local n = {}
  while true do
    local id = par.expect("ident")
    for i = 1, #n do
      if n[i].capture == id.capture and id.capture ~= '_' then
        api.warning("duplicate "..kind.." '"..id.capture.."'")
      end
    end
    table.insert(n, id)
    if not (par.check("comma") and par.check("ident", 1)) then
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
  -- [ expression1 ][ expression2 ].ident1.ident2
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
  until not par.checklist(plookup.varaccess)
  return scope
end

function stx.vararg()
  local var
  if par.check("lparen") then
    par.expect("lparen")
    var = stx.expression()
    par.expect("rparen")
  else
    var = par.expect("ident")
    par.access(var.capture)
  end
  if par.checklist(plookup.varaccess) then
    stx.varaccess()
  end
  return var
end

function stx.assignorcall()
  local lhs = {}
  local temp = {}
  while true do
    local var = stx.vararg()
    table.insert(lhs, var)
    if var and var ~= '_' then
      if temp[var] then
        api.warning("duplicate variable '"..var.."' on the left-hand side")
      end
      temp[var] = true
    end
    if not par.check("comma") then
      break
    end
    par.nextsym()
  end
  
  if par.check("assign") then
    -- var, var, var, ... = explist
    par.expect("assign")
    local rhs = stx.explist()
    if #lhs < #rhs then
      api.warning("too many values in assignment")
    end
  else
    if par.check("colon") then
      stx.call()
    end
    if par.check('lparen') or par.check('string') or par.check('table') then
      stx.args()
    end
  end
end

function stx.ifcondition()
  local i, l = par.mark()
  stx.expression()
  
  if par.varaccess < i then
    api.warning("constant if/else condition", l)
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
    api.warning("empty code block", i)
  end

  par.pop()
end

function stx.forloop()
  par.push()
  par.expect("for")
  if par.check("comma", 1) or par.check("in", 1) then
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
        api.warning("too many values in assignment")
      end
    end
  end
end

function stx.label()
  par.expect("dcolon")
  par.expect("ident")
  par.expect("dcolon")
end

function stx.gotolabel()
  par.expect("goto")
  par.expect("ident")
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
  elseif par.check("dcolon") then
    stx.label()
  elseif par.check("goto") then
    stx.gotolabel()
  end
end

function stx.chunk()
  --while not par.done() and not par.check("return") and not par.check("break") do
  while not par.done() do
    if par.checklist(plookup.stat) then
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
    if par.checklist(plookup.expression) then
      stx.explist()
    end
  elseif par.check("break") then
    par.nextsym()
    par.upvaccess[par.top] = true
  end
  -- skip all labels after the break/return
  while par.check("dcolon") do
    stx.label()
  end
  if par.check("semicolon") then
    par.nextsym()
  end
end

function stx.block()
  local i = par.mark()
  stx.chunk()
  
  if par.mark() > i and not par.upvaccess[par.top] then
    api.warning("unnecessary code block")
  end
end

function stx.neblock()
  local i = par.mark()
  stx.block()

  if par.mark() == i then
    api.warning("empty code block")
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

function par.check(a, offset)
  offset = offset or 0
  local sym = par.stream[par.index + offset]
  return sym and sym.token == a
end

function par.checklist(t, offset)
  offset = offset or 0
  local sym = par.stream[par.index]
  return sym and t[ sym.token ]
end

local runop = {
  caret = function(a, b) return a^b end,
  divide = function(a, b) return a/b end,
  multiply = function(a, b) return a*b end,
  percent = function(a, b) return a%b end,
  plus = function(a, b) return a+b end,
  minus = function(a, b) return a-b end,
  cat = function(a, b) return a..b end,
}

function par.runbinop(t, a, b)
  if a and b then
    local func = runop[t.token]
    local ok, res = pcall(func, a, b)
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
        api.warning("unused variable '"..k.."'", v.line)
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
    api.warning("variable name '"..id.."' redefinition")
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
    api.warning("undefined variable '"..k.."'")
  end
end

--- Logs severe mistakes and raises an error when the panic option is enabled.
-- @tparam string what Error message
-- @tparam[opt] string line Source code line
function api.error(what, line)
  line = line or par.line
  local src = api.where or "?"
  if line then
    src = src..":"..line
  end
  if api.errors then
    table.insert(api.errors, src..": "..what)
  end
  if api.panic then
    error("\n"..src..": "..what)
  end
end

--- Logs minor mistakes and raises an error when the panic option is enabled.
-- @tparam string what Warning message
-- @tparam[opt] string line Source code line
function api.warning(what, line)
  if api.warnings == false then
    return
  end
  return api.error(what, line)
end

--- Parses the source code string and checks it for mistakes.
-- @tparam string source Source code string
-- @tparam[opt] string where File path name
-- @treturn boolean True if no mistakes were found
-- @treturn table List of errors or nil
function api.parse(source, where)
  if not where then
    where = source
    if #where > 32 then
      where = where:sub(1, 32):gsub("%s*$", "").."..."
    end
    where = where:gsub("\n", " ")
  end
  
  api.where = where
  api.errors = {}

  -- ignore first line if it starts with #
  source = source:gsub("^#[^\n]\n", "")

  -- quick hack for the string escape problem
  source = source:gsub('([^\\])\\"', '%1 ')
  source = source:gsub("([^\\])\\'", "%1 ")
  
  -- skip files starting with --!strict
  if source:match("^[%s]-%-%-!strict[\n\r]") then
    return true
  end

  -- strip comments
  local stream = {}
  local j = 1
  for _, v in ipairs(lex.tokenize(source, ptokens)) do
    if not plookup.padding[ v.token ] then
      stream[j] = v
      j = j + 1
    --else
      --if v.capture:find("[Tt][Oo][Dd][Oo][^%a]") then
        --api.warning("detected 'todo' in comment", v.line)
      --end
    end
  end

  -- merge
  for _, t in ipairs(stream) do
    local k = t.token
    if k == "ident" then
      if plookup.keyword[ t.capture ] then
        t.token = t.capture
      end
    elseif plookup.number[k] then
      t.token = "number"
    elseif plookup.string[k] then
      t.token = "string"
    end
  end

  par.reset(stream)

  return (#api.errors == 0), api.errors
end

--- Scans the Lua source code string for mistakes without actually executing any code.
-- @tparam string source Source code string
-- @treturn boolean True if no mistakes were encountered
-- @treturn string String containing the line number and error message
function api.parseString(source)
  return api.parse(source)
end

--- Scans the Lua script file for mistakes without actually executing any code.
-- @tparam string path File name or path
-- @treturn boolean True if no mistakes were encountered
-- @treturn string String containing the line number and error message
function api.parseFile(path)
  path = path:gsub("\\", "/"):gsub("//", "/")
  local f = io.open(path, "r")
  if f then
    local source = f:read("*a")
    f:close()
    if source then
      return api.parse(source, path)
    end
  end
  return false, "could not parse file:"..path
end

--- Configures how Super Strict works.
-- @tparam table ops Options table containing the following fields: "panic", "warnings", "precision", "jit" and "lua"
function api.setOptions(ops)
  if ops.panic ~= nil then
    api.panic = ops.panic == true
  end
  if ops.warnings ~= nil then
    api.warnings = ops.warnings == true
  end
  if ops.precision then
    local p = ops.precision
    if p == 'auto' then
      p = 0
      while true do
        local x = 1 + 10^(-p)
        if x == 1 then
          break
        end
        p = p + 1
      end
    end
    p = tonumber(p)
    assert(p, "invalid precision in options: '"..ops.precision.."'")
    api.precision = p
  end
  if ops.jit then
    api.jit = ops.jit == true
  end
  if ops.lua then
    api.lua = ops.lua
    local ver = ops.lua:match("5%.%d+") or '5.2'
    ver = ver:gsub('%.', '')
    ver = tonumber(ver) or 51
    
    local ignore_lexemes = {}
    local ignore_tokens = {}
    -- ignore JIT extras
    if not api.jit then
      ignore_lexemes['hex64'] = true
      ignore_lexemes['int64'] = true
    end
    -- ignore goto operator
    if ver <= 51 then
      ignore_lexemes['dcolon'] = true
      ignore_tokens['goto'] = true
    end
    if ver <= 52 then
      ignore_lexemes['idiv'] = true
      ignore_lexemes['band'] = true
      ignore_lexemes['bor'] = true
      ignore_lexemes['bxor'] = true
      ignore_lexemes['shl'] = true
      ignore_lexemes['shr'] = true
    end
    -- build allowed tokens table
    ptokens = {}
    for t, p in pairs(tokens) do
      if not ignore_lexemes[t] then
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
    end
    
    -- build lookup table
    plookup = {}
    for k, list in pairs(lookup) do
      local t = {}
      for _, v in ipairs(list) do
        if not ignore_tokens[v] then
          t[v] = true
        end
      end
      plookup[k] = t
    end
  end
end

local _loadstring = _G.loadstring or _G.load
function api.loadstring(source, ...)
  local ok, err = api.parse(source, ...)
  if not ok then
    return nil, err
  end
  return _loadstring(source, ...)
end

local _loadfile = _G.loadfile
function api.loadfile(path, ...)
  local ok, err = api.parseFile(path)
  if not ok then
    api.error(err)
  end
  return _loadfile(path, ...)
end

local _require = _G.require
function api.require(rpath, ...)
  local path = rpath:gsub("%.", "/")

  local cpath = package.cpath
  local ppath = package.path
  local love = _G.love
  if love and love.filesystem then
    cpath = cpath..";"..love.filesystem.getCRequirePath()
    ppath = ppath..";"..love.filesystem.getRequirePath()
    local src = love.filesystem.getSource()
    ppath = ppath..";"..src.."/?.lua"
    ppath = ppath..";"..src.."/?/init.lua"
  end

  local parsed = false
  for q in string.gmatch(ppath..";", "([^;]+)") do
    local p = q:gsub("%?", path)
    local ok, err = api.parseFile(p)
    if ok then
      parsed = true
      break
    end
  end
  if not parsed then
    -- todo: check if binary
    print("could not check:"..rpath)
  end

  return _require(rpath, ...)
end

-- command line usage
local errors = {}
local checked = 0
for i, v in ipairs(arg) do
  if v == '-ss' then
    for j = i + 1, #arg do
      checked = checked + 1
      local out = checked..". "..arg[j]
      print(out)
      local ok, err = api.parseFile(arg[j], false)
      if not ok and err then
        for _, w in ipairs(err) do
          print(w)
          table.insert(errors, w)
        end
      end
    end
  end
end
if checked > 0 then
  print('')
  print(checked..' files scanned')
  print(#errors..' errors found')
  os.exit(#errors == 0 and 0 or 1, true)
end

api.setOptions({
  panic = true,
  warning = true,
  lua = _VERSION,
  jit = not not _G.jit,
  precision = 'auto',
})

if _G['require'] ~= api.require then
  local func = load and 'load' or 'loadstring'
  _G[func] = api.loadstring
  _G['loadfile'] = api.loadfile
  _G['dofile'] = api.loadfile
  _G['require'] = api.require
end

return api