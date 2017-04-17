#!/bin/bash

# SETTING: modify this to the real directory
SRC_DIR="/Users/simonkuang/workspace/ffmpeg-3.2.4"
NDK=$HOME/Library/Android/sdk/ndk-bundle
NDK_PLATFORM="darwin-x86_64"
#ABIS="armeabi armeabi-v7a arm64-v8a mips mips64 x86 x86_64"
ABIS="armeabi armeabi-v7a mips x86"
# TODO(simonkuang): settings for components here. like:
# ENCODERS="aac aac_at pcm_s16le pcm_s16be"
# MUXERS="adts adx aiff pcm_s16le pcm_s16be"
# ...


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

  PREFIX=${CURRENT_DIR}/.android/$ABI
  OUTPUT=${CURRENT_DIR}/ffmpeg_jni

  ADDI_CFLAGS+=" -I$SYSROOT/usr/include --sysroot=$SYSROOT"
  ADDI_LDFLAGS+=" --sysroot=$SYSROOT"

  # pick the needed parts
  DISABLE_EVERYTHING="--disable-everything"
  ENABLED_ENCODERS="\
      --enable-encoder=pcm_s16le \
      --enable-encoder=pcm_s16be \
      --enable-encoder=aac \
      --enable-encoder=aac_at"
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
      --enable-muxer=pcm_s16le \
      --enable-muxer=adts \
      --enable-muxer=adx \
      --enable-muxer=aiff"
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
    return -1
  fi

  # finish install
  cp config.h ${PREFIX}/config_$1.h

  # remove all the soft link
  find ${PREFIX} -type l -delete

  # rebuild the directory for android ndk path structure
  [ -d ${OUTPUT}/src/main/jniLibs/$1 ] || mkdir -p ${OUTPUT}/src/main/jniLibs/$1
  [ -d ${OUTPUT}/src/main/jni ] || mkdir -p ${OUTPUT}/src/main/jni
  # copy shared library binary to jniLibs directory with arch
  cp -rf ${PREFIX}/lib/*.so ${OUTPUT}/src/main/jniLibs/$1/
  # retrive the header files for arm arch
  [ "$1" == "armeabi" ] && \
      cp -rf ${PREFIX}/include/* ${OUTPUT}/src/main/jni/
}

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

for I in $ABIS; do
  Build_ $I
done

cd -

# clean work
#find ${BUILD_DIR} -type l -delete
