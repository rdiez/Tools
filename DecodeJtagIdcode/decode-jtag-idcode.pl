#!/usr/bin/perl

=head1 OVERVIEW

decode-jtag-idcode.pl version 1.00

This command-line tool breaks a JTAG IDCODE up into fields as specified in IEEE standard 1149.1.

=head1 USAGE

S<perl decode-jtag-idcode.pl [options] E<lt>0xIDCODE<gt>>

Example:

  perl decode-jtag-idcode.pl 0x4ba00477

=head1 OPTIONS

=over

=item *

B<-h, --help>

Print this help text.

=item *

B<--version>

Prints the name and version number.

=item *

B<--license>

Print the license.

=back

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2013 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut


use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use constant SCRIPT_NAME => $0;
use constant SCRIPT_VERSION => "1.00";  # If you update it, update also the perldoc text above.

use constant EXIT_CODE_SUCCESS       => 0;
use constant EXIT_CODE_FAILURE_ARGS  => 1;
use constant EXIT_CODE_FAILURE_ERROR => 2;

use integer;  # There is no need to resort to floating point at any time in this script.


# ----------- main routine, the script entry point is at the bottom -----------

sub main ()
{
  my $arg_help             = 0;
  my $arg_h                = 0;
  my $arg_version          = 0;
  my $arg_license          = 0;

  my $result = GetOptions(
                 'help'      =>  \$arg_help,
                 'h'         =>  \$arg_h,
                 'version'   =>  \$arg_version,
                 'license'   =>  \$arg_license
                );

  if ( not $result )
  {
    # GetOptions has already printed an error message.
    return EXIT_CODE_FAILURE_ARGS;
  }

  if ( $arg_help || $arg_h )
  {
    write_stdout( "\n" . get_cmdline_help_from_pod( SCRIPT_NAME ) );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_version )
  {
    write_stdout( "decode-jtag-idcode.pl version " . SCRIPT_VERSION . "\n" );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_license )
  {
    write_stdout( get_license_text() );
    return EXIT_CODE_SUCCESS;
  }

  if ( 1 != scalar @ARGV )
  {
    die "Invalid number of arguments. Run this tool with the --help option for usage information.\n";
  }

  my $idcodeArg = shift @ARGV;

  my $idcodeValue = read_idcode( trim_blanks( $idcodeArg ) );

  decode_idcode( $idcodeValue );

  return EXIT_CODE_SUCCESS;
}


sub read_idcode ( $ )
{
  my $idcodeArg = shift;

  my $ret;

  eval
  {
    use constant PREFIX => "0x";

    if ( !str_starts_with( $idcodeArg, PREFIX ) )
    {
      die qq<The IDCODE must start with "@{[ PREFIX ]}".\n>;
    }

    my $hexPart = substr( $idcodeArg, length(PREFIX) );

    if ( length( $hexPart ) == 0 )
    {
      die qq<Invalid JTAG IDCODE.\n>;
    }

    use constant MAX_HEX_DIGIT_LEN => 8;

    if ( length( $hexPart ) > MAX_HEX_DIGIT_LEN )
    {
      die qq<The IDCODE is too long. A JTAG IDCODE is a 32-bit number and can have a maximum of @{[ MAX_HEX_DIGIT_LEN ]} hexadecimal digits.\n>;
    }

    if ( lc( $hexPart ) =~ m/[^0-9a-f]/ )
    {
      die qq<The IDCODE is not a valid hexadecimal number.\n>;
    }

    $ret = hex( $hexPart );
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    die qq<Error reading JTAG IDCODE "$idcodeArg": $errorMessage\n>;
  }

  return $ret;
}


sub decode_idcode ( $ )
{
  my $idcodeValue = shift;

  # Convert to a 32-bit number, and then to binary.
  my $binaryVal = unpack( "B32", pack( "N", $idcodeValue ) );

  if ( 32 != length $binaryVal )
  {
    die qq<Internal error converting the JTAG IDCODE hexadecimal value to binary.\n>;
  }

  # write_stdout( $binaryVal . "\n" );

  my $version      = substr( $binaryVal, 0,   4 );
  my $partNumber   = substr( $binaryVal, 4,  16 );
  my $manufacturer = substr( $binaryVal, 20, 11 );
  my $leadingBit   = substr( $binaryVal, 31,  1 );


  my $versionsSuffix     = sprintf( "(0x%X, %u)", oct( "0b$version" )     , oct( "0b$version" )      );
  my $partNumberSuffix   = sprintf( "(0x%X, %u)", oct( "0b$partNumber" )  , oct( "0b$partNumber" )   );
  my $manufacturerSuffix = sprintf( "(0x%X, %u)", oct( "0b$manufacturer" ), oct( "0b$manufacturer" ) );

  my $manufacturerName = get_manufacturer_name( $manufacturer );
  my $manufacturerSuffix2 = "  # Name: $manufacturerName";

  write_stdout( sprintf( "Decoding of JTAG IDCODE 0x%08X (%u, 0b%s):\n", $idcodeValue, $idcodeValue, $binaryVal ) );
  write_stdout( "Version:      0b$version  $versionsSuffix\n" );
  write_stdout( "Part number:  0b$partNumber  $partNumberSuffix\n" );
  write_stdout( "Manufacturer: 0b$manufacturer  $manufacturerSuffix$manufacturerSuffix2\n" );

  # According to the IEEE standard 1149.1, if this bit is zero, then the device did not have an IDCODE to read.

  my $leadingBitSuffix = $leadingBit eq "1" ? "Always set to 1 according to the IEEE standard 1149.1" : "WRONG, should be 1 according to the IEEE standard 1149.1";

  write_stdout( "Leading bit:  $leadingBit  # $leadingBitSuffix\n" );
}


