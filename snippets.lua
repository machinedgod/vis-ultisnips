-- Config
-- menu app? dmenu, vis-menu...
menuapp = 'dmenu -l 5'
snippetfiles = '/home/john/.vim/bundle/vim-snippets/UltiSnips/'

--------------------------------------------------------------------------------

local function quoted(p)
  return lpeg.S('"') * p * lpeg.S('"')
end

local tsep               = lpeg.S(' ')
local tws                = tsep ^ 1
local tnewline           = lpeg.S('\n')
local tlowcasedword      = lpeg.R('az') ^ 1
local tdigit             = lpeg.locale()['digit']
local talphanum          = lpeg.locale()['alnum']
local tanyprintable      = lpeg.locale()['print']
local ttabtriggercomplex = quoted (tlowcasedword * lpeg.S('()[]?0123456789-')^1)
-- TODO This is just retarded
local ttabtriggerweird   = lpeg.S('!') * (lpeg.R('az') + lpeg.S('?()')) ^ 1 * lpeg.S('!')
local ttabtriggerweird2  = lpeg.P('#!')
local ttabtrigger        = ttabtriggercomplex + ttabtriggerweird + ttabtriggerweird2 + tlowcasedword
local tdescription       = quoted (lpeg.Cg( (tanyprintable - lpeg.S('"'))^1, 'description'))
local toption            = lpeg.R('az')

local tstartsnippet = lpeg.P('snippet') * tws * lpeg.Cg(ttabtrigger, 'tabtrigger') * tws * tdescription * tws ^ 0 * lpeg.Cg(toption^0, 'options')
local tendsnippet   = lpeg.P('endsnippet')
local tcontentline  = tanyprintable + lpeg.R(' \t')
local tcontent      = ((lpeg.S(' \t') + tanyprintable)^1 - tendsnippet) * tnewline
local tsnippet      = tstartsnippet * tnewline * ((tendsnippet * tnewline) + lpeg.Cg(tcontent ^ 1, 'content'))

local tcomment  = lpeg.S('#') * tanyprintable^0 * tnewline
local tpriority = lpeg.P('priority') * tws * lpeg.Cg(lpeg.S('-')^0 * tdigit^1, 'priority')

-- TODO doesn't work
local tsnippetsfile = ((lpeg.Ct(tsnippet) + tpriority + tcomment + tnewline) - -1) ^ 1

--------------------------------------------------------------------------------

-- Parses the snippet's content to create a table we later use
-- to corrently insert the text, the selections, and the default values
local function create_content(str)
  local content = {}
  content.str = str
  
  local alltags = str:gmatch('${[^}]+}') -- TODO this is the error, tags without default values have format '$%d+'
  for tag in alltags do
    local f = tag:gmatch('[^${}:]+') -- TODO this fails if there's no default value!
    local sel = {}
    sel.tagnum = f()
    sel.tagdefaultval = f()
    
    -- Replace this tag with its default value in the 'str'
    content.str = content.str:gsub(tag, sel.tagdefaultval)
    
    local start, end_ = str:find(tag)
    -- TODO This should NOT happen, but it does, and it needs to be bugfixed
    if start == nil then
      start = 0
    end
    if end_ == nil then
      end_ = 0
    end
    
    content[sel.tagnum] = { selstart = start - 1, selend = end_ - (4 + #sel.tagnum) }
  end
    --[[
    -- Either append to selections array in existing tag, or
    -- create a new tag and add a first entry
    if content[sel.tagnum] == nil then
      sel.selections = {}
      table.insert(sel.selections, { selstart = start - 1, selend = end_ - (4 + #sel.tagnum) }) -- These arithmetics are to account for ${ and }
      content[sel.tagnum] = sel
    else
      local existing = content[sel.tagnum]
      table.insert(content[sel.tagnum].selections, { selstart = start, selend = end_ })
    end
  end
  --]]
  
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
  
  local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | " .. menuapp, "r")
  local chosen = stdout:lines()()
  local success, msg, status = stdout:close()
  if success then
    local trigger = chosen:gmatch('[^ ]+')()
    local snipcontent = snippets[trigger].content
    file:insert(pos, snipcontent.str)
    --win.selection.pos = pos + #snipcontent.str

    if snipcontent['1'] ~= nil then
      vis.mode = vis.modes.VISUAL
      win.selection.range = { start  = pos + snipcontent['1'].selstart
                            , finish = pos + snipcontent['1'].selend 
                            }
    else
      win.selection.pos = pos + #snipcontent.str
    end
    
    -- TODO multiple selections and selection switching (using marks, or jumplist?)
    --win.selection.range = allselections[1].range
    --win.selections = mk_vis_selections(pos, snipcontent["1"])
  else
    vis:info(msg)
  end
end, "Insert a snippet")

