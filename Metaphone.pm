package Text::Metaphone;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use subs qw(soundex);

use integer;  # Kneed 4 Speed.  Module doesn't require floats.

require Exporter;

BEGIN; {
  @ISA = qw(Exporter);
  # Items to export into callers namespace by default. Note: do not export
  @EXPORT    = qw(
		  Metaphone
		 );
  @EXPORT_OK = qw(
		  soundex
		 );
  $VERSION = '0.02';
}


#--- FORWARD SUBROUTINE DECLARATION ---#
sub MaxPhonemeLen;   	# Access routine to set/read the length of our metaphone
			# encoding.
sub Metaphone;		# Encode the given word with Metaphone.
sub _Metamorphosize;  	# Where the work is done.  Encodes a string into a set
                        # of metaphone characters.


#--- CONSTANT LEXICALS (That's "statics" for you C++er's) ---#
# These should be probably be replaced with either constants or cpp macros.
my $VOWEL_SET 		= '[AEIOU]';	# Vowels (duh.)
my $SAME_SET 		= '[FJLMNR]';	# Letters which are the same when encoded.
my $AFFECTS_H_SET	= '[CGPST]';	# These form dipthongs when preceding H.
my $MAKESOFT_SET	= '[EIY]';	# These make C and G soft.
my $NOGHTOF_SET		= '[BDH]';	# They prevent GH from becoming F.


#--- GLOBAL LEXICALS ---#
my $MaxPhonemeLen;


#--- INITIALIZATION ---#
MaxPhonemeLen(6);
*soundex = \&Metaphone;  	# I -think- this will work.


# PUBLIC
# Accept and prep the word for metamorphosizing & pass it along to _Metamorphosize.
sub Metaphone {
  my($word) = @_;
  
  # Convert to uppercase & eliminate all non-alphabetical characters.
  $word = uc $word;
  $word =~ tr/A-Z//cd;
  
  return _Metamorphosize($word,MaxPhonemeLen());
}


# PUBLIC
# Set and/or return the maximum length our metaphone strings should be.
sub MaxPhonemeLen {
  my($maxPhonemeLen) = @_;
  if( defined $maxPhonemeLen ) {
    if( $maxPhonemeLen > 0 ) { $MaxPhonemeLen = $maxPhonemeLen; }
    else { $MaxPhonemeLen = undef; }
  }
  
  return $MaxPhonemeLen;
}


