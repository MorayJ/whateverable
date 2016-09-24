#!/usr/bin/env perl6
# Copyright © 2016
#     Aleks-Daniel Jakimenko-Aleksejev <alex.jakimenko@gmail.com>
#     Daniel Green <ddgreen@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use lib ‘.’;
use Whateverable;

use IRC::Client;

unit class Committable is Whateverable;

constant LIMIT      = 1000;
constant TOTAL-TIME = 60*3;

method help($message) {
    “Like this: {$message.server.current-nick}: f583f22,HEAD say ‘hello’; say ‘world’”
};

multi method irc-to-me($message where { .text !~~ /:i ^ [help|source|url] ‘?’? $ | ^stdin /
                                        # ↑ stupid, I know. See RT #123577
                                        and .text ~~ /^ \s* $<config>=\S+ \s+ $<code>=.+ / }) {
    my $value = self.process($message, ~$<config>, ~$<code>);
    return ResponseStr.new(:$value, :$message);
}

method process($message, $config, $code is copy) {
    my $start-time = now;
    my @commits;
    my $old-dir = $*CWD;
    if $config ~~ / ‘,’ / {
        @commits = $config.split: ‘,’;
    } elsif $config ~~ /^ $<start>=\S+ ‘..’ $<end>=\S+ $/ {
        chdir RAKUDO; # goes back in LEAVE
        if run(‘git’, ‘rev-parse’, ‘--verify’, $<start>).exitcode != 0 {
            return “Bad start, cannot find a commit for “$<start>””;
        }
        if run(‘git’, ‘rev-parse’, ‘--verify’, $<end>).exitcode   != 0 {
            return “Bad end, cannot find a commit for “$<end>””;
        }
        my ($result, $exit-status, $exit-signal, $time) =
          self.get-output(‘git’, ‘rev-list’, “$<start>^..$<end>”); # TODO unfiltered input
        return ‘Couldn't find anything in the range’ if $exit-status != 0;
        @commits = $result.split: “\n”;
        my $num-commits = @commits.elems;
        return “Too many commits ($num-commits) in range, you're only allowed {LIMIT}” if $num-commits > LIMIT;
    } elsif $config ~~ /:i releases / {
        @commits = @.releases;
    } else {
        @commits = $config;
    }

    my ($succeeded, $code-response) = self.process-code($code, $message);
    return $code-response unless $succeeded;
    $code = $code-response;

    my $filename = self.write-code($code);

    my @result;
    my %lookup;
    for @commits -> $commit {
        # convert to real ids so we can look up the builds
        my $full-commit = self.to-full-commit($commit);
        my $output = ‘’;
        if not defined $full-commit {
            $output = ‘Cannot find this revision’;
        } elsif not self.build-exists($full-commit) {
            $output = ‘No build for this commit’;
        } else { # actually run the code
            ($output, my $exit, my $signal, my $time) = self.run-snippet($full-commit, $filename);
            if $signal < 0 { # numbers less than zero indicate other weird failures
                $output = “Cannot test this commit ($output)”;
            } else {
                $output ~= “ «exit code = $exit»” if $exit != 0;
                $output ~= “ «exit signal = {Signal($signal)} ($signal)»” if $signal != 0;
            }
        }
        my $short-commit = self.get-short-commit($commit);

        # Code below keeps results in order. Example state:
        # @result = [ { commits => [‘A’, ‘B’], output => ‘42‘ },
        #             { commits => [‘C’],      output => ‘69’ }, ];
        # %lookup = { ‘42’ => 0, ‘69’ => 1 }
        if not %lookup{$output}:exists {
            %lookup{$output} = +@result;
            @result.push: { commits => [$short-commit], :$output };
        } else {
            @result[%lookup{$output}]<commits>.push: $short-commit;
        }

        if (now - $start-time > TOTAL-TIME) {
            return "«hit the total time limit of {TOTAL-TIME} seconds»";
        }
    }

    my $msg-response = ‘¦’ ~ @result.map({ “«{.<commits>.join(‘,’)}»: {.<output>}” }).join(“\n¦”);
    return $msg-response;

    LEAVE {
        chdir $old-dir;
        unlink $filename if $filename.defined and $filename.chars > 0;
    }
}

Committable.new.selfrun(‘committable6’, [ /commit6?/, fuzzy-nick(‘committable6’, 3) ]);

# vim: expandtab shiftwidth=4 ft=perl6
