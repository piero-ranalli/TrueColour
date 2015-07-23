# lupton.pl

True colour images with non-linear scaling after Lupton et al. (2004), PASP

use:

    ./lupton.pl red.fits green.fits blue.fits truecolour.fits



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


