#!/bin/bash

cpuCount=6
compile="false"
buildFFmpeg="false"

LOCALBUILDDIR=$PWD/build
LOCALDESTDIR=/usr/local
export LOCALBUILDDIR LOCALDESTDIR

PKG_CONFIG_PATH="${LOCALDESTDIR}/lib/pkgconfig"
CPPFLAGS="-I${LOCALDESTDIR}/include"
CFLAGS="-I${LOCALDESTDIR}/include -O2 -pipe"
CXXFLAGS="${CFLAGS}"
LDFLAGS="-L${LOCALDESTDIR}/lib -pipe"
export PKG_CONFIG_PATH CPPFLAGS CFLAGS CXXFLAGS LDFLAGS

[ -d $LOCALBUILDDIR ] || mkdir $LOCALBUILDDIR

# get git clone, or update
do_git() {
local gitURL="$1"
local gitFolder="$2"
local gitDepth="$3"
echo -ne "\033]0;compile $gitFolder\007"
if [ ! -d $gitFolder ]; then
	if [[ $gitDepth == "noDepth" ]]; then
		git clone $gitURL $gitFolder
	else
		git clone --depth 1 $gitURL $gitFolder
	fi
	compile="true"
	cd $gitFolder
else
	cd $gitFolder
	oldHead=`git rev-parse HEAD`
	git reset --hard @{u}
	git pull origin master
	newHead=`git rev-parse HEAD`

	if [[ "$oldHead" != "$newHead" ]]; then
		compile="true"
	fi
fi
}

# get svn checkout, or update
do_svn() {
local svnURL="$1"
local svnFolder="$2"
echo -ne "\033]0;compile $svnFolder\007"
if [ ! -d $svnFolder ]; then
	svn checkout $svnURL $svnFolder
	compile="true"
	cd $svnFolder
else
	cd $svnFolder
	oldRevision=`svnversion`
	svn update
	newRevision=`svnversion`

	if [[ "$oldRevision" != "$newRevision" ]]; then
		compile="true"
	fi
fi
}

# get hg clone, or update
do_hg() {
local hgURL="$1"
local hgFolder="$2"
echo -ne "\033]0;compile $hgFolder\007"
if [ ! -d $hgFolder ]; then
	hg clone $hgURL $hgFolder
	compile="true"
	cd $hgFolder
else
	cd $hgFolder
	oldHead=`hg id --id`
	hg pull
	hg update
	newHead=`hg id --id`

	if [[ "$oldHead" != "$newHead" ]]; then
		compile="true"
	fi
fi
}

# get wget download
do_wget() {
    local url="$1"
    local archive="$2"
    local dirName="$3"
    if [[ -z $archive ]]; then
        # remove arguments and filepath
        archive=${url%%\?*}
        archive=${archive##*/}
    fi

    local response_code=$(curl --retry 20 --retry-max-time 5 -L -k -f -w "%{response_code}" -o "$archive" "$url")

    if [[ $response_code = "200" || $response_code = "226" ]]; then
      case "$archive" in
        *.tar.gz)
          dirName=$( expr $archive : '\(.*\)\.\(tar.gz\)$' )
          rm -rf $dirName
          tar -xf "$archive"
          rm "$archive"
          cd "$dirName"
          ;;
        *.tar.bz2)
          dirName=$( expr $archive : '\(.*\)\.\(tar.bz2\)$' )
          rm -rf $dirName
          tar -xf "$archive"
          rm "$archive"
          cd "$dirName"
          ;;
        *.tar.xz)
          dirName=$( expr $archive : '\(.*\)\.\(tar.xz\)$' )
          #rm -rf $dirName
          tar -xf "$archive"
        #  rm "$archive"
          cd "$dirName"
          ;;
        *.zip)
          unzip "$archive"
          rm "$archive"
          ;;
        *.7z)
          dirName=$(expr $archive : '\(.*\)\.\(7z\)$' )
          7z x -o"$dirName" "$archive"
          rm "$archive"
          ;;
      esac
    elif [[ $response_code -gt 400 ]]; then
        echo "Error $response_code while downloading $URL"
        echo "Try again later or <Enter> to continue"
        do_prompt "if you're sure nothing depends on it."
    fi
}

