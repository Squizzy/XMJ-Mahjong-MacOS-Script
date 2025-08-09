#!/bin/bash

# Script to install Julian Bradfield XMJ Mahjong to MacOS
#
#   Credit for the great game and neat implentation:
#   https://mahjong.julianbradfield.org/
#
# This script:
# 2025-08-09 - Version 0.8 - now adds the non-standard dylib to the bundle to be portable. Several bug fixes. 
# 2025-08-04 - Version 0.7 - Added xmj-1.17 support, switched from manual editing patches to proper patching
# 2025-08-04 - Version 0.6 - Some refactoring for clarity
# 2024-09-06 - Version 0.5 - tested xmj-1.16 (-with-functions version) as working on Sonoma/Intel
# 2024-09-05 - Version 0.4 - structuring into function, untested, probably broken
# 2024-04-24 - Version 0.3 - first Beta
# 2024-04-24 - Version 0.2
# 2024-04-24 - Version 0.1
# https://github.com/Squizzy/

set -e  # Exit immediately if a command exits with a non-zero status
trap 'echo "Error occurred. Exiting..."; exit 1' ERR


XMJ_VERSION="1.17"
DOWNLOAD_ICONSET=true
ENABLE_LOG=false
CLEANUP=false

usage() {
    echo "Usage: $0 [-v version] [-c] [-d] [-l] [-h]"
    echo "  -v version  Specify XMJ version (default: 1.16)"
    echo "  -c          Enable cleanup after installation (default: false)"
    echo "  -d          Download iconset disable (default: true)"
    echo "  -l          Enable log (default: disabled)"
    echo "  -h          Display this help message"
    exit 1
}

# Check if a version was specified in the command line, in which case, overwrite above
while getopts ":v:lcdh" opt; do
  case $opt in
    v) XMJ_VERSION="$OPTARG" ;;
    l) ENABLE_LOG=true ;;
    c) CLEANUP=true ;;
    d) DOWNLOAD_ICONSET=false ;;
    h) usage ;;
    \?) echo "Invalid option -$OPTARG." >&2; exit 1 ;;
  esac
done

# Source file name and remote location
XMJ_SRC_FILENAME="mj-$XMJ_VERSION-src"
XMJ_SRC_FILENAME_COMPRESSED=$XMJ_SRC_FILENAME".tar.gz"

XMJ_SRC_WEBSITE="https://mahjong.julianbradfield.org/Source"
XMJ_SRC_REMOTE_FILE="$XMJ_SRC_WEBSITE/$XMJ_SRC_FILENAME_COMPRESSED"

# Apple Application Bundle specifics
APP_NAME="XMJ Mahjong.app"
APP_CONTENTS_FOLDER_NAME="Contents"
APP_EXECUTABLES_FOLDER_NAME="MacOS"
APP_RESOURCES_FOLDER_NAME="Resources"
APP_LIBS_FOLDER_NAME="Libs"
APP_INFO_PLIST_NAME="Info.plist"
MINI_SCRIPT_NAME="xmj-script"

# The file that should be executed to launch the game
APP_EXECUTABLE="$MINI_SCRIPT_NAME"

# Where the patches are stored
PATCHES_FOLDER_NAME="patches"


CURRENT_FOLDER=$(pwd)
TEMP_FOLDER_NAME="XMJ-MacOS-Prep"

TEMP_FOLDER="$CURRENT_FOLDER/$TEMP_FOLDER_NAME"

XMJ_UNCOMPRESS_FOLDER="$TEMP_FOLDER/$XMJ_SRC_FILENAME"

APP_FOLDER="$TEMP_FOLDER/$APP_NAME"
APP_CONTENTS_FOLDER="$APP_FOLDER/$APP_CONTENTS_FOLDER_NAME"
APP_EXECUTABLES_FOLDER="$APP_CONTENTS_FOLDER/$APP_EXECUTABLES_FOLDER_NAME"
APP_RESOURCES_FOLDER="$APP_CONTENTS_FOLDER/$APP_RESOURCES_FOLDER_NAME"
APP_LIBS_FOLDER="$APP_CONTENTS_FOLDER/$APP_LIBS_FOLDER_NAME"
APP_INFO_PLIST_LOCATION="$APP_CONTENTS_FOLDER/$APP_INFO_PLIST_NAME"

MINI_SCRIPT_LOCATION="$APP_EXECUTABLES_FOLDER/$MINI_SCRIPT_NAME"

PATCHES_FOLDER="$CURRENT_FOLDER/$PATCHES_FOLDER_NAME"


# CREATE_BACKUP=false

XCODE_INSTALLED=true
BREW_INSTALLED=true
GTK_INSTALLED=true
GTK_NEEDS_UPDATE=false
PKG_CONFIG_INSTALLED=true
PKG_CONFIG_NEEDS_UPDATE=false
DYLIBBUNDLER_INSTALLED=true
DYLIBBUNDLER_NEEDS_UPDATING=false



log() {
  ####################################
  ## Log helper function
  ####################################
  if [ "$ENABLE_LOG" = true ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  fi
}

confirm() {
  ####################################
  ## User confirmation helper function
  ##
  ## Prompts the user for confirmation with a yes/no question
  ## Returns true if the user confirms, false otherwise
  ####################################
  read -r -p "$1 [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) 
        true
        ;;
    *)
        false
        ;;
  esac
}

check_dependencies() {
  ####################################
  ## Check dependencies
  ## Checks if the required dependencies are installed
  ## If not, informs the user to install them and exit
  ####################################
  echo ""
  echo "================================================================="
  echo " Checking dependencies"
  echo "================================================================="
  
  log "Checking dependencies"
  command -v curl >/dev/null 2>&1 || { echo >&2 "curl is required but not installed. Aborting."; exit 1; }
  command -v tar >/dev/null 2>&1 || { echo >&2 "tar is required but not installed. Aborting."; exit 1; }
  command -v sed >/dev/null 2>&1 || { echo >&2 "sed is required but not installed. Aborting."; exit 1; }
  command -v patch >/dev/null 2>&1 || { echo >&2 "patch is required but not installed. Aborting."; exit 1; }
  command -v make >/dev/null 2>&1 || { echo >&2 "make is required but not installed. Aborting."; exit 1; }
  command -v otool >/dev/null 2>&1 || { echo >&2 "otool is required but not installed. Aborting."; exit 1; }
  command -v install_name_tool >/dev/null 2>&1 || { echo >&2 "install_name_tool is required but not installed. Aborting."; exit 1; }
  command -v iconutil >/dev/null 2>&1 || { echo >&2 "iconutil is required but not installed. Aborting."; exit 1; }

  # Dependencies that the script will check for brew installed software
  command -v xcode-select >/dev/null 2>&1 || { XCODE_INSTALLED=false; }
  command -v brew >/dev/null 2>&1 || { BREW_INSTALLED=false; }
  brew list gtk+ >/dev/null 2>&1 || { GTK_INSTALLED=false; }
  brew outdated gtk+ >/dev/null 2>&1 || { GTK_NEEDS_UPDATE=true; }
  brew list pkg-config >/dev/null 2>&1 || { PKG_CONFIG_INSTALLED=false; }
  brew outdated pkg-config >/dev/null 2>&1 || { PKG_CONFIG_NEEDS_UPDATE=true; }
  brew list dylibbundler >/dev/null 2>&1 || { DYLIBBUNDLER_INSTALLED=false; }
  brew outdated dylibbundler >/dev/null 2>&1 || { DYLIBBUNDLER_NEEDS_UPDATING=true; }


  if [ "$ENABLE_LOG" = true ]; then
    log "All dependencies are installed"
  fi

  echo " Dependencies check complete"
  echo "================================================================="

}

handle_xmj_in_Applications_folder() {
  ####################################
  ## Check if XMJ Mahjong is found in the Applications folder
  ##
  ## If yes, ask the user if they want to replace it
  ## If yes, removes the existing installation
  ####################################
  echo ""
  echo "================================================================="
  echo " Checking for existing XMJ Mahjong installation"
  echo "================================================================="

  log "Checking for existing XMJ Mahjong installation"

  if [ -d "/Applications/$APP_NAME" ]; then
    if confirm "XMJ Mahjong found in Applications folder. Replace it?"; then
      log "Removing existing installation"
      rm -rf "/Applications/$APP_NAME"
      echo " XMJ Mahjong in Applications folder removed"
    else
      log "Installation cancelled by user"
      exit 0
    fi
  fi

  echo " No XMJ Mahjong found in Applications folder"
  echo " or user chose to reinstall"
  echo "================================================================="
}

