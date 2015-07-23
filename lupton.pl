#!/usr/bin/env perl
#

=pod

 lupton.pl

 True colour images with non-linear scaling after Lupton et al. (2004), PASP 116, 133.

 use: ./lupton.pl red.fits green.fits blue.fits truecolour.fits


 This programme reads three FITS files corresponding to three
 different bands. A threshold is applied to each image for background
 suppression. Then the three a combined, and saved in a FITS file and in
 a PNG file. The FITS file can be opened with DS9 as:
   ds9 -rgbcube truecolour.fits


 The background thresholds and the scaling parameters are currently
 hard-wired. They should be tuned to the image.

 The scaling paramters are in the %scale hash:
    %scale = ( r => 2.2,
               g => 1.6,
	       b => 1.6  );

 The bkg tresholds are in the following sub calls:
    $rosso=comprimibkg($rosso,2,4);  # rosso=red, comprimi=compress
    $verde=comprimibkg($verde,2,4);  # verde=green
    $blu=  comprimibkg($blu,2,4);    # blu=blue
 All pixels with values lower than the first number (2 in the example
 above) are set to zero in the output image (they are meant to be
 background). All pixels with values larger than the second number (4
 in the example) are left untouched. The remaining pixels (between 2
 and 4 in the example above) are damped since they are in the "grey
 zone" between background and low-brightess features.

 This method of background suppression is effective for
 XMM-Newton. Chandra images might not need any kind of suppression, in
 that case just comment out any call to comprimibkg().



 (C) Piero Ranalli, 2005-2015

 This file is released under the GNU Affero GPL license, version 3, as
 published by the Free Software Foundation.
 http://www.gnu.org/licenses/agpl-3.0.html


=cut

# PR, 18-19.7.2005

use PDL;
use PDL::NiceSlice;
#use PDL::IO::Pic;
use Astro::FITS::Header;  # Otherwise makes a mess in the output image header


# COLOUR SCALING PARAMETERS
%scale = ( r => 2.2, 
	   g => 1.6, 
	   b => 1.6) ;

# other examples:
#
# %scale = ( 'r',1/.68,
# 	   'g',1/.37,
# 	   'b',1 );
#  %scale = ( 'r',1.,
#  	   'g',1.5,
#  	   'b',2.0 );
# %scale = ( 'r',1.,
# 	   'g',1.5,
# 	   'b',1.5 );

$nonlinearita = 2;  # amount of non-linearity

# program begins here
if ($#ARGV!=3) {  usage();
		  exit;
}


$filerosso=shift() . "[0]";
$fileverde=shift() . "[0]";
$fileblu=shift() . "[0]";
$fileoutput=shift;

$rosso=leggifits($filerosso);

@dimensioni = dims($rosso);
$dimx = shift @dimensioni; 
$dimy = shift @dimensioni; 

$hdr = rfitshdr($filerosso);

$verde= $fileverde eq 'void[0]' ? zeroes $dimx,$dimy : leggifits($fileverde);
$blu=leggifits($fileblu);


$rosso->inplace->badmask(0);
$verde->inplace->badmask(0);
$blu->inplace->badmask(0);


# BACKGROUND SUPPRESSION
$rosso=comprimibkg($rosso,2,4);
$verde=comprimibkg($verde,2,4);
$blu=  comprimibkg($blu,2,4);



 # OTHER EXAMPLES OF BKG SUPPRESSION

###$rosso=comprimibkg($rosso,3,5);
###$verde=comprimibkg($verde,10,15);
###$blu=  comprimibkg($blu,15,50);

# $rosso=comprimibkg($rosso,2,10);
# $verde=comprimibkg($verde,2,5);
# $blu=  comprimibkg($blu,7,15);

 # $rosso=comprimibkg($rosso,10**1,10**1.5);
 # $verde=comprimibkg($verde,10**.9,10**1.4);
 # $blu=  comprimibkg($blu,10**.9,10**1.8);





$rosso *= $scale{r};
$verde *= $scale{g};
$blu *=   $scale{b};

$i = $rosso+$verde+$blu;

$zeri = $i == 0; #prevent division by zero
$i += $zeri;
undef $zeri;  #should help with large images

$i = sqrt(asinh($i*$nonlinearita))/$nonlinearita/$i;
 
