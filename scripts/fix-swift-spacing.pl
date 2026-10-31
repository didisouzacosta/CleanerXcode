#!/usr/bin/env perl
# Inserts the blank lines required by the shared SwiftLint spacing rules:
# blank_line_before_block, blank_line_after_block and let_var_group_separation.
# The patterns mirror .swiftlint.yml; keep both in sync. The script is idempotent
# and only touches the files passed as arguments.
use strict;
use warnings;

my $attr = qr/(?:@[\w.]+(?:\([^()\n]*\))?[ \t]+)*/;
my $mods = qr/(?:(?:private|fileprivate|internal|public|package|open|static|class|nonisolated|lazy|weak|unowned|final|override)(?:\([a-z]+\))?[ \t]+)*/;
my $decl = qr/$attr$mods/;

sub fix {
    my ($source) = @_;
    my $changed = 1;
    my $passes = 0;

    while ($changed) {
        die "fix-swift-spacing: no fixed point after 20 passes\n" if ++$passes > 20;

        my $before = $source;

        # blank_line_before_block
        $source =~ s~^([ \t]+)((?!//|case\b|default\b|@|\#)[^\n]*[^\n{(\[,:\s](?<!\bin)\n)(?=\1(?:if|guard|for|while|switch|do|repeat|defer)\b)~$1$2\n~gm;

        # blank_line_after_block
        $source =~ s~^([ \t]+)(\}[ \t]*\n)(?=\1(?![ \t]|\}|\)|\]|\.|else\b|catch\b|case\b|default\b|\#|//)\S)~$1$2\n~gm;

        # let_var_group_separation
        $source =~ s~^([ \t]*)($decl let[ \t][^\n]*\n)(?=\1$decl var[ \t])~$1$2\n~gmx;
        $source =~ s~^([ \t]*)($decl var[ \t][^\n]*\n)(?=\1$decl let[ \t])~$1$2\n~gmx;

        # let_var_whitespace: a stored property directly followed by another member declaration.
        $source =~ s~^([ \t]*)($decl (?:let|var)[ \t][^\n]*[^\n{(\[,=][ \t]*\n)(?=\1$decl (?:init|func|deinit|subscript|struct|class|enum|actor|extension|typealias)\b)~$1$2\n~gmx;

        $changed = $source ne $before;
    }

    return $source;
}

my $status = 0;

for my $path (@ARGV) {
    next unless $path =~ /\.swift\z/ && -f $path && !-l $path;

    open(my $in, '<:raw', $path) or do { warn "fix-swift-spacing: cannot read $path: $!\n"; $status = 1; next };
    local $/;
    my $original = <$in>;
    close($in);

    my $fixed = fix($original);
    next if $fixed eq $original;

    open(my $out, '>:raw', $path) or do { warn "fix-swift-spacing: cannot write $path: $!\n"; $status = 1; next };
    print {$out} $fixed;
    close($out);
    print "Fixed spacing: $path\n";
}

exit $status;
