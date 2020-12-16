-- Config
-- menu app? dmenu, vis-menu...
menuapp = 'dmenu -l 5'
snippetfiles = "/home/john/.vim/bundle/vim-snippets/UltiSnips/"


-- Parses the snippet's content to create a table we later use
-- to corrently insert the text, the selections, and the default values
function create_content(str)
  local content = {}
  content.str = str -- TODO replace tags with default values

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

  return content
end


-- Takes a line starting with 'snippet' and a lines iterator, and creates
-- a 'snippet' table to be used
function create_snippet(line, linesit)
  -- Process initial line
  -- Grab the description first
  local tokens = string.gmatch(line, '[^\"]+')
  tokens() -- Lose the part before opening quotes
  local description = tokens() -- Grab the part inside
  
  -- Now grab the tabtrigger
  local tokens = string.gmatch(line, '[^ ]+')
  tokens() -- Ignore 'snippet' part
  local tabtrigger = tokens()
  
  -- We"ll parse options and stuff sometime later
  local options = {} -- TODO read options!
  local contentstr = ""
  
  -- Read content into list of lines until we hit `endsnippet`
  for line in linesit do
    local s,e = string.find(line, "endsnippet")
    if s == 1 then
      break
    else
      contentstr = contentstr .. line .. "\n"
    end
  end

  snippet = {}
  snippet.description = description
  snippet.options = options
  snippet.content = create_content(contentstr)
  return tabtrigger, snippet
end


-- Loads all snippets from passed '.snippets' file. Should probably be
-- triggered when new file is loaded or when syntax is set/changed
function load_snippets(snippetfile)
  snippets = {}

  local f = io.open(snippetfile, "r")
  if f then
    io.input(f)
    local linesit = io.lines()
    
    for line in linesit do 
      local s, e = string.find(line, "snippet")
      -- Find lines that start with 'snippet' and enter
      -- snippet reading loop
      if s == 1 then
        local tabtrigger, snippet = create_snippet(line, linesit)
        snippets[tabtrigger] = snippet
      end
    
    end
    io.close(f)
    return snippets, true
  else
    vis:info("Failed to load a correct snippet: " .. snippetfile)
    return snippets, false
  end
end


-- Takes list of snippets and concatenates them into the string suitable
-- for passing to dmenu (or, very probably, vis-menu)
function snippetslist(snippets)
  local list = ""

  for k,v in pairs(snippets) do
    list = list .. k .. ' - ' .. v.description .. '\n'
  end

  return list
end

-- Creates an array of vis Selection instances to be passed to
-- win.selections
function mk_vis_selections(pos, tag)
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
  --local snippetfile = snippetfiles .. "html" .. ".snippets"
  --vis.win.syntax = "java"
  local snippetfile = snippetfiles .. vis.win.syntax .. ".snippets"
  local snippets, success = load_snippets(snippetfile)
  if not success then
    return 
  end

  -- print all snippets we loaded and their names
  --[[
  for k, v in pairs(snippets) do
    local out = '[' .. k .. '] --> "' .. tostring(v.content) .. '"\n'
    vis.win.file:insert(vis.win.selection.pos, out)
    vis.win.selection.pos = vis.win.selection.pos + #out

    for k2, v2 in pairs(v.content) do
      if k2 == 'str' then
      else
        local no = '\t' .. k2 .. ' -> tagnum: ' .. v2.tagnum .. ', defaultval: ' .. v2.defaultval .. ', selstart: ' .. v2.selstart .. ', selend: ' .. v2.selend .. '\n'

        vis.win.file:insert(vis.win.selection.pos, no)
        vis.win.selection.pos = vis.win.selection.pos + #no
      end
    end
  end
  --]]

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
    vis.mode = vis.modes.VISUAL
    local allselections = mk_vis_selections(pos, snipcontent["1"])
    win.selection.range = allselections[1].range
    --win.selections = mk_vis_selections(pos, snipcontent["1"])
    -- TODO multiple selections and selection switching (using marks, or jumplist?)
  else
    vis:info(msg)
  end
  
end, "Insert a snippet")

