#!/usr/bin/env bash
tn='gcc-9.2.0'; url='http://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz'; 
set_source 'tar';
if [ $only_dw == 1 ];then return;fi

intermediate='';
target=--target=`_build`;
add_languages=""; #",objc,obj-c++,fortran,go";  #  --enable-objc-gc
if [ $stage -eq 0 ]; then 
	target="";
	add_languages="";
	intermediate='--disable-checking'; 
fi;

ln -s /usr/include/asm-generic /usr/include/asm;
config_dest;`src_path`/configure $intermediate --with-pic --enable-targets=x86-64-linux --disable-multilib \
		--enable-gold=yes --enable-languages=c,c++,lto,$add_languages --enable-static \
		--enable-shared=libgcc,libffi,boehm-gc,libstdc++ \
		--enable-libssp --enable-libasan --enable-libtsan \
		--enable-libgomp --enable-initfini-array --enable-vtable-verify \
		--enable-lto --enable-tls --enable-threads=posix --with-long-double-128 --enable-decimal-float=yes \
		--with-mpfr=$CUST_INST_PREFIX --with-mpc=$CUST_INST_PREFIX --with-isl=$CUST_INST_PREFIX --with-gmp=$CUST_INST_PREFIX \
		--prefix=$CUST_INST_PREFIX --build=`_build` $target;
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=58638  --enable-default-pie 

do_make;do_make install;do_make all;

if [ $CUST_INST_PREFIX != '/usr' ]; then
	if [ -f $CUST_INST_PREFIX/bin/gcc ]; then		
		if [ -f /usr/bin/gcc ]; then rm /usr/bin/gcc;rm /usr/bin/cc;fi
		ln -s $CUST_INST_PREFIX/bin/gcc $CUST_INST_PREFIX/bin/cc
	fi
	#if [ -f $CUST_INST_PREFIX/bin/cpp ] && [ -f /usr/bin/cpp ]; then rm /usr/bin/cpp;fi
	#if [ -f $CUST_INST_PREFIX/bin/c++ ] && [ -f /usr/bin/c++ ]; then rm /usr/bin/c++;fi
	#if [ -f $CUST_INST_PREFIX/bin/g++ ] && [ -f /usr/bin/g++ ]; then rm /usr/bin/g++;fi
	if [ -f $CUST_INST_PREFIX/bin/ar ] && [ -f /usr/bin/ar ]; then mv /usr/bin/ar /usr/bin/ar_os;fi
	if [ -f $CUST_INST_PREFIX/bin/ranlib ] && [ -f /usr/bin/ranlib ]; then mv /usr/bin/ranlib /usr/bin/ranlib_os;fi
	if [ -f $CUST_INST_PREFIX/bin/ld ] && [ ! -f $CUST_INST_PREFIX/bin/real-ld ]; then 
		rm -f /usr/bin/ld;
		ln -s $CUST_INST_PREFIX/bin/ld $CUST_INST_PREFIX/bin/real-ld;
		ln -s $CUST_INST_PREFIX/bin/ld.gold $CUST_INST_PREFIX/bin/real-ld.gold;
		ln -s $CUST_INST_PREFIX/bin/ld.bfd $CUST_INST_PREFIX/bin/real-ld.bfd;
		ln -s $CUST_INST_PREFIX/bin/ld $CUST_INST_PREFIX/bin/x86_64-linux-gnu-ld;
		ln -s $CUST_INST_PREFIX/bin/ld.gold $CUST_INST_PREFIX/bin/x86_64-linux-gnu-ld.gold;
		ln -s $CUST_INST_PREFIX/bin/ld.bfd $CUST_INST_PREFIX/bin/x86_64-linux-gnu-ld.bfd;
	fi

fi;

# --with-cloog=$CUST_INST_PREFIX --disable-cloog-version-check --enable-fixed-point  --enable-stage1-checking=all  --enable-stage1-languages=all #http://gcc.gnu.org/install/configure.html

#sed -i 's/if __cplusplus >= 201103L \&\& defined(__STRICT_ANSI__)/if __cplusplus >= 211103L \&\& defined(__STRICT_ANSI__)/g' $CUST_INST_PREFIX/include/c++/8.1.0/bits/stl_map.h;
#sed -i 's/ifdef __STRICT_ANSI__/if __cplusplus >= 211103L \&\& defined(__STRICT_ANSI__)/g' $CUST_INST_PREFIX/include/c++/8.1.0/bits/stl_set.h;