# check if compiled file exist
do_checkIfExist() {
	local packetName="$1"
	local fileName="$2"
	local fileExtension=${fileName##*.}
	if [[ "$fileExtension" = "exe" ]]; then
		if [ -f "$LOCALDESTDIR/$fileName" ]; then
			echo -
			echo -------------------------------------------------
			echo "build $packetName done..."
			echo -------------------------------------------------
			echo -
			else
				echo -------------------------------------------------
				echo "Build $packetName failed..."
				echo "Delete the source folder under '$LOCALBUILDDIR' and start again,"
				echo "or if you know there is no dependences hit enter for continue it."
				read -p ""
				sleep 5
		fi
	elif [[ "$fileExtension" = "a" ]]; then
		if [ -f "$LOCALDESTDIR/lib/$fileName" ]; then
			echo -
			echo -------------------------------------------------
			echo "build $packetName done..."
			echo -------------------------------------------------
			echo -
			else
				echo -------------------------------------------------
				echo "build $packetName failed..."
				echo "delete the source folder under '$LOCALBUILDDIR' and start again,"
				echo "or if you know there is no dependences hit enter for continue it"
				read -p "first close the batch window, then the shell window"
				sleep 5
		fi
	fi
}

buildProcess() {
	sudo apt install libsdl2-dev libv4l-dev libxcb-xinerama0 libxcb-xinerama0 libcurl4-openssl-dev libqt5widgets5 checkinstall

cd $LOCALBUILDDIR
echo "-------------------------------------------------------------------------------"
echo
echo "compile global tools"
echo
echo "-------------------------------------------------------------------------------"

if [ -f "$LOCALDESTDIR/bin/nasm" ]; then
	echo -------------------------------------------------
	echo "nasm-2.13.01 is already compiled"
	echo -------------------------------------------------
	else
		echo -ne "\033]0;compile nasm 64Bit\007"

		do_wget "http://www.nasm.us/pub/nasm/releasebuilds/2.13.01/nasm-2.13.01.tar.gz" nasm-2.13.01.tar.gz

		./configure --prefix=$LOCALDESTDIR

		make -j $cpuCount
		sudo make install

		do_checkIfExist nasm-2.13.01.tar.gz libnasm.a
fi

cd $LOCALBUILDDIR

do_git "https://github.com/sekrit-twc/zimg.git" zimg-git noDepth

if [[ $compile == "true" ]]; then
	if [ -d $LOCALDESTDIR/include/zimg.h ]; then
		make distclean
		make clean
	fi
	./autogen.sh

	./configure --prefix=$LOCALDESTDIR --disable-static --enable-shared

	make -j $cpuCount
	sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=zimg --fstrans=no --backup=no --pkgversion="$(date +%Y%m%d)-git" --deldoc=yes

	do_checkIfExist zimg-git libzimg.so
else
	echo -------------------------------------------------
	echo "zimg-git is already up to date"
	echo -------------------------------------------------
fi


echo "-------------------------------------------------------------------------------"
echo
echo "compile global tools done..."
echo
echo "-------------------------------------------------------------------------------"

cd $LOCALBUILDDIR
echo "-------------------------------------------------------------------------------"
echo
echo "compile audio tools"
echo
echo "-------------------------------------------------------------------------------"

if [ -f "$LOCALDESTDIR/lib/libmp3lame.so" ]; then
	echo -------------------------------------------------
	echo "lame-3.99.5 is already compiled"
	echo -------------------------------------------------
	else
		echo -ne "\033]0;compile lame\007"

		do_wget "http://sourceforge.net/projects/lame/files/lame/3.99/lame-3.99.5.tar.gz/download" lame-3.99.5.tar.gz

		./configure --prefix=$LOCALDESTDIR --enable-expopt=full --enable-shared=yes --enable-static=no

		make -j $cpuCount
		sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=libmp3lame --fstrans=no --backup=no --pkgversion="3.99.5" --deldoc=yes

		do_checkIfExist lame-3.99.5 libmp3lame.so
fi

cd $LOCALBUILDDIR

do_git "https://github.com/mstorsjo/fdk-aac" fdk-aac-git

if [[ $compile == "true" ]]; then
	if [[ ! -f ./configure ]]; then
		./autogen.sh
	else
		sudo make uninstall
		make clean
	fi

	./configure --prefix=$LOCALDESTDIR --enable-shared=yes --enable-static=no

	make -j $cpuCount
	sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=fdk-aac --fstrans=no --backup=no --pkgversion="$(date +%Y%m%d)-git" --deldoc=yes

	do_checkIfExist fdk-aac-git libfdk-aac.so
	compile="false"
else
	echo -------------------------------------------------
	echo "fdk-aac is already up to date"
	echo -------------------------------------------------
fi

echo "-------------------------------------------------------------------------------"
echo
echo "compile audio tools done..."
echo
echo "-------------------------------------------------------------------------------"

cd $LOCALBUILDDIR
sleep 3
echo "-------------------------------------------------------------------------------"
echo
echo "compile video tools"
echo
echo "-------------------------------------------------------------------------------"

cd $LOCALBUILDDIR

if [ -f "$LOCALDESTDIR/include/decklink/DeckLinkAPI.h" ]; then
	echo -------------------------------------------------
	echo "DeckLinkAPI is already downloaded"
	echo -------------------------------------------------
	else
	echo -ne "\033]0;download DeckLinkAPI\007"

		cd $LOCALDESTDIR/include
    mkdir decklink
    cd decklink

    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPI.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIConfiguration.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIDeckControl.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIDiscovery.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIModes.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIStreaming.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPITypes.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIVersion.h
    do_wget https://raw.githubusercontent.com/jb-alvarado/compile-ffmpeg-osx/master/decklink-nix/DeckLinkAPIDispatch.cpp

    sed -i '' "s/void	InitDeckLinkAPI (void)/static void	InitDeckLinkAPI (void)/" DeckLinkAPIDispatch.cpp
    sed -i '' "s/bool		IsDeckLinkAPIPresent (void)/static bool		IsDeckLinkAPIPresent (void)/" DeckLinkAPIDispatch.cpp
    sed -i '' "s/void InitBMDStreamingAPI(void)/static void InitBMDStreamingAPI(void)/" DeckLinkAPIDispatch.cpp

		if [ ! -f "$LOCALDESTDIR/include/decklink/DeckLinkAPI.h" ]; then
			echo -------------------------------------------------
			echo "DeckLinkAPI.h download failed..."
			echo "if you know there is no dependences hit enter for continue it,"
			echo "or run script again"
			read -p ""
			sleep 5
		else
			echo -
			echo -------------------------------------------------
			echo "download DeckLinkAPI done..."
			echo -------------------------------------------------
			echo -
		fi
fi

#------------------------------------------------
# final tools
#------------------------------------------------

cd $LOCALBUILDDIR

do_git "git://git.videolan.org/x264.git" x264-git noDepth

if [[ $compile == "true" ]]; then
	echo -ne "\033]0;compile x264-git\007"

	if [ -f "$LOCALDESTDIR/lib/libx264.so" ]; then
		rm -f $LOCALDESTDIR/include/x264.h $LOCALDESTDIR/include/x264_config.h $LOCALDESTDIR/lib/libx264.so
		rm -f $LOCALDESTDIR/bin/x264 $LOCALDESTDIR/lib/pkgconfig/x264.pc
	fi

	if [ -f "libx264.so" ]; then
		make distclean
	fi

	./configure --prefix=$LOCALDESTDIR --enable-shared

	make -j $cpuCount
	sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=x264 --fstrans=no --backup=no --pkgversion="$(date +%Y%m%d)-git" --deldoc=yes

	do_checkIfExist x264-git libx264.so
	compile="false"
	buildFFmpeg="true"
else
	echo -------------------------------------------------
	echo "x264 is already up to date"
	echo -------------------------------------------------
fi

cd $LOCALBUILDDIR

do_hg "https://bitbucket.org/multicoreware/x265" x265-hg

if [[ $compile == "true" ]]; then
	cd build/xcode
	rm -rf *
	rm -f $LOCALDESTDIR/bin/x265
	rm -f $LOCALDESTDIR/include/x265.h
	rm -f $LOCALDESTDIR/include/x265_config.h
	sudo rm -rf $LOCALDESTDIR/lib/libx265.so
	sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/x265.pc

	cmake ../../source -DCMAKE_INSTALL_PREFIX=$LOCALDESTDIR -DENABLE_SHARED:BOOLEAN=ON -DCMAKE_CXX_FLAGS_RELEASE:STRING="-O3 -DNDEBUG $CXXFLAGS"

	make -j $cpuCount
	sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=x265 --fstrans=no --backup=no --pkgversion="$(date +%Y%m%d)-git" --deldoc=yes

	do_checkIfExist x265-git libx265.so
	compile="false"
	buildFFmpeg="true"
else
	echo -------------------------------------------------
	echo "x265 is already up to date"
	echo -------------------------------------------------
fi

cd $LOCALBUILDDIR
echo "-------------------------------------------------------------------------------"
echo "compile ffmpeg"
echo "-------------------------------------------------------------------------------"

do_git "https://github.com/FFmpeg/FFmpeg.git" ffmpeg-git

if [[ $compile == "true" ]] || [[ $buildFFmpeg == "true" ]] || [[ ! -f $LOCALDESTDIR/bin/ffmpeg ]]; then
	if [ -f "$LOCALDESTDIR/lib/libavcodec.so" ]; then
		sudo rm -rf $LOCALDESTDIR/include/libavutil
		sudo rm -rf $LOCALDESTDIR/include/libavcodec
		sudo rm -rf $LOCALDESTDIR/include/libpostproc
		sudo rm -rf $LOCALDESTDIR/include/libswresample
		sudo rm -rf $LOCALDESTDIR/include/libswscale
		sudo rm -rf $LOCALDESTDIR/include/libavdevice
		sudo rm -rf $LOCALDESTDIR/include/libavfilter
		sudo rm -rf $LOCALDESTDIR/include/libavformat
		sudo rm -rf $LOCALDESTDIR/lib/libavutil.so
		sudo rm -rf $LOCALDESTDIR/lib/libswresample.so
		sudo rm -rf $LOCALDESTDIR/lib/libswscale.so
		sudo rm -rf $LOCALDESTDIR/lib/libavcodec.so
		sudo rm -rf $LOCALDESTDIR/lib/libavdevice.so
		sudo rm -rf $LOCALDESTDIR/lib/libavfilter.so
		sudo rm -rf $LOCALDESTDIR/lib/libavformat.so
		sudo rm -rf $LOCALDESTDIR/lib/libpostproc.so
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libavcodec.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libavutil.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libpostproc.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libswresample.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libswscale.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libavdevice.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libavfilter.pc
		sudo rm -rf $LOCALDESTDIR/lib/pkgconfig/libavformat.pc
	fi

	if [ -f "config.mak" ]; then
		make distclean
	fi
	sudo make uninstall

	./configure --prefix=$LOCALDESTDIR --enable-shared --disable-debug --disable-doc --enable-gpl --enable-version3  \
	--enable-nonfree --enable-runtime-cpudetect --enable-avfilter --enable-decklink --enable-opengl \
	--enable-libzimg --enable-libfdk-aac --enable-libmp3lame \
	--enable-libx264 --enable-libx265 #--extra-libs='-lstdc++ -lm -lrt -ldl -lz -lpng -lm'

	# --enable-libvpx --enable-fontconfig --enable-libfreetype --enable-libass --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-libsoxr --enable-libspeex --enable-libtheora --enable-libvorbis --enable-libvo-aacenc --enable-libopus  --enable-libx265 --enable-libxvid --enable-decklink --extra-cflags='-I$LOCALDESTDIR/include/decklink' --extra-ldflags='-L$LOCALDESTDIR/include/decklink' --extra-libs='-lpng -lm'

  #sed -i '' "s/ -std=c99//" config.mak

	make -j $cpuCount
	sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=FFmpeg --fstrans=no --backup=no --pkgversion="$(date +%Y%m%d)-git" --deldoc=yes


	#make install


	do_checkIfExist ffmpeg-git libavcodec.so

	compile="false"
else
	echo -------------------------------------------------
	echo "ffmpeg is already up to date"
	echo -------------------------------------------------
fi

cd $LOCALBUILDDIR || exit

git clone --recursive https://github.com/jp9000/obs-studio.git
  cd obs-studio
  mkdir build && cd build
  cmake -DUNIX_STRUCTURE=1 -DCMAKE_INSTALL_PREFIX=$LOCALDESTDIR ..
  make -j $cpuCount
  sudo checkinstall --maintainer="jb@amazing-discoveries.org" --pkgname=obs-studio --fstrans=no --backup=no \
         --pkgversion="$(date +%Y%m%d)-git" --deldoc=yes

cd $LOCALBUILDDIR || exit


echo -ne "\033]0;strip binaries\007"
echo
echo "-------------------------------------------------------------------------------"
echo
FILES=`find bin -type f -mmin -600 ! \( -name '*-config' -o -name '.DS_Store' -o -name '*.lua' \)`

for f in $FILES; do
 strip $f
 echo "strip $f done..."
done

#echo -ne "\033]0;deleting source folders\007"
#echo
#echo "deleting source folders..."
#echo
#find $LOCALBUILDDIR -mindepth 1 -maxdepth 1 -type d ! \( -name '*-git' -o -name '*-svn' -o -name '*-hg' \) -print0 | xargs -0 rm -rf
}

buildProcess

echo -ne "\033]0;compiling done...\007"
echo
echo "Window close in 15"
echo
sleep 5
echo
echo "Window close in 10"
echo
sleep 5
echo
echo "Window close in 5"
sleep 5
