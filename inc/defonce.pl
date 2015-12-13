# Copyright (c) 2009, Thomas C. Jones and Echelon Corporation
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
#   A defonce.pm tour de force
#
# TODOs:
#   none.
#

# Tell where to find defonce.pm
BEGIN{push @INC, "../bin"}; # specify a relative path from where ever you are

# use it
use defonce;

# use anything else in Perl you desire
use Data::Dumper;

# State which filetypes this template will target
open_files(VH, PH, INC, TCL, H); # You only need to specify the outout file types you desire

# A simple define of nothing - as in the case for an ifdef
define(IFDEFABLE);

# A simple define:
define([JOEBLOW  => 99]);

# Multiple defines with on statement comes for free:
define([THIS     => 1,
        THAT     => 2]);

# Define of a reg based on name and bit-width alone
define([REG8     => [-BITS    => 8]
       ]);

# Define of a reg with values
define([REG4     => [-BITS    => "REG8_BITS/2",     # math in quotes to evaluate properly
                     A        => 1,                 # put your comments here
                     B        => 2,
                     C        => 3,
                    ]
       ]);

# Define of a reg with explicit default value
define([REG2     => [-BITS    => &REG4_BITS/2,      # alternatively, use sub moniker if value known before define
                     E        => 0,                 # ...
                     F        => 1,
                     G        => 2,
                     H        => 3,
                     -DEFAULT => REG2_H,            # single values are automatically quoted
                    ]
       ]);

# TODO: Define of a reg with width and offset LSB
# TODO: Define of a reg with width and offset MSB
# TODO: Define of a reg with MSB and LSB

# Define a hierarchically defined structure
define([HIERARCHICAL => [FIELD1   => [-BITS    => 8,
                                      A        => 1,     # constants for this field
                                      B        => 2,     # just put your comments here
                                     ],
                         FIELD2   => [-BITS    => 16,
                                      C        => 3,     # ...
                                      D        => 4,     # ...
                                      -DEFAULT => "HIERARCHICAL_FIELD2_D",  # quotes don't hurt
                                     ],
                         FIELD3   => [-BITS    => 8,
                                      E        => 5,     # ...
                                      F        => 6,     # ...
                                     ],
                        ]
]);

# Define a register block
define([SDI     => [-BASE       => 0xFF00,                              # 'BASE' signals this is going to be a register array
                    -BITS       => 16,                                  # BITS here indicate the ADDRESS size
                    VERSION     => [-BITS       => 8,                   # BITS here are for the regs size (known redudancy)
                                    XCVR        => [-BITS    => 4,      # Transceiver Type
                                                    -ENUM    => [NONE,     # None
                                                                 FT,       # Free Topology
                                                                 PL,       # Power Line
                                                                 RF,       # Radio Frequency
                                                                 [XL=>9]]],# Bogus
                                   VER          => [-BITS    => 4]],    # SDI Version
                    CLOCK_RATE  => [MAX         => [-BITS    => 3,      # Max Clock Rate
                                                    '2M5'    => 0,      #   2.5MHz
                                                    '5M'     => 1,      #   5MHz
                                                    '10M'    => 2,      #   10MHz
                                                    '20M'    => 3,      #   20MHz
                                                    '40M'    => 4,      #   40MHz
                                                    '80M'    => 5,      #   80MHz
                                                    '160M'   => 6,      #   160MHz
                                                    '320M'   => 7]      #   320MHz
                                   ]
                   ],
       ]);
define([
        REFRESH => [-BASE       => 0xFF10,
                    -BITS       => 16,
                    CSR         => [-BITS       => 8,                   # bits for regs
                                    RETENTION   => [-BITS    => 2,      # Retention
                                                    -ENUM    => ['2MS',   #  2.0ms
                                                                 '3MS5',  #  3.5ms
                                                                 '5MS',   #  5.0ms
                                                                 '6MS5']],#  6.5ms
                                    RFRATE      => [-BITS    => 2,      # Refresh rate
                                                    1        => 0,      #   1 block/refresh
                                                    2        => 1,      #   2 block/refresh
                                                    4        => 2,      #   4 block/refresh
                                                    8        => 3],     #   8 block/refresh
                                   NO_QUEUE     => [-BITS    => 1],     # No refresh request queuing
                                   SPEEDUP      => [-BITS    => 1],     # Speed up refreshes for clock switching
                                   DISABLE      => [-BITS    => 1],     # Disable refresh (if debugMode) for debug purposes
                                   TIMEOUT      => [-BITS    => 1],     # Refresh timeout detected (read-only)
                                  ]
                   ]
        ]);

# default enumerated types
define([ENUMY    => [-BITS    => 2,
                     -ENUM    => -DEFAULT]]);       # 0=>0, ...


# Finally, pass anything you'd desire explicitly into target
pragma([
    VH  => "//vh pragma",
    PH  => "#ph pragma",
    INC => ";inc pragma",
    TCL => "#tcl pragma",
    H   => "
/*
 *  h pragma...
 */

"]);

# Close all the targets - this is necessary for closing the `ifdef/`endif type structure
close_files;


exit;