sub get_manufacturer_name ( $ )
{
  my $manufacturer = shift;

  my %list =
  (
      # Data copied from this file (under MIT license), which is dated from Oct 10, 2011:
      #   http://playtag.googlecode.com/svn/trunk/playtag/bsdl/data/manufacturers.txt
      # There is a script there in order to extract it from the published PDF document:
      #   http://playtag.googlecode.com/svn/trunk/tools/bsdl/updatemfg.py
      # And then processed with emacs' replace-regexp, in order to turn it into perl syntax as follows:
      #   \([01]*\)[ ]*\(.*\)  ->  '\1' => '\2',

      '00000000001' => 'AMD',
      '00000000010' => 'AMI',
      '00000000011' => 'Fairchild',
      '00000000100' => 'Fujitsu',
      '00000000101' => 'GTE',
      '00000000110' => 'Harris',
      '00000000111' => 'Hitachi',
      '00000001000' => 'Inmos',
      '00000001001' => 'Intel',
      '00000001010' => 'I.T.T.',
      '00000001011' => 'Intersil',
      '00000001100' => 'Monolithic Memories',
      '00000001101' => 'Mostek',
      '00000001110' => 'Freescale (Motorola)',
      '00000001111' => 'National',
      '00000010000' => 'NEC',
      '00000010001' => 'RCA',
      '00000010010' => 'Raytheon',
      '00000010011' => 'Conexant (Rockwell)',
      '00000010100' => 'Seeq',
      '00000010101' => 'NXP (Philips)',
      '00000010110' => 'Synertek',
      '00000010111' => 'Texas Instruments',
      '00000011000' => 'Toshiba',
      '00000011001' => 'Xicor',
      '00000011010' => 'Zilog',
      '00000011011' => 'Eurotechnique',
      '00000011100' => 'Mitsubishi',
      '00000011101' => 'Lucent (AT&T)',
      '00000011110' => 'Exel',
      '00000011111' => 'Atmel',
      '00000100000' => 'SGS/Thomson',
      '00000100001' => 'Lattice Semi.',
      '00000100010' => 'NCR',
      '00000100011' => 'Wafer Scale Integration',
      '00000100100' => 'IBM',
      '00000100101' => 'Tristar',
      '00000100110' => 'Visic',
      '00000100111' => 'Intl. CMOS Technology',
      '00000101000' => 'SSSI',
      '00000101001' => 'MicrochipTechnology',
      '00000101010' => 'Ricoh Ltd.',
      '00000101011' => 'VLSI',
      '00000101100' => 'Micron Technology',
      '00000101101' => 'Hynix Semiconductor (Hyundai Electronics)',
      '00000101110' => 'OKI Semiconductor',
      '00000101111' => 'ACTEL',
      '00000110000' => 'Sharp',
      '00000110001' => 'Catalyst',
      '00000110010' => 'Panasonic',
      '00000110011' => 'IDT',
      '00000110100' => 'Cypress',
      '00000110101' => 'DEC',
      '00000110110' => 'LSI Logic',
      '00000110111' => 'Zarlink (Plessey)',
      '00000111000' => 'UTMC',
      '00000111001' => 'Thinking Machine',
      '00000111010' => 'Thomson CSF',
      '00000111011' => 'Integrated CMOS (Vertex)',
      '00000111100' => 'Honeywell',
      '00000111101' => 'Tektronix',
      '00000111110' => 'Oracle Corporation',
      '00000111111' => 'Silicon Storage Technology',
      '00001000000' => 'ProMos/Mosel Vitelic',
      '00001000001' => 'Infineon (Siemens)',
      '00001000010' => 'Macronix',
      '00001000011' => 'Xerox',
      '00001000100' => 'Plus Logic',
      '00001000101' => 'SanDisk Corporation',
      '00001000110' => 'Elan Circuit Tech.',
      '00001000111' => 'European Silicon Str.',
      '00001001000' => 'Apple Computer',
      '00001001001' => 'Xilinx',
      '00001001010' => 'Compaq',
      '00001001011' => 'Protocol Engines',
      '00001001100' => 'SCI',
      '00001001101' => 'Seiko Instruments',
      '00001001110' => 'Samsung',
      '00001001111' => 'I3 Design System',
      '00001010000' => 'Klic',
      '00001010001' => 'Crosspoint Solutions',
      '00001010010' => 'Alliance Semiconductor',
      '00001010011' => 'Tandem',
      '00001010100' => 'Hewlett-Packard',
      '00001010101' => 'Integrated Silicon Solutions',
      '00001010110' => 'Brooktree',
      '00001010111' => 'New Media',
      '00001011000' => 'MHS Electronic',
      '00001011001' => 'Performance Semi.',
      '00001011010' => 'Winbond Electronic',
      '00001011011' => 'Kawasaki Steel',
      '00001011100' => 'Bright Micro',
      '00001011101' => 'TECMAR',
      '00001011110' => 'Exar',
      '00001011111' => 'PCMCIA',
      '00001100000' => 'LG Semi (Goldstar)',
      '00001100001' => 'Northern Telecom',
      '00001100010' => 'Sanyo',
      '00001100011' => 'Array Microsystems',
      '00001100100' => 'Crystal Semiconductor',
      '00001100101' => 'Analog Devices',
      '00001100110' => 'PMC-Sierra',
      '00001100111' => 'Asparix',
      '00001101000' => 'Convex Computer',
      '00001101001' => 'Quality Semiconductor',
      '00001101010' => 'Nimbus Technology',
      '00001101011' => 'Transwitch',
      '00001101100' => 'Micronas (ITT Intermetall)',
      '00001101101' => 'Cannon',
      '00001101110' => 'Altera',
      '00001101111' => 'NEXCOM',
      '00001110000' => 'QUALCOMM',
      '00001110001' => 'Sony',
      '00001110010' => 'Cray Research',
      '00001110011' => 'AMS(Austria Micro)',
      '00001110100' => 'Vitesse',
      '00001110101' => 'Aster Electronics',
      '00001110110' => 'Bay Networks (Synoptic)',
      '00001110111' => 'Zentrum/ZMD',
      '00001111000' => 'TRW',
      '00001111001' => 'Thesys',
      '00001111010' => 'Solbourne Computer',
      '00001111011' => 'Allied-Signal',
      '00001111100' => 'Dialog Semiconductor',
      '00001111101' => 'Media Vision',
      '00001111110' => 'Numonyx Corporation',
      '00010000001' => 'Cirrus Logic',
      '00010000010' => 'National Instruments',
      '00010000011' => 'ILC Data Device',
      '00010000100' => 'Alcatel Mietec',
      '00010000101' => 'Micro Linear',
      '00010000110' => 'Univ. of NC',
      '00010000111' => 'JTAG Technologies',
      '00010001000' => 'BAE Systems (Loral)',
      '00010001001' => 'Nchip',
      '00010001010' => 'Galileo Tech',
      '00010001011' => 'Bestlink Systems',
      '00010001100' => 'Graychip',
      '00010001101' => 'GENNUM',
      '00010001110' => 'VideoLogic',
      '00010001111' => 'Robert Bosch',
      '00010010000' => 'Chip Express',
      '00010010001' => 'DATARAM',
      '00010010010' => 'United Microelectronics Corp.',
      '00010010011' => 'TCSI',
      '00010010100' => 'Smart Modular',
      '00010010101' => 'Hughes Aircraft',
      '00010010110' => 'Lanstar Semiconductor',
      '00010010111' => 'Qlogic',
      '00010011000' => 'Kingston',
      '00010011001' => 'Music Semi',
      '00010011010' => 'Ericsson Components',
      '00010011011' => 'SpaSE',
      '00010011100' => 'Eon Silicon Devices',
      '00010011101' => 'Programmable Micro Corp',
      '00010011110' => 'DoD',
      '00010011111' => 'Integ. Memories Tech.',
      '00010100000' => 'Corollary Inc.',
      '00010100001' => 'Dallas Semiconductor',
      '00010100010' => 'Omnivision',
      '00010100011' => 'EIV(Switzerland)',
      '00010100100' => 'Novatel Wireless',
      '00010100101' => 'Zarlink (Mitel)',
      '00010100110' => 'Clearpoint',
      '00010100111' => 'Cabletron',
      '00010101000' => 'STEC (Silicon Tech)',
      '00010101001' => 'Vanguard',
      '00010101010' => 'Hagiwara Sys-Com',
      '00010101011' => 'Vantis',
      '00010101100' => 'Celestica',
      '00010101101' => 'Century',
      '00010101110' => 'Hal Computers',
      '00010101111' => 'Rohm Company Ltd.',
      '00010110000' => 'Juniper Networks',
      '00010110001' => 'Libit Signal Processing',
      '00010110010' => 'Mushkin Enhanced Memory',
      '00010110011' => 'Tundra Semiconductor',
      '00010110100' => 'Adaptec Inc.',
      '00010110101' => 'LightSpeed Semi.',
      '00010110110' => 'ZSP Corp.',
      '00010110111' => 'AMIC Technology',
      '00010111000' => 'Adobe Systems',
      '00010111001' => 'Dynachip',
      '00010111010' => 'PNY Electronics',
      '00010111011' => 'Newport Digital',
      '00010111100' => 'MMC Networks',
      '00010111101' => 'T Square',
      '00010111110' => 'Seiko Epson',
      '00010111111' => 'Broadcom',
      '00011000000' => 'Viking Components',
      '00011000001' => 'V3 Semiconductor',
      '00011000010' => 'Flextronics (Orbit Semiconductor)',
      '00011000011' => 'Suwa Electronics',
      '00011000100' => 'Transmeta',
      '00011000101' => 'Micron CMS',
      '00011000110' => 'American Computer & Digital Components Inc',
      '00011000111' => 'Enhance 3000 Inc',
      '00011001000' => 'Tower Semiconductor',
      '00011001001' => 'CPU Design',
      '00011001010' => 'Price Point',
      '00011001011' => 'Maxim Integrated Product',
      '00011001100' => 'Tellabs',
      '00011001101' => 'Centaur Technology',
      '00011001110' => 'Unigen Corporation',
      '00011001111' => 'Transcend Information',
      '00011010000' => 'Memory Card Technology',
      '00011010001' => 'CKD Corporation Ltd.',
      '00011010010' => 'Capital Instruments, Inc.',
      '00011010011' => 'Aica Kogyo, Ltd.',
      '00011010100' => 'Linvex Technology',
      '00011010101' => 'MSC Vertriebs GmbH',
      '00011010110' => 'AKM Company, Ltd.',
      '00011010111' => 'Dynamem, Inc.',
      '00011011000' => 'NERA ASA',
      '00011011001' => 'GSI Technology',
      '00011011010' => 'Dane-Elec (C Memory)',
      '00011011011' => 'Acorn Computers',
      '00011011100' => 'Lara Technology',
      '00011011101' => 'Oak Technology, Inc.',
      '00011011110' => 'Itec Memory',
      '00011011111' => 'Tanisys Technology',
      '00011100000' => 'Truevision',
      '00011100001' => 'Wintec Industries',
      '00011100010' => 'Super PC Memory',
      '00011100011' => 'MGV Memory',
      '00011100100' => 'Galvantech',
      '00011100101' => 'Gadzoox Networks',
      '00011100110' => 'Multi Dimensional Cons.',
      '00011100111' => 'GateField',
      '00011101000' => 'Integrated Memory System',
      '00011101001' => 'Triscend',
      '00011101010' => 'XaQti',
      '00011101011' => 'Goldenram',
      '00011101100' => 'Clear Logic',
      '00011101101' => 'Cimaron Communications',
      '00011101110' => 'Nippon Steel Semi. Corp.',
      '00011101111' => 'Advantage Memory',
      '00011110000' => 'AMCC',
      '00011110001' => 'LeCroy',
      '00011110010' => 'Yamaha Corporation',
      '00011110011' => 'Digital Microwave',
      '00011110100' => 'NetLogic Microsystems',
      '00011110101' => 'MIMOS Semiconductor',
      '00011110110' => 'Advanced Fibre',
      '00011110111' => 'BF Goodrich Data.',
      '00011111000' => 'Epigram',
      '00011111001' => 'Acbel Polytech Inc.',
      '00011111010' => 'Apacer Technology',
      '00011111011' => 'Admor Memory',
      '00011111100' => 'FOXCONN',
      '00011111101' => 'Quadratics Superconductor',
      '00011111110' => '3COM',
      '00100000001' => 'Camintonn Corporation',
      '00100000010' => 'ISOA Incorporated',
      '00100000011' => 'Agate Semiconductor',
      '00100000100' => 'ADMtek Incorporated',
      '00100000101' => 'HYPERTEC',
      '00100000110' => 'Adhoc Technologies',
      '00100000111' => 'MOSAID Technologies',
      '00100001000' => 'Ardent Technologies',
      '00100001001' => 'Switchcore',
      '00100001010' => 'Cisco Systems, Inc.',
      '00100001011' => 'Allayer Technologies',
      '00100001100' => 'WorkX AG (Wichman)',
      '00100001101' => 'Oasis Semiconductor',
      '00100001110' => 'Novanet Semiconductor',
      '00100001111' => 'E-M Solutions',
      '00100010000' => 'Power General',
      '00100010001' => 'Advanced Hardware Arch.',
      '00100010010' => 'Inova Semiconductors GmbH',
      '00100010011' => 'Telocity',
      '00100010100' => 'Delkin Devices',
      '00100010101' => 'Symagery Microsystems',
      '00100010110' => 'C-Port Corporation',
      '00100010111' => 'SiberCore Technologies',
      '00100011000' => 'Southland Microsystems',
      '00100011001' => 'Malleable Technologies',
      '00100011010' => 'Kendin Communications',
      '00100011011' => 'Great Technology Microcomputer',
      '00100011100' => 'Sanmina Corporation',
      '00100011101' => 'HADCO Corporation',
      '00100011110' => 'Corsair',
      '00100011111' => 'Actrans System Inc.',
      '00100100000' => 'ALPHA Technologies',
      '00100100001' => 'Silicon Laboratories, Inc. (Cygnal)',
      '00100100010' => 'Artesyn Technologies',
      '00100100011' => 'Align Manufacturing',
      '00100100100' => 'Peregrine Semiconductor',
      '00100100101' => 'Chameleon Systems',
      '00100100110' => 'Aplus Flash Technology',
      '00100100111' => 'MIPS Technologies',
      '00100101000' => 'Chrysalis ITS',
      '00100101001' => 'ADTEC Corporation',
      '00100101010' => 'Kentron Technologies',
      '00100101011' => 'Win Technologies',
      '00100101100' => 'Tachyon Semiconductor (ASIC)',
      '00100101101' => 'Extreme Packet Devices',
      '00100101110' => 'RF Micro Devices',
      '00100101111' => 'Siemens AG',
      '00100110000' => 'Sarnoff Corporation',
      '00100110001' => 'Itautec SA',
      '00100110010' => 'Radiata Inc.',
      '00100110011' => 'Benchmark Elect. (AVEX)',
      '00100110100' => 'Legend',
      '00100110101' => 'SpecTek Incorporated',
      '00100110110' => 'Hi/fn',
      '00100110111' => 'Enikia Incorporated',
      '00100111000' => 'SwitchOn Networks',
      '00100111001' => 'AANetcom Incorporated',
      '00100111010' => 'Micro Memory Bank',
      '00100111011' => 'ESS Technology',
      '00100111100' => 'Virata Corporation',
      '00100111101' => 'Excess Bandwidth',
      '00100111110' => 'West Bay Semiconductor',
      '00100111111' => 'DSP Group',
      '00101000000' => 'Newport Communications',
      '00101000001' => 'Chip2Chip Incorporated',
      '00101000010' => 'Phobos Corporation',
      '00101000011' => 'Intellitech Corporation',
      '00101000100' => 'Nordic VLSI ASA',
      '00101000101' => 'Ishoni Networks',
      '00101000110' => 'Silicon Spice',
      '00101000111' => 'Alchemy Semiconductor',
      '00101001000' => 'Agilent Technologies',
      '00101001001' => 'Centillium Communications',
      '00101001010' => 'W.L. Gore',
      '00101001011' => 'HanBit Electronics',
      '00101001100' => 'GlobeSpan',
      '00101001101' => 'Element 14',
      '00101001110' => 'Pycon',
      '00101001111' => 'Saifun Semiconductors',
      '00101010000' => 'Sibyte, Incorporated',
      '00101010001' => 'MetaLink Technologies',
      '00101010010' => 'Feiya Technology',
      '00101010011' => 'I & C Technology',
      '00101010100' => 'Shikatronics',
      '00101010101' => 'Elektrobit',
      '00101010110' => 'Megic',
      '00101010111' => 'Com-Tier',
      '00101011000' => 'Malaysia Micro Solutions',
      '00101011001' => 'Hyperchip',
      '00101011010' => 'Gemstone Communications',
      '00101011011' => 'Anadigm (Anadyne)',
      '00101011100' => '3ParData',
      '00101011101' => 'Mellanox Technologies',
      '00101011110' => 'Tenx Technologies',
      '00101011111' => 'Helix AG',
      '00101100000' => 'Domosys',
      '00101100001' => 'Skyup Technology',
      '00101100010' => 'HiNT Corporation',
      '00101100011' => 'Chiaro',
      '00101100100' => 'MDT Technologies GmbH',
      '00101100101' => 'Exbit Technology A/S',
      '00101100110' => 'Integrated Technology Express',
      '00101100111' => 'AVED Memory',
      '00101101000' => 'Legerity',
      '00101101001' => 'Jasmine Networks',
      '00101101010' => 'Caspian Networks',
      '00101101011' => 'nCUBE',
      '00101101100' => 'Silicon Access Networks',
      '00101101101' => 'FDK Corporation',
      '00101101110' => 'High Bandwidth Access',
      '00101101111' => 'MultiLink Technology',
      '00101110000' => 'BRECIS',
      '00101110001' => 'World Wide Packets',
      '00101110010' => 'APW',
      '00101110011' => 'Chicory Systems',
      '00101110100' => 'Xstream Logic',
      '00101110101' => 'Fast-Chip',
      '00101110110' => 'Zucotto Wireless',
      '00101110111' => 'Realchip',
      '00101111000' => 'Galaxy Power',
      '00101111001' => 'eSilicon',
      '00101111010' => 'Morphics Technology',
      '00101111011' => 'Accelerant Networks',
      '00101111100' => 'Silicon Wave',
      '00101111101' => 'SandCraft',
      '00101111110' => 'Elpida',
      '00110000001' => 'Solectron',
      '00110000010' => 'Optosys Technologies',
      '00110000011' => 'Buffalo (Formerly Melco)',
      '00110000100' => 'TriMedia Technologies',
      '00110000101' => 'Cyan Technologies',
      '00110000110' => 'Global Locate',
      '00110000111' => 'Optillion',
      '00110001000' => 'Terago Communications',
      '00110001001' => 'Ikanos Communications',
      '00110001010' => 'Princeton Technology',
      '00110001011' => 'Nanya Technology',
      '00110001100' => 'Elite Flash Storage',
      '00110001101' => 'Mysticom',
      '00110001110' => 'LightSand Communications',
      '00110001111' => 'ATI Technologies',
      '00110010000' => 'Agere Systems',
      '00110010001' => 'NeoMagic',
      '00110010010' => 'AuroraNetics',
      '00110010011' => 'Golden Empire',
      '00110010100' => 'Mushkin',
      '00110010101' => 'Tioga Technologies',
      '00110010110' => 'Netlist',
      '00110010111' => 'TeraLogic',
      '00110011000' => 'Cicada Semiconductor',
      '00110011001' => 'Centon Electronics',
      '00110011010' => 'Tyco Electronics',
      '00110011011' => 'Magis Works',
      '00110011100' => 'Zettacom',
      '00110011101' => 'Cogency Semiconductor',
      '00110011110' => 'Chipcon AS',
      '00110011111' => 'Aspex Technology',
      '00110100000' => 'F5 Networks',
      '00110100001' => 'Programmable Silicon Solutions',
      '00110100010' => 'ChipWrights',
      '00110100011' => 'Acorn Networks',
      '00110100100' => 'Quicklogic',
      '00110100101' => 'Kingmax Semiconductor',
      '00110100110' => 'BOPS',
      '00110100111' => 'Flasys',
      '00110101000' => 'BitBlitz Communications',
      '00110101001' => 'eMemory Technology',
      '00110101010' => 'Procket Networks',
      '00110101011' => 'Purple Ray',
      '00110101100' => 'Trebia Networks',
      '00110101101' => 'Delta Electronics',
      '00110101110' => 'Onex Communications',
      '00110101111' => 'Ample Communications',
      '00110110000' => 'Memory Experts Intl',
      '00110110001' => 'Astute Networks',
      '00110110010' => 'Azanda Network Devices',
      '00110110011' => 'Dibcom',
      '00110110100' => 'Tekmos',
      '00110110101' => 'API NetWorks',
      '00110110110' => 'Bay Microsystems',
      '00110110111' => 'Firecron Ltd',
      '00110111000' => 'Resonext Communications',
      '00110111001' => 'Tachys Technologies',
      '00110111010' => 'Equator Technology',
      '00110111011' => 'Concept Computer',
      '00110111100' => 'SILCOM',
      '00110111101' => '3Dlabs',
      '00110111110' => 'câ€™t Magazine',
      '00110111111' => 'Sanera Systems',
      '00111000000' => 'Silicon Packets',
      '00111000001' => 'Viasystems Group',
      '00111000010' => 'Simtek',
      '00111000011' => 'Semicon Devices Singapore',
      '00111000100' => 'Satron Handelsges',
      '00111000101' => 'Improv Systems',
      '00111000110' => 'INDUSYS GmbH',
      '00111000111' => 'Corrent',
      '00111001000' => 'Infrant Technologies',
      '00111001001' => 'Ritek Corp',
      '00111001010' => 'empowerTel Networks',
      '00111001011' => 'Hypertec',
      '00111001100' => 'Cavium Networks',
      '00111001101' => 'PLX Technology',
      '00111001110' => 'Massana Design',
      '00111001111' => 'Intrinsity',
      '00111010000' => 'Valence Semiconductor',
      '00111010001' => 'Terawave Communications',
      '00111010010' => 'IceFyre Semiconductor',
      '00111010011' => 'Primarion',
      '00111010100' => 'Picochip Designs Ltd',
      '00111010101' => 'Silverback Systems',
      '00111010110' => 'Jade Star Technologies',
      '00111010111' => 'Pijnenburg Securealink',
      '00111011000' => 'takeMS International AG',
      '00111011001' => 'Cambridge Silicon Radio',
      '00111011010' => 'Swissbit',
      '00111011011' => 'Nazomi Communications',
      '00111011100' => 'eWave System',
      '00111011101' => 'Rockwell Collins',
      '00111011110' => 'Picocel Co. Ltd. (Paion)',
      '00111011111' => 'Alphamosaic Ltd',
      '00111100000' => 'Sandburst',
      '00111100001' => 'SiCon Video',
      '00111100010' => 'NanoAmp Solutions',
      '00111100011' => 'Ericsson Technology',
      '00111100100' => 'PrairieComm',
      '00111100101' => 'Mitac International',
      '00111100110' => 'Layer N Networks',
      '00111100111' => 'MtekVision (Atsana)',
      '00111101000' => 'Allegro Networks',
      '00111101001' => 'Marvell Semiconductors',
      '00111101010' => 'Netergy Microelectronic',
      '00111101011' => 'NVIDIA',
      '00111101100' => 'Internet Machines',
      '00111101101' => 'Peak Electronics',
      '00111101110' => 'Litchfield Communication',
      '00111101111' => 'Accton Technology',
      '00111110000' => 'Teradiant Networks',
      '00111110001' => 'Scaleo Chip',
      '00111110010' => 'Cortina Systems',
      '00111110011' => 'RAM Components',
      '00111110100' => 'Raqia Networks',
      '00111110101' => 'ClearSpeed',
      '00111110110' => 'Matsushita Battery',
      '00111110111' => 'Xelerated',
      '00111111000' => 'SimpleTech',
      '00111111001' => 'Utron Technology',
      '00111111010' => 'Astec International',
      '00111111011' => 'AVM gmbH',
      '00111111100' => 'Redux Communications',
      '00111111101' => 'Dot Hill Systems',
      '00111111110' => 'TeraChip',
      '01000000001' => 'T-RAM Incorporated',
      '01000000010' => 'Innovics Wireless',
      '01000000011' => 'Teknovus',
      '01000000100' => 'KeyEye Communications',
      '01000000101' => 'Runcom Technologies',
      '01000000110' => 'RedSwitch',
      '01000000111' => 'Dotcast',
      '01000001000' => 'Silicon Mountain Memory',
      '01000001001' => 'Signia Technologies',
      '01000001010' => 'Pixim',
      '01000001011' => 'Galazar Networks',
      '01000001100' => 'White Electronic Designs',
      '01000001101' => 'Patriot Scientific',
      '01000001110' => 'Neoaxiom Corporation',
      '01000001111' => '3Y Power Technology',
      '01000010000' => 'Scaleo Chip',
      '01000010001' => 'Potentia Power Systems',
      '01000010010' => 'C-guys Incorporated',
      '01000010011' => 'Digital Communications Technology Incorporated',
      '01000010100' => 'Silicon-Based Technology',
      '01000010101' => 'Fulcrum Microsystems',
      '01000010110' => 'Positivo Informatica Ltd',
      '01000010111' => 'XIOtech Corporation',
      '01000011000' => 'PortalPlayer',
      '01000011001' => 'Zhiying Software',
      '01000011010' => 'ParkerVision, Inc.',
      '01000011011' => 'Phonex Broadband',
      '01000011100' => 'Skyworks Solutions',
      '01000011101' => 'Entropic Communications',
      '01000011110' => 'Pacific Force Technology',
      '01000011111' => 'Zensys A/S',
      '01000100000' => 'Legend Silicon Corp.',
      '01000100001' => 'Sci-worx GmbH',
      '01000100010' => 'SMSC (Standard Microsystems)',
      '01000100011' => 'Renesas Electronics',
      '01000100100' => 'Raza Microelectronics',
      '01000100101' => 'Phyworks',
      '01000100110' => 'MediaTek',
      '01000100111' => 'Non-cents Productions',
      '01000101000' => 'US Modular',
      '01000101001' => 'Wintegra Ltd.',
      '01000101010' => 'Mathstar',
      '01000101011' => 'StarCore',
      '01000101100' => 'Oplus Technologies',
      '01000101101' => 'Mindspeed',
      '01000101110' => 'Just Young Computer',
      '01000101111' => 'Radia Communications',
      '01000110000' => 'OCZ',
      '01000110001' => 'Emuzed',
      '01000110010' => 'LOGIC Devices',
      '01000110011' => 'Inphi Corporation',
      '01000110100' => 'Quake Technologies',
      '01000110101' => 'Vixel',
      '01000110110' => 'SolusTek',
      '01000110111' => 'Kongsberg Maritime',
      '01000111000' => 'Faraday Technology',
      '01000111001' => 'Altium Ltd.',
      '01000111010' => 'Insyte',
      '01000111011' => 'ARM Ltd.',
      '01000111100' => 'DigiVision',
      '01000111101' => 'Vativ Technologies',
      '01000111110' => 'Endicott Interconnect Technologies',
      '01000111111' => 'Pericom',
      '01001000000' => 'Bandspeed',
      '01001000001' => 'LeWiz Communications',
      '01001000010' => 'CPU Technology',
      '01001000011' => 'Ramaxel Technology',
      '01001000100' => 'DSP Group',
      '01001000101' => 'Axis Communications',
      '01001000110' => 'Legacy Electronics',
      '01001000111' => 'Chrontel',
      '01001001000' => 'Powerchip Semiconductor',
      '01001001001' => 'MobilEye Technologies',
      '01001001010' => 'Excel Semiconductor',
      '01001001011' => 'A-DATA Technology',
      '01001001100' => 'VirtualDigm',
      '01001001101' => 'G Skill Intl',
      '01001001110' => 'Quanta Computer',
      '01001001111' => 'Yield Microelectronics',
      '01001010000' => 'Afa Technologies',
      '01001010001' => 'KINGBOX Technology Co. Ltd.',
      '01001010010' => 'Ceva',
      '01001010011' => 'iStor Networks',
      '01001010100' => 'Advance Modules',
      '01001010101' => 'Microsoft',
      '01001010110' => 'Open-Silicon',
      '01001010111' => 'Goal Semiconductor',
      '01001011000' => 'ARC International',
      '01001011001' => 'Simmtec',
      '01001011010' => 'Metanoia',
      '01001011011' => 'Key Stream',
      '01001011100' => 'Lowrance Electronics',
      '01001011101' => 'Adimos',
      '01001011110' => 'SiGe Semiconductor',
      '01001011111' => 'Fodus Communications',
      '01001100000' => 'Credence Systems Corp.',
      '01001100001' => 'Genesis Microchip Inc.',
      '01001100010' => 'Vihana, Inc.',
      '01001100011' => 'WIS Technologies',
      '01001100100' => 'GateChange Technologies',
      '01001100101' => 'High Density Devices AS',
      '01001100110' => 'Synopsys',
      '01001100111' => 'Gigaram',
      '01001101000' => 'Enigma Semiconductor Inc.',
      '01001101001' => 'Century Micro Inc.',
      '01001101010' => 'Icera Semiconductor',
      '01001101011' => 'Mediaworks Integrated Systems',
      '01001101100' => 'Oâ€™Neil Product Development',
      '01001101101' => 'Supreme Top Technology Ltd.',
      '01001101110' => 'MicroDisplay Corporation',
      '01001101111' => 'Team Group Inc.',
      '01001110000' => 'Sinett Corporation',
      '01001110001' => 'Toshiba Corporation',
      '01001110010' => 'Tensilica',
      '01001110011' => 'SiRF Technology',
      '01001110100' => 'Bacoc Inc.',
      '01001110101' => 'SMaL Camera Technologies',
      '01001110110' => 'Thomson SC',
      '01001110111' => 'Airgo Networks',
      '01001111000' => 'Wisair Ltd.',
      '01001111001' => 'SigmaTel',
      '01001111010' => 'Arkados',
      '01001111011' => 'Compete IT gmbH Co. KG',
      '01001111100' => 'Eudar Technology Inc.',
      '01001111101' => 'Focus Enhancements',
      '01001111110' => 'Xyratex',
      '01010000001' => 'Specular Networks',
      '01010000010' => 'Patriot Memory (PDP Systems)',
      '01010000011' => 'U-Chip Technology Corp.',
      '01010000100' => 'Silicon Optix',
      '01010000101' => 'Greenfield Networks',
      '01010000110' => 'CompuRAM GmbH',
      '01010000111' => 'Stargen, Inc.',
      '01010001000' => 'NetCell Corporation',
      '01010001001' => 'Excalibrus Technologies Ltd',
      '01010001010' => 'SCM Microsystems',
      '01010001011' => 'Xsigo Systems, Inc.',
      '01010001100' => 'CHIPS & Systems Inc',
      '01010001101' => 'Tier 1 Multichip Solutions',
      '01010001110' => 'CWRL Labs',
      '01010001111' => 'Teradici',
      '01010010000' => 'Gigaram, Inc.',
      '01010010001' => 'g2 Microsystems',
      '01010010010' => 'PowerFlash Semiconductor',
      '01010010011' => 'P.A. Semi, Inc.',
      '01010010100' => 'NovaTech Solutions, S.A.',
      '01010010101' => 'c2 Microsystems, Inc.',
      '01010010110' => 'Level5 Networks',
      '01010010111' => 'COS Memory AG',
      '01010011000' => 'Innovasic Semiconductor',
      '01010011001' => '02IC Co. Ltd',
      '01010011010' => 'Tabula, Inc.',
      '01010011011' => 'Crucial Technology',
      '01010011100' => 'Chelsio Communications',
      '01010011101' => 'Solarflare Communications',
      '01010011110' => 'Xambala Inc.',
      '01010011111' => 'EADS Astrium',
      '01010100000' => 'Terra Semiconductor, Inc.',
      '01010100001' => 'Imaging Works, Inc.',
      '01010100010' => 'Astute Networks, Inc.',
      '01010100011' => 'Tzero',
      '01010100100' => 'Emulex',
      '01010100101' => 'Power-One',
      '01010100110' => 'Pulse~LINK Inc.',
      '01010100111' => 'Hon Hai Precision Industry',
      '01010101000' => 'White Rock Networks Inc.',
      '01010101001' => 'Telegent Systems USA, Inc.',
      '01010101010' => 'Atrua Technologies, Inc.',
      '01010101011' => 'Acbel Polytech Inc.',
      '01010101100' => 'eRide Inc.',
      '01010101101' => 'ULi Electronics Inc.',
      '01010101110' => 'Magnum Semiconductor Inc.',
      '01010101111' => 'neoOne Technology, Inc.',
      '01010110000' => 'Connex Technology, Inc.',
      '01010110001' => 'Stream Processors, Inc.',
      '01010110010' => 'Focus Enhancements',
      '01010110011' => 'Telecis Wireless, Inc.',
      '01010110100' => 'uNav Microelectronics',
      '01010110101' => 'Tarari, Inc.',
      '01010110110' => 'Ambric, Inc.',
      '01010110111' => 'Newport Media, Inc.',
      '01010111000' => 'VMTS',
      '01010111001' => 'Enuclia Semiconductor, Inc.',
      '01010111010' => 'Virtium Technology Inc.',
      '01010111011' => 'Solid State System Co., Ltd.',
      '01010111100' => 'Kian Tech LLC',
      '01010111101' => 'Artimi',
      '01010111110' => 'Power Quotient International',
      '01010111111' => 'Avago Technologies',
      '01011000000' => 'ADTechnology',
      '01011000001' => 'Sigma Designs',
      '01011000010' => 'SiCortex, Inc.',
      '01011000011' => 'Ventura Technology Group',
      '01011000100' => 'eASIC',
      '01011000101' => 'M.H.S. SAS',
      '01011000110' => 'Micro Star International',
      '01011000111' => 'Rapport Inc.',
      '01011001000' => 'Makway International',
      '01011001001' => 'Broad Reach Engineering Co.',
      '01011001010' => 'Semiconductor Mfg Intl Corp',
      '01011001011' => 'SiConnect',
      '01011001100' => 'FCI USA Inc.',
      '01011001101' => 'Validity Sensors',
      '01011001110' => 'Coney Technology Co. Ltd.',
      '01011001111' => 'Spans Logic',
      '01011010000' => 'Neterion Inc.',
      '01011010001' => 'Qimonda',
      '01011010010' => 'New Japan Radio Co. Ltd.',
      '01011010011' => 'Velogix',
      '01011010100' => 'Montalvo Systems',
      '01011010101' => 'iVivity Inc.',
      '01011010110' => 'Walton Chaintech',
      '01011010111' => 'AENEON',
      '01011011000' => 'Lorom Industrial Co. Ltd.',
      '01011011001' => 'Radiospire Networks',
      '01011011010' => 'Sensio Technologies, Inc.',
      '01011011011' => 'Nethra Imaging',
      '01011011100' => 'Hexon Technology Pte Ltd',
      '01011011101' => 'CompuStocx (CSX)',
      '01011011110' => 'Methode Electronics, Inc.',
      '01011011111' => 'Connect One Ltd.',
      '01011100000' => 'Opulan Technologies',
      '01011100001' => 'Septentrio NV',
      '01011100010' => 'Goldenmars Technology Inc.',
      '01011100011' => 'Kreton Corporation',
      '01011100100' => 'Cochlear Ltd.',
      '01011100101' => 'Altair Semiconductor',
      '01011100110' => 'NetEffect, Inc.',
      '01011100111' => 'Spansion, Inc.',
      '01011101000' => 'Taiwan Semiconductor Mfg',
      '01011101001' => 'Emphany Systems Inc.',
      '01011101010' => 'ApaceWave Technologies',
      '01011101011' => 'Mobilygen Corporation',
      '01011101100' => 'Tego',
      '01011101101' => 'Cswitch Corporation',
      '01011101110' => 'Haier (Beijing) IC Design Co.',
      '01011101111' => 'MetaRAM',
      '01011110000' => 'Axel Electronics Co. Ltd.',
      '01011110001' => 'Tilera Corporation',
      '01011110010' => 'Aquantia',
      '01011110011' => 'Vivace Semiconductor',
      '01011110100' => 'Redpine Signals',
      '01011110101' => 'Octalica',
      '01011110110' => 'InterDigital Communications',
      '01011110111' => 'Avant Technology',
      '01011111000' => 'Asrock, Inc.',
      '01011111001' => 'Availink',
      '01011111010' => 'Quartics, Inc.',
      '01011111011' => 'Element CXI',
      '01011111100' => 'Innovaciones Microelectronicas',
      '01011111101' => 'VeriSilicon Microelectronics',
      '01011111110' => 'W5 Networks',
      '01100000001' => 'MOVEKING',
      '01100000010' => 'Mavrix Technology, Inc.',
      '01100000011' => 'CellGuide Ltd.',
      '01100000100' => 'Faraday Technology',
      '01100000101' => 'Diablo Technologies, Inc.',
      '01100000110' => 'Jennic',
      '01100000111' => 'Octasic',
      '01100001000' => 'Molex Incorporated',
      '01100001001' => '3Leaf Networks',
      '01100001010' => 'Bright Micron Technology',
      '01100001011' => 'Netxen',
      '01100001100' => 'NextWave Broadband Inc.',
      '01100001101' => 'DisplayLink',
      '01100001110' => 'ZMOS Technology',
      '01100001111' => 'Tec-Hill',
      '01100010000' => 'Multigig, Inc.',
      '01100010001' => 'Amimon',
      '01100010010' => 'Euphonic Technologies, Inc.',
      '01100010011' => 'BRN Phoenix',
      '01100010100' => 'InSilica',
      '01100010101' => 'Ember Corporation',
      '01100010110' => 'Avexir Technologies Corporation',
      '01100010111' => 'Echelon Corporation',
      '01100011000' => 'Edgewater Computer Systems',
      '01100011001' => 'XMOS Semiconductor Ltd.',
      '01100011010' => 'GENUSION, Inc.',
      '01100011011' => 'Memory Corp NV',
      '01100011100' => 'SiliconBlue Technologies',
      '01100011101' => 'Rambus Inc.',
      '01100011110' => 'Andes Technology Corporation',
      '01100011111' => 'Coronis Systems',
      '01100100000' => 'Achronix Semiconductor',
      '01100100001' => 'Siano Mobile Silicon Ltd.',
      '01100100010' => 'Semtech Corporation',
      '01100100011' => 'Pixelworks Inc.',
      '01100100100' => 'Gaisler Research AB',
      '01100100101' => 'Teranetics',
      '01100100110' => 'Toppan Printing Co. Ltd.',
      '01100100111' => 'Kingxcon',
      '01100101000' => 'Silicon Integrated Systems',
      '01100101001' => 'I-O Data Device, Inc.',
      '01100101010' => 'NDS Americas Inc.',
      '01100101011' => 'Solomon Systech Limited',
      '01100101100' => 'On Demand Microelectronics',
      '01100101101' => 'Amicus Wireless Inc.',
      '01100101110' => 'SMARDTV SNC',
      '01100101111' => 'Comsys Communication Ltd.',
      '01100110000' => 'Movidia Ltd.',
      '01100110001' => 'Javad GNSS, Inc.',
      '01100110010' => 'Montage Technology Group',
      '01100110011' => 'Trident Microsystems',
      '01100110100' => 'Super Talent',
      '01100110101' => 'Optichron, Inc.',
      '01100110110' => 'Future Waves UK Ltd.',
      '01100110111' => 'SiBEAM, Inc.',
      '01100111000' => 'Inicore,Inc.',
      '01100111001' => 'Virident Systems',
      '01100111010' => 'M2000, Inc.',
      '01100111011' => 'ZeroG Wireless, Inc.',
      '01100111100' => 'Gingle Technology Co. Ltd.',
      '01100111101' => 'Space Micro Inc.',
      '01100111110' => 'Wilocity',
      '01100111111' => 'Novafora, Ic.',
      '01101000000' => 'iKoa Corporation',
      '01101000001' => 'ASint Technology',
      '01101000010' => 'Ramtron',
      '01101000011' => 'Plato Networks Inc.',
      '01101000100' => 'IPtronics AS',
      '01101000101' => 'Infinite-Memories',
      '01101000110' => 'Parade Technologies Inc.',
      '01101000111' => 'Dune Networks',
      '01101001000' => 'GigaDevice Semiconductor',
      '01101001001' => 'Modu Ltd.',
      '01101001010' => 'CEITEC',
      '01101001011' => 'Northrop Grumman',
      '01101001100' => 'XRONET Corporation',
      '01101001101' => 'Sicon Semiconductor AB',
      '01101001110' => 'Atla Electronics Co. Ltd.',
      '01101001111' => 'TOPRAM Technology',
      '01101010000' => 'Silego Technology Inc.',
      '01101010001' => 'Kinglife',
      '01101010010' => 'Ability Industries Ltd.',
      '01101010011' => 'Silicon Power Computer & Communications',
      '01101010100' => 'Augusta Technology, Inc.',
      '01101010101' => 'Nantronics Semiconductors',
      '01101010110' => 'Hilscher Gesellschaft',
      '01101010111' => 'Quixant Ltd.',
      '01101011000' => 'Percello Ltd.',
      '01101011001' => 'NextIO Inc.',
      '01101011010' => 'Scanimetrics Inc.',
      '01101011011' => 'FS-Semi Company Ltd.',
      '01101011100' => 'Infinera Corporation',
      '01101011101' => 'SandForce Inc.',
      '01101011110' => 'Lexar Media',
      '01101011111' => 'Teradyne Inc.',
      '01101100000' => 'Memory Exchange Corp.',
      '01101100001' => 'Suzhou Smartek Electronics',
      '01101100010' => 'Avantium Corporation',
      '01101100011' => 'ATP Electronics Inc.',
      '01101100100' => 'Valens Semiconductor Ltd',
      '01101100101' => 'Agate Logic, Inc.',
      '01101100110' => 'Netronome',
      '01101100111' => 'Zenverge, Inc.',
      '01101101000' => 'N-trig Ltd',
      '01101101001' => 'SanMax Technologies Inc.',
      '01101101010' => 'Contour Semiconductor Inc.',
      '01101101011' => 'TwinMOS',
      '01101101100' => 'Silicon Systems, Inc.',
      '01101101101' => 'V-Color Technology Inc.',
      '01101101110' => 'Certicom Corporation',
      '01101101111' => 'JSC ICC Milandr',
      '01101110000' => 'PhotoFast Global Inc.',
      '01101110001' => 'InnoDisk Corporation',
      '01101110010' => 'Muscle Power',
      '01101110011' => 'Energy Micro',
      '01101110100' => 'Innofidei',
      '01101110101' => 'CopperGate Communications',
      '01101110110' => 'Holtek Semiconductor Inc.',
      '01101110111' => 'Myson Century, Inc.',
      '01101111000' => 'FIDELIX',
      '01101111001' => 'Red Digital Cinema',
      '01101111010' => 'Densbits Technology',
      '01101111011' => 'Zempro',
      '01101111100' => 'MoSys',
      '01101111101' => 'Provigent',
      '01101111110' => 'Triad Semiconductor, Inc.',
      '01110000001' => 'Siklu Communication Ltd.',
      '01110000010' => 'A Force Manufacturing Ltd.',
      '01110000011' => 'Strontium',
      '01110000100' => 'Abilis Systems',
      '01110000101' => 'Siglead, Inc.',
      '01110000110' => 'Ubicom, Inc.',
      '01110000111' => 'Unifosa Corporation',
      '01110001000' => 'Stretch, Inc.',
      '01110001001' => 'Lantiq Deutschland GmbH',
      '01110001010' => 'Visipro.',
      '01110001011' => 'EKMemory',
      '01110001100' => 'Microelectronics Institute ZTE',
      '01110001101' => 'Cognovo Ltd.',
      '01110001110' => 'Carry Technology Co. Ltd.',
      '01110001111' => 'Nokia',
      '01110010000' => 'King Tiger Technology',
      '01110010001' => 'Sierra Wireless',
      '01110010010' => 'HT Micron',
      '01110010011' => 'Albatron Technology Co. Ltd.',
      '01110010100' => 'Leica Geosystems AG',
      '01110010101' => 'BroadLight',
      '01110010110' => 'AEXEA',
      '01110010111' => 'ClariPhy Communications, Inc.',
      '01110011000' => 'Green Plug',
      '01110011001' => 'Design Art Networks',
      '01110011010' => 'Mach Xtreme Technology Ltd.',
      '01110011011' => 'ATO Solutions Co. Ltd.',
      '01110011100' => 'Ramsta',
      '01110011101' => 'Greenliant Systems, Ltd.',
      '01110011110' => 'Teikon',
      '01110011111' => 'Antec Hadron',
      '01110100000' => 'NavCom Technology, Inc.',
      '01110100001' => 'Shanghai Fudan Microelectronics',
      '01110100010' => 'Calxeda, Inc.',
      '01110100011' => 'JSC EDC Electronics',
      '01110100100' => 'Kandit Technology Co. Ltd.',
      '01110100101' => 'Ramos Technology',
      '01110100110' => 'Goldenmars Technology',
      '01110100111' => 'XeL Technology Inc.',
      '01110101000' => 'Newzone Corporation',
      '01110101001' => 'ShenZhen MercyPower Tech',
      '01110101010' => 'Nanjing Yihuo Technology.',
      '01110101011' => 'Nethra Imaging Inc.',
      '01110101100' => 'SiTel Semiconductor BV',
      '01110101101' => 'SolidGear Corporation',
      '01110101110' => 'Topower Computer Ind Co Ltd.',
      '01110101111' => 'Wilocity',
      '01110110000' => 'Profichip GmbH',
      '01110110001' => 'Gerad Technologies',
      '01110110010' => 'Ritek Corporation',
      '01110110011' => 'Gomos Technology Limited',
      '01110110100' => 'Memoright Corporation',
      '01110110101' => 'D-Broad, Inc.',
      '01110110110' => 'HiSilicon Technologies',
      '01110110111' => 'Syndiant Inc..',
      '01110111000' => 'Enverv Inc.',
      '01110111001' => 'Cognex',
      '01110111010' => 'Xinnova Technology Inc.',
      '01110111011' => 'Ultron AG',
      '01110111100' => 'Concord Idea Corporation',
      '01110111101' => 'AIM Corporation',
      '01110111110' => 'Lifetime Memory Products',
      '01110111111' => 'Ramsway',
      '01111000000' => 'Recore Systems B.V.',
      '01111000001' => 'Haotian Jinshibo Science Tech',
      '01111000010' => 'Being Advanced Memory',
      '01111000011' => 'Adesto Technologies',
      '01111000100' => 'Giantec Semiconductor, Inc.',
      '01111000101' => 'HMD Electronics AG',
      '01111000110' => 'Gloway International (HK)',
      '01111000111' => 'Kingcore',
      '01111001000' => 'Anucell Technology Holding',
      '01111001001' => 'Accord Software & Systems Pvt. Ltd.',
      '01111001010' => 'Active-Semi Inc.',
      '01111001011' => 'Denso Corporation'
  );

  my $name = $list{ $manufacturer };

  return $name if ( defined $name );

  return "<this script does not know>";
}


