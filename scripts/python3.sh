#!/usr/bin/env bash
tn='Python-3.9.0a4'; url='http://www.python.org/ftp/python/3.9.0/Python-3.9.0a4.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi

# if [ ! -f $CUST_INST_PREFIX/bin/python3 ]; then # if not netplan
	#rm_os_pkg $sn;
# fi
config_dest;`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" \
				--with-system-expat --with-system-ffi --with-ensurepip=install --with-computed-gotos \
				--enable-shared --enable-optimizations --enable-ipv6 --with-lto --with-pymalloc --prefix=$CUST_INST_PREFIX; 
do_make build_all;do_make install;
mv $CUST_INST_PREFIX/include/python3.8m / $CUST_INST_PREFIX/include/python3.8
if [ -f $CUST_INST_PREFIX/bin/python3 ]; then
	rm -f /usr/bin/py3; ln -s $CUST_INST_PREFIX/bin/python3.8 /usr/bin/py3;
	echo $CUST_INST_PREFIX/lib/python3.8 > $LD_CONF_PATH/python3.8.conf;
	ldconfig
	py3 -m ensurepip; rm /usr/bin/py3_pip; ln -s $CUST_INST_PREFIX/bin/pip3 /usr/bin/py3_pip;
fi
source /etc/profile;source ~/.bashrc;ldconfig;


export VERBOSE=1;

rm -rf ~/.cache/pip 

export LDFLAGS="-DTCMALLOC_MINIMAL -ltcmalloc_minimal -fno-builtin-malloc -fno-builtin-calloc -fno-builtin-realloc -fno-builtin-free"
export CFLAGS="$ADD_O_FS $LDFLAGS -DNDEBUG"
export CPPFLAGS="$ADD_O_FS $LDFLAGS"
export INCLUDEDIRS="-I$CUST_INST_PREFIX/include"
	
$PIP_INSTALL python3 setuptools
$PIP_INSTALL python3 pip
$PIP_INSTALL python3 setuptools
$PIP_INSTALL python3 meson ninja 

#if [ -f /usr/bin/py3_pip ] && [ $stage -ne 0 ]; then
	$PIP_INSTALL python3 cffi 
	$PIP_INSTALL python3 greenlet
	$PIP_INSTALL python3 psutil deepdiff
	$PIP_INSTALL python3 xlrd lxml	
	$PIP_INSTALL python3 pycrypto 
	$PIP_INSTALL python3 cryptography
	$PIP_INSTALL python3 pyopenssl #LDFLAGS="-L$CUST_INST_PREFIX/ssl/lib" CFLAGS="-I$CUST_INST_PREFIX/ssl/include" 
	$PIP_INSTALL python3 pycryptodomex
	
	$PIP_INSTALL python3 pycparser
	
	$PIP_INSTALL python3 h2 #https://github.com/python-hyper/hyper-h2/archive/master.zip
	$PIP_INSTALL python3 urllib3 dnspython
	$PIP_INSTALL python3 linuxfd http://github.com/kashirin-alex/eventlet/archive/master.zip 
   
	$PIP_INSTALL python3 msgpack-python
	$PIP_INSTALL python3 webp Pillow Wand
	$PIP_INSTALL python3 weasyprint                 
	$PIP_INSTALL python3 brotli pylzma rarfile  #zipfile pysnappy
	$PIP_INSTALL python3 ply slimit
	$PIP_INSTALL python3 guess_language
	$PIP_INSTALL python3 paypalrestsdk #pygeocoder python-google-places
	$PIP_INSTALL python3 josepy acme
	$PIP_INSTALL python3 fontTools

	$PIP_INSTALL python3 http://github.com/kashirin-alex/libpyhdfs/archive/master.zip
	$PIP_INSTALL python3 http://github.com/kashirin-alex/PyHelpers/archive/master.zip
	
	(cd $SOURCES_PATH/boost;
	./bootstrap.sh --with-python=`_install_prefix`/bin/python3.8 --prefix=`_install_prefix`;
	./b2 --with-python  threading=multi link=shared runtime-link=shared install;)

#fi

export LDFLAGS=""
export CFLAGS=""
export CPPFLAGS=""
export INCLUDEDIRS=""