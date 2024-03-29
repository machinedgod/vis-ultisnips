--------------------------------------------------------------------------------
-- Module table

local M = {}

local lpeg = require('lpeg')



--------------------------------------------------------------------------------
-- lpeg rules

local tsep               = lpeg.S' \t'
local tws                = tsep ^ 1
local tnewline           = lpeg.S'\n'
local tlowcasedword      = lpeg.R'az' ^ 1
local tdigit             = lpeg.locale()['digit']
local talphanum          = lpeg.locale()['alnum']
local tanyprintable      = lpeg.locale()['print']
local tcontrol           = lpeg.locale()['cntrl']
local function surrounded(ch, p) return lpeg.S(ch) * p * lpeg.S(ch) end
local function anythingbut(ch) return (tanyprintable + tcontrol) - lpeg.S(ch) end

local ttabtriggercomplex = surrounded ('"',
                              tlowcasedword * lpeg.S'()[]?0123456789-'^1
                           )
-- TODO This is just retarded
--      Check the actual grammar and see what special starting chars are
--      then relax the grammar a bit
local ttabtriggerweird   = surrounded('!',
                             (lpeg.R'az' + lpeg.S'?()') ^ 1
                           )
local ttabtriggerweird2  = lpeg.P'#!'
local ttabtriggerweird3  = surrounded('/',
                             (anythingbut'/') ^1
                           )
local ttabtrigger        = ttabtriggercomplex
                         + ttabtriggerweird
                         + ttabtriggerweird2
                         + ttabtriggerweird3
                         + (tlowcasedword + lpeg.S'.')
local tdescription       = surrounded ('"',
                              lpeg.Cg( (tanyprintable - lpeg.S'"')^1, 'description')
                           )
local toption            = lpeg.R'az'

local tstartsnippet = lpeg.P'snippet'
                    * tws
                    * lpeg.Cg(ttabtrigger, 'tabtrigger')
                    * tws
                    * tdescription
                    * tws ^ 0
                    * lpeg.Cg(toption^0, 'options')
local tendsnippet   = lpeg.P'endsnippet'

-- The content parsing needs cleanup, its really convoluted due to me learning
-- lpeg while using it
--tcontent      = ((tanyprintable + tcontrol)^1 - tendsnippet) * tnewline
local tcontent = ((lpeg.S' \t' + tanyprintable)^1 - tendsnippet)
               * tnewline
local tsnippet = tstartsnippet
               * tnewline
               * ((tendsnippet * tnewline) + lpeg.Cg(tcontent ^ 1, 'content'))

local tcomment  = lpeg.S'#'
                * tanyprintable^0
                * tnewline
local tpriority = lpeg.P'priority'
                * tws
                * lpeg.Cg(lpeg.S('-')^0 * tdigit^1, 'priority')

-- TODO doesn't work
local tsnippetsfile = (lpeg.Ct(tsnippet) + tpriority + tcomment + tnewline) ^ 1


-- TODO does parse values correctly, but parsing out nested tags will
--      require recursion at the callsite since I have no clue how to do it
local ttag = { 'T'
       ; Expr = lpeg.C((lpeg.V'T' + ((tanyprintable + tcontrol) - lpeg.S'}'))^1)
       , Tnum = lpeg.Cg(tdigit ^ 1, 'tagnum')
       , Ps   = lpeg.Cg(lpeg.Cp(), 'selstart')
       , Pe   = lpeg.Cg(lpeg.Cp(), 'selend')
       , Tc   = lpeg.V'Ps'
                * lpeg.P'${'
                * lpeg.V'Tnum'
                * lpeg.S(':')
                * lpeg.Cg(lpeg.V'Expr', 'expr')
                * lpeg.V'Pe'
                * lpeg.S'}'
       , Ts   = lpeg.V'Ps' * lpeg.S'$' * lpeg.V'Pe' * lpeg.V'Tnum'
       , T    = lpeg.V'Tc' + lpeg.V'Ts'
       }



--------------------------------------------------------------------------------
-- Functions

-- Parses the snippet's content to create a table we later use
-- to corrently insert the text, the selections, and the default values
local function create_content(str)
  local content = {}
  content.str   = str
  content.tags  = {}

  local p = vis.lpeg.Ct((lpeg.Ct(ttag) + tanyprintable + tcontrol) ^ 1)
  local m = p:match(str)

  local s = 1 -- We start from 1 to adjust position from $^0 to ^$0
  for k,v in ipairs(m) do
    content.tags[k] = v
    -- TODO recurse over tag.expr to extract nested tags
    --      Of course this will actually have to be used later on, depending
    --      on whether the tag is added or not

    -- We need to keep track of how much we remove, and readjust all
    -- subsequent selection points
    -- Note to self, I hate all this bookkeeping
    local tagtext = string.sub(str, v.selstart, v.selend)
    if v.expr ~= nil then
      content.str = string.gsub(content.str, tagtext, v.expr)
      content.tags[k].selstart = content.tags[k].selstart - s
      content.tags[k].selend   = content.tags[k].selstart + #v.expr
      s = s + #'${' + #tostring(k) + #':' + 1
    else
      content.str = string.gsub(content.str, tagtext, '')
      content.tags[k].selstart = content.tags[k].selstart - s
      content.tags[k].selend   = content.tags[k].selstart
      s = s + #'$' + 1
    end
  end

  return content
end



-- Takes a line starting with 'snippet' and a lines iterator, and creates
-- a 'snippet' table to be used
-- If it fails it returns nil, otherwise returns two values, a tabtrigger
-- and a snippet
local function create_snippet(line, linesit)
  local snippetstr = line .. '\n'
  -- Read content into list of lines until we hit `endsnippet`
  for line in linesit do
    local s,e = string.find(line, 'endsnippet')
    if s == 1 then
      snippetstr = snippetstr .. 'endsnippet' .. '\n'
      break
    else
      snippetstr = snippetstr .. line .. '\n'
    end
  end

  local p = vis.lpeg.Ct(tsnippet)
  local m = p:match(snippetstr)

  if not m then
    -- Enable this when debugging, otherwise it nukes whole app
    vis:info('Failed to parse some snippets!')
    -- vis:message('Failed to parse snippet: ' .. snippetstr)
    return nil
  else
    local tabtrigger = m.tabtrigger
    local snippet = {}
    snippet.description = m.description
    snippet.options = m.options
    snippet.content = create_content(m.content)
    return tabtrigger, snippet
  end
end



-- Loads all snippets from passed '.snippets' file. Should probably be
-- triggered when new file is loaded or when syntax is set/changed
M.load_snippets = function(snippetfile)
  snippets = {}

  local f = io.open(snippetfile, 'r')
  if f then
    io.input(f)
    local linesit = io.lines()

    for line in linesit do
      -- TODO read whole file, then apply lpeg grammar that parses all
      -- snippets out rather than being pedestrian about it like this
      local s, e = string.find(line, 'snippet')
      -- Find lines that start with 'snippet' and enter
      -- snippet reading loop
      if s == 1 then
        local snippettext
        local tabtrigger, snippet = create_snippet(line, linesit)
        if tabtrigger then
          snippets[tabtrigger] = snippet
        end
      end
    end

    io.close(f)
    return snippets, true
  else
    return snippets, false
  end
end



--------------------------------------------------------------------------------
-- End module

return M