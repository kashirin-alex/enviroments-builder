#!/usr/bin/env bash
## Author Kashirin Alex (kashirin.alex@gmail.com)

# nohup bash ~/builder/build-env.sh --sources thrift hypertable &> '/root/builder/built.log' &
# bash ~/builder/build-env.sh --verbose --sources libeditline2 libgsasl libhdfspp 

################## DIRCETOTRIES CONFIGURATIONS ##################
CUST_INST_PREFIX=/usr/local
CUST_JAVA_INST_PREFIX=/usr/java

SCRIPTS_PATH=/root/builder/scripts
BUILDS_ROOT=/root/builds
DOWNLOAD_PATH=$BUILDS_ROOT/downloads
BUILDS_LOG_PATH=$BUILDS_ROOT/logs/$( date  +"%Y-%m-%d_%H-%M-%S")
SOURCES_PATH=/root/s
BUILTS_PATH=/root/b

ENV_SETTINGS_PATH=$CUST_INST_PREFIX/etc/profile.d/
LD_CONF_PATH=$CUST_INST_PREFIX/etc/ld.so.conf.d

ADD_LTO_FS="-flto -fuse-linker-plugin -ffat-lto-objects"
ADD_O_FS_from_stage_1="-O3 $ADD_LTO_FS"
ADD_O_FS_from_stage_2="$ADD_O_FS_from_stage_1"
##################################################################
ADD_O_FS=''
PIP_INSTALL=$SCRIPTS_PATH/../pip_install.sh
os_r=$(cat /usr/lib/os-release | grep "^ID=" |  sed 's/ID=//g');
echo $os_r;
if [[ $os_r == *"ubuntu"* ]]; then 
	os_r='ubuntu';
elif [[ $os_r == *"openSUSE"* ]]; then 
	os_r='openSUSE';
elif [[ $os_r == *"arch"* ]]; then 
	os_r='arch';
fi

build_target='node'
reuse_make=0
test_make=0
verbose=0
only_dw=0
help=''
stage=0
c=0
only_sources=()

ARGS=("$@")
while [ $# -gt 0 ]; do	
  let c=c+1;

  case $1 in
    --reuse-make) 	
		reuse_make=$(($2));
	;;
    --test-make)  		
		test_make=1
	;;
    --target)  		
		build_target=$2;
	;;
    --only-dw)  		
		only_dw=1;
	;;
    --verbose)  		
		verbose=1;
	;;
    --stage)  		
		stage=$(($2));
	;;
	--sources) 
		echo --sources at $c :
		echo ${ARGS[@]:$c}
		only_sources=(${ARGS[@]:$c});
		echo $only_sources
	;;
    --help)  			
		help='--help'
	;;
  esac
  shift
done

if [ ${#only_sources[@]} -eq 0 ]; then 
	echo '	--sources must be set with "all" or sources names'
	echo $only_sources
	exit 1
fi
build_all=0
if [ ${#only_sources[@]} -eq 1 ] && [ ${only_sources[0]} == 'all' ]; then 
	only_sources=()
	build_all=1
	#verbose=0;  
else
	stage=-1;
fi

if [ ${#only_sources[@]} -gt 0 ]; then 
	echo 'number of sources: '${#only_sources[@]}
fi
 
if [ -z $help ] && [ ${#only_sources[@]} -eq 0 ] && [ $build_all == 0 ]; then 
	verbose=1;    
	stage=0
fi


echo '--target:' $build_target
echo '--verbose:' $verbose
echo '--sources:' ${only_sources[@]}
echo '--help:' $help
echo '--stage:' $stage
echo '--test_make:' $test_make
echo '--reuse-make:' $reuse_make
echo '--only-dw:' $only_dw
#trap 'echo "trying to EXIT"' EXIT
#trap 'echo "trying to SIGINT"' SIGINT
#trap 'echo "trying to SIGTERM"' SIGTERM
#trap 'echo "trying to INT"' INT
#

mkdir -p $LD_CONF_PATH
mkdir -p $ENV_SETTINGS_PATH
mkdir -p $CUST_INST_PREFIX
mkdir -p $CUST_JAVA_INST_PREFIX
mkdir -p $BUILDS_ROOT
mkdir -p $DOWNLOAD_PATH
mkdir -p $SOURCES_PATH
if [ $verbose == 0 ]; then mkdir -p $BUILDS_LOG_PATH;fi;
mkdir -p $BUILTS_PATH
	
NUM_PROCS=$((`grep -c processor < /proc/cpuinfo || echo 1`*2))


#########
_install_prefix(){
	echo $CUST_INST_PREFIX; #/$sn
}
_build(){
	echo `uname -m`-$os_r-linux-gnu;
}

download() {
	if [ ! -f $DOWNLOAD_PATH/$sn/$sn.ext ]; then
		echo 'downloading:' $sn.ext: $url;
		if [ ! -d $DOWNLOAD_PATH/$sn ]; then
			mkdir $DOWNLOAD_PATH/$sn;
		fi	
		cd $DOWNLOAD_PATH/$sn;

		wget -O $sn.ext -nv --tries=3 --no-check-certificate $url;
	fi
}
extract() {
	echo 'extracting:'$sn'.ext to '$sn;
	if [ -d `src_path` ]; then
		echo 'removing old:' `src_path`;
		rm -rf `src_path`;
	fi
	cd $SOURCES_PATH; 
	
	if [ $archive_type == 'tar' ]; then
		tar xf $DOWNLOAD_PATH/$sn/$sn.ext;
	elif [ $archive_type == 'zip' ]; then
		unzip $DOWNLOAD_PATH/$sn/$sn.ext;
	fi
	if [ $tn != $sn ]; then
		mv $tn $sn;
	fi
}
set_source() {
	echo -e '\n\n\n'
	echo 'setting-source:' $sn
	if [ $reuse_make == 1 ] && [ -d `src_path` ]; then
		echo 'reusing previus make:' `src_path`
		cd `src_path`;
		return 1
	fi

	download $url
	archive_type=$1;
	extract;
	cd `src_path`;
}
mv_child_as_parent() {
	rm -f ../${sn}_tmp; mv $1 ../${sn}_tmp; rm -rf ../${sn}; mv ../${sn}_tmp ../${sn};cd ..;cd ${sn};
}
#########
config_dest() {
	if [ $reuse_make == 0 ] && [ -d $BUILTS_PATH/$sn ]; then
		rm -rf  $BUILTS_PATH/$sn;
	fi
	mkdir -p $BUILTS_PATH/$sn;
	cd $BUILTS_PATH/$sn;
}
src_path() {
	echo $SOURCES_PATH/$sn;
}
do_make() {
	echo 'make args:' -j$NUM_PROCS  ${@:1} VERBOSE=1;
	make -j$NUM_PROCS ${@:1} VERBOSE=1;
}
#########
finalize_build() {
	if [ `_install_prefix` != $CUST_INST_PREFIX ]; then
		paths=''
		if [ -d `_install_prefix`/lib ]; then
			paths=`_install_prefix`/lib;
		fi
		if [ -d `_install_prefix`/lib64 ]; then
			paths=$paths\\n`_install_prefix`/lib64
		fi
		if [ paths != '' ]; then 
			echo -e $paths > $LD_CONF_PATH/$sn.conf;
		fi
	fi

	source /etc/profile;
	source ~/.bashrc;
	rm /etc/ld.so.cache;
	ldconfig;
	echo 'finished:' $sn;
	cd $BUILDS_ROOT; 
	echo -e '\n\n\n'
}
#########

#########
do_build() {
	echo '-------------------------------'
	echo 'doing_build:' $sn 'stage:' $stage
	if [ -f $SCRIPTS_PATH/$sn.sh ]; then
		source $SCRIPTS_PATH/$sn.sh
	else
		_do_build #${@:1}
	fi
	
	if [ $only_dw == 0 ]; then 
		finalize_build;
	fi
	echo 'done_build:' $sn 'stage:' $stage
	echo '-------------------------------'
}
_do_build() {
  
  case $sn in

'make')
tn='make-4.3'; url='http://ftp.gnu.org/gnu/make/make-4.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
#sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-guile --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'libtool')
tn='libtool-2.4.6'; url='http://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-ltdl-install --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'autoconf')
tn='autoconf-2.69'; url='http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'autoconf-archive')
tn='autoconf-archive-2019.01.06'; url='http://ftp.gnu.org/gnu/autoconf-archive/autoconf-archive-2019.01.06.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'automake')
tn='automake-1.16.1'; url='http://ftp.gnu.org/gnu/automake/automake-1.16.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib; do_make install;do_make all; 
		shift;;

'cmake')
tn='cmake-3.16.5'; url='https://cmake.org/files/v3.16/cmake-3.16.5.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi

if [ $stage -eq 0 ]; then
./bootstrap --prefix=`_install_prefix` -- -DCMAKE_USE_OPENSSL=OFF;
else 
./bootstrap --prefix=`_install_prefix`;
fi
do_make;do_make install;do_make all;
		shift;;

'lz4')
tn='lz4-1.9.2'; url='http://github.com/lz4/lz4/archive/v1.9.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
do_make DESTDIR=`_install_prefix`;do_make install;
		shift;;

'brotli')
tn='brotli-1.0.7'; url='http://github.com/google/brotli/archive/v1.0.7.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure-cmake --prefix=`_install_prefix` --pass-thru -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC";
do_make;do_make install; 
		shift;;

'qazip')
tn='QATzip-1.0.1'; url='http://github.com/intel/QATzip/archive/v1.0.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'zlib')
tn='zlib-1.2.11'; url='http://zlib.net/zlib-1.2.11.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;do_make all;
		shift;;

'bzip2')
tn='bzip2-1.0.8'; url='http://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
do_make CFLAGS=-fPIC;do_make -f Makefile-libbz2_so CFLAGS=-fPIC; do_make install CFLAGS=-fPIC PREFIX=`_install_prefix`;
		shift;;

'unrar')
tn='unrar'; url='http://www.rarlab.com/rar/unrarsrc-5.9.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
make DESTDIR=`_install_prefix`;make lib DESTDIR=`_install_prefix`;make install-lib DESTDIR=`_install_prefix`;make install DESTDIR=`_install_prefix`;make all DESTDIR=`_install_prefix`;
		shift;;

'gzip')
tn='gzip-1.10'; url='http://ftp.gnu.org/gnu/gzip/gzip-1.10.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-threads=posix --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'lzo')
tn='lzo-2.10'; url='http://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'snappy')
tn='snappy-1.1.8'; url='http://github.com/google/snappy/archive/1.1.8.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DSNAPPY_BUILD_TESTS=0 -DBUILD_SHARED_LIBS=1 -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DSNAPPY_BUILD_TESTS=0 -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;

'zstd')
tn='zstd-1.4.4'; url='http://github.com/facebook/zstd/releases/download/v1.4.4/zstd-1.4.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path`/build/cmake -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make prefix=`_install_prefix` install;
		shift;;	
		
'xz')
tn='xz-5.2.4'; url='http://fossies.org/linux/misc/xz-5.2.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib;do_make install-strip;do_make install;do_make all; 
		shift;;