####---                THE MEAT & POTATOES OF THE MODULE              ---###
# 2DO:  - Encode based on phoneme's rather than by word.  ie.  DJE is encoded by D,
#	  then the word position is skipped forward twice.  J has no mention of the DJE
#	  phoneme, because D handles it already.
#	- use an incremented $metaLen instead of length $metaWord (trival?)
#	- check to see if Metaphone algorithm used here is even correct!
#	- make sure Metaphone(Merlin) == Metaphone(Merlyn) :)
#	- Check if $char =~ /^$SET$/o is faster than the equivelant $char eq 'A' ||
#	  $char eq 'B'... or if the coding array method used in Metaphone.cc is faster.
# 	  eq 2.49, regex 4.65, ^$SET$ 5.77  array 9.73, #DEFINE regex 1.90
#       - study $prevChar, $currChar & $nextChar
# From Metaphone.cc which is from the slapd package from umich, which is from C
#   Gazette, June/July 1991, pp 56-57 by Gary A. Parker with changes by Bernard
#   Tiffany & more changes by Tim Howes.
sub _Metamorphosize {
  # $word:  A string of uppercase letters to be encoded via Metaphone.
  # $maxPhonemeLen:  How long an encoding to perform.
  my($word, $maxPhonemeLen) = @_;
	
  
  my($metaWord) 	= '';	# Our metaphone encoded $word.
  # my($metaLen)  	= 0;	# How long is $metaWord?  *Unused so far.*
  my($wordPos)  	= 0;	# Our position on $word.
  my($wordLen)	 = length $word;
  my($prevChar) 	= '';
  my($currChar)  = substr($word,$wordPos,1);   # The current character we are encoding.
  my($nextChar)  = substr($word,$wordPos+1,1); # And the next one.
	
  # A little special preparation/adjustment for the first characters.
  # Check for CH[nonVowel], PN, KN, GN, AE, WR, WH, X or vowels at the start of the word.
  # For all but X, we remove the first letter from the word.  For X, we change it to S.
  PREFIX_ENCODING :{
    # 'CH[non-vowel]' is encoded as 'K' as in CHTULU
    $currChar eq 'C'   && do {
      if( $nextChar eq 'H' &&
	  substr($word,$wordPos+2,1) !~ /^$VOWEL_SET$/ ) {
	$metaWord .= 'K';
	$wordPos++;
      }
      last PREFIX_ENCODING;
    };

    # 'PN', 'KN', 'GN' becomes 'N'
    #  $currChar =~ /^[PKG]$/  Faster, maybe?
    ($currChar eq 'P' ||
     $currChar eq 'K' ||
     $currChar eq 'G') && do {  
       if( $nextChar eq 'N' ) {
	 substr($word,0,1) = 0;
	 $wordPos++;
       }  
       last PREFIX_ENCODING;  
     };

    # 'AE' becomes 'E'
    # Yes, this one's different from the rest.  Necessary to allow other combinations of
    # A to fall through to the $VOWEL_SET case.  (ie. "ANYTHING")  In the long run, this
    # is simpler, I think.
    # Also, unlike most of the rest, the meta encoding actually occurs here.
    ($currChar eq 'A'   &&  
     $nextChar eq 'E') && do {
      substr($word,0,1) = 0;
      $metaWord .= 'E';
      $wordPos += 2;
      last PREFIX_ENCODING;
    };

    # 'WR' becomes 'R' and 'WH' becomes 'H'
    $currChar eq 'W'   && do {
      if( $nextChar eq 'H' ||
	  $nextChar eq 'R' ) {
	substr($word,0,1) = 0;
	$wordPos++;
      }
      last PREFIX_ENCODING;
    };

    # 'X' becomes 'S'
    $currChar eq 'X'   && do {
      substr($word,0,1) = 'S';
      last PREFIX_ENCODING;
    };

    # Keep the vowel, if its the first letter in the word.
    $currChar =~ /^$VOWEL_SET$/o && do {
      $metaWord .= $currChar;
      $wordPos++;
      last PREFIX_ENCODING;
    };

    # DEFAULT:  Do nothing.
  }


  # Reinitialize our previous, current and next character pointers ( in case they got
  # mucked up by the prefix encoding.
  if ( $wordPos > 0 ) { $prevChar = substr($word,$wordPos-1,1); }
  if ( $wordPos < $wordLen ) { $currChar = substr($word,$wordPos,1); }
  else { $currChar = undef; }
  if ( $wordPos + 1 < $wordLen ) { $nextChar = substr($word,$wordPos+1,1); }
  else { $nextChar = '';  }

  # Encode the word.  Stop when the encoding is $maxPhonemeLen long, or when the
  # entire word is encoded.
  for( ;
       (!defined $maxPhonemeLen || length $metaWord < $maxPhonemeLen) &&
          $wordPos < $wordLen;
       $wordPos++
     ) {   # remember, $wordPos is one-off from $wordLen.

		
    # Drop duplicates, except for CC.
    if( $prevChar eq $currChar && $currChar ne 'C' ) { 
      # ignore it. 
    }
		
    # F J L M N R stay the same.
    elsif( $currChar =~ /^$SAME_SET$/o ) { $metaWord .= $currChar; }

    # Ignore vowels.
    elsif( $currChar =~ /^$VOWEL_SET$/o ) {
      # ignore it.
    }

    # Meta-encode!
    # TO DO.  Make it skip entire phoneme's.  ie.  if the pheneme is 'CH' there's
    # 	  no reason to check the next 'H', C's case should cause it to be
    #	  skipped.
    else {
       META_ENCODE: {
	   # 'B':	ignore if -MB, as in BOMB
	   $currChar eq 'B'     && do {
	     unless( $prevChar eq 'M' && !defined $nextChar ) {
	       $metaWord .= 'B';
	     }
	     last META_ENCODE;
	   };
	   
	   # 'C':  	'X'(sh) if -CIA- or -CH- except -SCH- (SCHWERN doesn't encode right :()
	   #		'S' if -CI-, -CE-, or -CY-
	   #		ignored if -SCI-, -SCE- or -SCY-
	   #		else 'K'.
	   $currChar eq 'C' 	&& do {
	     if( $prevChar eq 'S' && $nextChar =~ /^$MAKESOFT_SET$/o ) {
	       # ignore it.
	     }	
	     elsif( $nextChar eq 'H' && $prevChar ne 'S' ) {
	       $metaWord .= 'X'
	     }	     
	     elsif( substr($word, $wordPos+1,2) eq 'IA' ) {
	       $metaWord .= 'X';
	     }
	     elsif( $nextChar =~ /^$MAKESOFT_SET$/o ) {
	       $metaWord .= 'S';
	     }
	     else { $metaWord .= 'K'; }
	     last META_ENCODE;
	   };

	   # 'D':	'J' if -DGE-, -DGI-, or -DGY-
	   #		else 'T'
	   $currChar eq 'D'	&& do {
	     if( $nextChar eq 'G' &&
		 substr($word, $wordPos+2,1) =~ /^$MAKESOFT_SET$/o )
	       {
		 $metaWord .= 'J';
	       }
	     else { $metaWord .= 'T'; }
	     last META_ENCODE;
	   };

	   # 'G':	'F' if -GH but not B--GH, D--GH, -H--GH, or -H---GH
	   #		else ignored if -GNED, -GN, -DGE-, -DGI-, or -DGY-
	   #		'J' if -GE-, -GI-, or -GY- and not GG
	   #		else 'K'
	   $currChar eq 'G'	&&	do {
	     if( ($nextChar eq 'H' && ($wordPos+1 == $wordLen-1)) &&
		 (substr($word,$wordPos-2,1) !~ /^$NOGHTOF_SET$/o &&
		  substr($word,$wordPos-3,1) ne 'H') )
	       {
		 $metaWord .= 'F';
	       }
	     elsif( $nextChar eq 'N' ) {
	       if( ($wordPos+1 == $wordLen-1) ||
		   (substr($word,$wordPos+1,3) eq 'ED') ) {
		 # do nothing, ignore it.
	       }
	       else { $metaWord .= 'K' }
	     }
	     elsif( $nextChar =~ /^$MAKESOFT_SET$/o && $prevChar ne 'G' ) {
	       if( $prevChar eq 'D' ) { 
		 # ignore 
	       }
	       else {
		 $metaWord .= 'J';
	       }
	     }
	     else { $metaWord .= 'K'; }
	     last META_ENCODE;
	   };
	   
	   # 'H':	'H' if before a vowel, but not after C,G,P,S,T.
	   #		else ignored.
	   $currChar eq 'H'	&& do {
	     if( $nextChar =~ /^$VOWEL_SET$/o &&
		 $prevChar !~ /^[CGPST]$/ ) 
	     {
	       $metaWord .= 'H';
	     }
	     last META_ENCODE;
	   };
	   
	   # 'K':	'K' except after C.
	   $currChar eq 'K'	&& do {
	     unless($prevChar eq 'C') {
	       $metaWord .= 'K';
	     }
	     last META_ENCODE;
	   };

	   # 'P':	'F' if -PH-
	   #		else 'P'.
	   $currChar eq 'P'	&& do {
	     if($nextChar eq 'H') {
	       $metaWord .= 'F';
	     }
	     else { $metaWord .= 'P'; }
	     last META_ENCODE;
	   };

	   # 'Q': 	'K'.
	   $currChar eq 'Q' 	&& do {
	     $metaWord .= 'K';
	     last META_ENCODE;
	   };
	   
	   # 'S':	'X' (sh) in -SH-, -SIO-, or -SIA-
	   #		else 'S'
	   $currChar eq 'S'	&& do {
	     if( $nextChar eq 'H' ||
		 ($nextChar eq 'I' &&
		  substr($word,$wordPos+2,1) =~ /^[OA]$/) ) {
	       $metaWord .= 'X';
	     }
	     else { $metaWord .= 'S'; }
	     last META_ENCODE;
	   };
	   
	   # 'T': 	'X' (sh) in -TIA- or -TIO-
	   #		else 0 (th) before H
	   #		else ignored if in -TCH-
	   #		else 'T'
	   $currChar eq 'T'	&& do {
	     if( $nextChar eq 'I' &&
		 substr($word,$wordPos+2,1) =~ /^[OA]$/ ) {
	       $metaWord .= 'X';
	     }
	     elsif( $nextChar eq 'H' ) { $metaWord .= '0'; }
	     elsif( substr($word,$wordPos+1,2) eq 'CH' ) {
	       # ignore it.
	     }
	     else {
	       $metaWord .= 'T';
	     }
	     last META_ENCODE;
	   };

	   # 'V':	'F'.
	   $currChar eq 'V'	&& do {
	     $metaWord .= 'F';
	     last META_ENCODE;
	   };

	   # 'W': 	'W' after a vowel.
	   #		else ignored.
	   $currChar eq 'W'	&& do {
	     if( $prevChar =~ /^$VOWEL_SET$/o ) {
	       $metaWord .= 'W';
	     }
	     last META_ENCODE;
	   };

	   # 'X':	'KS'
	   $currChar eq 'X' 	&& do {
	     $metaWord .= 'KS';
	     last META_ENCODE;
	   };

	   # 'Y':  	'Y' unless before a vowel.
	   $currChar eq 'Y'	&& do {
	     unless( $nextChar =~ /^$VOWEL_SET$/o ) {
	       $metaWord .= 'Y';
	     }
	     last META_ENCODE;
	   };

	   # 'Z':  	'S'
	   $currChar eq 'Z' 	&& do {
	     $metaWord .= 'S';
	     last META_ENCODE;
	   };
	   
	   # DEFAULT:  ignore it.
	 } # end META_ENCODE

       } # end else


    $prevChar = $currChar;
    $currChar = $nextChar;
    # This if/else block shuts up a "substr outside of string" warning.
    unless ( ($wordPos+2) >= $wordLen ) {
      $nextChar = substr($word,$wordPos+2,1);  # Remember, $wordPos hasn't been incremented yet.
    }
    else {
      $nextChar = '';
    }
  } # end for


  return defined $maxPhonemeLen && 
         length $metaWord > $maxPhonemeLen   ? substr($metaWord,0,$maxPhonemeLen)
                                             : $metaWord;
}


