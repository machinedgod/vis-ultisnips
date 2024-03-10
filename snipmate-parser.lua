--------------------------------------------------------------------------------
-- Module table

local M = {}

local lpeg = require('lpeg')

--local logfile = io.open('snipmate-parser.log', 'w')
local logfile = nil

local function log(entry)
  if logfile then
    logfile:write(entry .. '\n')
  end
end

local function log_close()
  if logfile then
    logfile:close()
  end
end


--------------------------------------------------------------------------------
-- lpeg rules

-- Base definitions
local tws                = lpeg.S' ' ^ 1
local tnewline           = lpeg.S'\n'
local tlowcasedword      = lpeg.R'az' ^ 1
local tdigit             = lpeg.locale()['digit']
local talphanum          = lpeg.locale()['alnum']
local tanyprintable      = lpeg.locale()['print']
local tcontrol           = lpeg.locale()['cntrl']
local ttabtrigger        = tanyprintable ^ 1
local ttag               = lpeg.Cg(lpeg.Cp(), 'selstart')
                           * lpeg.P'${'
                           * lpeg.Cg(tdigit^1, 'tag-order') 
                           * (
                               (lpeg.S':' * lpeg.Cg(talphanum^1, 'default-value') * lpeg.S'}')
                               + lpeg.S'}'
                             )
                           * lpeg.Cg(lpeg.Cp(), 'selend')
local tsnippetdecl       = lpeg.P'snippet' * lpeg.S' ' * lpeg.Cg(ttabtrigger, 'tabtrigger') * tnewline
local tsnippetcontent    = lpeg.C(
                             lpeg.Cp() *
                             (lpeg.S'\t '^1 
                              * (lpeg.Ct(ttag) + tanyprintable)^1
                              * tnewline
                             )^1
                           ) 

-- Constructs
local tsnippet = tsnippetdecl * tsnippetcontent
local tcomment = lpeg.S'#' * tanyprintable^0 * tnewline

-- The way grammar captures:
-- Every snippet gets its own table, and every table has:
-- 'tabtrigger' - the tabtrigger
-- [1]          - full content
-- [2]          - start of snippet content (need to subtract from selstart/selend
-- [3..n]       - tags
local tsnippetsfile = lpeg.Ct((tcomment + lpeg.Ct(tsnippet) + tnewline) ^1)

--------------------------------------------------------------------------------
-- Functions

local function trim_tabs(content)
  local trim = function (s)
    return (string.gsub(s, "^\t(.-)$", "%1"))
  end

  local ret=''
  for str in string.gmatch(content, '([^\n]+)') do
    ret = ret .. trim(str) .. '\n'
  end
  return ret
end

-- Tags are on the top level of th table,
-- defined starting with index '3'
-- Index '2' is start of the content
-- Structure:
-- { tag-order: int
-- , selstart: int
-- , selend: int
-- , default-value: str
-- }
local function extract_tags(tableau)
  local tags = {}
  for k,v in ipairs(tableau) do
    if k >= 3 then -- Only process starting with ix 2
      tags[k - 2] = { selstart = v.selstart - tableau[2] - 1
                    , selend   = v.selend   - tableau[2] - 1
                    , default  = v['default-value']
                    , order    = v['tag-order']
                    }
      log('tag ' .. tostring(tags[k-2].order) .. ': ' .. tostring(tags[k-2].selstart) .. '/' .. tostring(tags[k-2].selend))
--      vis:message('snippet ' .. tableau.tabtrigger .. ' tag ' .. tostring(tags[k-1].order) .. ' has start/end: ' .. tostring(tags[k-1].selstart) .. '/' .. tostring(tags[k-1].selend))
    end
  end
  return tags
end

M.load_snippets = function(snippetfile)
  log('*** start ***')

  snippets = {}
  flag = false

  local f = io.open(snippetfile, 'r')
  if f then
    local content = f:read("*all")

    -- TODO hmmm, this'll make whole file unsuable, when it could
    --      in fact have usable snippets
    local m = tsnippetsfile:match(content)
    if not m then
      vis:info('Failed to parse SnipMate file: '.. snippetfile)
      return nil
    else
      -- k is index of snippet definition, v is table of snippet def
      for _,v in pairs(m) do
        snippets[v.tabtrigger] = { description = nil 
                                 , options     = {}
                                 , content = { str  = trim_tabs(v[1])
                                             , tags = extract_tags(v)
                                             }
                                 }
      end
    end

    f:close()
    flag = true
  else
    flag = false
  end

  log('*** end ***')
  log_close()
  return snippets, flag
end

--------------------------------------------------------------------------------
-- End module

return M
