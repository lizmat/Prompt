[![Actions Status](https://github.com/lizmat/Prompt/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Prompt/actions) [![Actions Status](https://github.com/lizmat/Prompt/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Prompt/actions) [![Actions Status](https://github.com/lizmat/Prompt/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Prompt/actions)

NAME
====

Prompt - a smarter prompt for user interaction

SYNOPSIS
========

```raku
# Best with any of Terminal::LineEditor, Linenoise or
# Readline distributions installed
use Prompt;

my $prompt = Prompt.new(:history<here>);  # auto-select editor
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

The `Prompt::Fallback` role serves as a base role for specific editor roles, such as `Prompt::Readline`, `Prompt::LineEditor` and `Prompt::Linenoise`, each of which have their pros and cons.

The `Prompt::Fallback` role provides all of the logic if no specific editor has been found, but is not recommended for production use.

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