1;
__END__


=head1 NAME

Text::Metaphone - A modern soundex.  Phonetic (english) encoding of words.

=head1 SYNOPSIS

  use Text::Metaphone;
  $metaWord = Metaphone($word);   # phonetically encode $word.

  # look at the max length of an encoding.
  $metaMax = Text::Metaphone::MaxPhonemeLen;
  # set the max encoding length.
  Text::Metaphone::MaxPhonemeLen(10);           


  use Text::Metaphone qw(soundex);
  $metaWord = soundex($word);  # Same as Metaphone.

=head1 DESCRIPTION

C<Metaphone()> is a function whereby a string/word is broken down into a rough approximation of its english phonetic pronunciation.  Very similar in concept and purpose to soundex (see L<Text::Soundex>), but more comprehensive in its approach.

If you are using L<Text::Soundex> in an existing program and wish to switch over to Metaphone, simply invoke this module as C<use Text::Metaphone qw(soundex);> rather than using L<Text::Soundex> and C<soundex()> will become exactly the same as C<Metamorphosize()>.  You might want to set Metaphone's maximum encoding length to 4, if your code expects a fixed size encoding (C<Text::Metaphone::MaxPhonemeLen(4);>).

If this doesn't excite you, then its YA module to give worms to ex-girlfriends. :)