'p7zip')
tn='p7zip_16.02'; url='http://fossies.org/linux/misc/p7zip_16.02_src_all.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
do_make;do_make all; ./install.sh; 
		shift;;

'tar')
tn='tar-1.32'; url='http://ftp.gnu.org/gnu/tar/tar-1.32.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;FORCE_UNSAFE_CONFIGURE=1 `src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib;do_make install-strip;do_make install;
		shift;;

'libzip')
tn='libzip-1.6.1'; url='http://libzip.org/download/libzip-1.6.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;	
		shift;;

'unzip')
tn='unzip60'; url='ftp://ftp.info-zip.org/pub/infozip/src/unzip60.tgz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
make -f unix/Makefile generic
make prefix=`_install_prefix` MANDIR=$CUST_INST_PREFIX/share/man/man1 -f unix/Makefile install
		shift;;

'libpng')
tn='libpng-1.6.37'; url='ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng16/libpng-1.6.37.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'librsvg')
tn='librsvg-2.48.0'; url='http://github.com/GNOME/librsvg/archive/2.48.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
autoreconf -vif
./configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'libjpeg')
tn='jpeg-9d'; url='http://www.ijg.org/files/jpegsrc.v9d.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;	

'libwebp')
tn='libwebp-1.1.0'; url='http://github.com/webmproject/libwebp/archive/v1.1.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./autogen.sh;
config_dest;`src_path`/configure --enable-everything CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;	

'byacc')
tn='byacc-20191125'; url='ftp://ftp.invisible-island.net/pub/byacc/byacc-20191125.tgz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
		shift;;	


'm4')
tn='m4-1.4.18'; url='http://ftp.gnu.org/gnu/m4/m4-1.4.18.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-c++ --enable-threads=posix  --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;
		
'gmp')
tn='gmp-6.2.0'; url='http://ftp.gnu.org/gnu/gmp/gmp-6.2.0.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/-lncurses/-lncursesw/g' configure;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-cxx --enable-fat --enable-assert  --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
		shift;;

'mpfr')
tn='mpfr-4.0.2'; url='http://ftp.gnu.org/gnu/mpfr/mpfr-4.0.2.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-decimal-float --enable-thread-safe --with-gmp-build=$BUILTS_PATH/gmp/ --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'mpc')
tn='mpc-1.1.0'; url='http://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'isl')
tn='isl-0.18'; url='http://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-gmp=build --with-gmp-builddir=$BUILTS_PATH/gmp/ --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'bison')
tn='bison-3.5.3'; url='http://ftp.gnu.org/gnu/bison/bison-3.5.3.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-threads=posix --prefix=`_install_prefix` --build=`_build`;
do_make; do_make lib;do_make install-strip;do_make install;
		shift;;

'texinfo')
tn='texinfo-6.7'; url='http://ftp.gnu.org/gnu/texinfo/texinfo-6.7.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/ncurses/ncursesw/g' configure;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-threads=posix --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'flex')
tn='flex-2.6.4'; url='http://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --with-pic --enable-shared --enable-static --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'flex_fallback')
tn='flex-2.6.3'; url='http://github.com/westes/flex/releases/download/v2.6.3/flex-2.6.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --with-pic --enable-shared --enable-static --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'coreutils')
tn='coreutils-8.32'; url='http://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;FORCE_UNSAFE_CONFIGURE=1 `src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-install-program=hostname --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'binutils')
tn='binutils-2.34'; url='http://ftp.ntua.gr/mirror/gnu/binutils/binutils-2.34.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-plugins --enable-gold=yes --enable-ld=yes --enable-libssp --enable-lto --enable-vtable-verify --with-system-zlib --with-mpfr=`_install_prefix` --with-mpc=`_install_prefix` --with-isl=`_install_prefix` --with-gmp=`_install_prefix` --prefix=`_install_prefix` --build=`_build`; # --enable-libada --enable-objc-gc 
do_make tooldir=`_install_prefix`; do_make tooldir=`_install_prefix` install-strip;do_make tooldir=`_install_prefix` install;do_make tooldir=`_install_prefix` all; # libiberty> --enable-shared=opcodes --enable-shared=bfd --enable-host-shared --enable-stage1-checking=all --enable-stage1-languages=all 
		shift;;

'gettext')
tn='gettext-0.20.1'; url='http://ftp.gnu.org/pub/gnu/gettext/gettext-0.20.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/ncurses/ncursesw/g' configure;sed -i 's/ncurses/ncursesw/g' gettext-tools/configure;
config_dest;`src_path`/configure CFLAGS="$ADD_LTO_FS" CPPFLAGS="$ADD_LTO_FS" --enable-threads=posix --prefix=`_install_prefix` --build=`_build`;
do_make; do_make install-strip;do_make install;do_make all;
		shift;;

'keyutils')
tn='keyutils-1.6'; url='http://people.redhat.com/~dhowells/keyutils/keyutils-1.6.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/\/usr\/bin\//\/usr\/local\/bin\//g' Makefile;
make DESTDIR="" SHAREDIR=`_install_prefix`/share MANDIR=`_install_prefix`/share LIBDIR=`_install_prefix`/lib INCLUDEDIR=`_install_prefix`/include  CFLAGS="-I. $ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" install all; 
		shift;;

'nettle')
tn='nettle-3.5.1'; url='http://ftp.gnu.org/gnu/nettle/nettle-3.5.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-gcov --enable-x86-aesni --enable-fat --libdir=`_install_prefix`/lib --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
		shift;;

'libtasn1')
tn='libtasn1-4.16.0'; url='http://ftp.gnu.org/gnu/libtasn1/libtasn1-4.16.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib;do_make install-strip;do_make install;do_make all;  	
		shift;;

'libiconv')
tn='libiconv-1.16'; url='http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --enable-extra-encodings --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-lib;do_make install-strip;do_make install;do_make all; 
		shift;;

'libunistring')
tn='libunistring-0.9.10'; url='http://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-threads=posix  --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'libidn2')
tn='libidn2-2.3.0'; url='http://ftp.gnu.org/pub/gnu/libidn/libidn2-2.3.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'libsodium')
tn='libsodium-1.0.18'; url='http://github.com/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-minimal --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'unbound')
tn='unbound-1.10.0'; url='http://nlnetlabs.nl/downloads/unbound/unbound-1.10.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure --enable-tfo-client --enable-tfo-server --enable-dnscrypt --prefix=`_install_prefix` --build=`_build`;
# CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" 
do_make;do_make lib;do_make install-lib;do_make install;do_make all; 
		shift;;

'libffi')
tn='libffi-3.3'; url='http://github.com/libffi/libffi/archive/v3.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./autogen.sh;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'p11-kit')
tn='p11-kit-0.23.20'; url='http://github.com/p11-glue/p11-kit/releases/download/0.23.20/p11-kit-0.23.20.tar.xz'; #gnutls(readyness)
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --without-trust-paths --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'gnutls')
tn='gnutls-3.6.12'; url='http://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.12.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --disable-gtk-doc --enable-openssl-compatibility --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'openmpi')
tn='openmpi-4.0.2'; url='http://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'pcre')
tn='pcre-8.44'; url='http://ftp.pcre.org/pub/pcre/pcre-8.44.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-newline-is-any --enable-pcre16 --enable-pcre32 --enable-jit --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-unicode-properties --enable-utf --enable-ucp --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;	

'pcre2')
tn='pcre2-10.34'; url='http://ftp.pcre.org/pub/pcre/pcre2-10.34.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-rebuild-chartables --enable-newline-is-any --enable-pcre2-16 --enable-pcre2-32 --enable-jit --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-unicode-properties --enable-utf --enable-ucp  --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'glib')
tn='glib-2.64.2'; url='http://download.gnome.org/sources/glib/2.64/glib-2.64.2.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
meson _build --default-library static -Dselinux=disabled -Dinternal_pcre=false --optimization=3 --buildtype=release --prefix=`_install_prefix`;
ninja -C _build install;
rm -r _build;
meson _build --default-library shared --optimization=3 --buildtype=release --prefix=`_install_prefix`;
ninja -C _build install;
		shift;;
	
'glib_fallback')
tn='glib-2.57.1'; url='http://download.gnome.org/sources/glib/2.57/glib-2.57.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-threads=posix --prefix=`_install_prefix` --build=`_build`; # --with-libiconv=gnu
do_make; do_make install;
		shift;;

'jemalloc')
tn='jemalloc-5.2.1'; url='http://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./autogen.sh;./configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-static --enable-shared --enable-xmalloc --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install;do_make all;
		shift;;

'libevent')
tn='libevent-2.1.11-stable'; url='http://github.com/libevent/libevent/releases/download/release-2.1.11-stable/libevent-2.1.11-stable.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install-strip;do_make install;do_make all;  
		shift;;

'libatomic_ops')
tn='libatomic_ops-7.6.10'; url='http://www.hboehm.info/gc/gc_source/libatomic_ops-7.6.10.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'gc')
tn='gc-8.0.4'; url='http://www.hboehm.info/gc/gc_source/gc-8.0.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-single-obj-compilation --enable-large-config --enable-redirect-malloc --enable-sigrt-signals --enable-parallel-mark --enable-handle-fork --enable-cplusplus  --with-libatomic-ops=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'gperf')
tn='gperf-3.1'; url='http://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib; do_make install;do_make all; 
		shift;;

