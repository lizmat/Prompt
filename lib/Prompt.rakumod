# Hopefully will become core at some point
use nqp;

# Need to stub first to allow all to see each oher
role Prompt { ... }

#- Prompt::Fallback ------------------------------------------------------------
role Prompt::Fallback {
    has $.history;
    has $.editor-name = "Fallback";
    has @.completions;
    has @.additional-completions;

    # Basic input reader
    method read($prompt) { &CORE::prompt($prompt) }

    # Do not support completions by default
    method supports-completions(--> False) { }

    # Fetching / Setting completions
    proto method completions(|) {*}
    multi method completions() { @!completions }
    multi method completions(*@completions) {
        @!completions := @completions.sort.List
    }

    # Find appropriate line completions
    method line-completions(
      str $line, int $pos = $line.chars
    ) is implementation-detail {
        my $completions := nqp::create(IterationBuffer);

        if $line {
            my str $prefix   = $line.substr(0,$pos).trim-trailing;
            my str $postfix  = $line.substr($prefix.chars);

            my str $lastword;
            my $index = quietly $prefix.rindex(" ") max $prefix.rindex(".");
            if $index == -Inf {
                $lastword = $prefix;
                $prefix   = "";
            }
            else {
                ++$index;
                $lastword = $prefix.substr($index);
                $prefix   = $prefix.substr(0,$index);
            }

            @!completions.map({
                $prefix ~ $_ ~ $postfix if .starts-with($lastword)
            }).iterator.push-all($completions);

            for @!additional-completions -> &completions {
                completions($line, $pos).iterator.push-all($completions);
            }
        }

        $completions.List
    }

    # Fetching / Setting / Updating history
    proto method history(|) {*}
    multi method history() { $!history }
    multi method history($history) {
        $!history := $history.IO;
        self.load-history;
        $!history
    }
    method load-history() { }
    method add-history($) { }
    method save-history() { }
}

#- Prompt::Readline ------------------------------------------------------------
role Prompt::Readline does Prompt::Fallback {
    has $!Readline is built;

    method editor-name(--> "Readline") { }

    method new() {
        with try "use Readline; Readline.new".EVAL {
            my $self := self.bless(:Readline($_), |%_);
            $self.history($_) with %_<history>;
            $self
        }
        else {
            Nil
        }
    }

    method read($prompt) { $!Readline.readline($prompt) }
    method add-history($code --> Nil) { $!Readline.add-history($code)}
    method load-history(--> Nil) {
        $!Readline.read-history(.absolute) with $.history;
    }
    method save-history(--> Nil) {
        $!Readline.write-history(.absolute) with $.history;
    }
}

#- Prompt::Linenoise -----------------------------------------------------------
role Prompt::Linenoise does Prompt::Fallback {
    has &!linenoise   is built;
    has &!HistoryAdd  is built;
    has &!HistoryLoad is built;
    has &!HistorySave is built;

    method editor-name(--> "Linenoise") { }

    method new() {

        # haz Linenoise
        with try "use Linenoise; Linenoise.WHO".EVAL -> %WHO {
            my $self := self.bless(
              linenoise             => %WHO<&linenoise>,
              HistoryAdd            => %WHO<&linenoiseHistoryAdd>,
              HistoryLoad           => %WHO<&linenoiseHistoryLoad>,
              HistorySave           => %WHO<&linenoiseHistorySave>,
              |%_
            );
            $self.history($_) with %_<history>;

            my &AddCompletion := %WHO<&linenoiseAddCompletion>;
            %WHO<&linenoiseSetCompletionCallback>( -> $line, $c {

                # The callback doesn't sink, so we need to make the
                # iterator do the work manually
                my @ is List = $self.line-completions($line).map: {
                    AddCompletion($c, $_)
                }
            });

            $self
        }

        # alas, no go
        else {
            Nil
        }
    }

    method read($prompt) { &!linenoise($prompt) }
    method add-history($code --> Nil) { &!HistoryAdd($code) }
    method load-history(--> Nil) { &!HistoryLoad(.absolute) with $.history }
    method save-history(--> Nil) { &!HistorySave(.absolute) with $.history }
    method supports-completions(--> True) { }
}

