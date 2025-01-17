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

    # Subset of ANSI color codes
    my sub expand-color(Str:D $format --> Str:D) {
        my constant %ansi = <
          reset          0
          normal         0
          bold           1
          dim            2
          italic         3
          underline      4
          blink          5
          inverse        7
          hidden         8
          strikethrough  9
          black         30
          red           31
          green         32
          yellow        33
          blue          34
          magenta       35
          cyan          36
          white         37
          default       39
          bg:black      40
          bg:red        41
          bg:green      42
          bg:yellow     43
          bg:blue       44
          bg:magenta    45
          bg:cyan       46
          bg:white      47
          bg:default    49
        >;

        $format.split(";").map( {
            if %ansi{$_} -> $code {
                "\x[1B][" ~ $code ~ 'm'
            }
            else {
                '\c{' ~ $_ ~ '}'
            }
        }).join
    }

    # Replace any "0" at start by blank
    my sub blank(Str:D $it) {
        $it.starts-with("0")
          ?? " " ~ $it.substr(1)
          !! $it
    }

    # Subset of strftime formatting
    my sub expand-datetime(Str:D $format, DateTime:D $dt --> Str:D) {
        my $now           := $dt // DateTime.new;
        my str $yyyy-mm-dd = $now.yyyy-mm-dd;
        my str $hh-mm-ss   = $now.hh-mm-ss;

        # Convert hour to am/pm
        sub ampm() {
            $hh-mm-ss.substr(0,2) gt "11" ?? "pm" !! "am"
        }

        # Convert hour to 12 hour format, with given prefix if < 10
        sub ampm-hour($prefix) {
            my $hour = $hh-mm-ss.substr(0,2);
            if $hour gt "12" {
                $hour -= 12;
                $hour < 10 ?? $prefix ~ $hour !! $hour
            }
            else {
                $hour
            }
        }

        $format.trans: <
          %d %D %e %F %H %I %j %k %l %m %M %p %r %R %s %S %T %u %w %Y
        > => (
          { $yyyy-mm-dd.substr(5,2) },                       # %d
          { $now.dd-mm-yyyy("/") },                          # %D
          { blank($yyyy-mm-dd.substr(5,2)) },                # %e
          $yyyy-mm-dd,                                       # %F
          { $hh-mm-ss.substr(0,2) },                         # %H
          { ampm-hour("0") },                                # %I
          { $now.day-of-year.fmt('%03d') },                  # %j
          { blank($hh-mm-ss.substr(0,2)) },                  # %k
          { ampm-hour(" ") },                                # %l
          { $yyyy-mm-dd.substr(3,2) },                       # %m
          { $hh-mm-ss.substr(3,2) },                         # %M
          { ampm },                                          # %p
          { "&ampm-hour(" ")$hh-mm-ss.substr(2) &ampm()" },  # %r
          { $hh-mm-ss.substr(0,5) },                         # %R
          { $now.Instant.to-posix.head.Int },                # %s
          { $hh-mm-ss.substr(6,2) },                         # %S
          $hh-mm-ss,                                         # %T
          { $now.day-of-week },                              # %u
          { $now.day-of-week - 1 },                          # %w
          { $yyyy-mm-dd.substr(0,4) },                       # %Y
        )
    }

    method expand(Prompt:
      Str:D  $prompt,
            :$now,
      int   :$index,
            :$symbol = '>',
    --> Str:D) {

        # Constants for readability and constantness
        my constant bell    = chr(7);
        my constant escape  = chr(27);
        my constant newline = "\n";
        my constant tab     = "\t";
        my constant prefix  = escape ~ '[';
        my constant reset   = prefix ~ "0m";

        $prompt.trans: (
          '\i',                        # index
          '\a',                        # bell
          '\t',                        # tab
          '\n',                        # newline
          '\e',                        # escape
          '\c',                        # reset
          '\d',                        # hh:mm:ss
          '\v',                        # compiler version
          '\V',                        # compiler version (verbose)
          '\l',                        # language version
          '\L',                        # language version (verbose)
          '\P',                        # prompt symbol
          rx/ '\c' '{' <-[}]>* '}' /,  # colors
          rx/ '\d' '{' <-[}]>* '}' /,  # time
        ) => (
          $index,
          bell,
          tab,
          newline,
          escape,
          reset,
          DateTime.now.hh-mm-ss,
          $*RAKU.compiler.version.Str.substr(0,7),
          $*RAKU.compiler.version.gist,
          $*RAKU.version.Str,
          $*RAKU.version.gist,
          $symbol,
          { expand-color    $/.substr(3, *-1)       },
          { expand-datetime $/.substr(3, *-1), $now },
        )
    }

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
    method readline($prompt?){
        with self.read($prompt // '> ') -> $line {
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

    with $*PROMPT.readline($prompt) {
        val($_)
    }
    else {
        Nil
    }
}

# vim: expandtab shiftwidth=4
