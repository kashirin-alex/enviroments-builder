#!/usr/bin/env bash
tn='pypy3.6-v7.3.0-src'; url='http://bitbucket.org/pypy/pypy/downloads/pypy3.6-v7.3.0-src.tar.bz2';
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
			--opt=jit targetpypystandalone.py --allworkingmodules \
			--objspace-std-intshortcut --objspace-std-newshortcut --objspace-std-optimized_list_getitem \
			--objspace-std-methodcachesizeexp=15 --objspace-std-withliststrategies\
			--objspace-std-withspecialisedtuple --objspace-std-withtproxy) &
# --objspace-std-withprebuiltint  --lto
while [ ! -f pypy3-c ]; do sleep 60; done;


if [ -f 'pypy3-c' ]; then
	./pypy3-c ../tool/build_cffi_imports.py ;
	python ../tool/release/package.py --without-tk --archive-name $sn --targetdir $DOWNLOAD_PATH/$sn.tar.bz2;

	cd $SOURCES_PATH/$sn;rm -rf built_pkg; mkdir built_pkg; cd built_pkg; tar -xf $DOWNLOAD_PATH/$sn.tar.bz2;
	rm -rf /opt/pypy3;mv pypy3 /opt/;
	rm -f /usr/bin/pypy3; ln -s /opt/pypy3/bin/pypy3 /usr/bin/pypy3
	pypy3 -m ensurepip; rm -f /usr/bin/pypy3_pip; ln -s /opt/pypy3/bin/pip3 /usr/bin/pypy3_pip
	
	source /etc/profile;source ~/.bashrc;ldconfig;

	rm -rf ~/.cache/pip 
	$PIP_INSTALL pypy3 setuptools
	$PIP_INSTALL pypy3 pip
	$PIP_INSTALL pypy3 setuptools

	$PIP_INSTALL pypy3 cffi 
	$PIP_INSTALL pypy3 greenlet
	$PIP_INSTALL pypy3 psutil deepdiff
	$PIP_INSTALL pypy3 xlrd lxml	
	with_gmp=no $PIP_INSTALL pypy3  pycrypto 
	$PIP_INSTALL pypy3 cryptography
	$PIP_INSTALL pypy3 pyopenssl #LDFLAGS="-L$CUST_INST_PREFIX/ssl/lib" CFLAGS="-I$CUST_INST_PREFIX/ssl/include" 
	
	$PIP_INSTALL pypy3 pycryptodomex

	$PIP_INSTALL pypy3 h2 #https://github.com/python-hyper/hyper-h2/archive/master.zip
	$PIP_INSTALL pypy3 urllib3 dnspython
	$PIP_INSTALL pypy3 linuxfd http://github.com/kashirin-alex/eventlet/archive/master.zip 

	$PIP_INSTALL pypy3 msgpack-python
	$PIP_INSTALL pypy3 webp 
	$PIP_INSTALL pypy3 Pillow Wand
	$PIP_INSTALL pypy3 weasyprint                 
	$PIP_INSTALL pypy3 brotli pylzma rarfile zopfli  #zipfile pysnappy
	$PIP_INSTALL pypy3 ply slimit
	$PIP_INSTALL pypy3 guess_language
	$PIP_INSTALL pypy3 paypalrestsdk #pygeocoder python-google-places
	$PIP_INSTALL pypy3 josepy acme
	$PIP_INSTALL pypy3 fontTools

	$PIP_INSTALL pypy3 http://github.com/kashirin-alex/libpyhdfs/archive/master.zip
	$PIP_INSTALL pypy3 http://github.com/kashirin-alex/PyHelpers/archive/master.zip

fi


export LDFLAGS=""
export CFLAGS=""
export CPPFLAGS=""
export INCLUDEDIRS=""