create_temp_folder(){
  ####################################
  ## Create the App Bundle preparation folder
  ##
  ## This is where the source code will be downloaded and prepared
  ## It will also contain the App Bundle tree
  ## This folder will be removed at the end of the installation
  ## unless the user chooses to keep it
  ## This is also where the patches will be stored
  ## This folder will be created in the current working directory
  ## The folder will be named XMJ-MacOS-Prep
  ####################################
  echo ""
  echo "================================================================="
  echo " Creating temporary folder for XMJ Mahjong app bundle preparaton"
  echo "================================================================="

  log "Creating temp folder"

  if [ -d "$TEMP_FOLDER" ]; then
    log "Removing existing temporary folder $TEMP_FOLDER"
    rm -rf "$TEMP_FOLDER"
  fi
  
  mkdir "$TEMP_FOLDER" || { echo "create_temp_folder: Failed to create ${TEMP_FOLDER}"; exit; }
  
  # if [ -d "$TEMP_FOLDER" ]; then
  #   log "Temporary folder $TEMP_FOLDER created"
  # else
  #   log "Failed to create temporary folder $TEMP_FOLDER"
  #   exit 1
  # fi

  echo " Temporary folder $TEMP_FOLDER created"
  echo "================================================================="
}

xmj_download_src() {
  ####################################
  ## Download the source code from the author's website
  ## for the specified version
  ####################################
  echo ""
  echo "================================================================="
  echo " Downloading application source from author's website"
  echo "================================================================="

  log "Downloading application source from author's website"

  # Change to the temporary folder
  pushd "$TEMP_FOLDER" || { echo "xmj_download_src: Failed to change directory to ${TEMP_FOLDER}"; exit; }

  # Download XMJ Mahjong source code from its original website (from Julian Bradfield)
  # curl https://mahjong.julianbradfield.org/Source/mj-1.16-src.tar.gz -O mj-1.16-src.tar.gz
  echo "$XMJ_SRC_REMOTE_FILE"
  echo "$XMJ_SRC_FILENAME_COMPRESSED"

  if ! curl -O "$XMJ_SRC_REMOTE_FILE" ; then
    echo "xmj_download_src: Failed to download xmj source file for: $XMJ_SRC_REMOTE_FILE"
    log "Failed to download source file"
    exit 1
  fi

  if [ ! -f "$XMJ_SRC_FILENAME_COMPRESSED" ]; then
    log "Source file $XMJ_SRC_FILENAME_COMPRESSED not found after download"
    echo "xmj_download_src: Source file $XMJ_SRC_FILENAME_COMPRESSED not found after download"
    exit 1
  fi
  log "Source file $XMJ_SRC_FILENAME_COMPRESSED downloaded successfully"

  echo " Source code downloaded to $TEMP_FOLDER/$XMJ_SRC_FILENAME_COMPRESSED"
  echo "================================================================="

  # Return to the original folder
  popd
}

xmj_uncompress_src() {
  ####################################
  ## Uncompress the downloaded application source code
  ##
  ## This creates the folder $XMJ_UNCOMMPRESS_FOLDER under $TEMP_FOLDER
  ## and extracts the source in it using
  ##   tar -zxvf ./mj-$XMJ_VERSION-src.tar.gz
  ####################################
  echo ""
  echo "================================================================="
  echo " Uncompressing source code"
  echo "================================================================="

  log "Uncompressing source code"

  # Change to the temporary folder
  pushd "$TEMP_FOLDER" || { echo "xmj_uncompress_src: Failed to change directory to ${TEMP_FOLDER}"; exit 1; }

  tar -zxvf ./"$XMJ_SRC_FILENAME_COMPRESSED" || { echo "xmj_uncompress_src: Failed to uncompress ${XMJ_SRC_FILENAME_COMPRESSED}"; exit 1; }

  # # Secondary check for success: if the folder resulting from decompession is not there, fail 
  # if [ -d "$XMJ_UNCOMPRESS_FOLDER" ]; then
  #   log "Source code uncompressed to $XMJ_UNCOMPRESS_FOLDER"
  # else
  #   log "folder $XMJ_UNCOMPRESS_FOLDER not found after uncompression, suspecting problem with decompression"
  #   exit 1
  # fi

  echo " Source code uncompressed to $XMJ_UNCOMPRESS_FOLDER"
  echo "================================================================="

  # Change back to the original folder
  popd
}

xmj_check_files_to_be_patched() {
  ####################################
  ## Check if the files to be patched are identical to the ones used to create the patches.
  ##
  ## This is to ensure that the patches are not applied to an incorrect version of the source code.
  ## Currently this only works for xmj 1.17
  ####################################
  echo ""
  echo "================================================================="
  echo " Checking that the source files to be patched are present and"
  echo " identical to the ones used to create the patches"
  echo "================================================================="

  log "Checking source files to be patched"

  if [ ! -f "$XMJ_UNCOMPRESS_FOLDER/gui.c" ]; then
    echo "Source file gui.c does not exist in $XMJ_UNCOMPRESS_FOLDER. Please check the download."
    exit 1
  fi

  if [ ! -f "$XMJ_UNCOMPRESS_FOLDER/controller.c" ]; then
    echo "Source file controller.c does not exist in $XMJ_UNCOMPRESS_FOLDER. Please check the download."
    exit 1
  fi

  if [ ! -f "$XMJ_UNCOMPRESS_FOLDER/greedy.c" ]; then
    echo "Source file greedy.c does not exist in $XMJ_UNCOMPRESS_FOLDER. Please check the download."
    exit 1
  fi

  if ! diff "$XMJ_UNCOMPRESS_FOLDER/gui.c" -q "$PATCHES_FOLDER/xmj_$XMJ_VERSION/gui_xmj_$XMJ_VERSION.c"; then
    echo "Source file $XMJ_UNCOMPRESS_FOLDER/gui.c is not identical to the file needed to be patched: $PATCHES_FOLDER/xmj_$XMJ_VERSION/gui_xmj_$XMJ_VERSION.c. Please check the download."
    exit 1
  fi

  if ! diff "$XMJ_UNCOMPRESS_FOLDER/controller.c" -q "$PATCHES_FOLDER/xmj_$XMJ_VERSION/controller_xmj_$XMJ_VERSION.c"; then
    echo "Source file $XMJ_UNCOMPRESS_FOLDER/controller.c is not identical to the file needed to be patched. Please check the download."
    exit 1
  fi

  if ! diff "$XMJ_UNCOMPRESS_FOLDER/greedy.c" -q "$PATCHES_FOLDER/xmj_$XMJ_VERSION/greedy_xmj_$XMJ_VERSION.c"; then
    echo "Source file $XMJ_UNCOMPRESS_FOLDER/greedy.c is not identical to the file needed to be patched. Please check the download."
    exit 1
  fi

  echo " All source files are identical to the files needed to be patched."
  echo "================================================================="
}

xmj_create_patches_for_version() {
  ####################################
  ## Create the patches for the version 
  ##
  ## Currently only version 1.17 (latest) has patches
  ####################################
  echo ""
  echo "================================================================="
  echo " Generating the patch files for version $XMJ_VERSION"
  echo "================================================================="

  log "Generating the patch files for version $XMJ_VERSION"

  # go to the patches folder
  pushd "$PATCHES_FOLDER" || { echo "xmj_create_patches: Failed to change directory to patches"; exit 1; }

  # Create the patches for the source files
  sh create_patches_for_version.sh -v "$XMJ_VERSION" || { echo "xmj_create_patches: Failed to create patches for version $XMJ_VERSION"; exit; }

  echo " Patches files for xmj_$XMJ_VERSION created"
  echo "================================================================="

  # return to the previous folder
  popd
}

