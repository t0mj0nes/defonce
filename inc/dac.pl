# Description:
#     Example Definitions for a fake DAC

BEGIN{push @INC, "../bin"}; # path to defonce.pm
use defonce 1.21;
use POSIX qw(ceil);

open_files(VH, PH, H);

$dac_bits         = 10;
$dac_midscale     = (1<<($dac_bits-1));
define([DAC      => [-BITS      => $dac_bits,                                                   # Define DAC + constants
                    MIDSCALE    => $dac_midscale,
                    -DEFAULT    => $dac_midscale]]);

define([ADDR     => [-BITS      => 32]]);                                                       # I'd put these in another defonce file...
define([DATA     => [-BITS      => 16]]);                                                       #     ...but for this example...


define([REG_DAC  => [-BASE       => 0x1234,                                                     # DAC block
                     -BITS       => &ADDR_BITS,                                                 # 
                     STATUS      => [-BITS           => &DATA_BITS,                             #   Status
                                    BUSY            => [-BITS   =>  1],                         #       Busy
                                    RSVD            => [-BITS   => 15]],                        #       Reserved (not necessary to include this)
                     DATA        => [-BITS           => &DATA_BITS,                             #   Data
                                    DATA            => [-BITS   => $dac_bits],                  #       DAC DATA portions
                                    RSVD            => [-BITS   => $DATA_BITS-$dac_bits]]]]);   #       Reserved (not necessary to include this)



pragma([H => "
/* comments, etc */

#define reg_dac_status      (*(unsigned int*)REG_DAC_STATUS)        // 0x1234
#define reg_dac_data        (*(unsigned int*)REG_DAC_DATA)          // 0x1235
                            /* your reg access may differ */
                            /* consult your FW engineer   */
"]);
 

close_files;#dac
