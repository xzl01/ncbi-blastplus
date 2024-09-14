# $Id: Makefile.phiblast_unit_test.app 673720 2023-10-06 19:32:59Z ivanov $

APP = phiblast_unit_test
SRC = phiblast_unit_test 

CPPFLAGS = -DNCBI_MODULE=BLAST $(ORIG_CPPFLAGS) $(BOOST_INCLUDE) -I$(srcdir)/../../api
LIB = test_boost $(BLAST_LIBS) xobjsimple $(OBJMGR_LIBS:ncbi_x%=ncbi_x%$(DLL))
LIBS = $(BLAST_THIRD_PARTY_LIBS) $(NETWORK_LIBS) $(CMPRS_LIBS) $(DL_LIBS) \
       $(ORIG_LIBS)
LDFLAGS = $(FAST_LDFLAGS)

CHECK_REQUIRES = MT in-house-resources
CHECK_CMD = phiblast_unit_test
CHECK_COPY = phiblast_unit_test.ini

WATCHERS = boratyng madden camacho fongah2