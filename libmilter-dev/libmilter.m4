dnl
dnl Enable libmilter with a pool of workers
APPENDDEF(`conf_libmilter_ENVDEF',`-D_FFR_WORKERS_POOL=1 -DMIN_WORKERS=4')
dnl
dnl Use poll instead of select
APPENDDEF(`conf_libmilter_ENVDEF',`-DSM_CONF_POLL=1')
dnl Enable IPv6
APPENDDEF(`conf_libmilter_ENVDEF',`-DNETINET6=1')
dnl Enable NEEDSGETIPNODE
APPENDDEF(`conf_libmilter_ENVDEF',`-DNEEDSGETIPNODE=1')
dnl
dnl Include our CFLAGS
APPENDDEF(`conf_libmilter_ENVDEF',`-Os -fomit-frame-pointer')
dnl
dnl Add -fPIC
APPENDDEF(`conf_libmilter_ENVDEF',`-fPIC')
dnl
