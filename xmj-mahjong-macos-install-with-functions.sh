#!/bin/sh

# Script to install Julian Bradfield XMJ Mahjong to MacOS
#
#   Credit for the great game and neat implentation:
#   https://mahjong.julianbradfield.org/
#
# This script:
# 2024-09-05 - Version 0.4 - structuring into function, untested, probably broken
# 2024-04-24 - Version 0.3 - first Beta
# 2024-04-24 - Version 0.2
# 2024-04-24 - Version 0.1
# https://github.com/Squizzy/

XMJ_VERSION="1.16"

# Check if a version was specified in the command line, in which case, overwrite above
while getopts ":v:" opt; do
  case $opt in
    v) XMJ_VERSION="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG. Only valid is -v <version number eg 1.16>" >&2; exit 1 ;;
  esac
done

XMJ_SRC_FILENAME="mj-"$XMJ_VERSION
XMJ_SRC_FILENAME_COMPRESSED=$XMJ_SRC_FILENAME"-src.tar.gz"

XMJ_SRC_WEBSITE="https://mahjong.julianbradfield.org/Source"
XMJ_SRC_REMOTE_FILE="$XMJ_SRC_WEBSITE/$XMJ_SRC_FILENAME"

TEMP_FOLDER="XMJ-MacOS-Prep"

APP_NAME="XMJ Mahjong.app"
APP_EXECUTABLES="$APP_NAME/Contents/MacOS"
APP_RESOURCES="$APP_NAME/Contents/Resources"
APP_LIBS="$APP_NAME/Contents/Libs"

CREATE_BACKUP=false
DOWNLOAD_ICONSET=true
CLEANUP=false


