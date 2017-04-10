#!/bin/bash

# SETTING: modify this to the real directory
SRC_DIR="/Users/simonkuang/workspace/ffmpeg-3.2.4"
NDK=$HOME/Library/Android/sdk/ndk-bundle
NDK_PLATFORM="darwin-x86_64"
#ABIS="armeabi armeabi-v7a arm64-v8a mips mips64 x86 x86_64"
ABIS="armeabi armeabi-v7a mips x86"


CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0});pwd)
BUILD_DIR=${CURRENT_DIR}/build
SELF_DIR=$(basename $CURRENT_DIR)  # for avoid delte itself
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_ORANGE="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_NC="\033[0m"

# Build
function Build_() {
  # clear the vars defined by previous building(s)
  . $CURRENT_DIR/setting_clear.sh

  # import the target host settings
  SETTING_FILE=$CURRENT_DIR/setting_$1.sh
  if [[ -f $SETTING_FILE ]];then
    echo -e "${COLOR_BLUE}Start building $1...${COLOR_NC}"
    . $SETTING_FILE

    if [[ "$ARCH" == "" ]]; then  # empty arch setting.
                                  # may the arch not supported yes
      echo -e "${COLOR_ORANGE}[WARN] not supported the arch $1.{$COLOR_NC}"
    fi
  else
    echo -e "${COLOR_RED}[ERROR] build $1 failed${COLOR_NC}"
    return -1
  fi

  # clear the build dir
  #find $CURRENT_DIR -maxdepth 1 | grep -v "\/${SELF_DIR}$" | grep -v "\.git" | grep -v "build$" | grep -v "android$" | grep -v "\.sh$"; exit
  #find $CURRENT_DIR -maxdepth 1 | grep -v "\/${SELF_DIR}$" | grep -v "\.git" | grep -v "build$" | grep -v "android$" | grep -v "\.sh$" | xargs rm -rf
  rm -rf ${BUILD_DIR}/*

  # diff between platforms
  OS=$(uname)
  case $OS in
    Darwin*)
      BAK_FLAG=".bak"
      CPU_NUM=$(sysctl -n hw.ncpu)
      ;;
    Linux*)
      BAK_FLAG=""
      CPU_NUM=$(/bin/nproc)
      ;;
  esac

  # modify the 'configure' file of source
  sed -i ${BAK_FLAG} -E "s@^SLIBNAME_WITH_MAJOR='.*@SLIBNAME_WITH_MAJOR='\$(SLIBPREF)\$(FULLNAME)-\$(LIBMAJOR)\$(SLIBSUF)'@" $SRC_DIR/configure
  sed -i ${BAK_FLAG} -E "s@^LIB_INSTALL_EXTRA_CMD='.*@LIB_INSTALL_EXTRA_CMD='\$\$(RANLIB) \"\$(LIBDIR)/\$(LIBNAME)\"'@" $SRC_DIR/configure
  sed -i ${BAK_FLAG} -E "s@^SLIB_INSTALL_NAME='.*@SLIB_INSTALL_NAME='\$(SLIBNAME_WITH_MAJOR)'@" $SRC_DIR/configure
  sed -i ${BAK_FLAG} -E "s@^SLIB_INSTALL_LINKS='.*@SLIB_INSTALL_LINKS='\$(SLIBNAME)'@" $SRC_DIR/configure

  TARGET_HOST=linux
  SYSROOT=$NDK/platforms/android-$COMPILED_VERSION/arch-$ARCH
  TOOLCHAIN=$NDK/toolchains/${TOOLCHAIN_PLATFORM}/prebuilt/${NDK_PLATFORM}
  CROSS_PREFIX=$TOOLCHAIN/bin/${BIN_PREFIX}

  PREFIX=${CURRENT_DIR}/android/$ABI

  ADDI_CFLAGS+=" -I$SYSROOT/usr/include --sysroot=$SYSROOT"
  ADDI_LDFLAGS+=" --sysroot=$SYSROOT"

  # pick the needed parts
  DISABLE_EVERYTHING="--disable-everything"
  ENABLED_ENCODERS="\
      --enable-encoder=pcm_s16le \
      --enable-encoder=pcm_s16be \
      --enable-encoder=aac"
  ENABLED_DECODERS="\
      --enable-decoder=mp3 \
      --enable-decoder=aac \
      --enable-decoder=aac_fixed \
      --enable-decoder=aac_latm \
      --enable-decoder=pcm_s16le \
      --enable-decoder=pcm_s16be"
  ENABLED_HWACCELS=""
  ENABLED_MUXERS="\
      --enable-muxer=pcm_s16be \
      --enable-muxer=pcm_s16le"
  ENABLED_DEMUXERS=""
  ENABLED_PARSERS="\
      --enable-parser=aac \
      --enable-parser=aac_latm \
      --enable-parser=mpegaudio"
  ENABLED_BSFS=""
  ENABLED_PROTOCOLS="\
      --enable-protocol=file"
  ENABLED_INDEVS=""
  ENABLED_OUTDEVS=""
  ENABLED_FILTERS="\
      --enable-filter=aecho \
      --enable-filter=equalizer"

  echo -e "[`date +'%Y-%m-%d %H:%M:%S'`][ARCH:$1] $SRC_DIR/configure \
      --prefix=$PREFIX \
      --enable-shared \
      --disable-static \
      --disable-doc \
      --disable-programs \
      --disable-ffmpeg \
      --disable-ffplay \
      --disable-ffprobe \
      --disable-ffserver \
      --disable-symver \
      --enable-avresample \
      --enable-jni \
      --enable-small \
      --enable-neon \
      $DISABLE_EVERYTHING \
      $ENABLED_ENCODERS \
      $ENABLED_DECODERS \
      $ENABLED_HWACCELS \
      $ENABLED_MUXERS \
      $ENABLED_DEMUXERS \
      $ENABLED_PARSERS \
      $ENABLED_BSFS \
      $ENABLED_PROTOCOLS \
      $ENABLED_INDEVS \
      $ENABLED_OUTDEVS \
      $ENABLED_FILTERS \
      --cross-prefix=${CROSS_PREFIX} \
      --target-os=$TARGET_HOST \
      --arch=$ARCH \
      $CPU_FLAG \
      --enable-cross-compile \
      --sysroot=$SYSROOT \
      --extra-cflags=\"-Os -fpic $ADDI_CFLAGS\" \
      --extra-ldflags=\"$ADDI_LDFLAGS\" \
      $ADDITIONAL_CONFIGURE_FLAG" >> ${CURRENT_DIR}/build.log

  $SRC_DIR/configure \
      --prefix=$PREFIX \
      --enable-shared \
      --disable-static \
      --disable-doc \
      --disable-programs \
      --disable-ffmpeg \
      --disable-ffplay \
      --disable-ffprobe \
      --disable-ffserver \
      --disable-symver \
      --enable-avresample \
      --enable-jni \
      --enable-small \
      --enable-neon \
      $DISABLE_EVERYTHING \
      $ENABLED_ENCODERS \
      $ENABLED_DECODERS \
      $ENABLED_HWACCELS \
      $ENABLED_MUXERS \
      $ENABLED_DEMUXERS \
      $ENABLED_PARSERS \
      $ENABLED_BSFS \
      $ENABLED_PROTOCOLS \
      $ENABLED_INDEVS \
      $ENABLED_OUTDEVS \
      $ENABLED_FILTERS \
      --cross-prefix=${CROSS_PREFIX} \
      --target-os=$TARGET_HOST \
      --arch=$ARCH \
      $CPU_FLAG \
      --enable-cross-compile \
      --sysroot=$SYSROOT \
      --extra-cflags="-Os -fpic $ADDI_CFLAGS" \
      --extra-ldflags="$ADDI_LDFLAGS" \
      $ADDITIONAL_CONFIGURE_FLAG && \
  make clean && \
  make -j$CPU_NUM && \
  make install

  if [[ $? -eq 0 ]]; then
    echo -e "${COLOR_GREEN}DONE. Finished build $1.${COLOR_NC}"
  else
    echo -e "${COLOR_RED}[ERROR] Failed on building on arch $1.${COLOR_NC}"
  fi
}

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

for I in $ABIS; do
  Build_ $I
done

cd -
