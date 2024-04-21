#!/bin/sh

# Script to install Julian Bradfield XMJ Mahjong to MacOS
#
#   Credit for the great game and neat implentation:
#   https://mahjong.julianbradfield.org/
#
# This script:
# 2024-04-22 - Version 0.1
# https://github.com/Squizzy/

####################################
#
# Prepare and Download
#
####################################
#
# Creare a folder for the setup
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

# - in gui.c:
# change
#     `char address[256] = "localhost:5000";`
# to 
#     `char address[256] = "localhost:4000";`
cp gui.c gui.c.backup
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
cp controller.c controller.c.backup
sed -i "" 's/char \*address = ":5000";/char \*address = ":4000";/' controller.c

# - in greedy.c:
# change
#   `char *address = ":5000";`
# to
#   `char *address = ":4000";`
cp greedy.c greedy.c.backup
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
#
# The below line executes this, which does exactly that:
#
# sed -i "" 's/strcpy(cmd,"mj-server --id-order-seats --server ");/
#   ifndef macOS\n\t\t\t\t
#       strcpy(cmd,"mj-server --id-order-seats --server ");\n\t\t\t
#   else\n\t\t\t\t
#       strcpy(cmd, "\.\/mj-server --id-order-seats --server ");\n\t\t\t
#   endif
# /' gui.c
sed -i "" 's/strcpy(cmd,"mj-server --id-order-seats --server ");/#ifndef macOS\n\t\t\t\tstrcpy(cmd,"mj-server --id-order-seats --server ");\n\t\t\t#else\n\t\t\t\tstrcpy(cmd, "\.\/mj-server --id-order-seats --server ");\n\t\t\t#endif/' gui.c

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
#
# The below line executes this, which does exactly that:
#
# sed -i "" 's/strcpy(cmd,"mj-player --server ");/
#     ifndef macOS\n\t\t
#         strcpy(cmd,"mj-player --server ");\n\t
#     else\n\t\t
#         strcpy(cmd,"\.\/mj-player --server ");\n\t
#     endif
# /' gui.c

sed -i "" 's/strcpy(cmd,"mj-player --server ");/#ifndef macOS\n\t\tstrcpy(cmd,"mj-player --server ");\n\t#else\n\t\tstrcpy(cmd,"\.\/mj-player --server ");\n\t#endif/' gui.c

# This concludes the essential code changes - could be done in a smarter way, presumably.


####################################
#
# Make the executables
#
####################################
#
# Install Homebrew, a package manager (installs stuff needed to run xmj)
# https://brew.sh/

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# Install GTK+, a package needed for the making the graphical interface from homebrew
brew install gtk+

# Install pkg-config from homebrew
brew install pkg-config

# Make the executables
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
cd Contents
echo '#!/bin/bash
    cd "${0%/*}"
    ./xmj' > xmj-script

# make this script executable
chmod +x xmj-script


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

echo "In order to trust you application, you should create the icon set following instructions."
echo "Alternatively, the file can be downloaded from the github this script was gotten from"
echo "By default you should not trust this file and create your own"
echo "based on the XMJ original icon file: 'icon.ico'"

# Download the iconset from Squizzy's github
# curl 