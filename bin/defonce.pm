# Copyright (c) 2010-2016 Thomas C. Jones 
# Copyright (c) 2009 Echelon Corporation
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# Description:
#   Define constants once (in a .pl file) then produce include files in many languages
#
# TODOs:
#   o TODO: ARRAY representation
#   o TODO: short-hand self-referential constants (e.g. 'D' short for 'REG2_D')
#   o TODO: Verilog style literals
#   o TODO:     How to handle 'X' for Verilog and others?
#   o TODO: output radix control
#   o TODO: .docx generation, .xml generation (IP-XACT)
#   o TODO: preserve hierarchical order (top-level top) in targets
#   o TODO: pass-thru comments?
#   o TODO: name collision detection (locally and in .tcl/.ph)
#   o TODO: variable output width
#   o TODO: arbitrarily long vectors
#   o TODO: 'ACCESS' for .doc and IP-XACT type functionality
#   o TODO: Add 'header' function to include proprietary info header
#   o TODO: switch-able ifndef protection
#   o TODO: programmable endianness
#   o TODO: preserve range when copy'g defined value
#

package defonce;

use warnings;
use strict;

=head1 NAME

defonce - or "define once" - create definitions for constants in defonce and generate:
    .vh
    .h
    .ph
    .tcl
    .inc (Neuron assembly)

=head1 VERSION

Version 1.1

=cut
our $VERSION   = '6';

use base 'Exporter';

# When defonce is invoked, export, by default, the function "define" into
# the namespace of the using code.

