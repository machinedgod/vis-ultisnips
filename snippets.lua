--------------------------------------------------------------------------------
-- Config
-- menu app? dmenu, vis-menu...
menuapp = 'dmenu -l 5 '
snippetfiles = '/home/john/.vim/bundle/vim-snippets/UltiSnips/'



--------------------------------------------------------------------------------
-- lpeg rules

local tsep               = lpeg.S' '
local tws                = tsep ^ 1
local tnewline           = lpeg.S'\n'
local tlowcasedword      = lpeg.R'az' ^ 1
local tdigit             = lpeg.locale()['digit']
local talphanum          = lpeg.locale()['alnum']
local tanyprintable      = lpeg.locale()['print']
local tcontrol           = lpeg.locale()['cntrl']
local function quoted(p) return lpeg.S('"') * p * lpeg.S('"') end
local function anythingbut(ch) return (tanyprintable + tcontrol) - lpeg.S(ch) end

local ttabtriggercomplex = quoted (tlowcasedword * lpeg.S'()[]?0123456789-'^1)
-- TODO This is just retarded
local ttabtriggerweird   = lpeg.S'!' 
                         * (lpeg.R'az' + lpeg.S'?()') ^ 1 
                         * lpeg.S'!'
local ttabtriggerweird2  = lpeg.P'#!'
local ttabtrigger        = ttabtriggercomplex 
                         + ttabtriggerweird 
                         + ttabtriggerweird2 
                         + tlowcasedword
local tdescription       = quoted (lpeg.Cg( (tanyprintable - lpeg.S'"')^1, 'description'))
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
-- Helper functions

-- Parses the snippet's content to create a table we later use
-- to corrently insert the text, the selections, and the default values
local function create_content(str)
  local content = {}
  content.str   = str
  content.tags  = {}

  local p = vis.lpeg.Ct((lpeg.Ct(ttag) + tanyprintable + tcontrol) ^ 1)
  local m = p:match(str)

  local i = 0
  local j = 0
  for k,v in ipairs(m) do
    content.tags[k] = v
    -- TODO recurse over tag.expr to extract nested tags
    --      Of course this will actually have to be used later on, depending
    --      on whether the tag is added or not

    -- We need to keep track of how much we remove, and readjust all
    -- subsequent selection points
    -- Note to self, I hate all this bookkeeping
    --local tagtext = string.sub(str, v.selstart, v.selend)
    --if v.expr ~= nil then
    --  content.str = string.gsub(content.str, tagtext, v.expr)
    --  local x = #('${'..tostring(k)..':')
    --  i = i + x
    --  j = j + x + #'}'
    --else
    --  content.str = string.gsub(content.str, tagtext, '')
    --  i = i + #'$'
    --  j = j + #'$' + #tostring(k)
    --end
    --content.tags[k].selstart = content.tags[k].selstart - i
    --content.tags[k].selend   = content.tags[k].selend - j
  end
  return content
end


-- Takes a line starting with 'snippet' and a lines iterator, and creates
-- a 'snippet' table to be used
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
  
  local tabtrigger = m.tabtrigger
  local snippet = {}
  snippet.description = m.description
  snippet.options = m.options
  snippet.content = create_content(m.content)
  return tabtrigger, snippet
end


-- Loads all snippets from passed '.snippets' file. Should probably be
-- triggered when new file is loaded or when syntax is set/changed
local function load_snippets(snippetfile)
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
        snippets[tabtrigger] = snippet
      end
    end
    
    io.close(f)
    return snippets, true
  else
    return snippets, false
  end
end


-- Takes list of snippets and concatenates them into the string suitable
-- for passing to dmenu (or, very probably, vis-menu)
local function snippetslist(snippets)
  local list = ''
  
  for k,v in pairs(snippets) do
    list = list .. k .. ' - ' .. v.description .. '\n'
  end
  
  return list
end

-- Creates an array of vis Selection instances to be passed to
-- win.selections
local function mk_vis_selections(pos, tag)
  vissels = {}
  for k,v in pairs(tag.selections) do
    local sel = { range    = { start  = pos + v.selstart
                             , finish = pos + v.selend
                             }
                , anchored = false
                , number   = #vissels + 1
                , pos      = 0
                , col      = 0
                , line     = 0
                }
    table.insert(vissels, sel)
  end
  return vissels
end



--------------------------------------------------------------------------------
-- Plugging it all in

vis:map(vis.modes.INSERT, "<C-x><C-j>", function()
  local snippetfile = snippetfiles .. vis.win.syntax .. '.snippets'
  local snippets, success = load_snippets(snippetfile)
  if not success then
    vis:info('Failed to load a correct snippet: ' .. snippetfile)
    return
  end
  
  local win = vis.win
  local file = win.file
  local pos = win.selection.pos
  
  if not pos then
    return
  end
  -- TODO do something clever here

  -- Use prefix W if exists
  local initial = ' '
  --local prefix = file:text_object_longword(pos-1)
  --if prefix ~= nil then
  --  initial = initial .. file:content(prefix)
  --end


  local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | " .. menuapp, "r")
  --local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | " .. menuapp .. initial, "r")
  local chosen = stdout:lines()()
  local success, msg, status = stdout:close()
  if success then
    local trigger = chosen:gmatch('[^ ]+')()
    local snipcontent = snippets[trigger].content
    --if prefix ~= nil then
    --  file:delete(prefix)
    --end
    vis:insert(snipcontent.str)

    if #snipcontent.tags > 0 then
      vis:info("Creating selections. Use 'g>' and 'g<' to navigate between anchors.")
      vis.mode = vis.modes.VISUAL

      for k,v in ipairs(snipcontent.tags) do
        vis:command('#' .. pos + v.selstart - 1 ..',#' .. pos + v.selend .. ' p')
        vis:command('gs') -- Tested, works without this too, but just in case
      end

      -- Backtrack through selections
      for _ in ipairs(snipcontent.tags) do
        vis:command('g<')
      end
    else
      win.selection.pos = pos + #snipcontent.str
    end
  else
    vis:info(msg)
  end
end, "Insert a snippet")

