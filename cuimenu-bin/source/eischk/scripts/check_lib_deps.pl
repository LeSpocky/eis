#! /usr/bin/perl
use strict;
use warnings;

# --- GLOBAL VARS ---
our (%files, %alias, %libs, 
     @files, @args, @res, 
     $key, $libc6_bin, $name, $type, $first, $verbose, $file, $error);

sub get_args {
    my ($aref) = @_;
    my @retlist = ();
    my ($i);
    for ($i=0; $i<20 && $#{$aref} >= 0; $i++) {
        push @retlist, "'" . shift (@$aref) . "'";
    }
    return @retlist;
}

sub print_verb {
    my ($txt, $serverity) = @_;
    return unless $verbose || $serverity;

    if ($first) {
        print "$name:\n";
        $first = 0;
    }
    print "    $txt";
}

# our (%files, %alias,
#      @files, @args, @res, @libs, 
#     $key, $name, $type, $first, $arg, $verbose);

$ENV{'LANG'} = 'C';

if ($#ARGV > -1 && $ARGV[0] eq "-v") {
    $verbose = 1;
    shift;
} else {
    $verbose = 0;
}
$error = 0; 
    
while(<>) {
    if (/^file.*/) {
	if (/^file\s+(\S+)\s+\'([^']+)\'.*/) {
	    $name=$1;
	    $file=$2;
	    $files{$file} = $name;
	} else {
	    ($type, $name, $file) = split;
	    $files{$file} = $name;
	}
    }
}


foreach $key (grep (/((^|.*\/)lib\/.*lib.*\.so.*)|((^|.*\/)ld-.*\.so)/,  sort values %files)) {
    $name = $key;
    $name =~ s#.*/##;
    
    print_verb("Warning: Ambigous library reference for $name: $key <-> $libs{$name}\n", 1) if defined $libs{$name} && $libs{$name} ne $key;

    $libs{$name} = $key;
}
    
foreach $key (keys %libs) {
    my($a);
    if ($key =~ /-\d+\.\d+.*/) {
	$a = $key;
	$a =~ s#-\d+\.\d+.*#.so.0#;
	$alias{$a} = $key;
	print_verb ("Alias: $key -> $a\n", 0);
    }
    if ($key =~ /(.*\.so\.\d+)(\.\d)+/) {
	$alias{$1} = $key;
	print_verb ("Alias: $key -> $1\n", 0);
    }
}
@files = sort keys %files;

$libc6_bin="";
for (@args = get_args(\@files); @args != 0; @args = get_args(\@files)) 
{
    open (STRINGS, "readelf -d @args 2> /dev/null |") || die "unable to fork readelf";
    while (<STRINGS>) {
        if (/^File: (.*)/) {
            $name = $1;
            $first = 1;
            next;
        }
        if (/.*NEEDED.*\[([^\]]+)\]/) {
            my ($lib, $txt, $err) = ("$1", "'$1' ", 0);
	    
            next if $lib eq "libc.so.0";
            if ($lib =~ /^libc\.so\..*/) {
                print_verb("uses alternate libc versions: $lib\n", 1);
		$libc6_bin=$name;
            }


	    if (defined $libs{$lib}) {
                $txt = "$txt ($libs{$lib})\n";
	    } elsif (defined($alias{$lib})) {
		$txt = "$txt ($alias{$lib})\n";		
	    } else {
		$txt = "$txt (missing)\n";
		$err = 1;
	    }
            $error = 1 if $err;
            print_verb ($txt, $err);
        }
    }
    close STRINGS;
}
if ($verbose) {
    print "\n#\n# Available Libraries:\n#\n";
    print "    ".join("\n    ",  keys %libs);
    print "\n";
}

exit $error;