#- Prompt::LineEditor ----------------------------------------------------------
role Prompt::LineEditor does Prompt::Fallback {
    has $!LineEditor is built;

    method editor-name(--> "LineEditor") { }

    method new() {
        my $self;

        # Sub needs to exist before input object is create
        my sub get-completions($line, $pos) {
            $self.line-completions($line, $pos)
        }

        # haz Terminal::LineEditor
        with try Q:to/CODE/.EVAL {
use Terminal::LineEditor;
use Terminal::LineEditor::RawTerminalInput;
Terminal::LineEditor::CLIInput.new(:&get-completions)
CODE
            # Set up the editor object
            $self := self.bless(:LineEditor($_), |%_);
            $self.history($_) with %_<history>;
            $self
        }
        # alas, no go
        else {
            Nil
        }
    }

    method read($prompt) { $!LineEditor.prompt($prompt.chop) }
    method add-history($code --> Nil) { $!LineEditor.add-history($code) }
    method load-history(--> Nil) {
        with $.history {
            .spurt unless .e;
            $!LineEditor.load-history($_);
        }
    }
    method save-history(--> Nil) {
        $!LineEditor.save-history($_) with $.history;
    }
    method supports-completions(--> True) { }
}

#- Prompt ----------------------------------------------------------------------
role Prompt {

    # The editor logic being used
    has Mu $.editor handles <
      additional-completions add-history completions editor-name history
      load-history read save-history supports-completions
    >;

    # The last line seen
    has Str $.last-line = "";

    method new(Mu $editor?) { self.bless(:$editor, |%_) }

    method TWEAK(*%nameds) {

        # Try the given editor
        sub try-editor($editor) {
            if Prompt::{$editor}:exists {
                $!editor = try Prompt::{$editor}.new(|%nameds);
                note "Failed to load support for '$editor'" without $!editor;
            }
            else {
                $!editor = Nil;
            }
        }

        # When running a REPL inside emacs the fallback behaviour
        # should be used, setting the editor name explicitely
        if %*ENV<INSIDE_EMACS> {
            $!editor = Prompt::Fallback.new(:editor-name<emacs>, |%nameds);
        }

        # When running a REPL inside an "rlwrap" the fallback behaviour
        # should be used, setting the editor name explicitely
        elsif (%*ENV<_> // "").ends-with: 'rlwrap' {
            $!editor = Prompt::Fallback.new(:editor-name<rlwrap>, |%nameds);
        }

        # A specific editor support has been requested
        elsif %*ENV<RAKUDO_LINE_EDITOR> -> $editor {
            try-editor($editor);
        }

        # A string argument was specified
        elsif nqp::istype($!editor,Str) {
            try-editor($!editor);
        }

        # A Bool argument was specified
        elsif nqp::istype($!editor,Bool) {
            $!editor = Nil;
        }

        # Still no editor yet, try them in order, any non-standard ones
        # first, in alphabetical order
        my constant @predefined = <Readline LineEditor Linenoise Fallback>;
        without $!editor {
            for |(Prompt::.keys (-) @predefined).keys.sort(*.fc), |@predefined {
                last if $!editor = try Prompt::{$_}.new(|%nameds);
            }
        }
    }

    # Read a line with history saving logic
    method readline($prompt = "> ") {
        with self.read($prompt) -> $line {
            if $line && $line ne $!last-line {
                self.add-history($line);
                $!last-line = $line;
            }

            $line
        }
        else {
            Nil
        }
    }
}

#- prompt ----------------------------------------------------------------------
my sub prompt($prompt = "") is export(:prompt) {
    without $*PROMPT {
        (nqp::istype($_,Failure)
          ?? PROCESS::<$PROMPT>  # no lexical dynamic found, stash it in PROCESS
          !! $*PROMPT            # uninitialized lexical dynamic found
        ) = Prompt.new;
    }
    val $*PROMPT.readline($prompt);
}

# vim: expandtab shiftwidth=4