$rosso *= $i;
$verde *= $i;
$blu   *= $i;

undef $i;  #should help with large images

# forse qui si protrebbe fare di meglio, usando il threading.. ma gia'
# cosi' i tempi di calcolo sono soddisfacenti: 8 secondi scarsi per
# fare 501x501 pixel, IDL su lamu' non faceva molto meglio.
# $fattore = pdl $rosso;
# for ($nx=0;$nx<$dimx;$nx++) {
#     for ($ny=0;$ny<$dimy;$ny++) {
# 	$tmp = maxval ( $rosso->at($nx,$ny),
# 			$verde->at($nx,$ny),
# 			$blu->at($nx,$ny),
# 			1);
# 	set $fattore,$nx,$ny, $tmp;
#     }
# }

# 6.12.2005, ecco qua: sto lavorando con immagini 2048x2048, cambiando
# i ciclo esplicito di sopra con la routine che segue, i tempi di calcolo
# passano (su crocchetta) da oltre due minuti a quindi secondi scarsi!! :)
#
# quanto a occupazione di memoria, siamo quasi al limite di crocchetta
# (512 mb/processore), e qui di seguito si potrebbe fare di meglio, visto
# che $uno e' superfluo che venga lasciato uguale da pdlmaxval
$uno = float(ones $rosso);
$fattore = pdlmaxval ($rosso,$verde,$blu,$uno);
undef $uno;

# fit_to_box (limits the pixel values of the image to a 'box'
# so that the colours do not saturate to white but to a specific colour
$rosso /= $fattore;
$verde /= $fattore;
$blu /= $fattore;
undef $fattore;  #should help with large images


# join dimension together: rgb cube for ds9
$arcobaleno=zeroes($dimx,$dimy,3);
$dimx1=$dimx-1;
$dimy1=$dimy-1;
$arcobaleno(:,:,0) .= $rosso;
$arcobaleno(:,:,1) .= $verde;
$arcobaleno(:,:,2) .= $blu;


# fits output
$fitsoutput = $fileoutput;
if ($fitsoutput =~ m/\.\w+$/) {
    $fitsoutput =~ s/\.\w+$/.fits/;
} else {
    $fitsoutput .= '.fits';
}

$arcobaleno->sethdr( $hdr ); #fits header
wfits $arcobaleno,$fitsoutput;

# true colour file output: first rearrange dimensions, from three planes
# of r/g/b images, to 2D matrix where each element is a vector:
# $arcobaleno = $arcobaleno->reorder(2,0,1);

# then output
# wpic $arcobaleno,$fileoutput;







##############################################################################
sub usage {   # usage
##############################################################################

    my ( $exit ) = @_;

    local $^W = 0;
    use Pod::Text;
 #   $Pod::Text::termcap=1;
    Pod::Text::pod2text ( '-75', $0);
    #exit $exit;
}



sub pdlmaxval {  # find maximum value in a list of piddles, recursively
    # NB $a originale, passato per referenza
    #    $b e' una (e una sola!) copia
    #    cosi' l'occupazione di memoria e' minima
    my $a = shift;
    unless ($#_+1) { return $a->copy };  # $#_ is -1 when array is empty
    my $b = pdlmaxval (@_);  # recursive call

    my $mask = $a < $b;
    $b *= float($mask);
    $b += $a *float(1-$mask);
    return $b;
}



sub comprimibkg {

    my ($img,$q,$w) = @_;
    my $denom = -$w**3 +3*$q*$w*$w -3*$q*$q*$w +$q**3;
    my $a = ($q+$w) / $denom;
    my $b = -2*($w*$w +$q*$w +$q*$q) / $denom;
    my $c = (4*$q*$w*$w + $q*$q*$w + $q*$q*$q) / $denom;
    my $d = -2*$q*$q *$w*$w / $denom;

    my $msk = ($img>$q) * ($img<$w);
    my $m = $msk*$img;
    #$n = $a*$m*$m*$m + $b*$m*$m + $c*$m + $d;
    $n = $d + $m*($c + $m*($b + $m*$a));
    $n *= $msk;
    $n += ($img>=$w)*$img;

    return $n;

}

sub leggifits {
    my $a=shift;
    my $b=rfits($a);
    # return float to limit memory occupation
    return float($b->inplace);
}

