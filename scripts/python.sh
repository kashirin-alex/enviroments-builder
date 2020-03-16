#!/usr/bin/env bash
tn='Python-2.7.17'; url='http://www.python.org/ftp/python/2.7.17/Python-2.7.17.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi

if [ ! -f $CUST_INST_PREFIX/bin/python ]; then
	rm_os_pkg $sn;
	if [[ $os_r == 'openSUSE' ]];then
		echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
		echo "export PYTHONHOME=\"$CUST_INST_PREFIX\"" >> $ENV_SETTINGS_PATH/$sn.sh
		source /etc/profile;source ~/.bashrc;ldconfig;
	fi
fi
config_dest;`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" \
				--with-wctype-functions --with-system-expat --with-system-ffi --with-ensurepip=install --with-dbmliborder=bdb:gdbm:ndbm:                \
				--with-computed-gotos --with-lto --with-signal-module --with-pth --with-pymalloc --with-fpectl                \
				--enable-shared --enable-unicode=ucs4 --enable-optimizations --enable-ipv6           \
				--prefix=$CUST_INST_PREFIX --target=`_build`; 
do_make build_all;do_make install;
source /etc/profile;source ~/.bashrc;ldconfig;

export VERBOSE=1;
export LDFLAGS="-DTCMALLOC_MINIMAL -ltcmalloc_minimal -fno-builtin-malloc -fno-builtin-calloc -fno-builtin-realloc -fno-builtin-free"
export CFLAGS="$ADD_O_FS $LDFLAGS -DNDEBUG"
export CPPFLAGS="$ADD_O_FS $LDFLAGS"
export INCLUDEDIRS="-I$CUST_INST_PREFIX/include"

if [ -f $CUST_INST_PREFIX/bin/pip ] && [ $stage -ne 0 ]; then
	ln -s $CUST_INST_PREFIX/bin/python /usr/bin/python;
	if [ $stage -eq 3 ]; then
		pip uninstall -y cffi greenlet psutil deepdiff xlrd lxml pycrypto cryptography pyopenssl pycparser h2 urllib3 dnspython \
						 eventlet msgpack-python Wand weasyprint pylzma rarfile guess_language paypalrestsdk josepy acme pyhdfs
	fi
	rm -rf ~/.cache/pip 

	$PIP_INSTALL python setuptools
	$PIP_INSTALL python pip
	$PIP_INSTALL python setuptools

	$PIP_INSTALL python cffi 
	$PIP_INSTALL python greenlet
	$PIP_INSTALL python psutil==5.6.3 deepdiff
	$PIP_INSTALL python xlrd lxml	
	$PIP_INSTALL python pycrypto 
	$PIP_INSTALL python cryptography
	$PIP_INSTALL python pyopenssl #LDFLAGS="-L$CUST_INST_PREFIX/ssl/lib" CFLAGS="-I$CUST_INST_PREFIX/ssl/include" 
	$PIP_INSTALL python pycryptodomex
	$PIP_INSTALL python pycparser
	
	$PIP_INSTALL python h2 #https://github.com/python-hyper/hyper-h2/archive/master.zip
	$PIP_INSTALL python urllib3 dnspython
   	$PIP_INSTALL python linuxfd http://github.com/kashirin-alex/eventlet/archive/master.zip 

	$PIP_INSTALL python msgpack-python
	$PIP_INSTALL python webp Pillow Wand
	$PIP_INSTALL python weasyprint==0.42.3                 
	$PIP_INSTALL python brotli pylzma rarfile  #zipfile pysnappy
	$PIP_INSTALL python ply slimit

	$PIP_INSTALL python guess_language
	$PIP_INSTALL python paypalrestsdk #pygeocoder python-google-places
	$PIP_INSTALL python josepy acme
	$PIP_INSTALL python fontTools

	$PIP_INSTALL python http://github.com/kashirin-alex/libpyhdfs/archive/master.zip
	$PIP_INSTALL python http://github.com/kashirin-alex/PyHelpers/archive/master.zip

	
	#$PIP_INSTALL pythonninja;
	#$PIP_INSTALL pythonhttp://chromium.googlesource.com/external/gyp/+archive/master.tar.gz;
	$PIP_INSTALL python Cython
fi

export LDFLAGS=""
export CFLAGS=""
export CPPFLAGS=""
export INCLUDEDIRS=""