xmj_adjust_src_port_number() {
  ####################################
  ## Adjust source for Apple port issue
  ##
  ## Apple has now bound some of its applications to the port 5000
  ## which has also been used as the default socket port by XMJ Mahjong.
  ##
  ## This has always been the default for XMJ Mahjong, but Apple's use
  ## makes it impossible for xmj to request it (and therefore run)
  ##
  ## This patch modifies the default port of XMJ Mahjong on MacOS to 4000.
  ## This value can still be altered in the game
  ## but setting it back to 5000 in MacOS will cause the game to not run
  ####################################
  echo ""
  echo "================================================================="
  echo " Modify source code as needed for Apple"
  echo ""
  echo " IMPORTANT NOTE: As Apple now uses port 5000 for its own functionality"
  echo " this redefines it to port 4000. On non-Apple XMJ, this value will need"
  echo " to be matched. 4000 can be changed in-gamme as desired as long as it is "
  echo " not a port number used by any of the application"
  echo "================================================================="

  log "Adjusting port number in source"

  patch -u "$XMJ_UNCOMPRESS_FOLDER"/gui.c -i "$PATCHES_FOLDER"/gui_xmj_"$XMJ_VERSION"_socket_port_fix.patch || { echo "xmj_adjust_src_port_number: Failed to patch gui.c"; exit; }
  patch -u "$XMJ_UNCOMPRESS_FOLDER"/controller.c -i "$PATCHES_FOLDER"/controller_xmj_"$XMJ_VERSION"_socket_port_fix.patch || { echo "xmj_adjust_src_port_number: Failed to patch controller.c"; exit; }
  patch -u "$XMJ_UNCOMPRESS_FOLDER"/greedy.c -i "$PATCHES_FOLDER"/greedy_xmj_"$XMJ_VERSION"_socket_port_fix.patch || { echo "xmj_adjust_src_port_number: Failed to patch greedy.c"; exit; }

  echo " Patches to adjust default network port number from 5000 to 4000 applied"
  echo "================================================================="
}

xmj_adjust_src_executables_path() {
  ####################################
  ## NOW IRRELEVANT as the script sets the required local path
  ##
  ## Sets the game path to mj-player and mj-server to the 
  ## relative same path as the main executable ('./')
  ##
  ## By default, XMJ loads the mj-player and mj-server executables by finding them
  ## in the PATH variable.
  ##
  ## When using bundles, a PATH variable is not generally created, and
  ## for security reason, Apple does not look in the same folder when 
  ## the relative path './' is not set
  ##
  ## For the moment, the solution is to patch the source code to add the './' to the 
  ## way the execution of the mj-player and mj-server are made
  ##
  ####################################
  echo ""
  echo "================================================================="
  echo " Adjusting executable relative paths in source code"
  echo ""
  echo " When apps are placed in Apple bundles, the main executable if expected to be found in /Contents/MacOS"
  echo " If this main executable needs to run other executables, these need to be found in this bundle."
  echo " by default the PATH variable would be looked for to find an executable but this doesn't work"
  echo " as it is not reasonable to have a path per app bundle."
  echo " Current fix is to make sure the other executables are in the same folder and are called using the './' local path."
  echo "================================================================="

  log "Adjusting executable relative paths in source"

  patch -u "$XMJ_UNCOMPRESS_FOLDER"/gui.c -i "$PATCHES_FOLDER"/gui_xmj_"$XMJ_VERSION"_executables_relative_path_fix.patch || { echo "xmj_adjust_src_executables_path: Failed to patch gui.c"; exit; }

  echo " Patches to adjust executables relative paths done"
  echo "================================================================="
}
# This concludes the essential code changes - could be done in a smarter way, presumably.

xmj_patch_tiles_display_bug_fix_for_xmj_1_17() {
  ####################################
  ## Tiles display Bug fix patch for xmj-1.17
  ##
  ## In MacOS, The tiles are not displayed correctly in v1.17.
  ## This is caused by the default colour values used for the gdk_draw_pixbuf
  ## in the MacOS variant,these is not well referenced in the gtk+ port. 
  ##
  ## This can be fixed by not allowing the use of the default values,
  ## by overriding the default value with a defined Graphics Context done
  ##
  ## gdk_draw_pixbuf is a new improvement in xmj-1.17, which is not present in xmj-1.16 and before
  ## Its use modernises the implementation of XMJ and allows fixing of some issues
  ## observed in previous versions
  ####################################
  echo ""
  echo "================================================================="
  echo " Tiles Display Bug fix for xmj-1.17"
  echo "================================================================="

  log "Tiles display Bug fix for xmj-1.17"

  # Fix the bug in gui.c
  patch -u "$XMJ_UNCOMPRESS_FOLDER"/gui.c -i "$PATCHES_FOLDER"/gui_xmj_"$XMJ_VERSION"_tiles_display_fix.patch || { echo "xmj_patch_tiles_display_bug_fix_for_xmj_1_17: Failed to patch gui.c"; exit; }

  echo " Tiles Display Bug fix for xmj-1.17 applied"
  echo "================================================================="
}

check_xcode_cli_tools() {
  ####################################
  ## Check if Xcode Command Line Tools are installed
  ##
  ## If not, prompt the user to install them
  ## 
  ####################################
  echo ""
  echo "================================================================="
  echo " Installing Xcode Command Line Tools (if not present)"
  echo "================================================================="

  log "Installing Xcode Command Line Tools (if not present)"

  if [ "$XCODE_INSTALLED" = false ]; then
    log "Xcode Command Line Tools are not installed. Installing them now..."
    xcode-select --install || { echo "check_xcode_cli_tools: Failed to install the tools"; exit 1; }
    echo " Xcode Command Line Tools installed successfully"
  else
    log " Xcode Command Line Tools are already installed, skipping"
    echo " Xcode Command Line Tools are already installed, skipping"
  fi

  echo "================================================================="
}

install_compiling_essentials() {
  ####################################
  ## Install essential files for compiling
  ##
  ## Install Homebrew, a package manager (https://brew.sh/)
  ## Then installs gtk+ and pkg-config which are needed to compile XMJ
  ####################################
  echo ""
  echo "================================================================="
  echo " Installing or updating Homebrew"
  echo " Then installing the required packages to compile XMJ Mahjong"
  echo "================================================================="

  log "Installing compiling essentials"

  # Install or upgrade homebrew, if needed
  if [ "$BREW_INSTALLED" = false ]; then
    log "Homebrew is not installed. Installing it now..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"  || { echo "install_compiling_essentials: Failed to install Homebrew"; exit 1; }
    echo " Homebrew installed successfully"
  else
    log "Homebrew is already installed. Updating it..."
    brew update || { echo "install_compiling_essentials: Failed to update Homebrew, skipping."; }
    echo " Homebrew updated successfully"
  fi


  # Install or update GTK+ using homebrew, if needed
  if [ "$GTK_INSTALLED" = false ]; then
    log "GTK+ is not installed. Installing it now..."
    brew install gtk+  || { echo "install_compiling_essentials: Failed to install gtk+"; exit 1; }
    echo " GTK+ installed successfully"
  else 
    if [ "$GTK_NEEDS_UPDATE" = true ]; then
      log "GTK+ is installed but needs to be updated. Updating it now..."
      brew upgrade gtk+ || { echo "install_compiling_essentials: Failed to update gtk+, skipping."; }
      echo "GTK+ upgraded successfully"
    else
      log "GTK+ is already installed and up to date."
      echo " GTK+ is already installed and up to date."

    fi
  fi

  # Install or upgrade pkg-config using homebrew, if needed
  if [ "$PKG_CONFIG_INSTALLED" = false ]; then
    log "pkg-config is not installed. Installing it now..."
    brew install pkg-config || { echo "install_compiling_essentials: Failed to install pkg-config"; exit 1; }
    echo " pkg-config installed successfully"
  else 
    if [ "$PKG_CONFIG_NEEDS_UPDATE" = true ]; then
      log "pkg-config is installed but needs to be updated. Updating it now..."
      brew upgrade pkg-config   || { echo "install_compiling_essentials: Failed to update pkg-config, skipping."; }
      echo " pkg-config upgraded successfully"
    else
      log "pkg-config is already installed and up to date."
      echo " pkg-config is already installed and up to date."
    fi
  fi

  echo ""
  echo " -> Compiling essentials installed successfully"
  echo "================================================================="
}

