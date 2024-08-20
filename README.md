# UltiSnips plugin for Vis editor.

This isn't an official plugin reimplementation. I am not in any way
affiliated with UltiSnips developer(s).

I needed this functionality in Vis, and UltiSnips seemed powerful and
mature enough, and had plenty of templates available.

## How to make it work

### Setup
1. clone `vis-ultisnips` into your `.config/vis/plugins` directory

2. (optional) if you don't already have snippets, get them. You can
clone https://github.com/honza/vim-snippets to get a large repository
of both SnipMate and UltiSnips

### Configuration
#### Enabling the plugin
In your `visrc.lua`:
```
local snips     = require('plugins/vis-ultisnips')
snips.snipmate  = '<path-to-SnipMate-snippets>'
snips.ultisnips = '<path-to-SnipMate-UltiSnips>'
```
Trailing slash is *necessary*!

If you're using `vis-plug`, follow their guide on how to config modules:
```
-- configure plugins in an array of tables with git urls and options 
local plugins = {
...
  { url = 'git@github.com:machinedgod/vis-ultisnips', alias = 'snips' },
...
}

-- require and optionally install plugins on init
visplug.init(plugins, true)

-- access plugins via alias
visplug.plugins.snips.snipmate  = '/home/john/.config/vis/vim-snippets/snippets/'
visplug.plugins.snips.ultisnips = '/home/john/.config/vis/vim-snippets/UltiSnips/'

```
Note that despite the example telling different - you have to
execute `visplug.init(plugins, true)` (or `false` if you want to run
`:plug-install` manually) before you can access plugin configuration.

#### Setting up syntaxfile → snippetfile mappings that don't match
Setup any lexer syntax file to snippet file mapping using two tables,
one for each snippet format. The key is the vis lexer (the thing you
type when you set syntax with `:set syntax syntaxfile`), while the value
is the string representing the filename of the snippetfile, without
syntax. The default mapping includes `cpp.lua` lexer to SnipMate's
`c.snippets` file as below.

If you report it as an issue (or even more lovely, as a pull request)
- I'll add it to default maps, but to quickly get it to work without
messing with the `init.lua` file, add the mappings in your `visrc.lua`
(purescript is just an example!):
```
snips.syntaxfilemaps =
  { snipmate  = { cpp        = "c"
                , purescript = "pure"
                }
  , ultisnips = { purescript = "pure"
				}
  }

```


### Usage
In insert mode, hit `<C-j>` to show `vis-menu` with all snippets found
for the currently set syntax - it literally looks for a file in your path
called `<syntax>.lua`. You can also pre-type the snippet tabtrigger that
you're looking for.

When snippet is expanded, all of its tags will be added to the selection
jumplist. You can use Vis motions `g<` and `g>` to navigate between them.

## What works
You can:

- get a list of snippets per syntax
- insert the snippet
- navigate around its anchor points

## What is known to _not_ work
### Temporarily
1. Multiple selections for same tag numbers (only figured out half an
hour ago a solution to multiple selections)

### Is unlikely to work until someone fixes it (ie. I don't care much about it right now)

1. python interpolations, date interpolations, etc etc etc

1. nested tags (correctly parsed, but not correctly inserted)

1. options


## What is _supposed_ to work but might _not_

- Parsing of more complex snippets. Lpeg grammar for this is quite complex
(I'm looking at you, nested tags feature)

- `vis-menu` for one or the other reason corrupts my terminal when
invoked. This might be plugin doing something its not supposed to -
but I don't know what. If you do, please PR. Mind you, dmenu has no
such problems.

- who knows??? This was supposed to be few hours project max, ended up
being a rabbit hole!


## Final notes
All of this, because muscle memory from vim made me remember I can't
just insert `{-# LANGUAGE ...#-}` pragma via template.

And I didn't like that.

So I spent upwards of 15h writing this plugin.

Go figure.