#------------------------------------------------------------------------

sub write_stdout ( $ )
{
  my $str = shift;

  ( print STDOUT $str ) or
     die "Error writing to standard output: $!\n";
}


#------------------------------------------------------------------------
#
# Returns a true value if the string starts with the given 'beginning' argument.
#

sub str_starts_with ( $ $ )
{
  my $str       = shift;
  my $beginning = shift;

  if ( length($str) < length($beginning) )
  {
    return 0;
  }

  return substr($str, 0, length($beginning)) eq $beginning;
}


#------------------------------------------------------------------------
#
# Removes leading and trailing blanks.
#
# Perl's definition of whitespace (blank characters) for the \s
# used in the regular expresion includes, among others, spaces, tabs,
# and new lines (\r and \n).
#

sub trim_blanks ( $ )
{
  my $retstr = shift;

  # POSSIBLE OPTIMISATION: Removing blanks could perhaps be done faster with transliterations (tr///).

  # Strip leading blanks.
  $retstr =~ s/^\s*//;

  # Strip trailing blanks.
  $retstr =~ s/\s*$//;

  return $retstr;
}


sub get_cmdline_help_from_pod ( $ )
{
  my $pathToThisScript = shift;

  my $memFileContents = "";

  open( my $memFile, '>', \$memFileContents )
      or die "Cannot open log memory file: $@";

  binmode( $memFile );  # Avoids CRLF conversion.


  pod2usage( -exitval    => "NOEXIT",
             -verbose    => 2,
             -noperldoc  => 1,  # Perl does not come with the perl-doc package as standard (at least on Debian 4.0).
             -input      => $pathToThisScript,
             -output     => $memFile );

  $memFile->close();

  return $memFileContents;
}


