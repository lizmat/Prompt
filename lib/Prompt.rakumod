# Hopefully will become core at some point
use nqp;

# Need to stub first to allow all to see each oher
role Prompt { ... }

#- Prompt::Fallback ------------------------------------------------------------
role Prompt::Fallback {
    has $.history;

    method read($prompt) { CORE::prompt($prompt) }
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

    method new() {
        with try "use Readline; Readline.new".EVAL {
            my $self := self.bless(:Readline($_));
            $self.history($_) with %_<history>;
            $self
        }
        else {
            Nil
        }
    }

    method read($prompt) {
        $!Readline.readline($prompt)
    }

    method add-history($code --> Nil) {
        $!Readline.add-history($code);
    }

    method load-history() {
        $!Readline.read-history(.absolute) with $.history;
    }

    method save-history() {
        $!Readline.write-history(.absolute) with $.history;
    }
}

#- Prompt::Linenoise -----------------------------------------------------------
role Prompt::Linenoise does Prompt::Fallback {
    has &!linenoise            is built;
    has &!linenoiseHistoryAdd  is built;
    has &!linenoiseHistoryLoad is built;
    has &!linenoiseHistorySave is built;

    method new() {
        with try "use Linenoise; Linenoise.WHO".EVAL -> %WHO {
            my $self := self.bless(
              linenoise            => %WHO<&linenoise>,
              linenoiseHistoryAdd  => %WHO<&linenoiseHistoryAdd>,
              linenoiseHistoryLoad => %WHO<&linenoiseHistoryLoad>,
              linenoiseHistorySave => %WHO<&linenoiseHistorySave>,
            );
            $self.history($_) with %_<history>;
            $self
        }
        else {
            Nil
        }
    }

    method read($prompt) {
        &!linenoise($prompt)
    }

    method add-history($code --> Nil) {
        &!linenoiseHistoryAdd($code);
    }

    method load-history() {
        &!linenoiseHistoryLoad(.absolute) with $.history;
    }

    method save-history() {
        &!linenoiseHistorySave(.absolute) with $.history;
    }
}

#- Prompt::Terminal::LineEditor ------------------------------------------------
role Prompt::LineEditor does Prompt::Fallback {
    has $!LineEditor is built;

    method new() {
        with try Q:to/CODE/.EVAL {
use Terminal::LineEditor;
use Terminal::LinePrompt::RawTerminalInput;
Terminal::LinePrompt::CLIInput.new
CODE
            my $self := self.bless(:LineEditor($_));
            $self.history($_) with %_<history>;
            $self
        }
        else {
            Nil
        }
    }

    method read($prompt) {
        $!LineEditor.prompt($prompt.chop)
    }

    method add-history($code --> Nil) {
        $!LineEditor.add-history($code);
    }

    method load-history() {
        $!LineEditor.load-history($_) with $.history;
    }

    method save-history() {
        $!LineEditor.save-history($_) with $.history;
    }
}

#- Prompt ----------------------------------------------------------------------
role Prompt {

    # The editor logic being used
    has Mu $.editor handles <
      add-history history load-history read save-history
    >;

    # The last line seen
    has Str $.last-line = "";

    method new(Mu $editor?) { self.bless(:$editor, |%_) }

    method TWEAK(*%nameds) {

        # Try the given editor
        sub try-editor($editor) {
            $!editor = try Prompt::{$editor}.new(|%nameds);
            note "Failed to load support for '$editor'" without $!editor;
        }

        # When running a REPL inside of emacs, the fallback behaviour
        # should be used, as that is provided by emacs itself
        if %*ENV<INSIDE_EMACS> {
            $!editor = Prompt::Fallback.new(|%nameds);
        }

        # A specific editor support has been requested
        elsif %*ENV<RAKUDO_LINE_EDITOR> -> $editor {
            try-editor($editor);
        }

        # A string argument was specified
        elsif nqp::istype($!editor,Str) {
            try-editor($!editor);
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

# vim: expandtab shiftwidth=4
