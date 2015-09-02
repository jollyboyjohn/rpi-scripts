#!/bin/bash
#
# This is an example of how to crosscompile something. 
#     Step 1. Build SDL (with VideoCore dispmanx optimisations)
#     Step 2. Build OpenTyrian (with optimised SDL)
#
export CROSSDIR="$HOME/x-tools/arm-unknown-linux-gnueabi"
export BUILDDIR="$HOME/builddir"
export VCOREDIR="$HOME/builddir/firmware/opt/vc"

#
# Step 1. Build SDL (with VideoCore dispmanx optimisations)
#
cd $BUILDDIR
git clone https://github.com/vanfanel/SDL-1.2.15-raspberrypi.git
cd SDL-1.2.15-raspberrypi

CC="$CROSSDIR/bin/arm-unknown-linux-gnueabi-gcc" \
    CXX="$CROSSDIR/bin/arm-unknown-linux-gnueabi-g++" \
    CFLAGS="-O3 -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard \
	-I$VCOREDIR/include \
	-I$VCOREDIR/include/interface/vcos/pthreads \
	-I$VCOREDIR/include/interface/vmcs_host/linux" \
    LDFLAGS="-L$VCOREDIR/lib" \
    ./configure \
	--prefix=$BUILDDIR/SDL-1.2.15 \
	--host=arm-unknown-linux-gnueabi \
	--enable-video-dispmanx \
	--disable-video-opengl \
	--disable-video-directfb \
	--disable-cdrom \
	--disable-oss \
	--disable-alsatest \
	--disable-pulseaudio \
	--disable-pulseaudio-shared \
	--disable-arts \
	--disable-nas \
	--disable-esd \
	--disable-nas-shared \
	--disable-diskaudio \
	--disable-dummyaudio \
	--disable-mintaudio \
	--disable-video-x11 \
	--disable-input-tslib
make
make install
cd ..

#
# Step 2. Build OpenTyrian (with optimised SDL)
#
cd $BUILDDIR
wget -c http://www.camanis.net/opentyrian/releases/opentyrian-2.1.20130907-src.tar.gz
tar xfvz opentyrian-2.1.20130907-src.tar.gz
cd opentyrian-2.1.20130907
patch -p1 < ../../opentyrian-dispmanx-noscaling.patch
sed "s#sdl-config#$BUILDDIR/SDL-1.2.15/bin/sdl-config#g" -i Makefile
sed "s#strip#$CROSSDIR/bin/arm-unknown-linux-gnueabi-strip#g" -i Makefile
CC="$CROSSDIR/bin/arm-unknown-linux-gnueabi-gcc" \
    LDFLAGS="-L$VCOREDIR/lib -lbcm_host -lvchiq_arm -lvcos" \
    make release
cd ..

#
# Step 3. Install OpenTyrian
#
mkdir -p opentyrian/data
cp opentyrian-2.1.20130907/opentyrian opentyrian/
wget -c http://www.camanis.net/tyrian/tyrian21.zip
unzip -j tyrian21.zip -d opentyrian/data
