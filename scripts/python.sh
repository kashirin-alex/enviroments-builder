#!/usr/bin/env bash
tn='Python-2.7.16'; url='http://www.python.org/ftp/python/2.7.16/Python-2.7.16.tar.xz';
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

if [ -f $CUST_INST_PREFIX/bin/pip ] && [ $stage -ne 0 ]; then
	ln -s $CUST_INST_PREFIX/bin/python /usr/bin/python;
	if [ $stage -eq 3 ]; then
		pip uninstall -y cffi greenlet psutil deepdiff xlrd lxml pycrypto cryptography pyopenssl pycparser h2 urllib3 dnspython \
						 eventlet msgpack-python Wand weasyprint pylzma rarfile guess_language paypalrestsdk josepy acme pyhdfs
	fi
	rm -rf ~/.cache/pip 

	pip install --upgrade setuptools
	pip install --upgrade pip
	pip install --upgrade setuptools

	pip install --upgrade  cffi 
	pip install --upgrade  greenlet
	pip install --upgrade  psutil deepdiff
	pip install --upgrade  xlrd lxml	
	pip install --upgrade  pycrypto 
	pip install --upgrade  cryptography
	pip install --upgrade  pyopenssl #LDFLAGS="-L$CUST_INST_PREFIX/ssl/lib" CFLAGS="-I$CUST_INST_PREFIX/ssl/include" 
	pip install --upgrade  pycryptodomex
	pip install --upgrade  pycparser
	
	pip install --upgrade  h2 #https://github.com/python-hyper/hyper-h2/archive/master.zip
	pip install --upgrade  urllib3 dnspython
   	pip install --upgrade linuxfd https://github.com/kashirin-alex/eventlet/archive/master.zip 

	pip install --upgrade  msgpack-python
	pip install --upgrade  webp Pillow Wand
	pip install --upgrade  weasyprint==0.42.3                 
	pip install --upgrade  brotli pylzma rarfile  #zipfile pysnappy
	pip install --upgrade ply slimit

	pip install --upgrade  guess_language
	pip install --upgrade  paypalrestsdk #pygeocoder python-google-places
	pip install --upgrade  josepy acme
	pip install --upgrade fontTools

	pip install --upgrade https://github.com/kashirin-alex/libpyhdfs/archive/master.zip

	
	#pip install --upgrade ninja;
	#pip install --upgrade http://chromium.googlesource.com/external/gyp/+archive/master.tar.gz;
	pip install --upgrade Cython
fi
