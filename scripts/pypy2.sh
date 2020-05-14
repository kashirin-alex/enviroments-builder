#!/usr/bin/env bash
tn='pypy2.7-v7.3.0-src'; url='http://bitbucket.org/pypy/pypy/downloads/pypy2.7-v7.3.0-src.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi

for n in ncurses panel term; do sed -i 's/'$n'/'$n'w/g' lib_pypy/_curses_build.py; sed -i 's/#include <'$n'w.h>/#include <'$n'.h>/g' lib_pypy/_curses_build.py; done;
sed -i 's/ncurses/ncursesw/g' pypy/module/_minimal_curses/fficurses.py;

cd pypy/goal;
export VERBOSE=1;
export LDFLAGS="-DTCMALLOC_MINIMAL -ltcmalloc_minimal -fno-builtin-malloc -fno-builtin-calloc -fno-builtin-realloc -fno-builtin-free"
export CFLAGS="$ADD_O_FS $LDFLAGS"
export CPPFLAGS="$ADD_O_FS $LDFLAGS"
export INCLUDEDIRS="-I$CUST_INST_PREFIX/include"
(
PYPY_LOCALBASE=$SOURCES_PATH/$sn \
python ../../rpython/bin/rpython \
			--no-shared --thread --make-jobs=$NUM_PROCS \
			--verbose --no-profopt --gc=incminimark --gcremovetypeptr --continuation \
			--inline-threshold=33.4 --translation-backendopt-inline --listcompr \
			--translation-backendopt-mallocs --translation-backendopt-constfold --translation-backendopt-stack_optimization \
			--translation-backendopt-storesink --translation-backendopt-remove_asserts --translation-backendopt-really_remove_asserts \
			--if-block-merge --translation-withsmallfuncsets=10 --translation-jit_opencoder_model=big --translation-jit_profiler=off \
			--translation-rweakref \
			--translation-backendopt-print_statistics \
			--opt=jit targetpypystandalone.py --allworkingmodules --withmod-_file \
			--objspace-std-intshortcut --objspace-std-newshortcut --objspace-std-optimized_list_getitem \
			--objspace-std-methodcachesizeexp=15 --objspace-std-withliststrategies\
			--objspace-std-withspecialisedtuple --objspace-std-withtproxy) &
# --objspace-std-withprebuiltint
while [ ! -f pypy-c ]; do sleep 60; done;
# --clever-malloc-removal --clever-malloc-removal-threshold=33.4 --translation-split_gc_address_space    #http://doc.pypy.org/en/latest/config/commandline.html#general-translation-options

if [ -f 'pypy-c' ]; then	
	
	./pypy-c ../tool/build_cffi_imports.py --without-tk;
	./pypy-c ../tool/release/package.py --without-tk --archive-name $sn --targetdir $DOWNLOAD_PATH/$sn.tar.bz2;

	cd $SOURCES_PATH/$sn;rm -rf built_pkg; mkdir built_pkg; cd built_pkg; tar -xf $DOWNLOAD_PATH/$sn.tar.bz2;
	rm -rf /opt/pypy2;mv pypy2 /opt/;
	rm -f /usr/bin/pypy; ln -s /opt/pypy2/bin/pypy /usr/bin/pypy
	pypy -m ensurepip; rm -f /usr/bin/pypy_pip; ln -s /opt/pypy2/bin/pip /usr/bin/pypy_pip
	
	source /etc/profile;source ~/.bashrc;ldconfig;

	rm -rf ~/.cache/pip 
	$PIP_INSTALL pypy setuptools
	$PIP_INSTALL pypy pip
	$PIP_INSTALL pypy setuptools

	$PIP_INSTALL pypy cffi 
	$PIP_INSTALL pypy greenlet
	 
	$PIP_INSTALL pypy psutil==5.6.3
	
	$PIP_INSTALL pypy deepdiff # psutil
	$PIP_INSTALL pypy xlrd lxml	
	with_gmp=no $PIP_INSTALL pypy pycrypto 
	$PIP_INSTALL pypy cryptography
	$PIP_INSTALL pypy pyopenssl #LDFLAGS="-L$CUST_INST_PREFIX/ssl/lib" CFLAGS="-I$CUST_INST_PREFIX/ssl/include" 

	$PIP_INSTALL pypy pycryptodomex
	$PIP_INSTALL pypy asn1crypto
	
	$PIP_INSTALL pypy w3lib
	$PIP_INSTALL pypy h2 #https://github.com/python-hyper/hyper-h2/archive/master.zip
	$PIP_INSTALL pypy urllib3 dnspython
	$PIP_INSTALL pypy linuxfd http://github.com/kashirin-alex/eventlet/archive/master.zip 

	$PIP_INSTALL pypy msgpack-python
	$PIP_INSTALL pypy webp 
	$PIP_INSTALL pypy Pillow Wand
	$PIP_INSTALL pypy weasyprint==0.42.3
	$PIP_INSTALL pypy brotli pylzma rarfile zopfli zstd #zipfile pysnappy
	$PIP_INSTALL pypy ply slimit
	$PIP_INSTALL pypy guess_language
	$PIP_INSTALL pypy paypalrestsdk #pygeocoder python-google-places
	$PIP_INSTALL pypy josepy acme
	$PIP_INSTALL pypy fontTools

	$PIP_INSTALL pypy thrift
	$PIP_INSTALL pypy http://github.com/kashirin-alex/libpyhdfs/archive/master.zip
	$PIP_INSTALL pypy http://github.com/kashirin-alex/PyHelpers/archive/master.zip
	
	STDCXX=17 $PIP_INSTALL pypy --verbose cppyy
	$PIP_INSTALL pypy objgraph
	
fi


export LDFLAGS=""
export CFLAGS=""
export CPPFLAGS=""
export INCLUDEDIRS=""
