# UltiSnips plugin for Vis editor.

This isn't an official plugin reimplementation. I am not in any way
affiliated with UltiSnips developer(s).

I needed this functionality in Vis, and UltiSnips seemed powerful and
mature enough, and had plenty of templates available.

## How to make it work

### Configuration
# OUT OF DATE NEEDS FIXING
1. copy `snippets.lua` into your `.config/vis/plugins` directory

2. (optional) if you don't already have snippets, get them. You can
clone https://github.com/honza/vim-snippets

3. in `snippets.lua` modify the `snippetfiles` value so that it points
to the absolute path where you keep your UltiSnip snippets. Trailing
slash is necessary

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