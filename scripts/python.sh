#!/usr/bin/env bash
tn='Python-2.7.14'; url='http://www.python.org/ftp/python/2.7.14/Python-2.7.14.tgz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi

if [ ! -f $CUST_INST_PREFIX/bin/python ]; then
	if [[ $os_r == 'Ubuntu' ]];then
		apt-get autoremove -yq --purge python2.7
	elif [ $os_r == 'openSUSE'] && [ $stage == 1 ];then
		echo 'possible? zypper rm -y python2';
	fi
	# echo $CUST_INST_PREFIX/include/python2.7 > $LD_CONF_PATH/python.conf
	if [[ $os_r == 'openSUSE' ]];then
		echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
		echo "export PYTHONHOME=\"$CUST_INST_PREFIX\"" >> $ENV_SETTINGS_PATH/$sn.sh
		# echo "export PYTHONPATH=\"$CUST_INST_PREFIX/lib/python2.7:$CUST_INST_PREFIX/lib/python2.7/lib-dynload:$CUST_INST_PREFIX/lib/python2.7/site-packages\"" >> $ENV_SETTINGS_PATH/$sn.sh
		# echo "export CPATH=\$CPATH:$CUST_INST_PREFIX/include/python2.7" >> $ENV_SETTINGS_PATH/$sn.sh

		source /etc/profile;source ~/.bashrc;ldconfig;
	fi
fi
configure_build --with-wctype-functions --with-system-expat --with-system-ffi --with-ensurepip=install --with-dbmliborder=bdb:gdbm:ndbm:                \
				--with-computed-gotos --with-lto --with-signal-module --with-pth --with-pymalloc --with-fpectl                \
				--enable-shared --enable-unicode=ucs4 --enable-optimizations --enable-ipv6           \
				--prefix=$CUST_INST_PREFIX --target=`_build`;   #
do_make;do_make install;
source /etc/profile;source ~/.bashrc;ldconfig;

if [ -f $CUST_INST_PREFIX/bin/pip ] && [ $stage != 0 ]; then
	ln -s $CUST_INST_PREFIX/bin/python /usr/bin/python;
	
	rm -r ~/.cache/pip 

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

	pip install --upgrade  pycparser
	
	pip install --upgrade  h2 #https://github.com/python-hyper/hyper-h2/archive/master.zip
	pip install --upgrade  urllib3 dnspython
	pip install --upgrade  https://github.com/eventlet/eventlet/archive/v0.19.0.zip # https://github.com/eventlet/eventlet/archive/master.zip #eventlet
	echo '' > "/usr/local/lib/python2.7/site-packages/eventlet/green/OpenSSL/rand.py"
	sed -i "1s;^;import OpenSSL.SSL\nfor n in dir(OpenSSL.SSL):\n    exec(n+'=getattr(OpenSSL.SSL, \"'+n+'\")')\n;" /usr/local/lib/python2.7/site-packages/eventlet/green/OpenSSL/SSL.py
	sed -i 's/from OpenSSL.SSL import \*//g' /usr/local/lib/python2.7/site-packages/eventlet/green/OpenSSL/SSL.py;
	sed -i "1s;^;import OpenSSL.crypto\nfor n in dir(OpenSSL.crypto):\n    exec(n+'=getattr(OpenSSL.crypto, \"'+n+'\")')\n;" /usr/local/lib/python2.7/site-packages/eventlet/green/OpenSSL/crypto.py

   
	pip install --upgrade  msgpack-python
	pip install --upgrade  Wand
	pip install --upgrade  weasyprint                 
	pip install --upgrade  pylzma rarfile  #zipfile pysnappy
	pip install --upgrade  guess_language
	pip install --upgrade  paypalrestsdk #pygeocoder python-google-places
	pip install --upgrade  josepy acme

	pip install --upgrade  https://github.com/kashirin-alex/libpyhdfs/archive/master.zip

fi