confirm() {
    read -r "?$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

create_temp_folder(){
  #
  # Create a folder for the setup
  
  # mkdir XMJ-MacOS-Install
  mkdir $TEMP_FOLDER

  # Go to this folder
  # cd XMJ-MacOS-Install  || { echo "Failed to get to the XMJ-MacOS-Install/ folder"; exit; }
  cd $TEMP_FOLDER  || { echo "xmj_download_src: Failed to change directory to ${TEMP_FOLDER}"; exit; }
}

xmj_download_src() {
  ####################################
  #
  # Prepare and Download
  #
  ####################################

  echo "================================================================="
  echo " Downloading application source from author's website"
  echo "================================================================="

  # Download XMJ Mahjong source code from its original website (from Julian Bradfield)
  # curl https://mahjong.julianbradfield.org/Source/mj-1.16-src.tar.gz -O mj-1.16-src.tar.gz
  curl "$XMJ_SRC_REMOTE_FILE" -O "$XMJ_SRC_FILENAME_COMPRESSED"
}

xmj_uncompress_src() {
  # Unzip the downloaded file
  # tar -zxvf ./mj-1.16-src.tar.gz

  tar -zxvf ./"$XMJ_SRC_FILENAME_COMPRESSED"

  # NOTE: This creates the folder $XMJ_SRC_FILENAME and extracts the source in it
}

xmj_adjust_src_port_number() {
  ####################################
  #
  # Adjust source for Apple port issue
  #
  ####################################
  #
  # Next, we need to modify the default port number:
  # Apple has now fixed its use of port 5000 for some of its functionality
  # This is the default for XMJ Mahjong, so this will become an annoying issue
  # Hopefully this can be addressed later but this will cause confusion for the forseeable future
  #
  # For now, change the XMJ Mahjong default port to 4000 (for example):
  echo "================================================================="
  echo " Modify source code as needed for Apple"
  echo ''
  echo 'IMPORTANT NOTE: As Apple now uses port 5000 for its own functionality'
  echo 'this redefines it to port 4000. On non-Apple XMJ, this value will need'
  echo 'to be matched. 4000 can be changed as desired as long as it is not a'
  echo 'port number used by any of the machines'
  echo ''
  echo "================================================================="

  # Go to the extracted folder
  # cd mj-1.16-src || { echo "Failed to get to the extracted mj-1.16-src/ folder"; exit; }
  cd "$XMJ_SRC_FILENAME" || { echo "xmj_adjust_src_port_number: Failed to change directory to extracted ${XMJ_SRC_FILENAME}"; exit; }

  # - in gui.c:
  # change
  #     `char address[256] = "localhost:5000";`
  # to 
  #     `char address[256] = "localhost:4000";`
  if [ $CREATE_BACKUP = true ] ; then
    cp gui.c gui.c.backup
  fi
  sed -i "" 's/char address\[256\] = "localhost:5000"/char address\[256\] = "localhost:4000"/' gui.c

  # change
  #     `if ( strcmp(redirected ? origaddress : address,"localhost:5000") != 0 ) {`
  # to
  #     `if ( strcmp(redirected ? origaddress : address,"localhost:4000") != 0 ) {`
  sed -i "" 's/if ( strcmp(redirected ? origaddress : address,"localhost:5000") != 0 ) {/if ( strcmp(redirected ? origaddress : address,"localhost:4000") != 0 ) {/' gui.c

  # - in controller.c:
  # change
  #   `char *address = ":5000";`
  # to
  #   `char *address = ":4000";`
  if [ $CREATE_BACKUP = true ] ; then
    cp controller.c controller.c.backup
  fi
  sed -i "" 's/char \*address = ":5000";/char \*address = ":4000";/' controller.c

  # - in greedy.c:
  # change
  #   `char *address = ":5000";`
  # to
  #   `char *address = ":4000";`
  if [ $CREATE_BACKUP = true ] ; then
    cp greedy.c greedy.c.backup
  fi
  sed -i "" 's/char \*address = ":5000";/char \*address = ":4000";/' greedy.c

  cd ..
}

xmj_adjust_src_executables_path () {
  ####################################
  #
  # Ensure mj-player and mj-server can 
  # be found in the Apple App Bundle
  #
  # TODO: find out if this can be omitted
  #
  ####################################
  # 
  # THIS CAN PROBABLY BE IMPROVED, BUT IT APPEARS BY DEFAULT IN AN APP BUNDLE
  # mj-server WAS NOT DISCOVERED WHEN LAUNCHED mj-player. 
  # THERE MIGHT BE A WAY OF/SETTING OF THE APP BUNDLE TO FIX THIS?
  #
  # mj-player and mj-server to be discovered in the same folder
  # as the executable xmj when it is in the macOS app bundle. 
  # (same folder for ease of use but adjust accordingly if placing somewhere else)
  # So for the purpose of the macOS app bundle only:


  # Go to the extracted folder
  # cd mj-1.16-src || { echo "Failed to get to the extracted mj-1.16-src/ folder"; exit; }
  cd "$XMJ_SRC_FILENAME" || { echo "xmj_adjust_src_executables_path: Failed to change directory to extracted ${XMJ_SRC_FILENAME}"; exit; }

  # - in gui.c:
  # somewhere above the two changes below, as a global define for the file:
  #  `#define macOS`
  sed -i "" 's/#include "gtkrc.h"/#include "gtkrc.h"\n#define MacOS/' gui.c

  # - also in gui.c
  # change
  #     `strcpy(cmd, "mj-server --id-order-seats --server ");`
  # to
  # ```
  #   #ifndef macOS
  #       strcpy(cmd, "mj-server --id-order-seats --server ");
  #   #else
  #       strcpy(cmd, "./mj-server --id-order-seats --server ");
  #   #endif
  # ```
  sed -i "" 's/strcpy(cmd,"mj-server --id-order-seats --server ");/#ifndef MacOS\n\t\t\t\tstrcpy(cmd,"mj-server --id-order-seats --server ");\n\t\t\t#else\n\t\t\t\tstrcpy(cmd, "\.\/mj-server --id-order-seats --server ");\n\t\t\t#endif/' gui.c

  # also in gui.c:
  # change:
  # 	`strcpy(cmd,"mj-player --server ");`
  # to 
  # ```
  #     #ifndef macOS
  #         strcpy(cmd,"mj-player --server ");
  #     #else
  #         strcpy(cmd,"./mj-player --server ");
  #     #endif
  # ```
  sed -i "" 's/strcpy(cmd,"mj-player --server ");/#ifndef MacOS\n\t\tstrcpy(cmd,"mj-player --server ");\n\t#else\n\t\tstrcpy(cmd,"\.\/mj-player --server ");\n\t#endif/' gui.c

  cd ..
}
# This concludes the essential code changes - could be done in a smarter way, presumably.

install_compiling_essentials() {
  ####################################
  #
  # Install essential files for compiling
  #
  # TODO: Pre-check installed, in which case, skip
  #
  ####################################
  #
  # Install Homebrew, a package manager (installs stuff needed to run xmj)
  # https://brew.sh/
  echo "================================================================="
  echo " Download Homebrew and required packages"
  echo "================================================================="

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

  # Install GTK+, a package needed for the making the graphical interface from homebrew
  brew install gtk+

  # Below comment is probably already obsolete:
  # As per 23rd Apr 2024 there is a problem as XPM had been removed from gdk-pixbuf.
  # This is in the process of being re-added but in the meantime here is a trick to enable it:
  # https://github.com/Homebrew/homebrew-core/issues/169803#issuecomment-2071212659
  # And the page with updates on the reinstallment:
  #

  # Install pkg-config from homebrew
  brew install pkg-config
}

make_executables() {
  # Make the executables
  echo "================================================================="
  echo " Creating the executables"
  echo "================================================================="

  # Go to the extracted folder
  # cd mj-1.16-src || { echo "Failed to get to the extracted mj-1.16-src/ folder"; exit; }
  cd "$XMJ_SRC_FILENAME" || { echo "make_executables: Failed to change directory to extracted ${XMJ_SRC_FILENAME}"; exit; }

  make

  cd ..
}

app_bundle_create_tree() {
  ####################################
  #
  # First step in making the Apple App Bundle 
  # (the application that appears in Launchpad)
  #
  ####################################
  #
  # An App bundler is a folder tree containing the executable, some resources such as the iconset.
  # In the case of XMJ, it needs to also contain the tilesets for the game, 
  # and will contain the linked librairies.
  #
  # XMJ Mahjong.app/
  #   - Info.plist
  #   + Contents/
  #       + MacOS/
  #           - xmj
  #           - mj-player
  #           - mj
  #           - mj-server
  #           - xmj-script
  #           + tiles_numbered/
  #               - (*.xpm)
  #           + tiles_small/
  #               - (*.xpm)
  #           + tiles_v1/
  #               - (*.xpm)
  #           + fallbacktiles/
  #               - (*.xpm)
  #       + Resources/
  #           - xmj.icns
  #       + Libs/
  #           - (libs)
  #
  # + folder
  # - file
  # - (bunch of files)
  #
  # First create the folder tree

  echo "================================================================="
  echo " Create folders tree that is the App Bundle"
  echo "================================================================="

  mkdir "$APP_NAME"
  cd "$APP_NAME" || { echo "app_bundle_create_tree: Failed to change directory to ${APP_NAME}"; exit; }

  mkdir Contents
  cd Contents  || { echo "app_bundle_create_tree: Failed to change directory to ${APP_NAME}/Contents/"; exit; }

  mkdir MacOS
  mkdir Resources
  mkdir Libs

  cd ../..
}

app_bundle_create_info_plist() {
  ####################################
  #
  # Create the Info.plist file
  #
  ####################################
  #
  # This file that instructs which file to execute and where some resources are stored
  # Its content is simple for the file organisation that this will use.
  # Description if these info.plis files is quite available.
  # Some improvements are probably possible
  #   eg: IFMajor and IFMinor version seem to be deprecated now
  #
  # Specific credit though to: Hayden Schiff under:
  # https://stackoverflow.com/questions/1596945/building-osx-app-bundle

  echo "================================================================="
  echo " Create Info.plist in Contents folder"
  echo "================================================================="

  cd "$APP_NAME" || { echo "app_bundle_create_info_plist: Failed to change directory to ${APP_NAME}"; exit; }

  echo '<?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
    <key>CFBundleGetInfoString</key>
    <string>XMJ Mahjong (c) 2000-now by Julian Bradfield</string>
    <key>CFBundleExecutable</key>
    <string>xmj-script</string>
    <key>CFBundleIdentifier</key>
    <string>com.xmj-mahjong.www</string>
    <key>CFBundleName</key>
    <string>XMJ Mahjong</string>
    <key>CFBundleIconFile</key>
    <string>xmj.icns</string>
    <key>CFBundleShortVersionString</key>
    <string>1.16</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>IFMajorVersion</key>
    <integer>1</integer>
    <key>IFMinorVersion</key>
    <integer>16</integer>
  </dict>
  </plist>' > Info.plist

  cd ..
}

app_bundle_create_launch_miniscript() {
  ####################################
  #
  # Create the miniscript to launch the app
  # probably unnecessary
  #
  ####################################
  #
  # Mini script (seemed not needed in this case)
  # This was a recommendation from Hayden in the link above
  # script stored under Contents folder
  # Script is called as pointed by Info.plist
  echo "================================================================="
  echo " Create miniscript in Contents/MacOS folder"
  echo "================================================================="

  cd "$APP_NAME/Contents/MacOS" || { echo "app_bundle_create_launch_miniscript: Failed to change directory to ${APP_NAME}/Contents/MacOS"; exit; }

  echo "#!/bin/bash"       > xmj-script
  echo "cd \"\${0%/*}\""  >> xmj-script
  echo "./xmj"            >> xmj-script

  # make this script executable
  chmod +x xmj-script

  cd ../../..
}

app_bundle_copy_executables() {
  ####################################
  #
  # Copy the executables and the tiles
  # to the Contents/MacOS folder
  #
  ####################################
  #
  echo "================================================================="
  echo " Copy the executables and tileset into the Contents/Macos folder"
  echo "================================================================="

  # cd MacOS   || { echo "Failed to get to the 'XMJ Mahjong.app/Contents/MacOS' folder"; exit; }

  # cp ../../../xmj  .
  # cp ../../../mj-player .
  # cp ../../../mj-server .
  cp "$XMJ_SRC_FILENAME"/xmj       "$APP_EXECUTABLES"/
  cp "$XMJ_SRC_FILENAME"/mj-player "$APP_EXECUTABLES"/
  cp "$XMJ_SRC_FILENAME"/mj-server "$APP_EXECUTABLES"/

  # cp -R ../../../tiles-numbered .
  # cp -R ../../../tiles-small .
  # cp -R ../../../tiles-v1 .
  # cp -R ../../../fallbacktiles .
  cp -R "$XMJ_SRC_FILENAME"/tiles-numbered "$APP_EXECUTABLES"/
  cp -R "$XMJ_SRC_FILENAME"/tiles-small    "$APP_EXECUTABLES"/
  cp -R "$XMJ_SRC_FILENAME"/tiles-v1       "$APP_EXECUTABLES"/
  cp -R "$XMJ_SRC_FILENAME"/fallbacktiles  "$APP_EXECUTABLES"/

  # cd ..
}

app_bundle_prepare_and_install_iconset() {
  ####################################
  #
  # Prepare the iconset for Apple
  #
  ####################################
  #
  # macOS app bundle needs a specific file (.icns) containing multiple icon resolutions. 
  # Thankfully it is easy to create:
  # make the xmj.icns from the xmj.ico provided with the source:

  # a) method 1, manual:
  # i) create a folder called xmj.iconset
  # ii) in it, create multiple png files with the following resolution an names(some repeat with different names): 

  # (Ideally start from a 1024x1024 base image - but here we don't have it).
  # using a tool such as GIMP http://gimp.org create the following images resized from the original - all square:
  # icon_1024x1024x.png 1024 x 1024
  # icon_512x512@2x.png 1024 x 1024
  # icon_512x512.png  512 x 512
  # icon_256x256@2x.png 512 x 512
  # icon_256x256.png  256 x 256
  # icon_128x128@2x.png 256 x 256
  # icon_128x128.png  128 x 128
  # icon_32x32@2x.png  64 x 64
  # icon_32x32.png   32 x 32
  # icon_16x16@2x.png  32 x 32
  # icon_16x16.png   16 x 16
  # 
  # iii) in a terminal, run the following apple command on the folder:
  #     `iconutil -c icns myicon.iconset`
  # 
  # b) method 2
  # Alternatively there are some very capable apps like "App Icon Producer", free on the App Store.
  # 
  # in the end, you will end up with an iconset `xmj.icns`

  echo "In order to trust your application, you should create the iconset yourself"
  echo "following the instructions in this script file of the Squizzy github, or other."
  echo "Alternatively, the file can be downloaded from the github this script was gotten from"
  echo "By default you should not trust this file and create your own"
  echo "based on the XMJ original icon file: 'icon.ico'"
  echo "This script will download it by default, but you can disable this by"
  echo "adding a # in from of the 'curl' line below" 

  if [ "$DOWNLOAD_ICONSET" = true ]; then
    # Download the iconset from Squizzy's github straight into the Resources folder 
    echo "================================================================="
    echo " Downloading iconset"
    echo "================================================================="
    curl -L -O https://github.com/Squizzy/XMJ-Mahjong-MacOS-Script/raw/development/icns/xmj.icns

    cp ./xmj.icns "$APP_RESOURCES"/


  else
    echo "================================================================="
    echo " iconset provided by you"
    echo "================================================================="
    echo "Remember to copy your iconset to the App Bundle."
    echo "As this script does not stop, you might want to change the one in the Applications folder directly"
    echo "placed at location: ${APP_RESOURCES}"
    echo
  fi
  
  
  # cd Resources  || { echo "Failed to get to the 'XMJ Mahjong.app/Contents/Resources/' folder"; exit; }
  # cd ..

  # cd ../..
}

app_bundle_install_to_Applications() {
  # Copy the app bundle to the applications folder / launchpad
  echo "================================================================="
  echo " Copy the app bundle to the Applications folder/Launchpad"
  echo "================================================================="

  if [ -d "/Applications/$APP_NAME" ]; then
      if confirm "XMJ Mahjong is already installed. Reinstall?"; then
          rm -rf "/Applications/$APP_NAME"
      else
          echo "Installation cancelled."
          exit 0
      fi
  fi

  cp -R "$APP_NAME" /Applications
}

# Below two functions is content that may be unnecessary now - for my reference just in case
install_dylibbundler() {
  ####################################
  #
  # Install dylibbundler
  #
  ####################################

  # In order to run, the executable files need librairies (files) that are not generically available on MacOS.
  # The application has used linked librairies (eg gkt+). This makes it not very portable. 
  # In order to fix this, it is possible to copy the required files into the App bundle
  # And then tell the executable files where to look for them in the bundle.
  # Thankfully that last part is available through applications such as:
  # https://github.com/auriamg/macdylibbundler
  #
  # The app can make sure the App Bundle includes all libraries it depends on to place in the "Applications" folder, so it can be shared with someone who hasn't installed all the brewed files.

  # The app `dylibbundler` will:
  # - find all the libraries used for the compilation of the executables, 
  # - copy them into the bundle (here, creating a new folder `libs` under `XMJ Mahjong.app/Contents/`), 
  # - points the executables to these versions:

  echo "========================================================"
  echo " Download dylibbundler"
  echo "========================================================"

  # # Install the app using homebrew
  brew install dylibbundler
}

execute_dylibbundler() {
  ####################################
  #
  # bundle the dylibs
  # flags used (probaby some redundance built in!):
  #  -b:          prepares the dylibs for the distribution
  #  -d <folder>: specify destination folder for the dylibs
  #  -p <folder>: destination folder to install to 
  #  -x <file>:   executable file to process
  #  -cd:         create destination folder if it does not exist
  #  -ns:         disable ad-hoc code signing
  #  -of:         overwrite files if exist
  #
  # https://github.com/auriamg/macdylibbundler
  #
  ####################################

  # run the app against each executable.
  # For example, when in terminal we are in the same folder as the app bundle:
  # (above "XMJ Mahjong.app"), use:
  
  # echo "========================================================"
  # echo " Run dylibbundler"
  # echo "========================================================"
  # cd ..
  # /usr/local/bin/dylibbundler  -b  -p ./XMJ\ Mahjong.app/Contents/Libs -x ./XMJ\ Mahjong.app/Contents/MacOS/xmj -d ./XMJ\ Mahjong.app/Contents/Libs -cd -ns -of
  # 
  # /usr/local/bin/dylibbundler  -b  -p ./XMJ\ Mahjong.app/Contents/Libs -x ./XMJ\ Mahjong.app/Contents/MacOS/mj-player -d ./XMJ\ Mahjong.app/Contents/Libs -cd -ns -of
  # 
  # /usr/local/bin/dylibbundler  -b  -p ./XMJ\ Mahjong.app/Contents/Libs -x ./XMJ\ Mahjong.app/Contents/MacOS/mj-server -d ./XMJ\ Mahjong.app/Contents/Libs -cd -ns -of

  echo "========================================================"
  echo " Run dylibbundler"
  echo "========================================================"

  cd /Applications ||  { echo "execute_dylibbundler: Failed to change directory to /Applications"; exit; }

  /usr/local/bin/dylibbundler -b -p "./$APP_LIBS" -x "./$APP_EXECUTABLES"/xmj -d "./$APP_LIBS" -cd -ns -of
  
  /usr/local/bin/dylibbundler -b -p "./$APP_LIBS" -x "./$APP_EXECUTABLES"/mj-player -d "./$APP_LIBS" -cd -ns -of
  
  /usr/local/bin/dylibbundler -b -p "./$APP_LIBS" -x "./$APP_EXECUTABLES"/mj-server -d "./$APP_LIBS" -cd -ns -of

}

this_script_cleanup() {
  if [ "$CLEANUP" = true ]; then
    # remove downloaded compressed src
    rm "$XMJ_SRC_FILENAME_COMPRESSED"
    # remove source working directory
    rm -Rf "$XMJ_SRC_FILENAME"
    # remove app bundle as it was copied in /Applications
    rm -Rf "$APP_NAME"
    # remove dowloaded iconset
    rm -Rf "xmj.icns"
  fi
}


xmj_download_src
xmj_uncompress_src
xmj_adjust_src_port_number
xmj_adjust_src_executables_path
install_compiling_essentials
make_executables
app_bundle_create_tree
app_bundle_create_info_plist
app_bundle_create_launch_miniscript
app_bundle_copy_executables
app_bundle_prepare_and_install_iconset
# install_dylibbundler
# execute_dylibbundler
app_bundle_install_to_Applications
this_script_cleanup