sub get_license_text ()
{
  return ( <<EOL

                    GNU AFFERO GENERAL PUBLIC LICENSE
                       Version 3, 19 November 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU Affero General Public License is a free, copyleft license for
software and other kinds of works, specifically designed to ensure
cooperation with the community in the case of network server software.

  The licenses for most software and other practical works are designed
to take away your freedom to share and change the works.  By contrast,
our General Public Licenses are intended to guarantee your freedom to
share and change all versions of a program--to make sure it remains free
software for all its users.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
them if you wish), that you receive source code or can get it if you
want it, that you can change the software or use pieces of it in new
free programs, and that you know you can do these things.

  Developers that use our General Public Licenses protect your rights
with two steps: (1) assert copyright on the software, and (2) offer
you this License which gives you legal permission to copy, distribute
and/or modify the software.

  A secondary benefit of defending all users' freedom is that
improvements made in alternate versions of the program, if they
receive widespread use, become available for other developers to
incorporate.  Many developers of free software are heartened and
encouraged by the resulting cooperation.  However, in the case of
software used on network servers, this result may fail to come about.
The GNU General Public License permits making a modified version and
letting the public access it on a server without ever releasing its
source code to the public.

  The GNU Affero General Public License is designed specifically to
ensure that, in such cases, the modified source code becomes available
to the community.  It requires the operator of a network server to
provide the source code of the modified version running there to the
users of that server.  Therefore, public use of a modified version, on
a publicly accessible server, gives the public access to the source
code of the modified version.

  An older license, called the Affero General Public License and
published by Affero, was designed to accomplish similar goals.  This is
a different license, not a version of the Affero GPL, but Affero has
released a new version of the Affero GPL which permits relicensing under
this license.

  The precise terms and conditions for copying, distribution and
modification follow.

                       TERMS AND CONDITIONS

  0. Definitions.

  "This License" refers to version 3 of the GNU Affero General Public License.

  "Copyright" also means copyright-like laws that apply to other kinds of
works, such as semiconductor masks.

  "The Program" refers to any copyrightable work licensed under this
License.  Each licensee is addressed as "you".  "Licensees" and
"recipients" may be individuals or organizations.

  To "modify" a work means to copy from or adapt all or part of the work
in a fashion requiring copyright permission, other than the making of an
exact copy.  The resulting work is called a "modified version" of the
earlier work or a work "based on" the earlier work.

  A "covered work" means either the unmodified Program or a work based
on the Program.

  To "propagate" a work means to do anything with it that, without
permission, would make you directly or secondarily liable for
infringement under applicable copyright law, except executing it on a
computer or modifying a private copy.  Propagation includes copying,
distribution (with or without modification), making available to the
public, and in some countries other activities as well.

  To "convey" a work means any kind of propagation that enables other
parties to make or receive copies.  Mere interaction with a user through
a computer network, with no transfer of a copy, is not conveying.

  An interactive user interface displays "Appropriate Legal Notices"
to the extent that it includes a convenient and prominently visible
feature that (1) displays an appropriate copyright notice, and (2)
tells the user that there is no warranty for the work (except to the
extent that warranties are provided), that licensees may convey the
work under this License, and how to view a copy of this License.  If
the interface presents a list of user commands or options, such as a
menu, a prominent item in the list meets this criterion.

  1. Source Code.

  The "source code" for a work means the preferred form of the work
for making modifications to it.  "Object code" means any non-source
form of a work.

  A "Standard Interface" means an interface that either is an official
standard defined by a recognized standards body, or, in the case of
interfaces specified for a particular programming language, one that
is widely used among developers working in that language.

  The "System Libraries" of an executable work include anything, other
than the work as a whole, that (a) is included in the normal form of
packaging a Major Component, but which is not part of that Major
Component, and (b) serves only to enable use of the work with that
Major Component, or to implement a Standard Interface for which an
implementation is available to the public in source code form.  A
"Major Component", in this context, means a major essential component
(kernel, window system, and so on) of the specific operating system
(if any) on which the executable work runs, or a compiler used to
produce the work, or an object code interpreter used to run it.

  The "Corresponding Source" for a work in object code form means all
the source code needed to generate, install, and (for an executable
work) run the object code and to modify the work, including scripts to
control those activities.  However, it does not include the work's
System Libraries, or general-purpose tools or generally available free
programs which are used unmodified in performing those activities but
which are not part of the work.  For example, Corresponding Source
includes interface definition files associated with source files for
the work, and the source code for shared libraries and dynamically
linked subprograms that the work is specifically designed to require,
such as by intimate data communication or control flow between those
subprograms and other parts of the work.

  The Corresponding Source need not include anything that users
can regenerate automatically from other parts of the Corresponding
Source.

  The Corresponding Source for a work in source code form is that
same work.

  2. Basic Permissions.

  All rights granted under this License are granted for the term of
copyright on the Program, and are irrevocable provided the stated
conditions are met.  This License explicitly affirms your unlimited
permission to run the unmodified Program.  The output from running a
covered work is covered by this License only if the output, given its
content, constitutes a covered work.  This License acknowledges your
rights of fair use or other equivalent, as provided by copyright law.

  You may make, run and propagate covered works that you do not
convey, without conditions so long as your license otherwise remains
in force.  You may convey covered works to others for the sole purpose
of having them make modifications exclusively for you, or provide you
with facilities for running those works, provided that you comply with
the terms of this License in conveying all material for which you do
not control copyright.  Those thus making or running the covered works
for you must do so exclusively on your behalf, under your direction
and control, on terms that prohibit them from making any copies of
your copyrighted material outside their relationship with you.

  Conveying under any other circumstances is permitted solely under
the conditions stated below.  Sublicensing is not allowed; section 10
makes it unnecessary.

  3. Protecting Users' Legal Rights From Anti-Circumvention Law.

  No covered work shall be deemed part of an effective technological
measure under any applicable law fulfilling obligations under article
11 of the WIPO copyright treaty adopted on 20 December 1996, or
similar laws prohibiting or restricting circumvention of such
measures.

  When you convey a covered work, you waive any legal power to forbid
circumvention of technological measures to the extent such circumvention
is effected by exercising rights under this License with respect to
the covered work, and you disclaim any intention to limit operation or
modification of the work as a means of enforcing, against the work's
users, your or third parties' legal rights to forbid circumvention of
technological measures.

  4. Conveying Verbatim Copies.

  You may convey verbatim copies of the Program's source code as you
receive it, in any medium, provided that you conspicuously and
appropriately publish on each copy an appropriate copyright notice;
keep intact all notices stating that this License and any
non-permissive terms added in accord with section 7 apply to the code;
keep intact all notices of the absence of any warranty; and give all
recipients a copy of this License along with the Program.

  You may charge any price or no price for each copy that you convey,
and you may offer support or warranty protection for a fee.

  5. Conveying Modified Source Versions.

  You may convey a work based on the Program, or the modifications to
produce it from the Program, in the form of source code under the
terms of section 4, provided that you also meet all of these conditions:

    a) The work must carry prominent notices stating that you modified
    it, and giving a relevant date.

    b) The work must carry prominent notices stating that it is
    released under this License and any conditions added under section
    7.  This requirement modifies the requirement in section 4 to
    "keep intact all notices".

    c) You must license the entire work, as a whole, under this
    License to anyone who comes into possession of a copy.  This
    License will therefore apply, along with any applicable section 7
    additional terms, to the whole of the work, and all its parts,
    regardless of how they are packaged.  This License gives no
    permission to license the work in any other way, but it does not
    invalidate such permission if you have separately received it.

    d) If the work has interactive user interfaces, each must display
    Appropriate Legal Notices; however, if the Program has interactive
    interfaces that do not display Appropriate Legal Notices, your
    work need not make them do so.

  A compilation of a covered work with other separate and independent