'patch')
tn='patch-2.7.6'; url='http://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;

'tcl')
tn='tcl8.6.10'; url='http://prdownloads.sourceforge.net/tcl/tcl8.6.10-src.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cd unix;./configure --enable-threads --enable-shared=yes --enable-static=yes --enable-64bit --prefix=`_install_prefix` --build=`_build`; 
make;make install-strip;make install;make all; 
		shift;;

'tk')
tn='tk8.6.10'; url='http://prdownloads.sourceforge.net/tcl/tk8.6.10-src.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cd unix;
./configure --enable-threads --enable-shared=yes --enable-static=yes --enable-64bit --prefix=`_install_prefix` --build=`_build`; #- --enable-xft  -with-tcl=`_install_prefix`/lib/
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'expect')
tn='expect5.45.4'; url='http://fossies.org/linux/misc/expect5.45.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-threads --enable-64bit --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
		shift;;

'libunwind')
tn='libunwind-1.3.1'; url='http://download-mirror.savannah.gnu.org/releases/libunwind/libunwind-1.3.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS " CPPFLAGS="$ADD_O_FS" --with-pic --disable-debug-frame --disable-cxx-exceptions --disable-debug --disable-documentation --disable-minidebuginfo --disable-msabi-support --enable-coredump  --enable-ptrace --enable-setjmp --enable-block-signals --enable-conservative-checks --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;

'libxml2')
tn='libxml2-2.9.10'; url='http://xmlsoft.org/sources/libxml2-2.9.10.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-ipv6=yes --with-c14n --with-fexceptions --with-icu --with-python --with-thread-alloc --with-coverage --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

'libxslt')
tn='libxslt-1.1.34'; url='http://xmlsoft.org/sources/libxslt-1.1.34.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install-strip;do_make install;do_make all; 	
		shift;;

'libeditline')
tn='libedit-20191231-3.1'; url='http://thrysoee.dk/editline/libedit-20191231-3.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/-lncurses/-lncursesw/g' configure;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-pic=yes --prefix=`_install_prefix` --build=`_build`; 
do_make SHLIB_LIBS="-lncursesw";do_make install-strip;do_make install;do_make all;
		shift;;
		
'libeditline2')
tn='editline-1.17.1'; url='http://github.com/troglobit/editline/releases/download/1.17.1/editline-1.17.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-pic=yes --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;
		shift;;

'termcap')
tn='termcap-1.3.1'; url='http://ftp.gnu.org/gnu/termcap/termcap-1.3.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
		shift;;

'libreadline')
tn='readline-8.0'; url='http://ftp.gnu.org/gnu/readline/readline-8.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/-lncurses/-lncursesw/g' configure;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --with-curses --enable-multibyte --prefix=`_install_prefix` --build=`_build`;
make SHLIB_LIBS="-lncursesw";make install;
		shift;;

'gdbm')
tn='gdbm-1.18.1'; url='http://ftp.gnu.org/gnu/gdbm/gdbm-1.18.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/ncurses/ncursesw/g' configure;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-libgdbm-compat --prefix=`_install_prefix` --build=`_build`;
make;make install-strip;make install;make all;
		shift;;

'libexpat')
tn='libexpat-R_2_2_9/expat'; url='http://github.com/libexpat/libexpat/archive/R_2_2_9.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./buildconf.sh
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'log4cpp')
tn='log4cpp-2.9.1'; url='http://github.com/orocos-toolchain/log4cpp/archive/v2.9.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;do_make all;
		shift;;
		
'libmesh')
tn='Mesh-master'; url='http://github.com/plasma-umass/Mesh/archive/master.zip';
set_source 'zip';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;
		
'gperftools')
tn='gperftools-2.7'; url='http://github.com/gperftools/gperftools/releases/download/gperftools-2.7/gperftools-2.7.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-libunwind --enable-frame-pointers --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;

're2')
tn='re2-2020-03-03'; url='http://github.com/google/re2/archive/2020-03-03.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path` -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;

'icu4c')
tn='icu/source'; url='http://github.com/unicode-org/icu/releases/download/release-66-1/icu4c-66_1-src.tgz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
echo '' > LICENSE;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --with-data-packaging=static --enable-plugins --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib;do_make install;do_make all;
		shift;;

'boost')
tn='boost_1_72_0'; url='http://dl.bintray.com/boostorg/release/1.72.0/source/boost_1_72_0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./bootstrap.sh --with-libraries=all --with-icu --prefix=`_install_prefix`;
./b2 -a cxxflags=-fPIC cflags=-fPIC threading=multi runtime-link=shared \
		--with-context --with-coroutine --with-atomic --with-regex --with-random \
		--with-date_time --with-thread --with-system --with-filesystem --with-iostreams \
		--with-program_options --with-thread --with-chrono --with-test  install; # --with-python 
		shift;;

'fuse2')
tn='fuse-2.9.9'; url='http://github.com/libfuse/libfuse/releases/download/fuse-2.9.9/fuse-2.9.9.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --enable-static --enable-shared --with-pic --enable-lib --enable-util --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib; do_make install-strip;do_make install;do_make all;
		shift;;

'fuse3')
tn='fuse-3.9.0'; url='http://github.com/libfuse/libfuse/archive/fuse-3.9.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-lib --enable-util --prefix=`_install_prefix` --build=`_build`;
do_make;do_make lib; do_make install-strip;do_make install;
		shift;;

