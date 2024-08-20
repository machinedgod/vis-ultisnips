--------------------------------------------------------------------------------
-- Modules

local M = {}
local cwd = ...
local SnipMate  = require(cwd .. '.snipmate-parser')
local UltiSnips = require(cwd .. '.ultisnips-parser')



--------------------------------------------------------------------------------
-- Config

M.snipmate       = ''
M.ultisnips      = ''
M.syntaxfilemaps =
  { snipmate  = { cpp = "c"
                }
  , ultisnips = {}
  }



--------------------------------------------------------------------------------
-- Helper functions

-- Takes list of snippets and concatenates them into the string suitable
-- for passing to dmenu (or, very probably, vis-menu)
local function snippetslist(snippets)
  local list = ''

  for k,v in pairs(snippets) do
    if not v.description then
      list = list .. k .. '\n'
    else
      list = list .. k .. ' - ' .. v.description .. '\n'
    end
  end

  return list
end



local function load_ultisnips()
  local snippetFilename = vis.win.syntax
  if M.syntaxfilemaps.ultisnips[snippetFilename] ~= nil then
    snippetFilename = M.syntaxfilemaps.ultisnips[snippetFilename]
  end

  local snippetfile = M.ultisnips .. snippetFilename .. '.snippets'
  local snippets, success = UltiSnips.load_snippets(snippetfile)
  if not success then
    vis:message('Failed to load a correct UltiSnip: ' .. snippetfile)
  end
  return snippets, success
end



local function load_snipmate()
  local snippetFilename = vis.win.syntax
  if M.syntaxfilemaps.snipmate[snippetFilename] ~= nil then
    snippetFilename = M.syntaxfilemaps.snipmate[snippetFilename]
  end

  local snippetfile = M.snipmate .. snippetFilename .. '.snippets'
  local snippets, success = SnipMate.load_snippets(snippetfile)
  if not success then
    vis:message('Failed to load a correct SnipMate: ' .. snippetfile)
  end
  return snippets, success
end


local function load_generalized(filemaps, modulefile, snippetsmodule, snippetstypestr)
  local snippetfilename = vis.win.syntax
  if filemaps[snippetfilename] ~= nil then
    snippetfilename = filemaps[snippetfilename]
  end

  local snippetfile = modulefile .. snippetfilename .. '.snippets'
  local snippets, success = snippetsmodule.load_snippets(snippetfile)

  if not success then
    vis:message('Failed to load a correct ' .. snippetstypestr .. ': ' .. snippetfile)
  end
  return snippets, success
end



-- Second will append to first using suffix for distinguishing
local function merge_and_override(snips1, snips2, suffix)
  for k,v in pairs(snips2) do
    snips1[k .. suffix] = v
  end
  return snips1
end


local function create_tag_selection(pos, contentlength, tagindex)
  local address = '#' .. pos .. ',#' .. pos + contentlength
  vis:command(address .. ' x/\\$\\{' .. tagindex .. '[^}]*\\}/')
end


--------------------------------------------------------------------------------
-- Plugging it all in

vis:map(vis.modes.INSERT, '<C-x><C-j>', function()
  --local function load_generalized(filemaps, modulefile, snippetsmodule, snippetstypestr)
  local snippets = merge_and_override(
    load_generalized(M.syntaxfilemaps.snipmate,  M.snipmate,  SnipMate , 'SnipMate' ),
    load_generalized(M.syntaxfilemaps.ultisnips, M.ultisnips, UltiSnips, 'UltiSnips'),
    '_us')
  
  -- local snippets = merge_and_override(
    -- load_snipmate(),
    -- load_ultisnips(),
    -- '_us')

  local win  = vis.win
  local file = win.file
  local pos  = win.selection.pos

  if not pos then
    return
  end
  -- TODO do something clever here

  -- Use prefix W if exists
  local initial = ' '
  local range = file:text_object_longword(pos > 0 and pos - 1 or pos)
  if file:content(range):match('[%w]+') then
    initial = initial .. file:content(range)
  else
    range = nil
  end

  -- Note, for one reason or another, using vis-menu corrupts my terminal
  -- (urxvt) for exact amount of lines that vis-menu takes
  -- dmenu has no such problems, but can't take initial input :-\
  --local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | dmenu -l 5", "r")
  local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | vis-menu " .. initial, "r")
  local chosen = stdout:lines()()
  local success, msg, status = stdout:close()
  if status ~= 0 or not chosen then
    vis:message(msg)
    return
  end

  local trigger     = chosen:gmatch('[^ ]+')()
  local snipcontent = snippets[trigger].content
  if range then
    file:delete(range)
    -- Update position after deleting the range
    pos = pos - (range.finish - range.start)
  end

  vis:insert(snipcontent.str)
  vis:redraw()

  -- Lets not recalculate this in the loop, god knows if underlying engine
  -- is cacheing it
  local snipcontentlen = snipcontent.str:len()

  if #snipcontent.tags > 0 then
    vis:info("Use 'g>' and 'g<' to navigate between anchors.")

    -- Create selections iteratively
    -- Because tag 0 seems to be main tag in snippets, we want to leave
    -- it last, therefore we start from 1 and count to tags - 1, then
    -- later manually add 0th tag
    for i = 1, #snipcontent.tags - 1, 1 do
      -- Can't use 'x' command because it'd select stuff across
      -- whole file
      --vis:command('#' .. pos + v.selstart ..',#' .. pos + v.selend .. ' p')
      
      -- Tue Aug 20 04:13:47 PM MDT 2024
      -- Yes, but if I limit the 'x' only within the inserted snippet
      -- scope, it'd work?
      -- After trying: yep, it works
      create_tag_selection(pos, snipcontentlen, i)
    end

    -- Manually add zero here without meddling with the loop up there
    create_tag_selection(pos, snipcontentlen, 0)

    -- Backtrack through all selections we've made first
    -- (so that we can use g> to move us forward)...
    for i = 1, #snipcontent.tags - 1, 1 do
      vis:feedkeys('g<')
    end
      
  else
    win.selection.pos = pos + #snipcontent.str
  end
end, "Insert a snippet")



--------------------------------------------------------------------------------
-- End module

return M