works, which are not by their nature extensions of the covered work,
and which are not combined with it such as to form a larger program,
in or on a volume of a storage or distribution medium, is called an
"aggregate" if the compilation and its resulting copyright are not
used to limit the access or legal rights of the compilation's users
beyond what the individual works permit.  Inclusion of a covered work
in an aggregate does not cause this License to apply to the other
parts of the aggregate.

  6. Conveying Non-Source Forms.

  You may convey a covered work in object code form under the terms
of sections 4 and 5, provided that you also convey the
machine-readable Corresponding Source under the terms of this License,
in one of these ways:

    a) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by the
    Corresponding Source fixed on a durable physical medium
    customarily used for software interchange.

    b) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by a
    written offer, valid for at least three years and valid for as
    long as you offer spare parts or customer support for that product
    model, to give anyone who possesses the object code either (1) a
    copy of the Corresponding Source for all the software in the
    product that is covered by this License, on a durable physical
    medium customarily used for software interchange, for a price no
    more than your reasonable cost of physically performing this
    conveying of source, or (2) access to copy the
    Corresponding Source from a network server at no charge.

    c) Convey individual copies of the object code with a copy of the
    written offer to provide the Corresponding Source.  This
    alternative is allowed only occasionally and noncommercially, and
    only if you received the object code with such an offer, in accord
    with subsection 6b.

    d) Convey the object code by offering access from a designated
    place (gratis or for a charge), and offer equivalent access to the
    Corresponding Source in the same way through the same place at no
    further charge.  You need not require recipients to copy the
    Corresponding Source along with the object code.  If the place to
    copy the object code is a network server, the Corresponding Source
    may be on a different server (operated by you or a third party)
    that supports equivalent copying facilities, provided you maintain
    clear directions next to the object code saying where to find the
    Corresponding Source.  Regardless of what server hosts the
    Corresponding Source, you remain obligated to ensure that it is
    available for as long as needed to satisfy these requirements.

    e) Convey the object code using peer-to-peer transmission, provided
    you inform other peers where the object code and Corresponding
    Source of the work are being offered to the general public at no
    charge under subsection 6d.

  A separable portion of the object code, whose source code is excluded