'libsigar')
tn='hyperic-sigar-1.6.4'; url='http://sourceforge.mirrorservice.org/s/si/sigar/sigar/1.6/hyperic-sigar-1.6.4.zip';
set_source 'zip';
if [ $only_dw == 1 ];then return;fi
cp sigar-bin/include/*.h `_install_prefix`/include; cp sigar-bin/lib/libsigar-amd64-linux.so `_install_prefix`/lib
		shift;;

'berkeley-db')
tn='db-6.2.32'; url='http://download.oracle.com/berkeley-db/db-6.2.32.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
dist/configure  CXXFLAGS="-std=c++17 $ADD_O_FS -m64 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE" CFLAGS="$ADD_O_FS -m64 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE"  --enable-shared=yes --enable-static=yes --enable-cxx --enable-tcl --enable-dbm --enable-posixmutexes --enable-o_direct --enable-stl --enable-atomicfileread --prefix=`_install_prefix`  --build=`_build`; # --enable-java --enable-smallbuild
do_make;do_make install;do_make all; 
		shift;;

'libgpg-error')
tn='libgpg-error-1.37'; url='http://github.com/gpg/libgpg-error/archive/libgpg-error-1.37.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/autogen.sh;
`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-pic=PIC --enable-static=yes --enable-threads=posix --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;	

'libgcrypt')
tn='libgcrypt-1.8.5'; url='ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-1.8.5.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-pic=PIC --enable-static=yes --enable-m-guard --enable-hmac-binary-check --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; #libcap =  --with-capabilities ,
		shift;;	

'libssh')
tn='libssh-0.9.3'; url='http://git.libssh.org/projects/libssh.git/snapshot/libssh-0.9.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DOPENSSL_USE_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DWITH_SSH1=ON -DWITH_LIBZ=ON -DWITH_GCRYPT=OFF -DWITH_GSSAPI=OFF -DWITH_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;do_make all; 
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DBUILD_SHARED_LIBS=ON -DWITH_SSH1=ON -DWITH_LIBZ=ON -DWITH_GCRYPT=OFF -DWITH_GSSAPI=OFF -DWITH_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;do_make all; 
		shift;;	

'cryptopp')
tn='cryptopp-CRYPTOPP_8_2_0'; url='http://github.com/weidai11/cryptopp/archive/CRYPTOPP_8_2_0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;do_make all; 
		shift;;	

'cronolog')
tn='cronolog-1.7.1'; url='http://github.com/holdenk/cronolog/archive/1.7.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make lib;do_make install-strip;do_make install;do_make all;
		shift;;	

'libuv')
tn='libuv-1.35.0'; url='http://github.com/libuv/libuv/archive/v1.35.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./autogen.sh;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;	

'libcares')
tn='c-ares-1.14.0'; url='http://c-ares.haxx.se/download/c-ares-1.14.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-libgcc --enable-nonblocking --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
		shift;;	

'sqlite')
tn='sqlite'; url='http://www.sqlite.org/src/tarball/sqlite.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-releasemode --enable-editline --enable-gcov --enable-session --enable-rtree  --enable-json1 --enable-fts5 --enable-fts4 --enable-fts3 --enable-memsys3 --enable-memsys5 --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all; 
		shift;;	

'imagemagick')
tn='ImageMagick-6.9.11-0'; url='http://www.imagemagick.org/download/ImageMagick-6.9.11-0.tar.xz'; #http://github.com/dahlia/wand/blob/f97277be6d268038a869e59b0d6c3780d7be5664/wand/version.py
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS"  --enable-shared=yes --enable-static=yes --with-jpeg=yes --with-webp=yes --with-quantum-depth=16 --enable-hdri --enable-pipes --enable-hugepages --disable-docs --with-aix-soname=both --with-modules --with-jemalloc --with-umem --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;	

'freetype')
tn='freetype-2.9.1'; url='http://download.savannah.gnu.org/releases/freetype/freetype-2.9.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
if [ -z $1 ]; then opt='--with-harfbuzz=no'; else opt=$1;fi 
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-fast-install=no $opt --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
		shift;;	

'harfbuzz')
tn='harfbuzz-2.6.4'; url='http://www.freedesktop.org/software/harfbuzz/release/harfbuzz-2.6.4.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
if [ -z $1 ]; then opt='--with-freetype=yes --with-fontconfig=no'; else opt=${@:1};fi 
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" $opt --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;do_make all;
sn='freetype'; _do_build --with-harfbuzz=yes; sn='harfbuzz';
		shift;;	

'itstool')
tn='itstool-2.0.6'; url='http://files.itstool.org/itstool/itstool-2.0.6.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;do_make all;
		shift;;	

'fontconfig')
tn='fontconfig-2.13.92'; url='http://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.92.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-default-fonts=`_install_prefix`/share/fonts/ --enable-iconv  --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all;
sn='harfbuzz';_do_build --with-fontconfig=yes --with-freetype=yes;sn='fontconfig';
finalize_build;fc-cache -f;
		shift;;		

'fonts')
font_dir=`_install_prefix`/share/fonts/;
mkdir -p $font_dir;
sn='freefont-ttf';tn='freefont-20120503'; url='http://ftp.gnu.org/gnu/freefont/freefont-ttf-20120503.zip';
set_source 'zip';cp *.ttf $font_dir;
sn='freefont-woff';tn='freefont-20120503'; url='http://ftp.gnu.org/gnu/freefont/freefont-woff-20120503.zip';
set_source 'zip';cp *.woff $font_dir;

sn='unifont_upper';download 'http://unifoundry.com/pub/unifont/unifont-12.1.03/font-builds/unifont_upper-12.1.03.ttf';cp $DOWNLOAD_PATH/$sn/$sn.ext $font_dir$sn.ttf
sn='unifont_csur';download 'http://unifoundry.com/pub/unifont/unifont-12.1.03/font-builds/unifont_csur-12.1.03.ttf';cp  $DOWNLOAD_PATH/$sn/$sn.ext $font_dir$sn.ttf
sn='unifont';download 'http://unifoundry.com/pub/unifont/unifont-12.1.03/font-builds/unifont-12.1.03.ttf';cp  $DOWNLOAD_PATH/$sn/$sn.ext $font_dir$sn.ttf
		shift;;		

'sparsehash')
tn='sparsehash-sparsehash-2.0.3'; url='http://github.com/sparsehash/sparsehash/archive/sparsehash-2.0.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;   # --enable-namespace=gpreftools
do_make;do_make install-strip;do_make install;do_make all; 	
		shift;;

'sparsepp')
tn='sparsepp-1.22'; url='http://github.com/greg7mdp/sparsepp/archive/1.22.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cp -r sparsepp `_install_prefix`/include/
		shift;;

'openjdk')	
tn='jdk-12.0.1'; url='http://download.java.net/java/GA/jdk12.0.1/69cfe15208a647278a19ef0990eea691/12/GPL/openjdk-12.0.1_linux-x64_bin.tar.gz';
#tn='jdk-13.0.1'; url='http://download.java.net/java/GA/jdk13.0.1/cec27d702aa74d5a8630c65ae61e4305/9/GPL/openjdk-13.0.1_linux-x64_bin.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
rm -rf  $CUST_JAVA_INST_PREFIX/$sn
mv ../$sn $CUST_JAVA_INST_PREFIX/;

if [ -f $CUST_JAVA_INST_PREFIX/$sn/bin/javac ] &&  [ -f $CUST_JAVA_INST_PREFIX/$sn/bin/java ]; then # &&  [ -f $CUST_JAVA_INST_PREFIX/$sn/jre/bin/java ]
	echo "#\!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
	echo "export JAVA_HOME=\"$CUST_JAVA_INST_PREFIX/$sn\"" >> $ENV_SETTINGS_PATH/$sn.sh
	echo "export PATH=\$PATH:\"$CUST_JAVA_INST_PREFIX/$sn/bin\"" >> $ENV_SETTINGS_PATH/$sn.sh
	echo -e $CUST_JAVA_INST_PREFIX/$sn/lib/server/ > $LD_CONF_PATH/$sn.conf;
	echo -e $CUST_JAVA_INST_PREFIX/$sn/lib/ >> $LD_CONF_PATH/$sn.conf;
fi
		shift;;	

'apache-ant')
tn='apache-ant-1.10.7'; url='http://www.apache.org/dist/ant/source/apache-ant-1.10.7-src.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./build.sh install-lite -Ddist.dir=$CUST_JAVA_INST_PREFIX/$sn -Dant.install=$CUST_JAVA_INST_PREFIX/$sn
echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
echo "export ANT_HOME=\"$CUST_JAVA_INST_PREFIX/$sn\"" >> $ENV_SETTINGS_PATH/$sn.sh
		shift;;	

'apache-maven')	
tn='apache-maven-3.6.3'; url='http://apache.mediamirrors.org/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
rm -rf  $CUST_JAVA_INST_PREFIX/$sn
mv ../$sn $CUST_JAVA_INST_PREFIX/;
if [ -f $CUST_JAVA_INST_PREFIX/$sn/bin/mvn ]; then
	echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
	echo "export MAVEN_HOME=\"$CUST_JAVA_INST_PREFIX/$sn\"" >> $ENV_SETTINGS_PATH/$sn.sh
	echo "export PATH=\$PATH:\"$CUST_JAVA_INST_PREFIX/$sn/bin\"" >> $ENV_SETTINGS_PATH/$sn.sh

fi
		shift;;	

'thrift')
tn='thrift-0.13.0'; url='http://archive.apache.org/dist/thrift/0.13.0/thrift-0.13.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./bootstrap.sh;
opts="--with-cpp --with-c_glib ";
if [ $build_target == 'node' ];then
	opts="--without-ruby --without-perl  --without-php --without-nodejs"; #--without-c_glib
fi
./configure CFLAGS="$ADD_O_FS" CXXFLAGS="$ADD_O_FS -fPIC" $opts --disable-tests --disable-tutorial --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
#cd lib/java;make install;
#cd `src_path`/lib/py/;python setup.py install;pypy setup.py install;
		shift;;	

'attr')
tn='attr-2.4.47'; url='http://download.savannah.gnu.org/releases/attr/attr-2.4.47.src.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-gettext=yes --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;
		shift;;	

'libjansson')
tn='jansson-2.12'; url='http://www.digip.org/jansson/releases/jansson-2.12.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make install;	
		shift;;

'curl')
tn='curl-curl-7_69_1'; url='http://github.com/curl/curl/archive/curl-7_69_1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
rm_os_pkg curl;
		shift;;	

'wget')
tn='wget-1.20.3'; url='http://ftp.gnu.org/gnu/wget/wget-1.20.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-ssl=openssl --prefix=`_install_prefix` --build=`_build`;
do_make install;	
rm_os_pkg wget;
		shift;;	

'gmock')
tn='googletest-release-1.10.0'; url='http://github.com/google/googletest/archive/release-1.10.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	

'protobuf')
tn='protobuf-3.11.4'; url='http://github.com/protocolbuffers/protobuf/archive/v3.11.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cp -r ../$sn ../$sn-tmp; mv ../$sn-tmp gtest;
./autogen.sh;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-zlib --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;
		shift;;	

'libhdfspp')
tn='hadoop-trunk'; url='http://github.com/apache/hadoop/archive/trunk.zip';
rm -rf `src_path`;
set_source 'zip';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path`/hadoop-hdfs-project/hadoop-hdfs-native-client/src/ -DJVM_ARCH_DATA_MODEL=64 -DHADOOP_BUILD=ON -DBUILD_SHARED_HDFSPP=ON -DCMAKE_C_FLAGS="$ADD_O_FS" -DCMAKE_CXX_FLAGS="$ADD_O_FS" -DHDFSPP_LIBRARY_ONLY=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
cd main/native/libhdfspp; do_make;do_make install;
		shift;;	

'apache-hadoop')
tn='hadoop-2.7.7'; url='http://archive.apache.org/dist/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
if [ -d $CUST_JAVA_INST_PREFIX/$sn ]; then rm -rf $CUST_JAVA_INST_PREFIX/$sn;fi;
mv ../$sn $CUST_JAVA_INST_PREFIX/$sn;
if [ ! -d /etc/opt/hadoop ]; then
	mkdir -p /etc/opt; mv $CUST_JAVA_INST_PREFIX/$sn/etc/hadoop /etc/opt/;chmod -R 777 /etc/opt/hadoop;
fi
rm -rf $CUST_JAVA_INST_PREFIX/$sn/etc/hadoop;ln -s /etc/opt/hadoop $CUST_JAVA_INST_PREFIX/$sn/etc/hadoop;

echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
echo "export HADOOP_HOME=\"$CUST_JAVA_INST_PREFIX/$sn\"" >> $ENV_SETTINGS_PATH/$sn.sh
echo "export HADOOP_CONF_DIR=\"$CUST_JAVA_INST_PREFIX/$sn/etc/hadoop\"" >> $ENV_SETTINGS_PATH/$sn.sh
echo "export HADOOP_VERSION=\"2.7.7\"" >> $ENV_SETTINGS_PATH/$sn.sh
echo "export HADOOP_INCLUDE_PATH=\"$CUST_JAVA_INST_PREFIX/$sn/include\"" >> $ENV_SETTINGS_PATH/$sn.sh
echo "export HADOOP_LIB_PATH=\"$CUST_JAVA_INST_PREFIX/$sn/lib\"" >> $ENV_SETTINGS_PATH/$sn.sh
echo "export PATH=\$PATH:\"$CUST_JAVA_INST_PREFIX/$sn/bin\"" >> $ENV_SETTINGS_PATH/$sn.sh
orig_IFS=$IFS;subs=('common common/lib hdfs hdfs/lib tools/lib');CLASSPATH='';for n in $subs;do CLASSPATH=$(JARS=($CUST_JAVA_INST_PREFIX/$sn/share/hadoop/$n/*.jar); IFS=:; echo "${JARS[*]}"):$CLASSPATH;done;IFS=$orig_IFS;
echo "export CLASSPATH=$CLASSPATH" >> $ENV_SETTINGS_PATH/$sn.sh
echo -e $CUST_JAVA_INST_PREFIX/$sn/lib/native/ > $LD_CONF_PATH/$sn.conf;
		shift;;	

'apache-zookeeper')
tn='apache-zookeeper-3.6.0-bin'; url='http://apache.mirrors.ovh.net/ftp.apache.org/dist/zookeeper/zookeeper-3.6.0/apache-zookeeper-3.6.0-bin.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
if [ -d $CUST_JAVA_INST_PREFIX/$sn ]; then rm -rf $CUST_JAVA_INST_PREFIX/$sn;fi;
mv ../$sn $CUST_JAVA_INST_PREFIX/$sn;
if [ ! -d /etc/opt/zookeeper ]; then
	mkdir -p /etc/opt; mv $CUST_JAVA_INST_PREFIX/$sn/conf /etc/opt/zookeeper;chmod -R 777 /etc/opt/zookeeper;
fi
rm -rf $CUST_JAVA_INST_PREFIX/$sn/conf;ln -s /etc/opt/zookeeper $CUST_JAVA_INST_PREFIX/$sn/conf;
		shift;;	

'nodejs')
tn='node-v11.15.0'; url='http://nodejs.org/dist/latest-v11.x/node-v11.15.0.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./configure --no-cross-compiling --prefix=`_install_prefix`; #--with-intl=none 
do_make;do_make install;
		shift;;	

'libhoard')
tn='Hoard'; url='http://github.com/emeryberger/Hoard/releases/download/3.13/hoard-release.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cd src;mv GNUmakefile Makefile;
make Linux-gcc-x86_64 CXX=gcc;mv libhoard.so $CUST_INST_PREFIX/lib/;
		shift;;	

'gawk')
tn='gawk-5.0.1'; url='http://ftp.gnu.org/gnu/gawk/gawk-5.0.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;

'pybind11')
tn='pybind11-2.4.3'; url='http://github.com/pybind/pybind11/archive/v2.4.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DPYBIND11_PYTHON_VERSION=2.7 -DCMAKE_CXX_FLAGS="$ADD_O_FS"  -DPYBIND11_TEST=OFF  -DCMAKE_INSTALL_INCLUDEDIR=`_install_prefix`/include;
do_make install;
		shift;;

'hypertable')
tn='hypertable-master'; url='http://github.com/kashirin-alex/hypertable/archive/master.zip';
rm -rf $DOWNLOAD_PATH/$sn
set_source 'zip';
if [ $only_dw == 1 ];then return;fi
ht_opts=" ";
if [ $build_target == 'node' ];then
	ht_opts="-Dlanguages=py2,pypy2,py3 -Dfsbrokers=hdfs ";
fi
config_dest;cmake `src_path` $ht_opts -DHT_O_LEVEL=6 -DTHRIFT_SOURCE_DIR=$SOURCES_PATH/thrift -DCMAKE_INSTALL_PREFIX=/opt/hypertable -DCMAKE_BUILD_TYPE=Release -DINSTALL_EXCLUDE_DEPENDENT_LIBS=ON;
do_make;do_make install;##  -DUSE_JEMALLOC=ON  -DPACKAGE_OS_SPECIFIC=1  -DVERSION_MISC_SUFFIX=$( date  +"%Y-%m-%d_%H-%M") # php,java,rb,tl,js,py3,pypy3,
cp `_install_prefix`/lib/libsigar-amd64-linux.so /opt/hypertable/0.9.8.17/lib/
#env CTEST_OUTPUT_ON_FAILURE=1 make alltests; #if [ $test_make == 1 ];then make alltests; fi;
		shift;;

'llvm')
tn='llvm-9.0.0.src'; url='http://releases.llvm.org/9.0.0/llvm-9.0.0.src.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DFFI_INCLUDE_DIR=`_install_prefix`/lib/libffi-3.2.1/include -DLLVM_ENABLE_FFI=ON -DLLVM_USE_INTEL_JITEVENTS=ON -DLLVM_LINK_LLVM_DYLIB=ON -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;

'clang')
tn='cfe-9.0.0.src'; url='http://releases.llvm.org/9.0.0/cfe-9.0.0.src.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;	
		shift;;

'lld')
tn='lld-9.0.0.src'; url='http://releases.llvm.org/9.0.0/lld-9.0.0.src.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;	
		shift;;
		
'cling')
tn='cling-0.6'; url='http://github.com/root-project/cling/archive/v0.6.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;	
		shift;;
 
'libconfuse')
tn='confuse-3.2.2'; url='http://github.com/martinh/libconfuse/releases/download/v3.2.2/confuse-3.2.2.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;

'apr')
tn='apr-1.7.0'; url='http://archive.apache.org/dist/apr/apr-1.7.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-threads --enable-posix-shm --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'apr-util')
tn='apr-util-1.6.1'; url='http://archive.apache.org/dist/apr/apr-util-1.6.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-crypto=`_install_prefix` --with-openssl=`_install_prefix` --with-apr=`_install_prefix` --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'libsigcpp')
tn='libsigc++-3.0.2'; url='http://download.gnome.org/sources/libsigc++/3.0/libsigc++-3.0.2.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;

'libsvg')
tn='libsvg-0.1.4'; url='http://cairographics.org/snapshots/libsvg-0.1.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install-strip;do_make install;do_make all; 
		shift;;
		
'pixman')
tn='pixman-0.38.4'; url='http://www.cairographics.org/releases/pixman-0.38.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-timers --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'cairo')
tn='cairo-1.16.0'; url='http://www.cairographics.org/releases/cairo-1.16.0.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-pdf=yes --enable-svg=yes --enable-tee=yes --enable-fc=yes --enable-ft=yes --enable-xml=yes --enable-pthread=yes --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'cairomm')
tn='cairomm-1.15.5'; url='http://www.cairographics.org/releases/cairomm-1.15.5.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS -std=c++1z" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'gobject-ispec')
tn='gobject-introspection-1.64.0'; url='http://ftp.acc.umu.se/pub/gnome/sources/gobject-introspection/1.64/gobject-introspection-1.64.0.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;	

'fribidi')
tn='fribidi-1.0.7'; url='http://github.com/fribidi/fribidi/releases/download/v1.0.7/fribidi-1.0.7.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;	

'pango')
tn='pango-1.42.4'; url='http://ftp.acc.umu.se/pub/GNOME/sources/pango/1.42/pango-1.42.4.tar.xz';
#tn='pango-1.44.7'; url='http://ftp.acc.umu.se/pub/GNOME/sources/pango/1.44/pango-1.44.7.tar.xz'; meson _build;
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;	

'rrdtool')
tn='rrdtool-1.7.2'; url='http://github.com/oetiker/rrdtool-1.x/releases/download/v1.7.2/rrdtool-1.7.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./configure --disable-python --disable-tcl --disable-perl --disable-ruby --disable-lua --disable-docs --disable-examples --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;	

'ruby')
tn='ruby-2.6.5'; url='http://cache.ruby-lang.org/pub/ruby/2.6/ruby-2.6.5.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
gem install sinatra rack thin json titleize syck;
		shift;;

'pkgconfig')
tn='pkg-config-0.29.2'; url='http://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
cp /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc `_install_prefix`/lib/$sn/;
cp /usr/lib/pkgconfig/*.pc `_install_prefix`/lib/$sn/;
		shift;;	

'gdb')
tn='gdb-9.1'; url='http://ftp.gnu.org/gnu/gdb/gdb-9.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-lto  --enable-vtable-verify --prefix=`_install_prefix` --build=`_build`; #--enable-objc-gc
do_make;do_make install;
		shift;;	

'kerberos')
tn='krb5-1.17'; url='http://web.mit.edu/kerberos/dist/krb5/1.17/krb5-1.17.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/src/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --disable-dns-for-realm --disable-athena --without-ldap --disable-asan --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;
		shift;;

'libonig')
tn='onig-6.9.4'; url='http://github.com/kkos/oniguruma/releases/download/v6.9.4/onig-6.9.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	

'php')
tn='php-7.4.3'; url='http://mirror.cogentco.com/pub/php/php-7.4.3.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure --enable-shared=yes --enable-static=yes --enable-mbstring --enable-json --with-curl --with-zip --with-zlib --with-openssl --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
php -r "copy('http://getcomposer.org/installer', 'composer-setup.php');" 
php composer-setup.php; mv composer.phar `_install_prefix`/bin/composer;
# composer global require laravel/installer;
#  /root/.config/composer/vendor/bin/laravel new libthither
		shift;;
 
'ganglia-web')
tn='ganglia-web-3.7.2'; url='http://sourceforge.net/projects/ganglia/files/ganglia-web/3.7.2/ganglia-web-3.7.2.tar.gz/download';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
echo "\$conf['rrdtool'] = \"rrdtool\";" >> conf_default.php;
if [ -d /usr/share/ganglia-webfrontend ]; then rm -rf /usr/share/ganglia-webfrontend; fi;
do_make install; #/usr/share/ganglia-webfrontend
		shift;;	

'ganglia')
tn='ganglia-3.7.2'; url='http://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/3.7.2/ganglia-3.7.2.tar.gz/download';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./configure --with-gmetad --enable-status --enable-shared=yes --enable-static=yes --enable-python --disable-perl --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;	

'libmnl')
tn='libmnl-1.0.4'; url='http://www.netfilter.org/projects/libmnl/files/libmnl-1.0.4.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'libnftnl')
tn='libnftnl-1.1.5'; url='http://netfilter.org/projects/libnftnl/files/libnftnl-1.1.5.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared=yes --enable-static=yes --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;	
		shift;;

'nftables')
tn='nftables-0.9.3'; url='http://netfilter.org/projects/nftables/files/nftables-0.9.3.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
rm_os_pkg ebtables iptables;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --disable-man-doc --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;	
		shift;;

'pth')
tn='pth-2.0.7'; url='http://ftp.gnu.org/gnu/pth/pth-2.0.7.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-m-guard --enable-hmac-binary-check --prefix=`_install_prefix` --build=`_build`; 
make;make install;
		shift;;	

'libgsasl')
tn='libgsasl-1.8.1'; url='http://ftp.gnu.org/gnu/gsasl/libgsasl-1.8.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --with-openssl=yes --without-libgcrypt --with-linux-crypto --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;
		shift;;	

'libhdfs3')
tn='attic-c-hdfs-client-2.2.31'; url='http://github.com/ccw/libhdfs3/archive/v2.2.31.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
mkdir $sn-tmp; cd $sn-tmp;
../bootstrap --prefix=`_install_prefix`;
do_make; do_make install;
		shift;;	

'glibc')
tn='glibc-2.31'; url='http://ftp.gnu.org/gnu/libc/glibc-2.31.tar.gz';
set_source 'tar'; 
if [ $only_dw == 1 ];then return;fi
wget 'http://ftp.gnu.org/gnu/libc/glibc-linuxthreads-2.5.tar.bz2';tar xf glibc-linuxthreads-2.5.tar.bz2;
config_dest;`src_path`/configure --disable-sanity-checks  --disable-nss-crypt \
		--disable-multi-arch --enable-kernel=4.0.0 --enable-shared --enable-static \
		--enable-lock-elision=yes --enable-stack-protector=all --enable-tunables --enable-mathvec \
		--enable-pt_chown --disable-build-nscd --disable-nscd --disable-obsolete-nsl \
		--with-fp --prefix=`_install_prefix`/`_build` --build=`_build`; # --enable-static-pie
do_make; do_make install;
		shift;;	

'util-linux')
tn='util-linux-2.35.1'; url='http://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.35/util-linux-2.35.1.tar.xz';
set_source 'tar'; 
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-shared --enable-static \
						--prefix=`_install_prefix`/`_build` --build=`_build`;
do_make; do_make install;
		shift;;	

'perl')
tn='perl-5.30.1'; url='http://www.cpan.org/src/5.0/perl-5.30.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./Configure -de -A ccflags="$ADD_O_FS" -Duse64bitall -Dusethreads -Dprefix=`_install_prefix`; 
do_make;do_make install;
if [ -f $CUST_INST_PREFIX/bin/perl ] && [ -f /usr/bin/perl ]; then
	rm_os_pkg perl;
fi
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e "install Class::Accessor";
if [ $stage > 1 ]; then
	PERL_MM_USE_DEFAULT=1 perl -MCPAN -e "install Bit::Vector";
fi
		shift;;	

'bash')
tn='bash-5.0'; url='http://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/ncurses/ncursesw/g' configure;
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`; 
do_make;do_make install;
		shift;;	

'lsof')
tn='lsof_4.91'; url='http://www.mirrorservice.org/sites/lsof.itap.purdue.edu/pub/tools/unix/lsof/lsof_4.91.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
tar -xf lsof_4.91_src.tar;cd lsof_4.91_src;
./Configure -n linux;
do_make;install -v -m0755 -o root -g root lsof `_install_prefix`/bin;
		shift;;	

'graphviz')
tn='graphviz-2.40.1'; url='http://graphviz.gitlab.io/pub/graphviz/stable/SOURCES/graphviz.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;	

'nspr')
tn='nspr-4.25'; url='http://archive.mozilla.org/pub/nspr/releases/v4.25/src/nspr-4.25.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/nspr/configure CFLAGS="-I/usr/include/x86_64-linux-gnu $ADD_O_FS" CPPFLAGS="$ADD_O_FS" --enable-strip  --enable-ipv6 --without-mozilla  --with-pthreads --enable-64bit --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;	

'nss')
tn='nss-3.51'; url='http://archive.mozilla.org/pub/security/nss/releases/NSS_3_51_RTM/src/nss-3.51.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cd nss; #./build.sh;
make NSPR_INCLUDE_DIR=`_install_prefix`/include/nspr BUILD_OPT=1 USE_64=1 NSS_USE_SYSTEM_SQLITE=1;
cd ../dist &&
install -v -m755 Linux*/lib/*.so              /usr/lib              &&
install -v -m644 Linux*/lib/{*.chk,libcrmf.a} /usr/lib              &&
install -v -m755 -d                           /usr/include/nss      &&
cp -v -RL {public,private}/nss/*              /usr/include/nss      &&
chmod -v 644                                  /usr/include/nss/*    &&
install -v -m755 Linux*/bin/{certutil,nss-config,pk12util} /usr/bin &&
install -v -m644 Linux*/lib/pkgconfig/nss.pc  /usr/lib/pkgconfig
		shift;;		

