#!/usr/bin/python

import sys
from rpmUtils.miscutils import splitFilename

for filename in sys.argv[1:]:
   (n, v, r, e, a) = splitFilename(filename)
   print "https://kojipkgs.fedoraproject.org/packages/%s/%s/%s/%s/%s-%s-%s.%s.rpm" % (n,v,r,a,n,v,r,a)