from the Corresponding Source as a System Library, need not be
included in conveying the object code work.

  A "User Product" is either (1) a "consumer product", which means any
tangible personal property which is normally used for personal, family,
or household purposes, or (2) anything designed or sold for incorporation
into a dwelling.  In determining whether a product is a consumer product,
doubtful cases shall be resolved in favor of coverage.  For a particular
product received by a particular user, "normally used" refers to a
typical or common use of that class of product, regardless of the status
of the particular user or of the way in which the particular user
actually uses, or expects or is expected to use, the product.  A product
is a consumer product regardless of whether the product has substantial
commercial, industrial or non-consumer uses, unless such uses represent
the only significant mode of use of the product.

  "Installation Information" for a User Product means any methods,
procedures, authorization keys, or other information required to install
and execute modified versions of a covered work in that User Product from
a modified version of its Corresponding Source.  The information must
suffice to ensure that the continued functioning of the modified object
code is in no case prevented or interfered with solely because
modification has been made.

  If you convey an object code work under this section in, or with, or
specifically for use in, a User Product, and the conveying occurs as
part of a transaction in which the right of possession and use of the
User Product is transferred to the recipient in perpetuity or for a
fixed term (regardless of how the transaction is characterized), the
Corresponding Source conveyed under this section must be accompanied
by the Installation Information.  But this requirement does not apply
if neither you nor any third party retains the ability to install
modified object code on the User Product (for example, the work has
been installed in ROM).

  The requirement to provide Installation Information does not include a