'yasm')
tn='yasm-1.3.0'; url='http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS" CPPFLAGS="$ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'libibverbs')
tn='libibverbs-1.1.4'; url='http://www.openfabrics.org/downloads/libibverbs/libibverbs-1.1.4-1.24.gb89d4d7.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
# ./autogen.sh
config_dest;`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --with-pic --enable-shared --enable-static --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;

'leveldb')
tn='leveldb-1.22'; url='http://github.com/google/leveldb/archive/1.22.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;

'oath-toolkit')
tn='oath-toolkit-2.6.2'; url='http://download.savannah.gnu.org/releases/oath-toolkit/oath-toolkit-2.6.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
`src_path`/configure CFLAGS="$ADD_O_FS -fPIC" CPPFLAGS="$ADD_O_FS -fPIC" --with-pic --enable-shared --enable-static --prefix=`_install_prefix` --build=`_build`;
make;make install-strip;
		shift;;

'rocksdb')
tn='rocksdb-6.6.4'; url='http://github.com/facebook/rocksdb/archive/v6.6.4.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DWITH_TESTS=OFF -DWITH_ZSTD=ON -DWITH_ZLIB=ON -DWITH_LZ4=ON -DWITH_SNAPPY=ON -DWITH_BZ2=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make; PORTABLE=1 do_make static_lib;do_make shared_lib;do_make install;
		shift;;	

'libaio')
tn='libaio-0.3.112'; url='http://ftp.de.debian.org/debian/pool/main/liba/libaio/libaio_0.3.112.orig.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
make prefix=`_install_prefix` install;
		shift;;		

'ceph')
tn='ceph-14.2.8'; url='http://download.ceph.com/tarballs/ceph_14.2.8.orig.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi #  -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="-std=c++17 $ADD_O_FS -fPIC -DPIC"
sed -i 's/ncurses/ncursesw/g' src/tools/rbd/CMakeLists.txt;
config_dest;cmake `src_path` \
-DWITH_LIBCEPHFS=ON -DENABLE_SHARED=ON \
-DWITH_RADOSGW=OFF -DWITH_KVS=OFF -DWITH_RADOSGW_AMQP_ENDPOINT=OFF \
-DWITH_RDMA=OFF -DWITH_GRAFANA=OFF \
-DWITH_MGR=OFF -DWITH_MGR_DASHBOARD_FRONTEND=OFF -DWITH_GRAFANA=OFF \
-DWITH_TESTS=OFF -DWITH_MANPAGE=OFF \
-DWITH_BLUEFS=OFF -DWITH_FUSE=OFF -DWITH_OPENLDAP=OFF \
-DWITH_XFS=OFF -DWITH_BLUESTORE=ON -DWITH_SPDK=OFF -DWITH_LTTNG=OFF -DWITH_BABELTRACE=OFF \
-DALLOCATOR=tcmalloc_minimal -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix` \
-DCURSES_NEED_WIDE=ON -DCURSES_INCLUDE_PATH=`_install_prefix`/include;
make VERBOSE=1 cephfs;do_make cephfs install;
		shift;;

