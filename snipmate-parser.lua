--------------------------------------------------------------------------------
-- Module table

local M = {}

local lpeg = require('lpeg')



--------------------------------------------------------------------------------
-- lpeg rules

-- Base definitions
local tws                = lpeg.P' ' ^ 1
local tnewline           = lpeg.P'\n'
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
                               lpeg.P'}'
                               + ( lpeg.P':'
                                 -- Match either reference (since that's
                                 -- what \$[0-9] are) or default value
                                 * ((lpeg.P'$' * lpeg.Cg(tdigit, 'reference-value'))
                                   + lpeg.Cg((talphanum + lpeg.P'.')^1, 'default-value') 
                                   )
                                 * lpeg.P'}'
                                 )
                             )
                           * lpeg.Cg(lpeg.Cp(), 'selend')
local tsnippetdecl       = lpeg.P'snippet' * lpeg.P' ' * lpeg.Cg(ttabtrigger, 'tabtrigger') * tnewline
local tsnippetcontent    = lpeg.C(
                             lpeg.Cp() *
                             (lpeg.S'\t '^1 
                              * (lpeg.Ct(ttag) + tanyprintable)^1
                              * tnewline
                             )^1
                           ) 

-- Constructs
local tsnippet = tsnippetdecl * tsnippetcontent
local tcomment = lpeg.P'#' * tanyprintable^0 * tnewline

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
-- { selstart: int
-- , selend: int
-- , default-value: str
-- , reference-value: int
-- , order: int
-- }
local function extract_tags(tableau)
  local tags = {}
  for k,v in ipairs(tableau) do
    if k >= 3 then -- Only process starting with ix 2
      -- TODO Figured out what's the bug here!!!!
      --      The error of selection increases with newlines; each newline
      --      increases it forth. I don't know if this is LPEG error
      --      or vis selection creation error?
      local bias = 1
      
      tags[k - 2] = { selstart  = v.selstart - tableau[2] - bias
                    , selend    = v.selend   - tableau[2] - bias
                    , default   = v['default-value']
                    , reference = v['reference-value']
                    , order     = v['tag-order']
                    }
--      vis:message('snippet ' .. tableau.tabtrigger .. ' tag ' .. tostring(tags[k-1].order) .. ' has start/end: ' .. tostring(tags[k-1].selstart) .. '/' .. tostring(tags[k-1].selend))
    end
  end
  return tags
end

M.load_snippets = function(snippetfile)
  snippets = {}

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
    return snippets, true
  else
    return snippets, false
  end
end

--------------------------------------------------------------------------------
-- End module

return M