requirement to continue to provide support service, warranty, or updates
for a work that has been modified or installed by the recipient, or for
the User Product in which it has been modified or installed.  Access to a
network may be denied when the modification itself materially and
adversely affects the operation of the network or violates the rules and
protocols for communication across the network.

  Corresponding Source conveyed, and Installation Information provided,
in accord with this section must be in a format that is publicly
documented (and with an implementation available to the public in
source code form), and must require no special password or key for
unpacking, reading or copying.

  7. Additional Terms.

  "Additional permissions" are terms that supplement the terms of this
License by making exceptions from one or more of its conditions.
Additional permissions that are applicable to the entire Program shall
be treated as though they were included in this License, to the extent
that they are valid under applicable law.  If additional permissions
apply only to part of the Program, that part may be used separately
under those permissions, but the entire Program remains governed by
this License without regard to the additional permissions.

  When you convey a copy of a covered work, you may at your option
remove any additional permissions from that copy, or from any part of
it.  (Additional permissions may be written to require their own
removal in certain cases when you modify the work.)  You may place
additional permissions on material, added by you to a covered work,
for which you have or can give appropriate copyright permission.

  Notwithstanding any other provision of this License, for material you
add to a covered work, you may (if authorized by the copyright holders of
that material) supplement the terms of this License with terms:

    a) Disclaiming warranty or limiting liability differently from the
    terms of sections 15 and 16 of this License; or

    b) Requiring preservation of specified reasonable legal notices or
    author attributions in that material or in the Appropriate Legal
    Notices displayed by works containing it; or

    c) Prohibiting misrepresentation of the origin of that material, or
    requiring that modified versions of such material be marked in
    reasonable ways as different from the original version; or

    d) Limiting the use for publicity purposes of names of licensors or
    authors of the material; or

    e) Declining to grant rights under trademark law for use of some
    trade names, trademarks, or service marks; or

    f) Requiring indemnification of licensors and authors of that
    material by anyone who conveys the material (or modified versions of
    it) with contractual assumptions of liability to the recipient, for
    any liability that these contractual assumptions directly impose on
    those licensors and authors.

  All other non-permissive additional terms are considered "further