'spdylay')
tn='spdylay-1.4.0'; url='http://github.com/tatsuhiro-t/spdylay/archive/v1.4.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
autoreconf -i;automake;autoconf;
./configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
cd python;cython spdylay.pyx;
pypy setup.py install;rm -r build;pypy3 setup.py install;rm -r build;
python setup.py install;rm -r build;python3 setup.py install;
		shift;;	
	
'go')
tn='go'; url='http://dl.google.com/go/go1.13.4.src.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cd src;./all.bash -v
		shift;;	

'libquic')
tn='libquic-0.0.3-6e3a05d'; url='http://github.com/devsisters/libquic/archive/v0.0.3-6e3a05d.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path`  -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="-std=c++17 $ADD_O_FS -fPIC -DPIC" -DGO_EXECUTABLE=NONE -DWITH_TESTS=OFF -DENABLE_SHARED=ONE=ON -DALLOCATOR=tcmalloc_minimal -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	
 
'elfutils')
tn='elfutils-0.178'; url='http://sourceware.org/elfutils/ftp/0.178/elfutils-0.178.tar.bz2';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./configure  --with-pic --enable-shared --enable-static --with-zlib --with-lzma --with-bzlib --prefix=`_install_prefix` --build=`_build`;
do_make;do_make install;
		shift;;	

'glog')
tn='glog-0.4.0'; url='http://github.com/google/glog/archive/v0.4.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	
	
'gflags')
tn='gflags-2.2.2'; url='http://github.com/gflags/gflags/archive/v2.2.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	
		
'double-conversion')
tn='double-conversion-3.1.5'; url='http://github.com/google/double-conversion/archive/v3.1.5.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path` -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;

		shift;;	

'folly')
tn='folly-2020.03.09.00'; url='http://github.com/facebook/folly/archive/v2020.03.09.00.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path` -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	

'fizz')
tn='fizz-2020.03.09.00'; url='http://github.com/facebookincubator/fizz/archive/v2020.03.09.00.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path`/fizz -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
config_dest;cmake `src_path`/fizz -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;
		shift;;	

'wangle')
tn='wangle-2020.03.09.00'; url='http://github.com/facebook/wangle/archive/v2020.03.09.00.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path`/wangle -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;#  -DBUILD_SHARED_LIBS=ON
config_dest;cmake `src_path`/wangle -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;#  -DBUILD_SHARED_LIBS=ON
		shift;;	

'lapack')
tn='lapack-3.9.0'; url='http://github.com/Reference-LAPACK/lapack/archive/v3.9.0.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path`  -DCMAKE_C_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_CXX_FLAGS="$ADD_O_FS -fPIC -DPIC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=`_install_prefix`;
do_make;do_make install;#  -DBUILD_SHARED_LIBS=ON
		shift;;	

'ncurses')
tn='ncurses-6.2'; url='http://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;
ncurses_args="CPPFLAGS=-P --with-shared --with-termlib --enable-rpath --disable-overwrite --enable-termcap --enable-getcap --enable-ext-colors --enable-ext-mouse --enable-sp-funcs --enable-pc-file --enable-const --enable-sigwinch --enable-hashmap -disable-widec";
if [ $stage -eq 0 ]; then
	`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --without-libtool --without-gpm --without-hashed-db $ncurses_args --prefix=`_install_prefix` --build=`_build`;
else	
	`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --with-libtool --without-hashed-db --with-gpm $ncurses_args --prefix=`_install_prefix` --build=`_build`;
fi
make;make install;
		shift;;	

'ncursesw')
tn='ncurses-6.2'; url='http://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;
ncurses_args="--enable-termcap --with-shared --enable-rpath --enable-overwrite --enable-getcap --enable-ext-colors --enable-ext-mouse --enable-sp-funcs --enable-pc-file --enable-const --enable-sigwinch --enable-hashmap --enable-widec ";
if [ $stage -eq 0 ]; then
	`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --without-libtool --without-gpm --without-hashed-db $ncurses_args --prefix=`_install_prefix` --build=`_build`;
else	
	`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --with-cxx-shared --with-libtool --without-hashed-db --with-gpm $ncurses_args --prefix=`_install_prefix` --build=`_build`;
