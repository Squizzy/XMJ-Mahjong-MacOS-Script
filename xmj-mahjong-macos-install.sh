#!/bin/sh

# Script to install Julian Bradfield XMJ Mahjong to MacOS
#
#   Credit for the great game and neat implentation:
#   https://mahjong.julianbradfield.org/
#
# This script:
# 2024-04-24 - Version 0.3 - first Beta
# 2024-04-24 - Version 0.2
# 2024-04-24 - Version 0.1
# https://github.com/Squizzy/

####################################
#
# Prepare and Download
#
####################################
#
# Creare a folder for the setup

echo "================================================================="
echo " Download and extract application from author's website"
echo "================================================================="

mkdir XMJ-MacOS-Install

# Go to this folder
cd XMJ-MacOS-Install

# Download XMJ Mahjong source code from its original website (from Julian Bradfield)
curl https://mahjong.julianbradfield.org/Source/mj-1.16-src.tar.gz -O mj-1.16-src.tar.gz

# Unzip the downloaded file
tar -zxvf ./mj-1.16-src.tar.gz

# Remove the zip file, it won't be useful any more
rm mj-1.16-src.tar.gz

# Go to the extracted folder
cd mj-1.16-src


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
echo "================================================================="

# - in gui.c:
# change
#     `char address[256] = "localhost:5000";`
# to 
#     `char address[256] = "localhost:4000";`
#cp gui.c gui.c.backup
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
#cp controller.c controller.c.backup
sed -i "" 's/char \*address = ":5000";/char \*address = ":4000";/' controller.c

# - in greedy.c:
# change
#   `char *address = ":5000";`
# to
#   `char *address = ":4000";`
#cp greedy.c greedy.c.backup
sed -i "" 's/char \*address = ":5000";/char \*address = ":4000";/' greedy.c


####################################
#
# Ensure mj-player and mj-server can 
# be found in the Apple App Bundle
#
####################################
# 
# We also need mj-player and mj-server to be discovered in the same folder
# as the executable xmj when it is in the macOS app bundle. 
# (same folder for ease of use but adjust accordingly if placing somewhere else)
# So for the purpose of the macOS app bundle only:

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

# This concludes the essential code changes - could be done in a smarter way, presumably.


####################################
#
# Make the executables
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

# As per 23rd Apr 2024 there is a problem as XPM had been removed from gdk-pixbuf.
# This is in the process of being re-added but in the meantime here is a trick to enable it:
# https://github.com/Homebrew/homebrew-core/issues/169803#issuecomment-2071212659
# And the page with updates on the reinstallment:
#

# Install pkg-config from homebrew
brew install pkg-config

# Make the executables
echo "================================================================="
echo " Make the executable"
echo "================================================================="
make


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

mkdir XMJ\ Mahjong.app
cd XMJ\ Mahjong.app
mkdir Contents
cd Contents
mkdir MacOS
mkdir Resources
mkdir Libs


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
cd MacOS
echo '#!/bin/bash
    cd "${0%/*}"
    ./xmj' > xmj-script

# make this script executable
chmod +x xmj-script


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
cd MacOS
cp ../../../xmj .
cp ../../../mj-player .
cp ../../../mj-server .
cp -R ../../../tiles-numbered .
cp -R ../../../tiles-small .
cp -R ../../../tiles-v1 .
cp -R ../../../fallbacktiles .
cd ..


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
echo "adding a # in from of the "curl" line below" 

# Download the iconset from Squizzy's github straight into the Resources folder
echo "================================================================="
echo " Download iconset"
echo "================================================================="
cd Resources
curl https://github.com/Squizzy/xmj-script/blob/development/icns/xmj.icns -O xmj.icns
cd ..

cd ../../..


# Download the iconset from Squizzy's github straight into the Resources folder
echo "================================================================="
echo " Copy the app bundle to the Applications folder/Launchpad"
echo "================================================================="
cp -R XMJ\ Mahjong.app /Applications


# Below is content that is unnecessary now - for my reference just in case
####################################
#
# Make the App bundle complete
#
####################################
#
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

# echo "========================================================"
# echo " Download dylibbundler"
# echo "========================================================"

# # Install the app using homebrew
# brew install dylibbundler

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
