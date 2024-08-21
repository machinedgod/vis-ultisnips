--------------------------------------------------------------------------------
-- Modules

local M = {}
local cwd = ...
local SnipMate  = require(cwd .. '.snipmate-parser')
local UltiSnips = require(cwd .. '.ultisnips-parser')



--------------------------------------------------------------------------------
-- Config

M.snipmate        = ''
M.ultisnips       = ''
-- Lets disable UltiSnips for now since they aren't nearly parsed well
-- enough as SnipMates. Still leave it as an option so that whoever
-- wants to use them  at their own risk - they can.
M.enableUltiSnips = false
M.syntaxfilemaps  =
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


-- Loads snippet file using either SnipMate or UltiSnips module
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


-- From testing with vis:
-- :7 x/\$\{(1(:[^}]+)?|[0-9]+:\$1)\}/
local function create_tag_selection_with_refs(pos, contentlength, tagindex)
  local address   = '#' .. pos .. ',#' .. pos + contentlength
  -- Has to match either just pure tag or with default value
  -- no need to capture the default value here
  local mainregex = tagindex .. '(:[^}]+)?'
  -- Don't care about the other tag index here, just need to find
  -- the same reference
  local refregex  = '[0-9]+:\\$' .. tagindex
  vis:command(address
             .. ' x/\\$\\{('
             .. mainregex
             .. '|'
             .. refregex
             .. ')\\}/'
             )
end


-- :g/\$\{[0-9]+:([^}]+)\}/ c/Default value/
local function replace_tag_with_default_value(defaultval)
  -- Has to match either just pure tag or with default value
  -- no need to capture the default value here
  local gregex    = '\\$\\{[0-9]+:([^}]+)\\}'
  local changecmd = 'c/' .. defaultval .. '/'
  vis:command('g/' 
             .. gregex 
             .. '/' 
             .. changecmd
             )
end


local function replace_selections_with_default_values_or_empty(defaultval)
  if defaultval ~= nil then
    replace_tag_with_default_value(defaultval)
  else
    vis:command('c/ /')
  end
end


--------------------------------------------------------------------------------
-- Plugging it all in

vis:map(vis.modes.INSERT, '<C-x><C-j>', function()
  local snippets = {}
  if M.enableUltiSnips then
    snippets = merge_and_override(
      load_generalized(M.syntaxfilemaps.snipmate,  M.snipmate,  SnipMate , 'SnipMate' ),
      load_generalized(M.syntaxfilemaps.ultisnips, M.ultisnips, UltiSnips, 'UltiSnips'),
      '_UltiSnip')
  else
    snippets = load_generalized(M.syntaxfilemaps.snipmate,  M.snipmate,  SnipMate , 'SnipMate' )
  end

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
    --
    -- Wed Aug 21 05:15:23 AM MDT 2024
    -- It seems that the whole shennangian with 0th tag being first is not
    -- really a thing and its messing up snippets that don't work this way
    -- (like C snippets). What should REALLY happen is that I sort the tags
    -- somehow, but for now, I'm just gonna ignore this convention
    --
    -- Wed Aug 21 05:26:00 AM MDT 2024
    -- Welp, this is now an issue :(
    -- It seems this makes C.snippet tags work very nice (with occassional
    -- parsing bugs), but its messing up haskell snippets now
    -- I need to rethink this whole strategy with ordering
    --
    -- Meanwhile, its likely that C will be used more than haskell so,
    -- I'll leave it this way for now
    local selectionrollbackcounter = 0
    --for i = 1, #snipcontent.tags - 1, 1 do
    for i = 1, #snipcontent.tags, 1 do
      -- Can't use 'x' command because it'd select stuff across
      -- whole file
      --vis:command('#' .. pos + v.selstart ..',#' .. pos + v.selend .. ' p')
      
      -- Tue Aug 20 04:13:47 PM MDT 2024
      -- Yes, but if I limit the 'x' only within the inserted snippet
      -- scope, it'd work?
      -- After trying: yep, it works

      -- Skip reference tags, they'll be picked up by main tag
      if snipcontent.tags[i].reference == nil then
        create_tag_selection_with_refs(pos, snipcontentlen, i)
        replace_selections_with_default_values_or_empty(snipcontent.tags[i].default)
        selectionrollbackcounter = selectionrollbackcounter + 1
      end
    end

    -- Manually add zero here without meddling with the loop up there
    -- Wed Aug 21 05:17:23 AM MDT 2024
    -- Nah, see comment upstairs with same date
    --create_tag_selection_with_refs(pos, snipcontentlen, 0)
    --replace_selections_with_default_values_or_empty(snipcontent.tags[#snipcontent.tags].default)

    -- Backtrack through all selections we've made first
    -- (so that we can use g> to move us forward)...
    for i = 1, selectionrollbackcounter -1, 1 do
      vis:feedkeys('g<')
    end

      
  else
    win.selection.pos = pos + #snipcontent.str
  end
end, "Insert a snippet")



--------------------------------------------------------------------------------
-- End module

return M