fi  # --with-termlib
make;make install;
		shift;;

'ncursestw')
tn='ncurses-6.2'; url='http://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;
ncurses_args="CPPFLAGS=-P --with-shared --with-termlib --enable-overwrite --enable-pthreads-eintr --enable-reentrant --enable-termcap --enable-getcap --enable-ext-colors --enable-ext-mouse --enable-sp-funcs --enable-pc-file --enable-const --enable-sigwinch --enable-widec --with-pthread";
if [ $stage -eq 0 ]; then	
	`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --without-libtool --without-gpm --without-hashed-db $ncurses_args --prefix=`_install_prefix` --build=`_build`;
else	
	`src_path`/configure CFLAGS="-P $ADD_O_FS" CPPFLAGS="-P $ADD_O_FS" --with-libtool --with-hashed-db --with-gpm $ncurses_args --prefix=`_install_prefix` --build=`_build`;
fi # --enable-weak-symbols --disable-overwrite
make;make install;
echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/$sn.sh
echo "export CPATH=\$CPATH:\$CUST_INST_PREFIX/include/$sn" >> $ENV_SETTINGS_PATH/$sn.sh
		shift;;	

'pstack')
tn='pstack'; url='http://code.lm7.fr/robotux/pstack/archive/pstack-1.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
do_make; do_make install BINDIR=`_install_prefix`/bin  MANDIR=`_install_prefix`/share/man;
		shift;;	

'doxygen')
tn='doxygen-1.8.17'; url='http://doxygen.nl/files/doxygen-1.8.17.src.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
config_dest;cmake `src_path` -G "Unix Makefiles" -Dbuild_doc=OFF -Denglish_only=ON -DCMAKE_INSTALL_PREFIX=`_install_prefix`; # -DCMAKE_CXX_FLAGS="-liconv"
make; make install;
		shift;;	

'libpam')
tn='Linux-PAM-1.3.1'; url='http://github.com/linux-pam/linux-pam/releases/download/v1.3.1/Linux-PAM-1.3.1.tar.xz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
cp -r libpam/include/security /`_install_prefix`/include/;cp -r libpam_misc/include/security /`_install_prefix`/include/;cp -r libpamc/include/security /`_install_prefix`/include/;
#./autogen.sh;./configure --prefix=`_install_prefix`/;#do_make; do_make install;
		shift;;

'libpcap')
tn='libpcap-libpcap-1.9.1'; url='http://github.com/the-tcpdump-group/libpcap/archive/libpcap-1.9.1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
autoreconf -vif;
`src_path`/configure CXXFLAGS="$ADD_O_FS" CFLAGS="$ADD_O_FS" --enable-shared=yes --prefix=`_install_prefix`; 
make; make install;
		shift;;	

'tcptrack')
tn='tcptrack-1.4.3'; url='http://github.com/bchretien/tcptrack/archive/v1.4.3.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
sed -i 's/-lncurses/-lncursesw/g' configure;
`src_path`/configure CXXFLAGS="$ADD_O_FS" CFLAGS="$ADD_O_FS" --prefix=`_install_prefix`; 
make; make install;
		shift;;	

'asio')
tn='asio-asio-1-16-1/asio'; url='http://github.com/chriskohlhoff/asio/archive/asio-1-16-1.tar.gz';
set_source 'tar';
if [ $only_dw == 1 ];then return;fi
./autogen.sh;./configure;do_make install prefix=`_install_prefix`;
		shift;;	

### http://github.com/intel/tbb/archive/2020_U1.tar.gz

    *)         echo "Unknown build: $sn";       shift;;
  esac
  
}
#########

#########
do_install() {
  for sn in "$@"; do
	if [ $verbose == 1 ]; then
		sleep 1
		do_build;
	else
		do_build &>> $BUILDS_LOG_PATH/$stage-$sn'.log';
	fi
  done
}
#########

#########
compile_and_install(){

	if [ $only_dw == 1 ] || [ $stage -eq 0 ] || [ $stage -eq 1 ]; then
		if [ $os_r == 'arch' ]; then
			do_install glibc util-linux;
		fi
		do_install make cmake;
		do_install m4 gmp mpfr mpc isl;
		do_install autoconf autoconf-archive automake libtool gawk;
		do_install ncursesw libreadline libeditline libeditline2;
		do_install libatomic_ops libunwind libtasn1;
		do_install zlib bzip2 tar gzip lzo snappy unrar libzip unzip xz p7zip lz4 brotli zstd; # qazip
		do_install icu4c bison texinfo;
		if [ $only_dw == 1 ]; then	
			do_install flex flex_fallback;
		elif [ $stage -eq 0 ]; then	
			do_install flex_fallback;
		else
			do_install flex_fallback; #flex;
		fi
		
		do_install binutils; 
		do_install gettext libexpat libunistring libidn2; # libiconv libconfuse
		
		do_install libffi tcl pcre pcre2;  # nettle p11-kit gnutls tk openmpi
		do_install expect attr patch;
		
		do_install gc gperf gperftools; # libhoard jemalloc

		if [ $only_dw == 1 ]; then	
			do_install glib glib_fallback;
		elif [ $stage -eq 0 ]; then	
			do_install glib_fallback;
		else
			do_install glib; 
		fi
		
		do_install pkgconfig gcc; 
		
		##  byacc libgpg-error libgcrypt kerberos
		do_install openssl;
		do_install libssh; 
		 
		do_install asio libaio coreutils libcares;
		do_install gdb bash lsof curl wget;
		do_install sqlite berkeley-db gdbm;
		do_install python perl python3;
		# 
	fi
	if [ $only_dw == 1 ] || [ $stage -eq 2 ]; then
		# pstack pth fuse2 fuse3
		do_install libmnl libnftnl nftables;
		if [ $build_target == 'all-tmp' ];then
			do_install llvm clang lld;
		fi
		#  apr apr-util log4cpp 
		do_install libpam libpcap tcptrack elfutils; 
		#do_install libsodium unbound;
		
		do_install re2 libjansson libxml2 libxslt; # sparsehash 
		do_install libpng libjpeg libsvg libwebp; 
		do_install openjdk apache-ant apache-maven libsigar;
		do_install apache-zookeeper apache-hadoop;  # libhdfs3
		do_install fonts itstool freetype harfbuzz fontconfig; 
		do_install pixman cairo cairomm fribidi pango; # gobject-ispec libsigcpp
		do_install imagemagick; # librsvg
		
		#do_install libeditline2 libgsasl libhdfspp 
		
		do_install protobuf;
		do_install doxygen;
		
		if [ $only_dw == 1 ] || [ $build_target == 'all' ];then
			do_install double-conversion gflags glog gmock; 
			
			do_install perl libonig php;
			do_install libuv nodejs; # pypy2stm 
			# ganglia-web # ganglia 
			do_install leveldb;
			do_install keyutils nspr nss;
			#  yasm libibverbs oath-toolkit rocksdb 
			do_install ceph;
			
			do_install go;
			do_install libquic; 
		fi
	fi
	
	if [ $only_dw == 1 ] || [ $stage -eq 3 ]; then
		do_install pybind11;
		do_install python pypy2 python3 pypy3 spdylay;
		do_install boost libevent thrift;
		do_install ruby graphviz rrdtool;
		do_install cronolog hypertable;
	fi
	# do_install folly fizz wangle;
} 
#########

#########
rm_os_pkg(){
	if [ $os_r == 'ubuntu' ]; then
		pkg=''
		case $1 in
			'python')
				pkg="python2.7";
				shift;;	
			'python3')
				pkg="python3*";
				shift;;	
			'openssl')
				pkg="openssl ca-certificates*";
				shift;;	
			*)  
				pkg=$1
				shift;;
		esac
		apt-get autoremove -yq --purge $pkg;
	elif [ $os_r == 'arch' ]; then
		pkg=''
		case $1 in
			'python')
				pkg="python2.7";
				shift;;	
			'python3')
				pkg="python3*";
				shift;;	
			'openssl')
				pkg="openssl ca-certificates*";
				shift;;	
			*)  
				pkg=$1
				shift;;
		esac
		pacman -R $pkg;
	elif [ $os_r == 'openSUSE' ]; then
		echo 'possible? zypper rm -y python2';
	fi
}
os_releases(){
	if [ $verbose == 1 ]; then
		sleep 5
		_os_releases ${@:1};
		sleep 5
	else
		_os_releases ${@:1} &>> $BUILDS_LOG_PATH/os_releases_$1'.log';
	fi
}

_os_releases(){
	if [ $1 == 'install' ]; then
		echo 'os_releases-install: '$os_r
		
		if [ ! -f $CUST_INST_PREFIX/bin/gcc ] && [ ! -f /usr/bin/gcc ]; then
			if [ $os_r == 'ubuntu' ];then
				front_state=$DEBIAN_FRONTEND;export DEBIAN_FRONTEND=noninteractive;		
				apt-get install -yq --reinstall libblkid-dev libmount-dev uuid-dev libudev-dev ;
				echo '' > /var/log/dpkg.log;
				apt-get install -yq --reinstall make pkg-config build-essential gcc 
				export DEBIAN_FRONTEND=$front_state;
				
			elif [ $os_r == 'arch' ];then
				pacman -S --noconfirm libutil-linux
				echo '' > /var/log/pacman.log;
				pacman -S --noconfirm make pkg-config gcc
				
			elif [ $os_r == 'openSUSE' ]; then
				zypper rm -y tar make gcc cpp g++ c++;
				zypper install -y libblkid-devel libmount-devel libuuid-devel
				zypper install -y tar pkg-config make gcc cpp gcc-c++; #zypper info -t pattern devel_basis
				rm -f /usr/share/site/x86_64-unknown-linux-gnu; 
			fi
		fi
		echo 'fin:os_releases-install: '$os_r
		
	elif [ $1 == 'uninstall' ]; then
		echo 'os_releases-uninstall: '$os_r
		
		if [ -f $CUST_INST_PREFIX/bin/make ] && [ -f $CUST_INST_PREFIX/bin/gcc ]; then
			if [ $os_r == 'ubuntu' ]; then
				front_state=$DEBIAN_FRONTEND;export DEBIAN_FRONTEND=noninteractive;
				echo 'pkgs to remove';
				apt-get autoremove -yq --purge $(zgrep -h ' install ' /var/log/dpkg.log* | sort | awk '{print $4}');
				export DEBIAN_FRONTEND=$front_state;
				
			elif [ $os_r == 'arch' ];then
				pacman -R --noconfirm $(cat  /var/log/pacman.log | grep " installed "  | sort | awk '{print $5}');
				echo include $LD_CONF_PATH/*.conf > "/etc/ld.so.conf.d/usr.conf"
				
			elif [ $os_r == 'openSUSE' ]; then
				zypper rm -y xz xz-lang tar tar-lang openssl ca-certificates python python-base make gcc cpp gcc-c++ binutils cpp48 gcc48 gcc48-c++ gcc-c++ libasan0 libatomic1 libcloog-isl4 libgomp1 libisl10 libitm1 libmpc3 libmpfr4 libstdc++48-devel libtsan0 site-config;
				# linux-glibc-devel glibc-devel pkg-config 
			fi;
	    else
			exit 1; 
		fi;
		echo 'fin:os_releases-uninstall: '$os_r
	fi
}
#########

#########
env_setup(){
	if [ $verbose == 1 ]; then
		sleep 5
		_env_setup ${@:1};
		sleep 5
	else
		_env_setup ${@:1} &>> $BUILDS_LOG_PATH/env_setup_$1'.log';
	fi
}
_env_setup(){
	echo env_setup-$1
	
	if [ $1 == 'pre' ]; then
		if [ ! -d $CUST_INST_PREFIX/lib64 ]; then
			mkdir -p $CUST_INST_PREFIX/lib;ln -s  $CUST_INST_PREFIX/lib $CUST_INST_PREFIX/lib64;
		fi
		if [[ $os_r == 'openSUSE' ]];then
			if [[ $(cat /etc/profile) != *"#EDITTED ETC/PROFILE"* ]]; then
				echo 'if [ -d /etc/profile.d ]; then for i in /etc/profile.d/*.sh; do if [ -r $i ]; then . $i;fi;done;unset i;fi; #EDITTED ETC/PROFILE'  >> "/etc/profile";
			fi
		fi

		if [[ $os_r == 'arch' ]];then
			echo "#!/usr/bin/env bash" > $ENV_SETTINGS_PATH/os.sh
			echo "export CPATH=\$CPATH:\/usr/include" >> $ENV_SETTINGS_PATH/os.sh
		fi
		
		echo include $LD_CONF_PATH/*.conf > "/etc/ld.so.conf.d/usr.conf"
		echo "$CUST_INST_PREFIX/lib" >> "/etc/ld.so.conf.d/usr.conf"

		echo '''source /etc/environment; CPATH=''; if [ -d '''$ENV_SETTINGS_PATH''' ]; then  for i in '''$ENV_SETTINGS_PATH'''*.sh; do    if [ -r $i ]; then       source $i;     fi;   done; unset i; fi; ''' > /etc/profile.d/custom_env.sh;
		chmod -R 777 /etc/profile.d/custom_env.sh
		


	elif [ $1 == 'post' ]; then
		if [ -d $ENV_SETTINGS_PATH ]; then
			chmod -R 777 $ENV_SETTINGS_PATH
			sn=${only_sources[@]}
			finalize_build;
		fi
	fi
	
	echo fin:env_setup-$1
}
#########

#########
_run_setup(){
	if [ $stage == 0 ]; then
		env_setup pre
		reuse_make=0
		os_releases install;
		compile_and_install;
		os_releases uninstall;
		stage=1
	fi
	if [ $stage == 1 ]; then
		ADD_O_FS=$ADD_O_FS_from_stage_1
		compile_and_install;
		stage=2
	fi
	if [ $stage == 2 ]; then
		reuse_make=0;
		ADD_O_FS=$ADD_O_FS_from_stage_2
		compile_and_install
		stage=3
	fi
	if [ $stage == 3 ]; then
		reuse_make=0
		compile_and_install
		env_setup post
	fi
}
#########

#########
if [  ${#only_sources[@]} -gt 0  ]; then 
	source /etc/profile
	source ~/.bashrc
	
	ADD_O_FS=$ADD_O_FS_from_stage_2
	do_install ${only_sources[@]}
	exit 1
fi
#########

if [ $only_dw == 1 ];then 
	compile_and_install;
else
	_run_setup
fi




exit 1





# DRAFTS #######################################################################
 

TMP_NAME=openssh
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://ftp.halifax.rwth-aachen.de/openbsd/OpenSSH/portable/openssh-7.5p1.tar.gz'
tar xf openssh-7.5p1.tar.gz
mv openssh-7.5p1 $TMP_NAME;cd $TMP_NAME
./configure --with-ssh1 --with-kerberos5 --with-pam --with-ssl-engine --with-pie --prefix=/usr/local; 
make; make install;


TMP_NAME=proxygen; 
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://github.com/facebook/proxygen/archive/v2019.02.11.00.tar.gz'
tar xf v2019.02.11.00.tar.gz
mv proxygen-2019.02.11.00 $TMP_NAME; cd $TMP_NAME/proxygen;
autoreconf -vif
./configure CXXFLAGS="-std=c++17 $ADD_O_FS -m64 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURC" CFLAGS="$ADD_O_FS -m64 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE"  --enable-shared=yes --enable-static=yes --prefix=/usr/local; 
# make; make install;


TMP_NAME=greeny; 
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
rm master.zip;
wget 'http://github.com/nifigase/greeny/archive/master.zip'
/usr/local/bin/unzip master.zip
mv greeny-master $TMP_NAME; cd $TMP_NAME;


TMP_NAME=poco
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://pocoproject.org/releases/poco-1.7.8/poco-1.7.8p2.tar.gz'
tar xf poco-1.7.8p2.tar.gz
mv  poco-1.7.8p2 $TMP_NAME;cd $TMP_NAME
./configure --shared --unbundled --everything --config=Linux --prefix=/usr/local; 
make; make install;


TMP_NAME=libev
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://dist.schmorp.de/libev/libev-4.25.tar.gz'
tar xf libev-4.25.tar.gz
mv libev-4.25 $TMP_NAME;cd $TMP_NAME
./configure --prefix=/usr/local/libev; 
make; make install;


TMP_NAME=nghttp2
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://github.com/nghttp2/nghttp2/releases/download/v1.37.0/nghttp2-1.37.0.tar.xz'
tar xf nghttp2-1.37.0.tar.xz
mv nghttp2-1.37.0 $TMP_NAME;
cd $TMP_NAME

cmake ./ -DLIBEVENT_INCLUDE_DIR=/usr/local/include -DLIBEV_LIBRARY=/usr/local/libev/lib/libev.so -DLIBEV_INCLUDE_DIR=/usr/local/libev/include
#./configure --without-spdylay --without-systemd  --prefix=/usr/local; 
make; 
make install;



echo llvm_mono
cd ~/dependeciesBuilds; rm -r llvm_mono;
wget 'http://github.com/mono/llvm/archive/RELEASE_27.tar.gz'
tar xvf RELEASE_27.tar.gz
mv llvm-RELEASE_27 llvm_mono;cd llvm_mono
./configure  --enable-targets="x86_64"  --prefix=/usr/local ; --enable-jit --enable-threads  --enable-libffi --enable-optimized --enable-bindings --enable-ltdl-install ;
make; make check; make install
cd ~; /sbin/ldconfig

echo mono
cd ~/dependeciesBuilds; rm -r mono;
wget 'http://download.mono-project.com/sources/mono/mono-5.0.0.94.tar.bz2'
tar xf mono-5.0.0.94.tar.bz2
mv mono-5.0.0 mono; cd mono
./configure --enable-parallel-mark --enable-big-arrays --enable-llvm --enable-loadedllvm  --enable-llvm-runtime --enable-vtune --enable-icall-symbol-map --enable-dynamic-btls --enable-icall-export --with-tls=pthread --with-bitcode=yes --prefix=/usr/local; 
make; make check; make install
cd ~; /sbin/ldconfig






TMP_NAME=gf-complete
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://lab.jerasure.org/jerasure/gf-complete/repository/archive.tar.gz'  -O gf-complete.tar.gz
tar xf gf-complete.tar.gz
mv gf-complete.git $TMP_NAME;cd $TMP_NAME
./autogen.sh; ./configure --enable-avx --prefix=/usr/local; 
make; make install;

TMP_NAME=jerasure
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://www.kaymgee.com/Kevin_Greenan/Software_files/jerasure.tar.gz'
tar xf jerasure.tar.gz
mv jerasure $TMP_NAME;cd $TMP_NAME
./configure --prefix=/usr/local; 
make; make install;

TMP_NAME=qfs
echo $TMP_NAME
mkdir ~/tmpBuilds
cd ~/tmpBuilds; rm -r $TMP_NAME;
wget 'http://github.com/quantcast/qfs/archive/1.2.1.tar.gz'
tar xzf 1.2.1.tar.gz
mv qfs-1.2.1 $TMP_NAME;
mkdir $TMP_NAME-build;cd $TMP_NAME-build;
cmake -DFUSE_INCLUDE_DIRS=/usr/local/include/fuse3 -DFUSE_LIBRARIES=/usr/local/lib/libfuse3.so -DOPENSSL_ROOT_DIR=/usr/local/ssl -DQFS_USE_STATIC_LIB_LINKAGE=OFF -DCMAKE_BUILD_TYPE=Release ../$TMP_NAME
make; make check; make install
cd ~; /sbin/ldconfig




#echo kosmosfs
#cd ~
#wget 'http://sourceforge.net/projects/kosmosfs/files/kosmosfs/kfs-0.5/kfs-0.5.tar.gz/download' --output-document=kfs-0.5.tar.gz
#tar xzvf kfs-0.5.tar.gz
#cd kfs-0.5
#mkdir build
#cd build
#cmake -D CMAKE_BUILD_TYPE=RelWithDebInfo ~/kfs-0.5/
#make
#make install
#cd ~; /sbin/ldconfig