our @EXPORT = qw(open_files define pragma close_files);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    BEGIN{push @INC, "../bin"};
    use defonce;

    include(xyz.ph);

    open_files(TCL, ...
    define(IFDEFABLE)
    define({THIS => That})
    define({NAME => signal,
           {BITS => 8,
          });
    ...
    close_files;

=head1 EXPORT

A list of functions that can be exported:
    open_files/configure:
      - filetypes to produce
      - ifndef protection
      - SV support flags?
      - case support/handling
      - perl scalar vs hash defines
      - overlapping fields
      - global prefix?
    define
    include
    pragma
    close_files

=head1 FUNCTIONS

=head2 define

=cut

use Data::Dumper;

# keywords
#    -BITS       - number of bits
#    -HI         - specify msb bit
#    -LO         - specify lsb bit
#    -BASE       - this is is a reg space and this is the base address
#    -MASK       - explicit mask
#    -CARDINAL   - this is a cardinal number
#    -OFFSET     - offset from base
#    -ENUM       - enumerate
#    -SUB        - subordinate type
#    -...        - any -{name} will be added to structure but not use until future apps

sub define {
    # parameters
    my ($args) = @_;

    # locals
    my $filetype;       # to cycle through each filetype opened
    my $name;           # name/
    my $value;          #   value pairs
    my %reg;            # register definition hash
    my @order;          # order list of non-std fields in register defn
    my $constant;       #   to cycle through ordered array
    my $tmp;            # temp copy of array reference for value
    my $flags;          # which range fields are actually specified
    my $BITS;           # scalar copies of range fields
    my $HI;             #
    my $LO;             #
    my $definition;     # hash reference to definition data

    # check for simple value-less define
    if(ref($args) eq "") {
        foreach $filetype (keys %defonce::handles) {
            if($filetype eq "VH")  { print {$defonce::handles{VH}}  "`define $args\n\n";              }
            if($filetype eq "PH")  { print {$defonce::handles{PH}}  "eval 'sub $args () {1;}';\n\n";  }
            if($filetype eq "INC") { print {$defonce::handles{INC}} "$args equ 1\n\n";                }
            if($filetype eq "TCL") { print {$defonce::handles{TCL}} "set $args 1;\n\n";               }
            if($filetype eq "H")   { print {$defonce::handles{H}}   "#define $args\n\n";              }
        }
        # also, define locally and in main namespace
        eval "sub $args       () {1;}";
        eval "sub main::$args () {1;}";
        return;
    }

    # Check for any but ARRAY - this must be an error
    if(ref($args) ne "ARRAY") {
        print STDERR "define: Error in input - received as follows:\n";
        print STDERR Dumper($args);
        die;
    }

    # Now parse the array
    while (@{$args}) {
        $name  = shift @{$args};
        $value = shift @{$args};

        # check for simple name/value define
        if(ref($value) eq "") {
            $value = _expand($value);

            foreach $filetype (keys %defonce::handles) {
                if($filetype eq "VH")  { print {$defonce::handles{VH}}  "`define $name $value\n";            }
                if($filetype eq "PH")  { print {$defonce::handles{PH}}  "eval 'sub $name () {$value;}';\n";  }
                if($filetype eq "INC") { if($value >= 64*1024) { print {$defonce::handles{INC}} ";$name equ $value\n";  }
                                         else                  { print {$defonce::handles{INC}} "$name equ $value\n"; } }
                if($filetype eq "TCL") { print {$defonce::handles{TCL}} "set $name $value;\n";               }
                if($filetype eq "H")   { print {$defonce::handles{H}}   "#define $name $value\n";            }
            }
            # also, define locally and in main namespace
            eval "sub $name       () {$value;}";
            eval "sub main::$name () {$value;}";
        } elsif(ref($value) eq "ARRAY") {

            # parse through array, converting to hash (ref)
            $definition->{$name}         = _parse($value);
            $defonce::definitions{$name} = $definition->{$name};
            _elaborate($definition, $definition->{$name}, 0);
            _define($definition->{$name}, $name);

            # if doing Tcl, and a hierarchical data structure is detected then create procs to access subfields
            if(exists $defonce::handles{TCL} && _hierarchical($definition->{$name},$name)) {
                _procs($definition->{$name},$name);
            }

        };#ref value is array
    };#while args

    # add a space after each define block
    foreach $filetype (keys %defonce::handles) {
        if($filetype eq "VH")  { print {$defonce::handles{VH}}  "\n"; }
        if($filetype eq "PH")  { print {$defonce::handles{PH}}  "\n"; }
        if($filetype eq "INC") { print {$defonce::handles{INC}} "\n"; }
        if($filetype eq "TCL") { print {$defonce::handles{TCL}} "\n"; }
        if($filetype eq "H")   { print {$defonce::handles{H}}   "\n"; }
    }

    return;
}#define


=head2 open_files

=cut
# Subroutine to open various types of include files
# Creates %handles and %files - also opens files and puts in initial information
sub open_files {

    # Get root file name
    my $base = $0;
    $base =~ s/.*\///;      # rm all up to last slash
    $base =~ s/.*\\//;      # rm all up to last backslash
    $base =~ s/\..*//;      # rm extension
    my $ROOT = uc $base;    # get an uppercase version of base
    my $file;               # ea. filename

    my $time = localtime(time);

    foreach my $arg (@_) {
        if(uc $arg eq "VH") {
            $file    = "_${base}.vh";
            open(FILE_VH, ">$file");
            $defonce::handles{VH}    = \*FILE_VH;

            print {$defonce::handles{VH}} "// Created from $0 on $time\n\n";

            print {$defonce::handles{VH}} "`ifndef _${ROOT}_VH\n";
            print {$defonce::handles{VH}} "`define _${ROOT}_VH\n\n";
        }
        if(uc $arg eq "PH") {
            $file    = "_${base}.ph";
            open(FILE_PH, ">$file");
            $defonce::handles{PH}    = \*FILE_PH;

            print {$defonce::handles{PH}} "# Created from $0 on $time\n\n";

            print {$defonce::handles{PH}} "unless(defined(&_${ROOT}_PH)) {\n";
            print {$defonce::handles{PH}} "eval 'sub _${ROOT}_PH () {1;}';\n\n";

        }
        if(uc $arg eq "INC") {
            $file   = "_${base}.inc";
            open(FILE_INC, ">$file");
            binmode FILE_INC;
            $defonce::handles{INC}    = \*FILE_INC;

            print {$defonce::handles{INC}} "; Created from $0 on $time\n\n";

            print {$defonce::handles{INC}} "    IFNDEF  _${ROOT}_INC\n";
            print {$defonce::handles{INC}} "_${ROOT}_INC equ 1\n\n";
        }
        if(uc $arg eq "TCL") {
            $file   = "_${base}.tcl";
            open(FILE_TCL, ">$file");
            $defonce::handles{TCL}    = \*FILE_TCL;

            print {$defonce::handles{TCL}} "# Created from $0 on $time\n\n";

            print {$defonce::handles{TCL}} "if {![info exists _${ROOT}_TCL]} {\n";
            print {$defonce::handles{TCL}} "set _${ROOT}_TCL 1;\n\n";
        }
        if(uc $arg eq "H") {
            $file     = "_${base}.h";
            open(FILE_H, ">$file");
            $defonce::handles{H}    = \*FILE_H;

            print {$defonce::handles{H}} "// Created from $0 on $time\n\n";

            print {$defonce::handles{H}} "#ifndef _${ROOT}_H\n";
            print {$defonce::handles{H}} "#define _${ROOT}_H\n\n";
        }
    }
}#open_files


=head2 close_files

=cut
# Subroutine to close various types of include files
# Uses %handles - also puts in final information before closing
sub close_files {

    # locals
    my $filetype;

    foreach $filetype (keys %defonce::handles) {
        if($filetype eq "VH")  { print {$defonce::handles{VH}}  "`endif\n";    close($defonce::handles{VH});  }
        if($filetype eq "PH")  { print {$defonce::handles{PH}}  "}\n1\n";      close($defonce::handles{PH});  }
        if($filetype eq "INC") { print {$defonce::handles{INC}} "    ENDIF\n"; close($defonce::handles{INC}); }
        if($filetype eq "TCL") { print {$defonce::handles{TCL}} "}\n";         close($defonce::handles{TCL}); }
        if($filetype eq "H")   { print {$defonce::handles{H}}   "#endif\n";    close($defonce::handles{H});   }
    }
}#close_files


=head2 pragma

=cut
# Subroutine to impart implementaion-specific information in
# specific filetypes
# Uses %handles
sub pragma {

    my ($args) = @_;

    # locals
    my $filetype;       # filetype to pragma to
    my $pragma;         # pragma data

    # Check for any but ARRAY - this must be an error
    if(ref($args) ne "ARRAY") {
        print STDERR "pragma: Error in input - received as follows:\n";
        print STDERR Dumper($args);
        die;
    }

    # Now parse the array
    while (@{$args}) {
        $filetype  = shift @{$args};
        $pragma     = shift @{$args};

        # Sanity-check data
        if(ref($filetype) ne "" || ref($pragma) ne "") {
            print STDERR "pragma: Error in input - received as follows:\n";
            print STDERR Dumper($args);
            die;
        }

        print {$defonce::handles{$filetype}}  "$pragma\n\n";
    };#while args
}#pragma


# private function to parse the input array
sub _parse {

    # Get array ref
    my ($aref) = @_;

    # locals - really local because it is recursive
    my $name;
    my $value;
    my $comment = "";
    my %hash;

    # sanity-check input
    if(ref($aref) ne "ARRAY") { die("parse: received non-array: ref($aref)\n"); }

    # cycle through each name/value pair
    while (@{$aref}) {
        if(${$aref}[0] =~ /^#/) { $comment  = shift @{$aref}; }
        else                    { $name     = shift @{$aref}; }
        if(${$aref}[0] =~ /^#/) { $comment  = shift @{$aref}; }
        else                    { $value    = shift @{$aref}; }
        if(@{$aref} && ${$aref}[0] =~ /^#/) { $comment  = shift @{$aref}; }
        
        if(ref($name) ne "") { die("Always use names in LHS\n"); }

        # 'DEFAULT' is a special case - may use either 'DEFAULT' or '-DEFAULT'
        if($name eq "-DEFAULT") { $name = "DEFAULT"; }

        # If not keyword save it in the order array (e.g. DEFAULT is OK)
        unless($name =~ /^-/) {
            push @{$hash{_ORDER}}, $name;
        }


        if(ref($value) eq "") {
            # See if default-type enumeration
            if($name eq "-ENUM") {
                if($value !~ /DEFAULT$/) { die("What do you want?: $name => $value\n"); }
                unless(exists $hash{-BITS}) { die("Define -BITS before default enumeration.\n"); }
                for($value=0;$value<(1<<$hash{-BITS});$value++) {
                    push @{$hash{_ORDER}}, "$value";
                    $hash{$value} = $value;
                }
            }elsif($name eq "-SUB") {
                unless(exists $defonce::definitions{$value}) { die("Define -SUB $name does not exist.\n"); }
                return _subordinate($defonce::definitions{$value});
            } else {
                $hash{$name} = $value;
            }
        } else { # if embedded array parse it
            # first, check for enumeration
            if($name eq "-ENUM") {
                #$hash{$name} = _enumerate($value);
                _enumerate(\%hash,$value);
            } else {
                $hash{$name} = _parse($value);
            }
        }

        # Queue comment if applicable
        if($comment ne "") {
            $comment               =~ s/#[ ]//;
            $hash{-COMMENT}{$name} =  $comment;
            $comment               =  "";
        }
    }
    return \%hash;
}#_parse

# private function to _enumerate an array reference
#   format is [a, b, c, d] which yields
#       _ORDER = [a, b, c, d]
#       a=>0, ... d=>3
#   alternatively [a, [b => 2], c, d] yields
#       _ORDER = [a, b, c, d]
#       a => 0, b=>2, c=>3, d=>4
sub _enumerate {
    my ($href,$aref) = @_;  # hash ref to parent data structure, array ref of data structure

    my $name;               # each entry in array
    my $value = 0;          # current value - starts @0 by default
    my $tn;                 # temporary name - to sanity-check update name
    my $tv;                 # temporary value - to sanity-check update value

    foreach $name (@{$aref}) {

        if(ref($name) eq "HASH") { die("hash not allowed in enumerations: " . Dumper($name)); }

        if(ref($name) eq "ARRAY") {
            ($tn,$tv) = @{$name};
            if($tn eq "" || $tv eq "") { die("error in enumeration: " . Dumper($name)); }
            if($tv<$value) { die("value sort order invalid in enumeration: $tn: $tv < $value\n"); }
            $name  = $tn;
            $value = $tv;
        }

        # If/when simple name add to order and set value
        push @{$href->{_ORDER}}, $name;
        $href->{$name} = $value++;
    }
}#_enumerate


# private function to _subordinate a predefined type
# Because it is fully _elaborated and _defined it is necessary
# to strip the keywords that fully define it (lo, hi, up)
# Added the recursive call for hash subfields but I don't think it
# is needed.  Other types (scalars and arrays) are just copied over
sub _subordinate {
    my ($href) = @_;        # hash ref to pre-defined data type

    my $key;                # each entry in hash
    my $value;              # each value
    my $name;               # each entry in an array
    my $hrefout;            # hash reference to construct
    my $tn;                 # temporary name - to sanity-check update name
    my $tv;                 # temporary value - to sanity-check update value

    foreach $key (keys %{$href}) {

        if($key eq "-LO" ||
           $key eq "-HI" ||
           $key eq "_UP") { next; }

        if(ref($key) eq "HASH") { 
            $hrefout->{$key} = _subordinate($href->{$key});
            next;
        }

        # Otherwise, just copy scalar or array
        $hrefout->{$key} = $href->{$key}
    }
    return $hrefout;
}#_subordinate


# private function to elaborate a hash reference, filling out bit widths, defaults, masks, etc.
sub _elaborate {

    # Get hash ref
    my ($up,$href,$bits) = @_;    # hash ref of data structure, current bit width

    # locals
    my $field;      # each ordered field of the input hash

    # Check for lowest level of elaboration - resolving any internal definitions:
    if(ref($href) eq "") {
        # try evaluating expression - can't do existence check if string contains math
        # If it still contains non numeric then barf
        $up->{$bits} = eval "$href";    # pass field name through bits for this part
        if($up->{$bits} !~ /^-?\d/) { die("$href: expected numeric or known value.\n"); }
        return;
    }

    # check/set _UP
    if(exists $href->{_UP}) {
        die("_UP already exists " . Dumper($href) . "\n");
    } else {
        $href->{_UP} = $up;
    }

    # Check if top-level of an address-able block of registers
    if(exists $href->{-BASE}) {

        if(!exists $href->{-BITS}) { die("Must specify -BITS w/ -BASE.\n"); }

        my $address = $href->{-BASE}; # local address for each register w/in a block
        my $offset  = 0;              #   = base + offset
        ($field)    = @{$href->{_ORDER}}; # get bits to use throughout - in first field
        if(!exists $href->{$field}->{-BITS}) { die("Must explicit about first reg -BITS when using -BASE.\n"); }
        my $BITS    = $href->{$field}->{-BITS};

        # cycle through each field
        foreach $field (@{$href->{_ORDER}}) {
            if(ref($href->{$field}) eq "HASH") {
                if(exists $href->{$field}->{-BITS} && $href->{$field}->{-BITS} != $BITS) {
                    die("Overriding local bits ($href->{$field}->{-BITS}) w/ register block bits ($href->{-BITS}) \@ $field.\n");
                }
                $href->{$field}->{-BITS}     = $BITS;
                if(exists $href->{$field}->{-OFFSET}) {
                    $href->{$field}->{_ADDRESS}  = $href->{-BASE} + $href->{$field}->{-OFFSET};
                    $address = $href->{$field}->{_ADDRESS}+1;
                    $href->{$field}->{OFFSET}    = $href->{$field}->{-OFFSET};
                    $offset                      = $href->{$field}->{-OFFSET}+1;
                } else {
                    if(exists $href->{$field}->{_ADDRESS}) { die("Overriding local address ($href->{$field}->{_ADDRESS}) w/ register block address ($address) \@ $field.\n"); }
                    $href->{$field}->{OFFSET}    = $offset++;
                    $href->{$field}->{_ADDRESS}  = $address++;
                }
                push @{$href->{$field}->{_ORDER}}, "_ADDRESS";
                push @{$href->{$field}->{_ORDER}}, "OFFSET";
            }
        }

        # put BASE back on the _ORDER list for kicks
        $href->{BASE} = $href->{-BASE};
        push @{$href->{_ORDER}}, "BASE";
    }

    # check/set LO
    if(exists $href->{-LO}) {
        _elaborate($href, $href->{-LO}, "-LO");
        if($href->{-LO} != $bits) {
            if($bits>0) {die("LSB mismatch $href->{-LO} s/b $bits\n");}
            $bits = $href->{-LO};
        }
    } else {
        $href->{-LO} = $bits;
    }

    # cycle through each field
    foreach $field (@{$href->{_ORDER}}) {
        if(ref($href->{$field}) eq "HASH") {
            $bits = _elaborate($href, $href->{$field}, $bits);
            if(exists $href->{-BASE}) {$bits=0;} # reset bits on each field w/ it's own address
        }
    }

    # Check if cardinal
    if(exists $href->{-CARDINAL}) {
        # fake it with bits - will fix-up later
        $href->{-BITS} = $href->{-CARDINAL};
    }

    # check/set -BITS - if not set must be at the top-level
    if(!exists $href->{-BITS}) {
        $href->{-BITS} = $bits - $href->{-LO};
    } else {
        _elaborate($href, $href->{-BITS}, "-BITS");
    }

    # HI is just LO+BITS-1
    $href->{-HI} = $href->{-LO} + $href->{-BITS} - 1;
    return $href->{-HI}+1;
}#_elaborate

# private function to produce define from fully elaborated hash reference
sub _define {

    # Get hash ref
    my ($href,$prefix) = @_;    # hash ref of data structure, name prefix (e.g. TOP_FIELD...)

    # locals
    my $filetype;   # to cycle through each filetype opened
    my $field;      # each ordered field of the input hash
    my $BITS;       # scalar copies of range fields
    my $HI;         #
    my $LO;         #

    # check _ORDER
    if(exists $href->{_ORDER}) {
        foreach $field (@{$href->{_ORDER}}) {
            if(ref($href->{$field}) eq "HASH") {
                _define($href->{$field}, "${prefix}_${field}");
            }
        }
    }

    # Get reg range-specific params back to scalars for convenience
    $BITS = $href->{-BITS};
    $LO   = $href->{-LO};
    $HI   = $href->{-HI};

    # if default and mask are not explicitly defined do so now
    if(!exists $href->{DEFAULT} && !exists $href->{-BASE}) {
        $href->{DEFAULT} = 0;
        if(exists $href->{_ORDER}) {
            foreach $field (@{$href->{_ORDER}}) {
                if($field eq "_ADDRESS" || $field eq "OFFSET") { next; }
                if(ref($href->{$field}) && exists $href->{$field}->{DEFAULT} && exists $href->{$field}->{-LO}) {
                    $href->{DEFAULT} |= $href->{$field}->{DEFAULT} << $href->{$field}->{-LO};
                } elsif($href->{DEFAULT}) {
                    print STDERR "Warning: some subfields of $prefix have DEFAULT value, $field does not.\n";
                    die;
                }
            }
        }
        push @{$href->{_ORDER}}, "DEFAULT";
    }
    if(!exists $href->{MASK} && !exists $href->{-BASE}) {
        $href->{MASK} = 0;
        for(my $i=0;$i<$BITS;$i++) { # hacky way to get up to 32b
            $href->{MASK} |= (1<<$i);
        }
        push @{$href->{_ORDER}}, "MASK";
    }

    # Regardless of supported filetype create variables in local and main namespaces
    if(exists $href->{-CARDINAL}) {
        _define_here("${prefix}", $BITS);
    } else {
        _define_here("${prefix}_BITS", $BITS);
    }
    _define_here("${prefix}_LO",   $LO);
    _define_here("${prefix}_HI",   $HI);
    foreach $field (@{$href->{_ORDER}}) {
        if(ref($href->{$field}) ne "HASH") {
            # re-elaborate field in case it refers to another field that's just been defined
            _elaborate($href, $href->{$field}, $field);
            _define_here("${prefix}_$field", $href->{$field});
        }
    }

    # Define regs per language
    foreach $filetype (keys %defonce::handles) {
        if($filetype eq "VH") {
            if(!exists $href->{-BASE}) {
                if(exists $href->{-CARDINAL}) {
                    _define_VH("${prefix}", $BITS);
                } else {
                    _define_VH("${prefix}_BITS", $BITS);
                    _define_VH("${prefix}_NULL", "\{$BITS\{1'b0\}\}");
                    _define_VH("${prefix}_FULL", "\{$BITS\{1'b1\}\}");
                }
                _define_VH("${prefix}_LO",   $LO);
                _define_VH("${prefix}_HI",   $HI);
                if(exists $href->{-CARDINAL}) {
                    _define_VH("${prefix}_RANGE", "$LO:$HI");
                    _define_VH("${prefix}_REVERSE", "$HI:$LO");
                } else {
                    _define_VH("${prefix}_RANGE", "$HI:$LO");
                    _define_VH("${prefix}_REVERSE", "$LO:$HI");
                    # non-cardinals fields get range shorthand
                    if(exists $href->{_UP}->{-BITS}) {
                        if($href->{-BITS}==1) {  #TODO: check for collisions?
                            _define_VH("${prefix}", "$LO");
                        } else {
                            _define_VH("${prefix}", "$HI:$LO");
                        }
                    }
                }
            }# no BASE
            foreach $field (@{$href->{_ORDER}}) {
                if(ref($href->{$field}) ne "HASH") {
                    if($field eq "MASK"    && exists $href->{_UP}->{-BITS} && !exists $href->{_ADDRESS}) {
                        _define_VH("${prefix}_$field", sprintf("$href->{_UP}->{-BITS}'h%X", $href->{$field}<<$LO));
                    } elsif($field eq "_ADDRESS" && exists $href->{_UP}->{-BITS}) {
                        _define_VH("${prefix}$field", sprintf("$href->{_UP}->{-BITS}'h%X", $href->{$field}));
                    } else {
                        if(exists $href->{MASK}) {
                            _define_VH("${prefix}_$field", sprintf("${BITS}'h%X", $href->{$field} & $href->{MASK}));
                        } elsif($field eq "BASE") {
                            _define_VH("${prefix}_$field", sprintf("${BITS}'h%X", $href->{$field}));
                        } else {
                            die("$field: no mask?\n") unless(exists $href->{MASK});
                        }
                    }
                }
            }
            if(!exists $href->{-BASE}) {
                print {$defonce::handles{VH}}  "\n";
                print {$defonce::handles{VH}}  "`ifdef _SYSTEMVERILOG\n";
                print {$defonce::handles{VH}}  "typedef reg [`${prefix}_RANGE] T_${prefix};\n";
                print {$defonce::handles{VH}}  "`endif // _SYSTEMVERILOG\n";
                print {$defonce::handles{VH}}  "\n";
            }# no BASE
        };#VH
        if($filetype eq "PH") {
            if(!exists $href->{-BASE}) {
                if(exists $href->{-CARDINAL}) {
                    _define_PH("${prefix}", $BITS);
                } else {
                    _define_PH("${prefix}_BITS", $BITS);
                }
                _define_PH("${prefix}_LO",   $LO);
                _define_PH("${prefix}_HI",   $HI);
                if(exists $href->{-CARDINAL}) {
                    _define_PH("${prefix}_RANGE", "($LO,$HI)");
                    _define_PH("${prefix}_REVERSE", "($HI,$LO)");
                } else {
                    _define_PH("${prefix}_RANGE", "($HI,$LO)");
                    _define_PH("${prefix}_REVERSE", "($LO,$HI)");
                    # non-cardinals fields get range shorthand
                    if(exists $href->{_UP}->{-BITS}) {
                        if($href->{-BITS}==1) {  #TODO: check for collisions?
                            _define_PH("${prefix}", $LO);
                        } else {
                            _define_PH("${prefix}", "($HI,$LO)");
                        }
                    }
                }
            }# no BASE
            foreach $field (@{$href->{_ORDER}}) {
                if(ref($href->{$field}) ne "HASH") {
                    if($field eq "_ADDRESS") {
                        _define_PH("${prefix}${field}", sprintf("0x%X", $href->{$field}));
                    } else {
                        if($LO>31 || $HI>31) { # can't handle 33b values in 32b OSs
                            _comment_PH("${prefix}_$field", sprintf("0x%X", $href->{$field}<<$LO));
                        } else {
                            _define_PH("${prefix}_$field", sprintf("0x%X", $href->{$field}<<$LO));
                        }
                    }
                }
            }
            print {$defonce::handles{PH}} "\n";
        };#PH
        if($filetype eq "INC") {
            if(!exists $href->{-BASE}) {
                if(exists $href->{-CARDINAL}) {
                    _define_INC("${prefix}", $BITS);
                } else {
                    _define_INC("${prefix}_BITS", $BITS);
                }
                _define_INC("${prefix}_LO",   $LO);
                _define_INC("${prefix}_HI",   $HI);
            }# no BASE
            foreach $field (@{$href->{_ORDER}}) {
                if(ref($href->{$field}) ne "HASH") {
                    if($field eq "_ADDRESS") {
                        _define_INC("${prefix}", sprintf("H'%X", $href->{$field}));
                    } else {
                        # suppress quantities > 64K since they cause nas to fail
                        if($href->{$field}<<$LO >= 64*1024) {
                            _comment_INC("${prefix}_$field", sprintf("H'%X", $href->{$field}<<$LO));
                        } else {
                            _define_INC("${prefix}_$field", sprintf("H'%X", $href->{$field}<<$LO));
                        }
                    }
                }
            }
            print {$defonce::handles{INC}} "\n";
        };#INC
        if($filetype eq "TCL") {
            if(!exists $href->{-BASE}) {
                if(exists $href->{-CARDINAL}) {
                    _define_TCL("${prefix}", $BITS);
                } else {
                    _define_TCL("${prefix}_BITS", $BITS);
                }
                _define_TCL("${prefix}_LO",   $LO);
                _define_TCL("${prefix}_HI",   $HI);
            }# no BASE
            foreach $field (@{$href->{_ORDER}}) {
                if(ref($href->{$field}) ne "HASH") {
                    if($field eq "_ADDRESS") {
                        _define_TCL("${prefix}", sprintf("0x%X", $href->{$field}));
                    } else {
                        _define_TCL("${prefix}_$field", sprintf("0x%X", $href->{$field}));
                    }
                }
            }
            print {$defonce::handles{TCL}} "\n";
        };#TCL
        if($filetype eq "H") {
            if(!exists $href->{-BASE}) {
                if(exists $href->{-CARDINAL}) {
                    _define_H("${prefix}", $BITS);
                } else {
                    _define_H("${prefix}_BITS", $BITS);
                }
                _define_H("${prefix}_LO",   $LO);
                _define_H("${prefix}_HI",   $HI);
                if($LO eq $HI && !(exists $href->{-CARDINAL})) { # TODO: consolodate CARDINAL/!CARDINAL
                    _define_H("${prefix}",   $LO);
                }
                if(exists $href->{-CARDINAL}) {
                    _define_H("${prefix}_RANGE", "$LO:$HI");
                    _define_H("${prefix}_REVERSE", "$HI:$LO");
                } else {
                    _define_H("${prefix}_RANGE", "$HI:$LO");
                    _define_H("${prefix}_REVERSE", "$LO:$HI");
                }
            }# no BASE
            foreach $field (@{$href->{_ORDER}}) {
                if(ref($href->{$field}) ne "HASH") {
                    if($field eq "_ADDRESS") {
                        _define_H("${prefix}", sprintf("0x%X", $href->{$field}));
                    } else {
                        _define_H("${prefix}_$field", sprintf("0x%X", $href->{$field}<<$LO));
                    }
                }
            }
            print {$defonce::handles{H}} "\n";
        };#H
    };#foreach filetype

    return;
}#_define

# defonce global field width
$defonce::WIDTH = 38;

# filetype-specific defines
sub _define_VH  { printf {$defonce::handles{VH}}  "`define %-${defonce::WIDTH}s %s\n",           $_[0], $_[1];}
sub _define_PH  { printf {$defonce::handles{PH}}  "eval 'sub %-${defonce::WIDTH}s () {%s;}';\n", $_[0], $_[1];}
sub _comment_PH  { printf {$defonce::handles{PH}}  "#eval 'sub %-${defonce::WIDTH}s () {%s;}';\n", $_[0], $_[1];}
sub _define_INC { printf {$defonce::handles{INC}} "%-${defonce::WIDTH}s equ %s\n",               $_[0], $_[1];}
sub _comment_INC { printf {$defonce::handles{INC}} ";%-${defonce::WIDTH}s equ %s\n",               $_[0], $_[1];}
sub _define_TCL { printf {$defonce::handles{TCL}} "set %-${defonce::WIDTH}s %s\n",               $_[0], $_[1];}
sub _define_H   { printf {$defonce::handles{H}}   "#define %-${defonce::WIDTH}s %s\n",           $_[0], $_[1];}

# local and global namespace define
sub _define_here { eval "sub $_[0] () {$_[1];}"; eval "sub main::$_[0] () {$_[1];}"; }

# expand individual value
sub _expand {
    my $value = shift @_;
    if($value !~ /^-?\d/) {
        my $new = eval "$value";
        if($new !~ /^-?\d/) { die("$value: expected numeric or known value.\n"); }
        $value = $new;
    }
    return $value
}

# DFS traversal to determine which structures are "hierarchical"
# item must have bit-width and it's children must have the same
# Although reg-spaces are hierarchical by this defn they are not included
#   b/c the goal to create get/put procs in Tcl and it doesn't make sense for reg spaces
sub _hierarchical {

    # Get hash ref
    my ($href,$prefix) = @_;    # hash ref of data structure, name prefix (e.g. TOP_FIELD...)

    # locals
    my $field;      # each ordered field of the input hash

    # check _ORDER
    if(exists $href->{_ORDER}) {
        foreach $field (@{$href->{_ORDER}}) {
            if(ref($href->{$field}) eq "HASH") {
                if(exists $href->{$field}->{-BITS}) {
                    _hierarchical($href->{$field}, "${prefix}_${field}");
                    push @{$href->{_HIERARCHICAL}},$field;
                }
            }
        }
    }
    return exists $href->{_HIERARCHICAL};
}

# Once hierarchy is determined this routine re-traverses and generates the procs (in Tcl)
sub _procs {

    # Get hash ref
    my ($href,$prefix) = @_;    # hash ref of data structure, name prefix (e.g. TOP_FIELD...)

    # locals
    my $field;      # each ordered field of the input hash

    # check _HIERARCHICAL
    if(exists $href->{_HIERARCHICAL}) {
        if(!exists $href->{-BASE}) {
            _procs_TCL($prefix, $href->{_HIERARCHICAL});
        }
        foreach $field (@{$href->{_HIERARCHICAL}}) {
            _procs($href->{$field}, "${prefix}_${field}");
        }
    }
}#_procs


sub _procs_TCL {

    # Get hash ref
    my ($prefix,$aref) = @_;    # name prefix and list of subfields, in order

    if(!defined $defonce::Tcl_helper_proc_named) {
        print {$defonce::handles{TCL}} "# proc to assist in named arguments - OK to multiply define\n";
        print {$defonce::handles{TCL}} "proc named {args defaults} {\n";
        print {$defonce::handles{TCL}} "    upvar 1 \"\" \"\"\n";
        print {$defonce::handles{TCL}} "    array set \"\" \$defaults\n";
        print {$defonce::handles{TCL}} "    foreach {key value} \$args {\n";
        print {$defonce::handles{TCL}} "        if {![info exists (\$key)]} {\n";
        print {$defonce::handles{TCL}} "            error \"bad option \'\$key\', should be one of: [lsort [array names {}]]\"\n";
        print {$defonce::handles{TCL}} "        }\n";
        print {$defonce::handles{TCL}} "        set (\$key) \$value\n";
        print {$defonce::handles{TCL}} "    }\n";
        print {$defonce::handles{TCL}} "};#named\n";
        $defonce::Tcl_helper_proc_named = 1;
    }

    # locals
    my $field;      # each ordered field of the input array

    # print put proc
    print {$defonce::handles{TCL}} "# Set any number of field in ${prefix}\n";
    print {$defonce::handles{TCL}} "proc $prefix {args} {\n";
    print {$defonce::handles{TCL}} "    global ${prefix}_MASK\n";
    foreach $field (@{$aref}) {
        print {$defonce::handles{TCL}} "    global ${prefix}_${field}_MASK  ${prefix}_${field}_LO\n";
    }
    print {$defonce::handles{TCL}} "\n    named \$args { -${prefix} 0 ";
    foreach $field (@{$aref}) {
        print {$defonce::handles{TCL}} "-${field} _x ";
    }
    print {$defonce::handles{TCL}} "}\n\n";
    foreach $field (@{$aref}) {
        print {$defonce::handles{TCL}} "    if {\$(-${field}) != \"_x\"} { set (-${prefix}) [expr (\$(-${prefix}) & (\$${prefix}_MASK ^ (\$${prefix}_${field}_MASK << \$${prefix}_${field}_LO))) | ((\$(-${field}) & \$${prefix}_${field}_MASK) << \$${prefix}_${field}_LO)] }\n"
    }
    print {$defonce::handles{TCL}} "\n    return \$(-${prefix});\n";
    print {$defonce::handles{TCL}} "};#$prefix\n\n";

    # print get procs
    foreach $field (@{$aref}) {
        print {$defonce::handles{TCL}} "# Get ${prefix}_${field} from ${prefix}\n";
        print {$defonce::handles{TCL}} "proc ${prefix}_${field} {${prefix}} {\n";
        print {$defonce::handles{TCL}} "    global ${prefix}_${field}_MASK ${prefix}_${field}_LO\n\n";
        print {$defonce::handles{TCL}} "    return [expr (\$${prefix} >> \$${prefix}_${field}_LO) & \$${prefix}_${field}_MASK]\n";
        print {$defonce::handles{TCL}} "};#${prefix}_${field}\n\n";
    }
}#_procs


=head1 AUTHOR

Thomas C. Jones, C<< <thomas.jones at earthlink.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-defonce at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=defonce>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc defonce


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=defonce>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/defonce>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/defonce>

=item * Search CPAN

L<http://search.cpan.org/dist/defonce/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Thomas C. Jones, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of defonce
