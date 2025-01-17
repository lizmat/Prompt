[![Actions Status](https://github.com/lizmat/Prompt/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Prompt/actions) [![Actions Status](https://github.com/lizmat/Prompt/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Prompt/actions) [![Actions Status](https://github.com/lizmat/Prompt/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Prompt/actions)

NAME
====

Prompt - a smarter prompt for user interaction

SYNOPSIS
========

```raku
use Prompt;

my $prompt = Prompt.new(:history<here>);
loop {
    last without my $line = $prompt.readline("> ");
    say $line;
}
$prompt.save-history;
```

DESCRIPTION
===========

The Prompt module offers a better `prompt` experience, drawing on the logic of the Raku REPL.

It also optionally provides a replacement for Raku's standard [`prompt`](https://docs.raku.org/routine/prompt) functionality.

ROLES
=====

The `Prompt` role is what usually gets punned into a class.

The `Prompt::Fallback` role provides all of the logic if no specific editor has been found. It also serves as a base role for specific editor roles, such as `Prompt::Readline`, `Prompt::LineEditor` and `Prompt::Linenoise`.

Prompt
------

The `Prompt` role embodies the information needed to read a line of input from a user, and optionally keep a history of the lines that were entered.

### method new

```raku
my $Prompt = Prompt.new(
  :editor(Any),    # or "Readline", "LineEditor", "Linenoise"
  :history<here>,                       # default: none
  :completions(@completions),           # default: none
  :additional-completions(&one, &two),  # default: none
);
loop {
    last without my $line = $Prompt.readline;
    say $line;
}
$Prompt.save-history;
```

The `new` method is called to instantiate a `Prompt` object. It takes a number of named arguments described below.

#### :editor

The editor logic to be used. Can be specified as a string, or as an instantiated object that implements the `Prompt::Fallback` role.

If the value is not a string, it is expected to be a class that implements to the `Prompt::Fallback` interface.

Otherwise defaults to `Any`, which means to search first for unknown roles in the `Prompt::` namespace, then to try if there is support installed for [`Readline`](https://raku.land/zef:clarkema/Readline), [`LineEditor`](https://raku.land/zef:japhb/Terminal::LineEditor), or [`Linenoise`](https://raku.land/zef:raku-community-modules/Linenoise).

If that failed, then the `Fallback` editor logic will be used, which may cause a cumbersome user experience, unless the process was wrapped with a call to the [`rlwrap`](https://github.com/hanslub42/rlwrap) readline wrapper.

Used value available with the `.editor` method.

#### :history

String or `IO::Path` object. Specifies the path to keep any lines that have been previously entered and/or will be entered in the future by any user interactions. Defaults to `Any`, indicating **no** history will be kept.

Will load any persistent history already available if the specified path already existed.

Used value available with the `.history` method.

#### :completions

A `List` of strings to be used for tab-completions by the editor. Will only be useful if the `.supports-completions` method returns `True`.

#### :additional-completions

A `List` of `Callables` to be called to support additional completion logic. Will only be useful if the `.supports-completions` method returns `True`.

### method readline

```raku
my $line = $Prompt.readline("> ");
```

The `readline` method takes a single positional argument for the prompt to be shown (defaults to "> ") and returns a line of input from the user.

The prompt will be scanned for escape sequence [interpolation](#INTERPOLATIONS).

An undefined value is returned if the user has indicated there is no more input to be obtained.

If the `Prompt` object was made with a history file, then that history will be available to the user depending on whether the `editor` used supports that (the `Prompt::Fallback` editor does **not**). And in that case, the `readline` will make sure that any new lines will be added to the history.

Note that to persistently store the history, one **must** call the `save-history`, when appropriate (usually when the user is done).

### method read

```raku
my $line = $Prompt.read("> ");
```

The `read` method takes a single positional argument for the prompt to be shown and returns a line of input from the user. It does **not** handle anything history related, nor does it do any escape code analysis.

### method completions

```raku
.say for $Prompt.completions;

$Prompt.completions(<a b c>);
```

The `completions` method returns the current sorted `List` of completions.

If called with a `Positional`, will sort that and use that as the list of completions to use.

### method additional-completions

The `additional-completions` method returns an `Array` of `Callable`s that will be called whenever a completion is requested. Each `Callable` is expected to accepted two positional arguments: the first is the line that has been entered so far by the user, and the second is the position of the cursor when a completion was requested.

### method editor-name

```raku
say $Prompt.editor-name;
```

The `editor-name` method returns the name of the editor support that was activated. It is intended to be purely informatonal.

### method history

```raku
my $history = $Prompt.history;

$Prompt.save-history;
$Prompt.history("another-file");
```

Returns the `IO::Path` object representing the persistent history file.

Can also be called with a positional argument, indicating the file to be used for history keeping from now on. Note that if history was already being kept in another history file, any additions to that will be lost unless a call to `save-history` was done before that.

### method add-history

```raku
$Prompt.add-history($line);
```

The `add-history` method can be called to add a line to the current history. It takes a single positional argument: the line to be added.

Note that calling this method is not needed if the `readline` method is being used to obtain input from a user.

### method load-history

Will (re-)load the history from the file indicated with `history`.

### method save-history

Will save the current history to the file indicated with `history`.

### method expand

```raku
my $prompt = Prompt.expand('\c{yellow;bold}\d{%r}\c > ');
Prompt.new.readline($prompt);
```

The `expand` method will scan the given string for a number of escape escape sequences and interpolate the values associated with the given escape sequence if found.

<table class="pod-table">
<thead><tr>
<th>Sequence</th> <th>Prompt Expansion</th>
</tr></thead>
<tbody>
<tr> <td>\a</td> <td>alert / bell character</td> </tr> <tr> <td>\t</td> <td>tab</td> </tr> <tr> <td>\n</td> <td>newline</td> </tr> <tr> <td>\c</td> <td>color / formatting - see below for options</td> </tr> <tr> <td>\d</td> <td>time - see below for options</td> </tr> <tr> <td>\e</td> <td>escape character</td> </tr> <tr> <td>\i</td> <td>the value of $*INDEX</td> </tr> <tr> <td>\l</td> <td>language version</td> </tr> <tr> <td>\L</td> <td>language version (verbose)</td> </tr> <tr> <td>\v</td> <td>compiler version</td> </tr> <tr> <td>\V</td> <td>compiler version (verbose)</td> </tr>
</tbody>
</table>

#### color / formatting sequences (\c)

Provide some common ANSI codes with short names. Defaults to `reset` if a bare `\c` is used, and multiple arguments can be separated with a `;`, e.g. `\c{yellow;bold}`.

##### formatting

These identifiers can be used for general formatting: `reset`, `normal`, `bold`, `dim`, `italic`, `underline`, `blink`, `inverse`, `hidden`, `strikethrough`.

##### foreground colors

These identifiers can be used for foreground colors: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, `default`.

##### background colors

These identifiers can be used for background colors: `bg:black`, `bg:red`, `bg:green`, `bg:yellow`, `bg:blue`, `bg:magenta`, `bg:cyan`, `bg:white`, `bg:default`.

#### time sequences (\d)

The `\d` construct takes an optional `{ }` containing a subset of `strftime` codes, defaulting to `%T` if a bare `\d` is used.

<table class="pod-table">
<thead><tr>
<th>Code</th> <th>Value</th>
</tr></thead>
<tbody>
<tr> <td>%d</td> <td>day of month (&quot;01&quot; .. &quot;31&quot;)</td> </tr> <tr> <td>%D</td> <td>%m/%d/%y</td> </tr> <tr> <td>%e</td> <td>day of month (&quot; 1&quot; .. &quot;31&quot;)</td> </tr> <tr> <td>%F</td> <td>%Y-%m-%d</td> </tr> <tr> <td>%H</td> <td>24-hour hour (&quot;00&quot; .. &quot;23&quot;)</td> </tr> <tr> <td>%I</td> <td>12-hour hour (&quot;01&quot; .. &quot;12&quot;)</td> </tr> <tr> <td>%j</td> <td>day of the year (&quot;001&quot; .. &quot;366&quot;)</td> </tr> <tr> <td>%k</td> <td>24-hour hour (&quot; 1&quot; .. &quot;23&quot;)</td> </tr> <tr> <td>%l</td> <td>12-hour hour (&quot; 1&quot; .. &quot;12&quot;)</td> </tr> <tr> <td>%M</td> <td>minute (&quot;00&quot; .. &quot;59&quot;)</td> </tr> <tr> <td>%m</td> <td>month (&quot;01&quot; .. &quot;12&quot;)</td> </tr> <tr> <td>%p</td> <td>&quot;am&quot; | &quot;pm&quot;</td> </tr> <tr> <td>%R</td> <td>%H:%M</td> </tr> <tr> <td>%r</td> <td>%I:%M:%S %p</td> </tr> <tr> <td>%S</td> <td>second (&quot;00&quot; .. &quot;59&quot;)</td> </tr> <tr> <td>%T</td> <td>%H:%M:%S</td> </tr> <tr> <td>%u</td> <td>weekday (1 .. 7)</td> </tr> <tr> <td>%w</td> <td>weekday (0 .. 6)</td> </tr> <tr> <td>%Y</td> <td>year (yyyy)</td> </tr>
</tbody>
</table>

EDITOR ROLES
============

An editor role must supply the methods as defined by the `Prompt::Fallback` role. Its `new` method should either return an instantiated class, or `Nil` if the class could not be instantiated (usually because of lack of installed module dependencies).

The other methods are (in alphabetical order):

### add-history

Expected to take a single string argument to be added to the (possibly persistent) history. Does not perform any action by default in `Prompt::Fallback`.

### history

If called as an accessor, should return the `IO::Path` object of the history file.

If called as a mutator with a single positional argument, should set that as the current history file, and load that history.

### load-history

Expected to take no arguments and load any persistent history information, as indicated by its `history` method. Does not perform any action by the default implementation in the `Prompt::Fallback` role.

read
----

Expected to take a string argument with the prompt to be shown, and return the next line of input from the user. Expected to return an undefined value to indicate that no further input is to be expected.

Defaults to showing the prompt and taking a line from `$*IN` in `Prompt::Fallback`.

save-history
------------

Expected to take no arguments and save any persistent history information, as indicated by its `history` method. Does not perform any action by the default implementation in the `Prompt::Fallback` role.

supports-completions
--------------------

Expected to take no arguments and return a `Bool` indicating whether this editor supports completions. Defaults to `False` in the `Prompt::Fallback` role.

Prompt::Fallback
----------------

Apart from the definition of the interface for editors, it provides the default logic for handling the interaction with the user.

Prompt::Readline
----------------

The role that implements the user interface using the [`Readline`](https://raku.land/zef:clarkema/Readline) module.

Prompt::LineEditor
------------------

The role that implements the user interface using the [`Terminal::LineEditor`](https://raku.land/zef:japhb/Terminal::LineEditor) module.

Prompt::Linenoise
-----------------

The role that implements the user interface using the [`Linenoise`](https://raku.land/zef:raku-community-modules/Linenoise) module.

SUBROUTINES
===========

sub prompt
----------

```raku
use Prompt :prompt;

say prompt("> ");
```

If the `:prompt` named argument is specified with the `use Prompt` statement, a lexical replacement for the standard `prompt` functionality will be exported.

### $*PROMPT

The `$*PROMPT` dynamic variable will be used to obtain the `Prompt` object to be used in the interaction. If none was found, a new `Prompt` object will be created and stored as `$*PROMPT` in the `PROCESS::` stash (making it automatically available for any subsequent call to the exported `prompt` subroutine).

```raku
use Prompt :prompt;

my $*PROMPT = Prompt.new(...);
say prompt("> ");
```

If one needs specific initializations with the `Prompt` object, one can also define ones own `$*PROMPT` dynamic variable before calling `prompt`.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Prompt . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024, 2025 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

