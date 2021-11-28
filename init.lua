--------------------------------------------------------------------------------
-- Modules

local M = {}
local SnipMate = require('plugins/vis-ultisnips/snipmate-parser')
local UltiSnips = require('plugins/vis-ultisnips/ultisnips-parser')



--------------------------------------------------------------------------------
-- Config

M.snipmate  = ''
M.ultisnips = ''



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

local function load_ultisnips()
  local snippetfile = M.ultisnips .. vis.win.syntax .. '.snippets'
  local snippets, success = UltiSnips.load_snippets(snippetfile)
  if not success then
    vis:info('Failed to load a correct UltiSnip: ' .. snippetfile)
  end
  return snippets, success
end

local function load_snipmate()
  local snippetfile = M.snipmate .. vis.win.syntax .. '.snippets'
  local snippets, success = SnipMate.load_snippets(snippetfile)
  if not success then
    vis:info('Failed to load a correct SnipMate: ' .. snippetfile)
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

vis:map(vis.modes.INSERT, "<C-x><C-j>", function()
  local snippets = merge_and_override(load_snipmate(), load_ultisnips(), '_us')

  local win = vis.win
  local file = win.file
  local pos = win.selection.pos

  if not pos then
    return
  end
  -- TODO do something clever here

  -- Use prefix W if exists
  local initial = ' '
  local range = file:text_object_longword(pos > 0 and pos - 1 or pos)
  if range then
      initial = initial .. file:content(range)
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

  local trigger = chosen:gmatch('[^ ]+')()
  local snipcontent = snippets[trigger].content
  if range then
    file:delete(range)
    -- Update position after deleting the range
    pos = pos - (range.finish - range.start)
    vis:redraw()
  end

  vis:insert(snipcontent.str)
  --win.selection.pos = pos

  if #snipcontent.tags > 0 then
    vis:info("Use 'g>' and 'g<' to navigate between anchors.")
    vis.mode = vis.modes.VISUAL

    -- Create selections iteratively using `:#n,#n2 p` command and `gs` to
    -- save it in the jumplist
    for k,v in ipairs(snipcontent.tags) do
      vis:command('#' .. pos + v.selstart ..',#' .. pos + v.selend .. ' p')
--      vis:feedkeys('gs') -- Tested, works without this too, but just in case
    end

    -- Backtrack through all selections we've made first
    -- (so that we can use g> to move us forward)...
    for _ in ipairs(snipcontent.tags) do
      vis:feedkeys('g<')
    end

    -- ... then set us on the first selection
    vis:feedkeys('g>')
  else
    win.selection.pos = pos + #snipcontent.str
  end
end, "Insert a snippet")



--------------------------------------------------------------------------------
-- End module

return M