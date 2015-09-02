#!/bin/bash
#
# This is a script to create a toolchain on x86 for Raspberry Pi compilation:
#
#     Step 1. Compile crosstool-ng
#     Step 2. Use crosstool-ng to compile the toolchain
#     Step 3. Obtain Raspberry Pi VideoCore code
#
# Note: the ct-ng.config.wheezy file will compile a GCC 4.7.2 toolchain
#
export CROSSDIR="$HOME/x-tools/arm-unknown-linux-gnueabi"
export BUILDDIR="$HOME/builddir"

#
# Step 1. Compile crosstool-ng
#
mkdir -p $BUILDDIR
cd $BUILDDIR
wget -c www.crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.21.0.tar.bz2
tar xfvj crosstool-ng-1.21.0.tar.bz2
cd crosstool-ng-1.21.0
./configure --prefix=$BUILDDIR/crosstool-ng
make 
make install
cd ..

#
# Step 2. Use crosstool-ng to compile the toolchain
#
mkdir -p $BUILDDIR/build-crosstool
cd $BUILDDIR/build-crosstool
cp $HOME/ct-ng.config.wheezy .config
$BUILDDIR/crosstool-ng/bin/ct-ng build
cd ..


#
# Step 3. Obtain Raspberry Pi VideoCore code
#
cd $BUILDDIR
git init firmware
cd firmware
git remote add -f origin https://github.com/raspberrypi/firmware.git
git config core.sparseCheckout true
echo "opt/vc/" >> .git/info/sparse-checkout
git pull origin master
cd ..