restrictions" within the meaning of section 10.  If the Program as you
received it, or any part of it, contains a notice stating that it is
governed by this License along with a term that is a further
restriction, you may remove that term.  If a license document contains
a further restriction but permits relicensing or conveying under this
License, you may add to a covered work material governed by the terms
of that license document, provided that the further restriction does
not survive such relicensing or conveying.

  If you add terms to a covered work in accord with this section, you
must place, in the relevant source files, a statement of the
additional terms that apply to those files, or a notice indicating
where to find the applicable terms.

  Additional terms, permissive or non-permissive, may be stated in the
form of a separately written license, or stated as exceptions;
the above requirements apply either way.

  8. Termination.

  You may not propagate or modify a covered work except as expressly
provided under this License.  Any attempt otherwise to propagate or
modify it is void, and will automatically terminate your rights under
this License (including any patent licenses granted under the third
paragraph of section 11).

  However, if you cease all violation of this License, then your
license from a particular copyright holder is reinstated (a)
provisionally, unless and until the copyright holder explicitly and
finally terminates your license, and (b) permanently, if the copyright
holder fails to notify you of the violation by some reasonable means
prior to 60 days after the cessation.

  Moreover, your license from a particular copyright holder is
reinstated permanently if the copyright holder notifies you of the
violation by some reasonable means, this is the first time you have
received notice of violation of this License (for any work) from that
copyright holder, and you cure the violation prior to 30 days after
your receipt of the notice.

  Termination of your rights under this section does not terminate the
licenses of parties who have received copies or rights from you under
this License.  If your rights have been terminated and not permanently
reinstated, you do not qualify to receive new licenses for the same
material under section 10.

  9. Acceptance Not Required for Having Copies.

  You are not required to accept this License in order to receive or
run a copy of the Program.  Ancillary propagation of a covered work
occurring solely as a consequence of using peer-to-peer transmission
to receive a copy likewise does not require acceptance.  However,
nothing other than this License grants you permission to propagate or
modify any covered work.  These actions infringe copyright if you do
not accept this License.  Therefore, by modifying or propagating a
covered work, you indicate your acceptance of this License to do so.

  10. Automatic Licensing of Downstream Recipients.

  Each time you convey a covered work, the recipient automatically
receives a license from the original licensors, to run, modify and
propagate that work, subject to this License.  You are not responsible
for enforcing compliance by third parties with this License.

  An "entity transaction" is a transaction transferring control of an
organization, or substantially all assets of one, or subdividing an
organization, or merging organizations.  If propagation of a covered
work results from an entity transaction, each party to that
transaction who receives a copy of the work also receives whatever
licenses to the work the party's predecessor in interest had or could
give under the previous paragraph, plus a right to possession of the
Corresponding Source of the work from the predecessor in interest, if
the predecessor has it or can get it with reasonable efforts.

  You may not impose any further restrictions on the exercise of the
rights granted or affirmed under this License.  For example, you may
not impose a license fee, royalty, or other charge for exercise of
rights granted under this License, and you may not initiate litigation
(including a cross-claim or counterclaim in a lawsuit) alleging that
any patent claim is infringed by making, using, selling, offering for
sale, or importing the Program or any portion of it.

  11. Patents.

  A "contributor" is a copyright holder who authorizes use under this
License of the Program or a work on which the Program is based.  The
work thus licensed is called the contributor's "contributor version".

  A contributor's "essential patent claims" are all patent claims
owned or controlled by the contributor, whether already acquired or
hereafter acquired, that would be infringed by some manner, permitted
by this License, of making, using, or selling its contributor version,
but do not include claims that would be infringed only as a
consequence of further modification of the contributor version.  For
purposes of this definition, "control" includes the right to grant
patent sublicenses in a manner consistent with the requirements of
this License.

  Each contributor grants you a non-exclusive, worldwide, royalty-free
patent license under the contributor's essential patent claims, to
make, use, sell, offer for sale, import and otherwise run, modify and
propagate the contents of its contributor version.

  In the following three paragraphs, a "patent license" is any express
agreement or commitment, however denominated, not to enforce a patent
(such as an express permission to practice a patent or covenant not to
sue for patent infringement).  To "grant" such a patent license to a
party means to make such an agreement or commitment not to enforce a
patent against the party.

  If you convey a covered work, knowingly relying on a patent license,
and the Corresponding Source of the work is not available for anyone
to copy, free of charge and under the terms of this License, through a
publicly available network server or other readily accessible means,
then you must either (1) cause the Corresponding Source to be so
available, or (2) arrange to deprive yourself of the benefit of the
patent license for this particular work, or (3) arrange, in a manner
consistent with the requirements of this License, to extend the patent
license to downstream recipients.  "Knowingly relying" means you have
actual knowledge that, but for the patent license, your conveying the
covered work in a country, or your recipient's use of the covered work
in a country, would infringe one or more identifiable patents in that
country that you have reason to believe are valid.

  If, pursuant to or in connection with a single transaction or
arrangement, you convey, or propagate by procuring conveyance of, a
covered work, and grant a patent license to some of the parties
receiving the covered work authorizing them to use, propagate, modify
or convey a specific copy of the covered work, then the patent license
you grant is automatically extended to all recipients of the covered
work and works based on it.

  A patent license is "discriminatory" if it does not include within
the scope of its coverage, prohibits the exercise of, or is
conditioned on the non-exercise of one or more of the rights that are
specifically granted under this License.  You may not convey a covered
work if you are a party to an arrangement with a third party that is
in the business of distributing software, under which you make payment
to the third party based on the extent of your activity of conveying
the work, and under which the third party grants, to any of the
parties who would receive the covered work from you, a discriminatory
patent license (a) in connection with copies of the covered work
conveyed by you (or copies made from those copies), or (b) primarily
for and in connection with specific products or compilations that
contain the covered work, unless you entered into that arrangement,
or that patent license was granted, prior to 28 March 2007.

  Nothing in this License shall be construed as excluding or limiting
any implied license or other defenses to infringement that may
otherwise be available to you under applicable patent law.

  12. No Surrender of Others' Freedom.

  If conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot convey a
covered work so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you may
not convey it at all.  For example, if you agree to terms that obligate you
to collect a royalty for further conveying from those to whom you convey
the Program, the only way you could satisfy both those terms and this
License would be to refrain entirely from conveying the Program.

  13. Remote Network Interaction; Use with the GNU General Public License.

  Notwithstanding any other provision of this License, if you modify the
Program, your modified version must prominently offer all users
interacting with it remotely through a computer network (if your version
supports such interaction) an opportunity to receive the Corresponding
Source of your version by providing access to the Corresponding Source
from a network server at no charge, through some standard or customary
means of facilitating copying of software.  This Corresponding Source
shall include the Corresponding Source for any work covered by version 3
of the GNU General Public License that is incorporated pursuant to the
following paragraph.

  Notwithstanding any other provision of this License, you have
permission to link or combine any covered work with a work licensed
under version 3 of the GNU General Public License into a single
combined work, and to convey the resulting work.  The terms of this
License will continue to apply to the part which is the covered work,
but the work with which it is combined will remain governed by version
3 of the GNU General Public License.

  14. Revised Versions of this License.

  The Free Software Foundation may publish revised and/or new versions of
the GNU Affero General Public License from time to time.  Such new versions
will be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

  Each version is given a distinguishing version number.  If the
Program specifies that a certain numbered version of the GNU Affero General
Public License "or any later version" applies to it, you have the
option of following the terms and conditions either of that numbered
version or of any later version published by the Free Software
Foundation.  If the Program does not specify a version number of the
GNU Affero General Public License, you may choose any version ever published
by the Free Software Foundation.

  If the Program specifies that a proxy can decide which future
versions of the GNU Affero General Public License can be used, that proxy's
public statement of acceptance of a version permanently authorizes you
to choose that version for the Program.

  Later license versions may give you additional or different
permissions.  However, no additional obligations are imposed on any
author or copyright holder as a result of your choosing to follow a
later version.

  15. Disclaimer of Warranty.

  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. Limitation of Liability.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

  17. Interpretation of Sections 15 and 16.

  If the disclaimer of warranty and limitation of liability provided
above cannot be given local legal effect according to their terms,
reviewing courts shall apply local law that most closely approximates
an absolute waiver of all civil liability in connection with the
Program, unless a warranty or assumption of liability accompanies a
copy of the Program in return for a fee.

                     END OF TERMS AND CONDITIONS

            How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
state the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

Also add information on how to contact you by electronic and paper mail.

  If your software can interact with users remotely through a computer
network, you should also make sure that it provides a way for users to
get its source.  For example, if your program is a web application, its
interface could display a "Source" link that leads users to an archive
of the code.  There are many ways you could offer source, and different
solutions will be better for different programs; see section 13 for the
specific requirements.

  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU AGPL, see
<http://www.gnu.org/licenses/>.

EOL
  );
}


# ------------ Script entry point ------------

eval
{
  my $exitCode = main();
  exit $exitCode;
};

my $errorMessage = $@;

# We want the error message to be the last thing on the screen,
# so we need to flush the standard output first.
STDOUT->flush();

print STDERR "\nError running @{[SCRIPT_NAME]}: $errorMessage";

exit EXIT_CODE_FAILURE_ERROR;