make_executables() {
  #####################################
  ## Make the XMJ executables
  ##
  ## This will compile the source code and create the executables
  ## The executables will be created in the extracted source folder
  ## The executables are:
  ##   - xmj
  ##   - mj-player
  ##   - mj-server
  ## The compilation is done using the make command
  ## and the Makefile provided by the XMJ author
  #####################################
  echo ""
  echo "================================================================="
  echo " Creating the executables"
  echo "================================================================="

  log "Making the executable"

  # Go to the extracted folder
  pushd "$XMJ_UNCOMPRESS_FOLDER" || { echo "make_executables: Failed to change directory to extracted ${XMJ_UNCOMPRESS_FOLDER}"; exit; }

  make clean || { echo "make_executables: Failed to clean make"; exit 1;}

  if ! make; then
    log "make command failed. Please check the output for errors."
    echo " Make failed, please check the output for errors."
    exit 1
  fi

  echo " Executables created in ${XMJ_UNCOMPRESS_FOLDER}"
  echo "================================================================="

  # Change back to the original folder
  popd
}

app_bundle_create_tree() {
  ####################################
  ## Create the App Bundle tree
  ##
  ## A MacOS app is stored under a tree (the roof of which is the name of the app)
  ## This enables the application to appears Launchpad when saved under /Applications
  ##
  ## An App bundler is a folder tree containing the executable
  ##    (in MacoOS folder)
  ## some resources such as the iconset.
  ##    (in Resources folder)
  ## In the case of XMJ, it needs to also contain the tilesets for the game 
  ##    (in MacOS folder - as need to be relative to the executable)
  ## and for portability, it should contain the linked librairies
  ##    (in Libs folder)
  ##
  ## XMJ Mahjong.app/
  ##    + Contents/
  ##      - Info.plist
  ##      + MacOS/
  ##        - xmj
  ##        - mj-player
  ##        - mj-server
  ##        - xmj-script
  ##        + tiles_numbered/
  ##          - (*.xpm)
  ##        + tiles_small/
  ##          - (*.xpm)
  ##        + tiles_v1/
  ##          - (*.xpm)
  ##        + fallbacktiles/
  ##          - (*.xpm)
  ##      + Resources/
  ##        - xmj.icns
  ##      + Libs/
  ##        - (libs)
  ##
  ## Legend:
  ## +: folder
  ## -: file
  ## -: (bunch of files)
  ########################################
  echo ""
  echo "================================================================="
  echo " Creating folders tree that is the App Bundle"
  echo "================================================================="

  log "Creating App Bundle folder tree"

  if [ -d "$APP_FOLDER" ]; then
    log "Removing existing App Bundle folder ${APP_FOLDER}"
    rm -rf "$APP_FOLDER"
  fi

  mkdir "$APP_FOLDER" || { echo "app_bundle_create_tree: Failed to create folder${APP_FOLDER}"; exit; }
  mkdir "$APP_CONTENTS_FOLDER" || { echo "app_bundle_create_tree: Failed to create folder ${APP_CONTENTS_FOLDER}"; exit; }
  mkdir "$APP_EXECUTABLES_FOLDER" || { echo "app_bundle_create_tree: Failed to create folder ${APP_EXECUTABLES_FOLDER}"; exit; }
  mkdir "$APP_RESOURCES_FOLDER" || { echo "app_bundle_create_tree: Failed to create folder ${APP_RESOURCES_FOLDER}"; exit; }
  mkdir "$APP_LIBS_FOLDER" || { echo "app_bundle_create_tree: Failed to create folder ${APP_LIBS_FOLDER}"; exit; }

  echo " App Bundle folder tree created in ${APP_FOLDER}"
  echo "================================================================="
}