=head1 FUNCTIONS

=over 4

=item Metaphone(STRING)

Takes any string and encodes it according to the Metaphone algorithm.  Non-letters are ignored by the algorithm.

'sh' is encoded as 'X'.  'th' is encoded as '0'  (I'll allow this to be set by the user, eventually.)

=item soundex(STRING)

Simply an alias to C<Metaphone()>.  Activate it by importing this function.  (C<use Text::Metaphone qw(soundex);>)

=item Text::Metaphone::MaxPhonemeLen([LENGTH])  

Set or get the metaphone encoding limit.  If called without any args, the current setting is returned.  If given a positive integer, it uses that as the maximum length of a metaphone encoding which C<Metaphone()> will produce.  Anything else, and no limit is placed on C<Metaphone()>  Normally, Metaphone limits its encoding to 6 characters by default.  (I'm thinking of changing the default to unlimited.)

=head1 KNOWN BUGS

I guess this would be a pre-alpha, so I'm quite sure its infested.  For gods sake, don't use it in production code.

The metaphone encoding is sure to change many times in the coming days/weeks/months before it stablizes, so don't be surprised if the encoding you get in this version is different from future versions.

Some words just don't encode right.  "sugar" for instance, encodes to "SKR" (should be "XKR").  "Schwartz" encodes to "SKRTS" (should be "XRTS").  My name encodes improperly ("SKRN" instead of "XRN")  This is a fault of the algorithm itself and can be improved to a point, but due to the massive inconsistancies in english, there's no way it will be perfect.

=head1 TO DO

=over 4

=item Allow the special sound encodings ('sh' and 'th') to be user defined.

=item Improve the efficiency of the code.  I'm shooting to outpace Text::Soundex.

=item Add in functionality for automatically storing the metaencodings of common words.

=item Port _Metamorphosize over to C/XS.

=item I probably should think of a better than than "MaxPhonemeLen" :)

=head1 AUTHOR

Michael G Schwern, schwern@rt1.net, CPAN ID - MSCHWERN

Drop me a line you use this module (or want to use it, but won't because its untested... ESPECIALLY let me know if that's the case), find bugs, want a new dipthong added, etc...

=head1 SEE ALSO

=head2 Manual Pages

L<Text::Soundex>

=head2 Books, Journals and Magazines

 Binstock, Andrew & Rex, John. "Metaphone:  A Modern Soundex." I<Practical Algorithms For Programmers.>  Reading, Mass:  Addion-Wesley, 1995  pp160-169 
 Contains an explaination of the basic metaphone concept & algorithm and C code from which I learned of Metaphone and ported this module.

 Parker, Gary. "A Better Phonetic Search." I<C Gazette>, Vol. 5, No. 4 (June/July), 1990.  
 This is the public-domain C version of metaphone from which Binstock & Rex based their own..  I haven't actually read it.

 Philips, Lawrence. I<Computer Language>, Vol. 7, No. 12 (December), 1990.  
 And here's the original Metaphone algorithm as presented in Pick BASIC.

=head1 COPYRIGHT AND LEGAL BULLSHIT

 Copyright (c) 1995 Michael G Schwern.  All rights reserved.
 This program is free software; you can redistribute it and/or 
 modify it under the same terms as Perl itself.

=cut