app_bundle_create_info_plist() {
  ####################################
  ## Create the Info.plist file
  ##
  ## The Info.plist file  instructs which file to execute and where some resources are stored
  ##
  ##
  ## For initial understanding, specific credit though to: Hayden Schiff under:
  ## https://stackoverflow.com/questions/1596945/building-osx-app-bundle
  ##
  ## Also Apple Developer documentation: (this archive seems easier to navigate than the new doc)
  ## https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/TP40009249-SW1
  ####################################
  echo ""
  echo "================================================================="
  echo " Create Info.plist in Contents folder"
  echo "================================================================="

  log "Creating App Bundle plist"

  # cd "$APP_NAME/Contents" || { echo "app_bundle_create_info_plist: Failed to change directory to ${APP_NAME}"; exit; }


  # set the variables of interest
  CF_BUNDLE_DISPLAY_NAME="XMJ Mahjong"
  CF_BUNDLE_NAME="$CF_BUNDLE_DISPLAY_NAME"
  CF_BUNDLE_INFO_STRING="XMJ Mahjong (c) 2000-now by Julian Bradfield"
  # CF_BUNDLE_IDENTIFIER="com.xmj-mahjong.www"
  CF_BUNDLE_IDENTIFIER="org.julianbradfield.mahjong" # This appears more appropriate than the above
  # CF_BUNDLE_EXECUTABLE="xmj" # This is the main executable file
  CF_BUNDLE_EXECUTABLE="$APP_EXECUTABLE" # This is the script that could be executed instead of the main executable
  CF_BUNDLE_VERSION="$XMJ_VERSION"
  CF_BUNDLE_SHORT_VERSION="$XMJ_VERSION.0" # maintenance version is not specified in the original
  CF_BUNDLE_ICON_FILE="xmj"
  CF_BUNDLE_INFO_DICT_VERSION="6.0" # Specified by Apple
  CF_BUNDLE_PACKAGE_TYPE="APPL" # Application bundle
  LS_MINIMUM_SYSTEM_VERSION="10.13" # Minimum macOS version supported (Sequoia, 2024) - for now


  # Build up the info.plist variables
  INFO_PLIST_CONTENT=$(cat <<EndOfText
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleDisplayName</key>
    <string>${CF_BUNDLE_DISPLAY_NAME}</string>
    <key>CFBundleName</key>
    <string>${CF_BUNDLE_NAME}</string>
    <key>CFBundleGetInfoString</key>
    <string>${CF_BUNDLE_INFO_STRING}</string>
    <key>CFBundleIdentifier</key>
    <string>${CF_BUNDLE_IDENTIFIER}</string>
    <key>CFBundleExecutable</key>
    <string>${CF_BUNDLE_EXECUTABLE}</string>
    <key>CFBundleVersion</key>
    <string>${CF_BUNDLE_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${CF_BUNDLE_SHORT_VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>${CF_BUNDLE_ICON_FILE}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>${CF_BUNDLE_INFO_DICT_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>${CF_BUNDLE_PACKAGE_TYPE}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${LS_MINIMUM_SYSTEM_VERSION}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
  </dict>
</plist>
EndOfText
  )

  # Save the info.plist file
  printf '%s' "$INFO_PLIST_CONTENT" > "$APP_INFO_PLIST_LOCATION"  || { echo "app_bundle_create_info_plist: Failed to save ${APP_INFO_PLIST_LOCATION}"; exit 1; }

  echo " Info.plist created in ${APP_INFO_PLIST_LOCATION}"
  echo "================================================================="
}

app_bundle_create_launch_miniscript() {
  ####################################
  ## Create the miniscript to launch the app
  ##
  ## This script's purpose is to make the local folder of the executable 
  ## the current working folder. This is because by default when launching
  ## an app from a bundle, the current working folder is the folder 
  ## where the app is, like /Applications
  ##
  ## It is also used to intialise some variables for portability
  ## so it does not depend on other installed libraries
  ##
  ## this script is stored in the MacOS folder of the App Bundle
  ####################################
  echo ""
  echo "================================================================="
  echo " Create miniscript in Contents/MacOS folder"
  echo "================================================================="

  log "Creating App Bundle launch miniscript"
  
  MINI_SCRIPT_CONTENT=$(cat <<EndOfText
#!/bin/bash

# Change to the folder this script is in
cd "\${0%/*}"

# Export the path so mj-player and mj-server are found (without patching)
export PATH="\$(pwd):\$PATH"

# identify the root of the app bundle (2 folders above the current script)
APP_FOLDER="\$(dirname "\$0")/../.."

# Ensure that the needed pixbuf references are loaded
export GDK_PIXBUF_MODULE_FILE="\$APP_FOLDER/Contents/Libs/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export GDK_PIXBUF_MODULEDIR="\$APP_FOLDER/Contents/Libs/gdk-pixbuf-2.0/2.10.0/loaders"

# Ensure that the dylib references the app bundle's
export DYLD_LIBRARY_PATH="\$APP_FOLDER/Contents/Libs"

# Run the app
exec "\$APP_FOLDER/Contents/MacOS/xmj" "\$@" 
EndOfText
)

  printf '%s' "$MINI_SCRIPT_CONTENT" > "$MINI_SCRIPT_LOCATION" || { echo "app_bundle_create_launch_miniscript: Failed to save ${MINI_SCRIPT_LOCATION}"; exit 1; }

  chmod +x "$MINI_SCRIPT_LOCATION"  || { echo "app_bundle_create_launch_miniscript: Failed to make the miniscript executable"; exit 1; }

  echo " xmj-script successfully created in ${MINI_SCRIPT_LOCATION}"
  echo "================================================================="
}

app_bundle_copy_executables() {
  ####################################
  ## Copy the executables and the tiles
  ## to the Contents/MacOS folder
  ####################################
  echo ""
  echo "================================================================="
  echo " Copy the executables into the Contents/Macos folder"
  echo "================================================================="

  log "copying executables in App Bundle "

  cp "$XMJ_UNCOMPRESS_FOLDER"/xmj       "$APP_EXECUTABLES_FOLDER"/
  cp "$XMJ_UNCOMPRESS_FOLDER"/mj-player "$APP_EXECUTABLES_FOLDER"/
  cp "$XMJ_UNCOMPRESS_FOLDER"/mj-server "$APP_EXECUTABLES_FOLDER"/

  echo " Executables copied to ${APP_EXECUTABLES_FOLDER}"
  echo "================================================================="
}

app_bundle_copy_tilesets() {
  ####################################
  ## Copy the executables and the tiles
  ## to the Contents/MacOS folder
  ####################################
  echo ""
  echo "================================================================="
  echo " Copy the tilesets into the Contents/Macos folder"
  echo "================================================================="

  log "copying tilesets in App Bundle "

  cp -pR "$XMJ_UNCOMPRESS_FOLDER"/tiles-numbered "$APP_EXECUTABLES_FOLDER"/
  cp -pR "$XMJ_UNCOMPRESS_FOLDER"/tiles-small    "$APP_EXECUTABLES_FOLDER"/
  cp -pR "$XMJ_UNCOMPRESS_FOLDER"/tiles-v1       "$APP_EXECUTABLES_FOLDER"/
  cp -pR "$XMJ_UNCOMPRESS_FOLDER"/fallbacktiles  "$APP_EXECUTABLES_FOLDER"/

  echo " Tilesets copied to ${APP_EXECUTABLES_FOLDER}"
  echo "================================================================="
}

app_bundle_prepare_and_install_iconset() {
  ####################################
  ## Prepare the iconset for Apple
  ##
  ## To display an icon, macOS app bundle needs a specific file (.icns) 
  ## This file contains multiple icon resolutions. 
  ##
  ## Thankfully it is easy to create:
  ## make the xmj.icns from the xmj.ico provided with the source:
  ##
  ## A/ Manual method:
  ##
  ##   1. Create a folder called xmj.iconset (eg on desktop)
  ##
  ##   2. Create PNG files for the icons in the folder created in 1.
  ##      Ideally start with a 1024x1024 png file and scale down - Here this resolution was not available.
  ##      Gimp (http://gimp.org) was used here)
  ##      All PNG must be square
  ##      PNG names should follow the naming convention below (notice one filename has the @2x suffix)
  ##      Generate all the following resolutions:    
  ##
  ##    1024 x 1024   icon_1024x1024x.png
  ##    1024 x 1024   icon_512x512@2x.png 
  ##     512 x  512   icon_512x512.png  
  ##     512 x  512   icon_256x256@2x.png 
  ##     256 x  256   icon_256x256.png  
  ##     256 x  256   icon_128x128@2x.png 
  ##     128 x  128   icon_128x128.png  
  ##      64 x   64   icon_64x64@2x.png  
  ##      64 x   64   icon_32x32@2x.png  
  ##      32 x   32   icon_32x32.png   
  ##      32 x   32   icon_16x16@2x.png  
  ##      16 x   16   icon_16x16.png   
  ## 
  ##   3. in a terminal, run the following apple command on the folder:
  ##     `iconutil -c icns myicon.iconset`
  ## 
  ## B/ Using existing tool
  ##   There are some very capable apps, like "App Icon Producer", free on the App Store.
  ## 
  ## C/ Download the iconset from Squizzy's github
  ##   This script will do this if the variable DOWNLOAD_ICONSET is set to true
  ##   This should not be the preferred method as less trustable than if you do it yourself
  ##
  ## in the end, you will end up with an iconset `xmj.icns`
  #####################################
  echo ""
  echo "================================================================="
  echo " Generating the xmj iconset for MacOS"
  echo
  echo " In order to trust your application, you should create the iconset yourself"
  echo " Instructions are probided in this script file to do this."
  echo ""
  echo " Alternatively, the file can be downloaded from Squizzy's github (where this script is located)"
  echo ""
  echo " However, by default you should not trust this file and create your own"
  echo " based on the XMJ original icon file: 'icon.ico'"
  echo " This script value 'DOWNLOAD_ICONSET' at the top of the file directs the script "
  echo " to download the icon from Squizzy's github  by default"
  echo ""
  echo " Download can be disabled by changing 'DOWNLOAD_ICONSET=true' to 'DOWNLOAD_ICONSET=false'" 
  echo "================================================================="

  log "Installing iconset in App Bundle "

  if [ "$DOWNLOAD_ICONSET" = true ]; then
    # Download the iconset from Squizzy's github straight into the Resources folder 
    echo ""
    echo "================================================================="
    echo " Downloading iconset"
    echo "================================================================="
    curl -L -O https://github.com/Squizzy/XMJ-Mahjong-MacOS-Script/raw/development/icns/xmj.icns || { echo "app_bundle_prepare_and_install_iconset: Failed to download iconset."; exit 1; }

    mv ./xmj.icns "$APP_RESOURCES_FOLDER"/  || { echo "app_bundle_prepare_and_install_iconset: Failed to copy the iconset to ${APP_RESOURCES_FOLDER}"; exit 1; }

    echo " Iconset downloaded and moved to ${APP_RESOURCES_FOLDER}"

  else
    echo ""
    echo "================================================================="
    echo " iconset provided by you"
    echo "================================================================="
    echo " Remember to copy your iconset to the App Bundle."
    echo " As this script does not stop, you might want to change the one in the Applications folder directly"
    echo " placed at location: ${APP_RESOURCES_FOLDER}"
    echo " File must be named 'xmj.icns' (or modify the Info.plist file to match your icon name)"
    echo ""
    echo " Enter [Y] to continue"
    confirm
  fi
  
  echo "================================================================="
}

# Below two functions with dylibbundler are for portability.
# Currently the below doesn't work fully and the app is not portable with it
# So prefer to use the next, manual, method
install_dylibbundler() {
  ####################################
  ## Install dylibbundler
  ##
  ## The make command creates the executables and uses linked libraries, such as gtk+.
  ## These libraries are not statically linked into the executables, so by default the bundle is not portable.
  ## Whilst this script will download the required libraries, therefore make the application executable 
  ## on the machine where it is compiled, simply copying the app bundle to another machine will not work.
  ##
  ## To fix this:
  ##   - the required libraries need to be copied into the App bundle
  ##   - then the executable files must be instructed where to look for them in the bundle.
  ##
  ## The above can be performed using applications such as `dylibbundler`:
  ##    https://github.com/auriamg/macdylibbundler
  ## However this application has not been updated in a while and 
  ## does not seem to work well any more (with MacOS 15 at least).
  ##
  ## The app can make sure the App Bundle includes all libraries it depends on, 
  ## so the app can be placed in the "Applications" folder.
  ##
  ## The app `dylibbundler` will:
  ## - find all the libraries used for the compilation of the executables, 
  ## - copy them into the bundle (here, creating a new folder `libs` under `XMJ Mahjong.app/Contents/`), 
  ## - points the executables to these versions:
  ####################################
  echo ""
  echo "========================================================"
  echo " Installing dylibbundler from https://github.com/auriamg/macdylibbundler"
  echo " This will identify and load the libraries used by the "
  echo " executables xmj, mj-player and mj-server"
  echo " into the App Bundle, so it can be shared with others"
  echo ""
  echo " The implementation here does not fully work"
  echo " Prefer the alternative method provided"
  echo "========================================================"

  log "installing dylibbundler"

  # Install or upgrade dylibbundler using homebrew if needed
  if [ "$DYLIBBUNDLER_INSTALLED" = false ]; then
    log "dylibbundler is not installed. Installing it now..."
    brew install dylibbundler
    echo " dylibbundler installed successfully"
  else
    if [ "$DYLIBBUNDLER_NEEDS_UPDATING" = true ]; then
      log "dylibbundler is already installed. Updating it..."
      brew upgrade dylibbundler
      echo " dylibbundler updated successfully"
    else
      log "dylibbundler is already installed and up to date."
      echo " dylibbundler already installed and up to date"
    fi
  fi

  echo "========================================================"
}

execute_dylibbundler() {
  ####################################
  ## bundle the dylibs and patch the executable files appropriately
  ##
  ## flags used (probaby some redundance built in!):
  ##  -x <file>:   executable file to process
  ##  -b:          prepares the dylibs for the distribution
  ##  -d <folder>: folder where the dylibs are stored
  ##  -p <folder>: path from the executables folder to the folder where the dylibs are stored 
  ##  -cd:         create destination folder if it does not exist
  ##  -ns:         disable ad-hoc code signing
  ##  -of:         overwrite files if exist
  ##
  ## https://github.com/auriamg/macdylibbundler
  ##
  ##
  ## TODO: This might need to be applied against the bundled dylibs as well
  ####################################
  echo ""
  echo "========================================================"
  echo " Running dylibbundler"
  echo ""
  echo " This will copy the libraries used by the executables"
  echo " into the App Bundle, so the app bundle can be shared with others"
  echo "========================================================"

  log "Executing dylibbundler "

  dylibbundler -b -d "$APP_LIBS_FOLDER" -p "@executable_path/../$APP_LIBS_FOLDER_NAME" -cd -ns -of -x "$APP_EXECUTABLES_FOLDER/xmj" 
  
  dylibbundler -b -d "$APP_LIBS_FOLDER" -p "@executable_path/../$APP_LIBS_FOLDER_NAME" -cd -ns -of -x "$APP_EXECUTABLES_FOLDER/mj-player"
  
  dylibbundler -b -d "$APP_LIBS_FOLDER" -p "@executable_path/../$APP_LIBS_FOLDER_NAME" -cd -ns -of -x "$APP_EXECUTABLES_FOLDER/mj-server"

  echo " dylibbundler executed successfully"
  echo "========================================================"
}


# Below replace the use of dylibbundler
# This is a more manual way to do the same thing, but it is more reliable.
dylib_handling_for_executables_identify_dylibs_to_import() {
  ####################################
  ## Identify the dylibs to import
  ##
  ## This will identify the libraries used by the executables
  ## and store them in the TEMP_FOLDER/dylibs_to_import.txt file
  ## Exclude the standard MacOS libraries
  ####################################
  echo ""
  echo "================================================================="
  echo " Identifying the non-standard dylibs for the executables to the App Bundle"
  echo "================================================================="

  log "Identifying the non-standard dylibs for the executables to the App Bundle"

  # Go to the extracted folder
  pushd "$XMJ_UNCOMPRESS_FOLDER" || { echo "identify_dylibs_to_import: Failed to change directory to extracted ${XMJ_UNCOMPRESS_FOLDER}"; exit; }

  # Use otool to find the libraries used by the executables
  # NR>1 = skip the first line
  # greps out the standard libraries to isolate the non-standard 
  #   libraries used by the app (grep -v means exclude)

  echo " Identifying dylibs used by the executables in ${APP_EXECUTABLES_FOLDER}"

  echo ""
  XMJ_OTOOL=$(otool -L "$APP_EXECUTABLES_FOLDER/xmj" | grep  -v "\/System\/Library\/" | grep -v "\/usr\/lib\/" | awk 'NR>1 {print $1}')
  x=0
  echo "xmj:"
  for item in $XMJ_OTOOL; do
    echo "$x - $item"
    x=$((x+1))
  done

  if [ ! -z "$XMJ_OTOOL" ]; then
    printf "%s" "$XMJ_OTOOL" > "$TEMP_FOLDER"/xmj_dylibs_to_import.txt || { echo "identify_dylibs_to_import: Failed to save dylibs to ${TEMP_FOLDER}/xmj_dylibs_to_import.txt"; exit; }
    echo " xmj dylibs saved to ${TEMP_FOLDER}/xmj_dylibs_to_import.txt"
  else
    echo " No dylibs found for xmj"
  fi

  echo ""
  MJ_PLAYER_OTOOL=$(otool -L "$APP_EXECUTABLES_FOLDER/mj-player" | grep  -v "\/System\/Library\/" | grep -v "\/usr\/lib\/" | awk 'NR>1 {print $1}')
  echo "mj_player:"
  x=0
  for item in $MJ_PLAYER_OTOOL; do
    echo "$x - $item"
    x=$((x+1))
  done

  if [ ! -z "$MJ_PLAYER_OTOOL" ]; then
    printf "%s" "$MJ_PLAYER_OTOOL" > "$TEMP_FOLDER"/mj_player_dylibs_to_import.txt || { echo "identify_dylibs_to_import: Failed to save dylibs to ${TEMP_FOLDER}/mj_player_dylibs_to_import.txt"; exit; }
    echo " mj_player dylibs saved to ${TEMP_FOLDER}/mj_player_dylibs_to_import.txt"
  else
    echo " No dylibs found for mj-player"
  fi

  echo ""
  MJ_SERVER_OTOOL=$(otool -L "$APP_EXECUTABLES_FOLDER/mj-server" | grep  -v "\/System\/Library\/" | grep -v "\/usr\/lib\/" | awk 'NR>1 {print $1}')
  x=0
  echo "mj_server:"
  for item in $MJ_SERVER_OTOOL; do
    echo "$x - $item"
    x=$((x+1))
  done

  if [ ! -z "$MJ_SERVER_OTOOL" ]; then
    printf "%s" "$MJ_SERVER_OTOOL" > "$TEMP_FOLDER"/mj_server_dylibs_to_import.txt || { echo "identify_dylibs_to_import: Failed to save dylibs to ${TEMP_FOLDER}/mj_server_dylibs_to_import.txt"; exit; }
    echo " mj_server dylibs saved to ${TEMP_FOLDER}/mj_server_dylibs_to_import.txt"
  else
    echo " No dylibs found for mj-server"
  fi

  echo ""
  echo " List(s) of identified non-standard dylibs stored in ${TEMP_FOLDER}"
  echo "================================================================="

  # Change back to the original folder
  popd || { echo "identify_dylibs_to_import: Failed to change back to the original folder"; exit; }
}

dylib_handling_for_executables_copy_dylibs_to_import() {
  ####################################
  ## Copy the dylibs to import into the App Bundle
  ## ## This will copy the dylibs identified by the otool command
  ## into the App Bundle
  ####################################
  echo ""
  echo "================================================================="
  echo " Copying the non-standard dylibs for the executables to the App Bundle"
  echo "================================================================="

  log "Copying the non-standard dylibs for the executables to the App Bundle"

  # If there is a file with the list of dylibs to import
  # Then read it line by line (each line contains the absolute path to the lib)
  # If the lib is found, then copy it to the Libs folder
  if [ -f "$TEMP_FOLDER"/xmj_dylibs_to_import.txt ]; then
    echo " Copying xmj dylibs to import"
    # the  '|| [ -n "$dylib" ]' ensures that the last line is read even if there is no line feed
    while IFS= read -r dylib || [ -n "$dylib" ]; do
      echo "This one one: $dylib"
      if [ -f "$dylib" ]; then
        DYLIB_FILENAME=$(basename "$dylib")
        if [ ! -f "$APP_LIBS_FOLDER/$DYLIB_FILENAME" ]; then
          # If the dylib is not already in the App Bundle, copy it
          cp "$dylib" "$APP_LIBS_FOLDER"/ || { echo "copy_dylibs_to_import: Failed to copy $dylib to ${APP_LIBS_FOLDER}"; exit; }
          echo " Copied $dylib to ${APP_LIBS_FOLDER}"
        else
          # If the dylib is already in the App Bundle, skip it
          echo " Warning: $dylib already exists in ${APP_LIBS_FOLDER}, skipping"
        fi
      else
        echo " Warning: $dylib does not exist, skipping"
      fi
    done < "$TEMP_FOLDER"/xmj_dylibs_to_import.txt
  else
    echo " No xmj dylibs to import found"
  fi

  if [ -f "$TEMP_FOLDER"/mj_player_dylibs_to_import.txt ]; then
    echo " Copying mj-player dylibs to import"
    while IFS= read -r dylib || [ -n "$dylib" ]; do
      if [ -f "$dylib" ]; then
        DYLIB_FILENAME=$(basename "$dylib")
        if [ ! -f "$APP_LIBS_FOLDER/$DYLIB_FILENAME" ]; then
          # If the dylib is not already in the App Bundle, copy it
          cp "$dylib" "$APP_LIBS_FOLDER"/ || { echo "copy_dylibs_to_import: Failed to copy $dylib to ${APP_LIBS_FOLDER}"; exit; }
          echo " Copied $dylib to ${APP_LIBS_FOLDER}"
        else
          # If the dylib is already in the App Bundle, skip it
          echo " Warning: $dylib already exists in ${APP_LIBS_FOLDER}, skipping"
        fi
      else
        echo " Warning: $dylib does not exist, skipping"
      fi
    done < "$TEMP_FOLDER"/mj_player_dylibs_to_import.txt
  else
    echo " No mj-player dylibs to import found"
  fi

  if [ -f "$TEMP_FOLDER"/mj_server_dylibs_to_import.txt ]; then
    echo " Copying mj-server dylibs to import"
    while IFS= read -r dylib || [ -n "$dylib" ]; do
      if [ -f "$dylib" ]; then
        DYLIB_FILENAME=$(basename "$dylib")
        if [ ! -f "$APP_LIBS_FOLDER/$DYLIB_FILENAME" ]; then
          # If the dylib is not already in the App Bundle, copy it
          cp "$dylib" "$APP_LIBS_FOLDER"/ || { echo "copy_dylibs_to_import: Failed to copy $dylib to ${APP_LIBS_FOLDER}"; exit; }
          echo " Copied $dylib to ${APP_LIBS_FOLDER}"
        else
          # If the dylib is already in the App Bundle, skip it
          echo " Warning: $dylib already exists in ${APP_LIBS_FOLDER}, skipping"
        fi
      else
        echo " Warning: $dylib does not exist, skipping"
      fi
    done < "$TEMP_FOLDER"/mj_server_dylibs_to_import.txt
  else
    echo " No mj-server dylibs to import found"
  fi

  echo " Non-standard dylibs for the executables copied to the App Bundle"
  echo "================================================================="
}

dylib_handling_for_executables_update_executables_references(){
  ####################################
  ## Update the executables to use the bundled dylibs
  ##
  ## This will update the executables to use the dylibs copied into the App Bundle
  ## This is done by using the install_name_tool command
  ## The command will update the path of the dylibs in the executables
  ## to point to the dylibs in the App Bundle
  ####################################
  echo ""
  echo "================================================================="
  echo " Updating the executables to use the bundled dylibs"
  echo "================================================================="

  log "Updating executables to use bundled dylibs"

  # Go to the App Bundle executables folder
  pushd "$APP_EXECUTABLES_FOLDER" || { echo "update_executables_for_bundled_dylibs: Failed to change directory to ${APP_EXECUTABLES_FOLDER}"; exit; }

  # Set the rpath
  install_name_tool -add_rpath "@executable_path/../$APP_LIBS_FOLDER_NAME" "$APP_EXECUTABLES_FOLDER/xmj"
  install_name_tool -add_rpath "@executable_path/../$APP_LIBS_FOLDER_NAME" "$APP_EXECUTABLES_FOLDER/mj-player"
  install_name_tool -add_rpath "@executable_path/../$APP_LIBS_FOLDER_NAME" "$APP_EXECUTABLES_FOLDER/mj-server"

  # Use install_name_tool to update the path of the dylibs in the executables
  # to point to the dylibs in the App Bundle
  # NR>1 = skip the first line
  echo " Updating xmj executable to use bundled dylibs"
  if [ -f "$TEMP_FOLDER/xmj_dylibs_to_import.txt" ]; then
    while IFS= read -r dylib || [ -n "$dylib" ]; do
      if [ -f "$dylib" ]; then
        DYLIB_FILENAME=$(basename "$dylib")
        install_name_tool -change "$dylib" "@rpath/$DYLIB_FILENAME" xmj || { echo "update_executables_for_bundled_dylibs: Failed to update xmj executable"; exit; }
        echo " Updated xmj executable to use $DYLIB_FILENAME from the App Bundle"
      else
        echo " Warning: $dylib does not exist, skipping"
      fi
    done < "$TEMP_FOLDER"/xmj_dylibs_to_import.txt
  else
    echo " No xmj dylibs to import found, skipping"
  fi
  
  echo " Updating mj-player executable to use bundled dylibs"
  if [ -f "$TEMP_FOLDER/mj_player_dylibs_to_import.txt" ]; then
    while IFS= read -r dylib || [ -n "$dylib" ]; do
      if [ -f "$dylib" ]; then
        DYLIB_FILENAME=$(basename "$dylib")
        install_name_tool -change "$dylib" "@rpath/$DYLIB_FILENAME" mj-player || { echo "update_executables_for  bundled_dylibs: Failed to update mj-player executable"; exit; }
        echo " Updated mj-player executable to use $DYLIB_FILENAME from the App Bundle"
      else
        echo " Warning: $dylib does not exist, skipping"
      fi
    done < "$TEMP_FOLDER"/mj_player_dylibs_to_import.txt
  else
    echo " No mj-player dylibs to import found, skipping"
  fi  

  echo " Updating mj-server executable to use bundled dylibs"
  if [ -f "$TEMP_FOLDER/mj_server_dylibs_to_import.txt" ]; then
    while IFS= read -r dylib || [ -n "$dylib" ]; do
      if [ -f "$dylib" ]; then
        DYLIB_FILENAME=$(basename "$dylib")
        install_name_tool -change "$dylib" "@rpath/$DYLIB_FILENAME" mj-server || { echo "update_executables_for_bundled_dylibs: Failed to update mj-server executable"; exit; }
        echo " Updated mj-server executable to use $DYLIB_FILENAME from the App Bundle"
      else
        echo " Warning: $dylib does not exist, skipping"
      fi
    done < "$TEMP_FOLDER"/mj_server_dylibs_to_import.txt
  else
    echo " No mj-server dylibs to import found, skipping"
  fi

  echo ""
  echo " Executables updated to use bundled dylibs"
  echo "================================================================="

  # Return to the previous folder
  popd
}

dylib_handling_for_bundled_dylibs_load_non_standard_dylibs_needed_by_dylibs(){
  ####################################
  ## Load the dylibs referenced by the bundled dylibs
  ##
  ## This idenfies the dylibs that the loaded dylibs need 
  ## in addition to the current ones
  ## The copy them to the Libs folder
  ####################################
  echo ""
  echo "================================================================="
  echo " Loading dylibs reference in the bundled dylibs"
  echo "================================================================="

  log "Loading dylibs referenced in the bundled dylibs"

  # Recover all the non-standard dylibs referenced by the App bundle dylibs (Libs folder)
  NEW_LIBS=true

  while [ "$NEW_LIBS" = true ]; do
    NEW_LIBS=false

    DYLIBS_IN_LIBS=$(ls "$APP_LIBS_FOLDER"/*.dylib 2>/dev/null) # List all dylibs in the libs folder

    IFS=$'\n' # Set IFS to newline to handle spaces in filenames

    for dylib in $DYLIBS_IN_LIBS; do
      DYLIB_FILENAME=$(basename "$dylib")

      DYLIB_OTOOL=$(otool -L "$dylib" | grep  -v "\/System\/Library\/" | grep -v "\/usr\/lib\/" | awk 'NR>1 {print $1}')
    
      if [ -z "$DYLIB_OTOOL" ]; then
        # echo " No references to non-standard dylibs found in $DYLIB_FILENAME, skipping"
        continue
      else
        for item in $DYLIB_OTOOL; do
          DYLIB_FILENAME=$(basename "$item")
          # If the dylib is not already in the App Bundle Libs folder, copy it
          if [ ! -f "$APP_LIBS_FOLDER/$DYLIB_FILENAME" ]; then
            cp "$item" "$APP_LIBS_FOLDER/$DYLIB_FILENAME" || { echo "update_bundled_dylibs_references: Failed to copy $item to ${APP_LIBS_FOLDER}"; exit; }
            echo " Copied $DYLIB_FILENAME to ${APP_LIBS_FOLDER}"
            NEW_LIBS=true # Set the flag to true to indicate that new libs were added
          fi
        done 
      fi
    done
  done
  
  echo " All new dylibs identified have been copied"
  echo "================================================================="
}

dylib_handling_for_bundled_dylibs_update_bundled_dylibs_references() {
  ####################################
  ## Update the references to the bundled dylibs
  ##
  ## updates all the dylib references in the dylib in the Libs folder fo the app bundle
  ## to point to the dylibs in the App Bundle
  ####################################
  echo ""
  echo "================================================================="
  echo " Updating references in the bundled dylibs"
  echo "================================================================="

  log "Updating references in the bundled dylibs"

  # update the references in the dylibs
  echo " Updating reference in the bundled dylibs to point to the App Bundle version"

  DYLIBS_IN_LIBS=$(ls "$APP_LIBS_FOLDER"/*.dylib 2>/dev/null) # List all dylibs in the libs folder
  IFS=$'\n' # Set IFS to newline to handle spaces in filenames

  for dylib in $DYLIBS_IN_LIBS; do
    DYLIB_FILENAME=$(basename "$dylib")

    # set the instll name to the "@rpath/filename"
    # This is to make sure the application will open this local file not the 
    # reference inside of it
    install_name_tool -id "@rpath/$DYLIB_FILENAME" "$dylib"

    # find all the relevant dylibs in this dylib that need to be re-referenced 
    # This means not the ones which are already using the correct relative path
    # and not the standard MacOS ones
    DYLIB_OTOOL=$(otool -L "$dylib" | grep  -v "\/System\/Library\/" | grep -v "\/usr\/lib\/" | grep -v "\@executable_path\/" | grep -v "\@rpath\/" | awk 'NR>1 {print $1}')

    for item in $DYLIB_OTOOL; do
      echo "$item"
      item_FILENAME=$(basename "$item")

      install_name_tool -change "$item" "@rpath/$item_FILENAME" "$APP_LIBS_FOLDER/$DYLIB_FILENAME" || { echo "update_bundled_dylibs_references: Failed to update $DYLIB_FILENAME"; exit; }
      echo " Updated reference for $item to use @rpath/$item_FILENAME"
    done

  done

  echo " References in the bundled dylibs updated"
  echo "================================================================="
}

dylib_handling_add_gdk_pixbuf_loaders_and_cache() {
  #####################################
  ## Import gdk_pixbuf XMP .so and cache
  ##
  ## The compilation makes use of pkg-config which uses the 
  ## homebrew version of gdk_pixbuf which refers to the homebrew
  ## version in the binary. As it is dynamically loaded, this needs 
  ## to be adjusted partly in real time
  ######################################
  echo ""
  echo "================================================================="
  echo " importing the gdk-pixbuf loaders and regenerate cache"
  echo "================================================================="

  log "Updating references in the bundled dylibs"

  # create the repository for the pixbuf loaders and cache
  mkdir -p "$APP_LIBS_FOLDER/gdk-pixbuf-2.0/2.10.0" || { echo "dylib_handling_add_gdk_pixbuf_loaders_and_cache: failed to create folder."; exit 1; }

  # Copy the loaders and the cache
  cp -r /usr/local/lib/gdk-pixbuf-2.0/2.10.0/ "$APP_LIBS_FOLDER/gdk-pixbuf-2.0/2.10.0/" || { echo "dylib_handling_add_gdk_pixbuf_loaders_and_cache: failed to copy files.";  exit 1; }

  command -v gdk-pixbuf-query-loaders >/dev/null 2>&1 || { echo >&2 "gdk-pixbuf-query-loaders is required (part of gtk+) but not present. Aborting."; exit 1; }

  # Regenerate the gdk_pixbuf cache with the app bundle's
  GDK_PIXBUF_MODULEDIR="$APP_FOLDER/Contents/Libs/gdk-pixbuf-2.0/2.10.0/loaders" gdk-pixbuf-query-loaders > "$APP_FOLDER/Contents/Libs/gdk-pixbuf-2.0/2.10.0/loaders.cache"

  echo " gdk-pixbuf processed and cache regenerated"
  echo "================================================================="
}

app_bundle_install_to_Applications() {
  #####################################
  ## Copy the app bundle to the 
  ## /Applications folder -> launchpad
  #####################################
  echo ""
  echo "================================================================="
  echo " Copying the app bundle to the Applications folder"
  echo " This should set it to be automatically visible in the Launchpad"
  echo "================================================================="

  log "Copying App Bundle to /Applications"

  cp -R "$APP_FOLDER" /Applications || { echo "app_bundle_install_to_Applications: Failed to copy ${APP_FOLDER} to /Applications"; exit 1; }

  echo " App Bundle copied to /Applications"
  echo "================================================================="
}

this_script_cleanup() {
  #####################################
  ## Clean up the preparation files
  #####################################
  echo ""
  echo "================================================================="
  echo " Clean up the preparation files"
  echo "================================================================="

  log "Cleaning up"

  if [ "$CLEANUP" = true ]; then
    # # remove downloaded compressed src
    # rm "$XMJ_SRC_FILENAME_COMPRESSED"
    # # remove source working directory
    # rm -Rf "$XMJ_SRC_FILENAME"
    # # remove app bundle as it was copied in /Applications
    # rm -Rf "$APP_NAME"
    rm -Rf "$TEMP_FOLDER"
    # remove dowloaded iconset
    rm -Rf "xmj.icns"
    echo " Cleanup complete"
  else
    echo " Cleanup skipped"
  fi

  echo "================================================================="
}

main() {
  check_dependencies
  handle_xmj_in_Applications_folder
  create_temp_folder
  xmj_download_src
  xmj_uncompress_src
  xmj_check_files_to_be_patched
  xmj_create_patches_for_version
  xmj_adjust_src_port_number
  # xmj_adjust_src_executables_path # No longer needed
  xmj_patch_tiles_display_bug_fix_for_xmj_1_17
  check_xcode_cli_tools
  install_compiling_essentials
  make_executables
  app_bundle_create_tree
  app_bundle_create_info_plist
  app_bundle_create_launch_miniscript
  app_bundle_copy_executables
  app_bundle_copy_tilesets
  app_bundle_prepare_and_install_iconset

  #    Alternative 1 to finalise a portable bundle (but not working so well at the moment)
  # install_dylibbundler 
  # execute_dylibbundler

  #    Alternative 2, should be working
  dylib_handling_for_executables_identify_dylibs_to_import
  dylib_handling_for_executables_copy_dylibs_to_import
  dylib_handling_for_executables_update_executables_references
  dylib_handling_for_bundled_dylibs_load_non_standard_dylibs_needed_by_dylibs
  dylib_handling_for_bundled_dylibs_update_bundled_dylibs_references
  dylib_handling_add_gdk_pixbuf_loaders_and_cache

  app_bundle_install_to_Applications
  log "Installation completed successfully"
  trap this_script_cleanup EXIT
}

main