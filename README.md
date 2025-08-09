# XMJ Mahjong on MacOS

A script to install Julian Bradfield's XMJ Mahjong on MacOS, fixing some MacOS issues

* [XMJ Mahjong](https://mahjong.julianbradfield.org/)

## Short instructions

* Download the file 'xmj-mahjong-macos-install-with-function.sh'
* run, from a terminal: 'sh ./xmj-mahjong-macos-install-with-function.sh'

If all goes well, XMJ Mahjong app should be in /Applications folder, and also be found in Launchpad.

## Command line arguments

```bash
-v <XMJ_VERSION> : xmj version to download and use (current default: 1.17)
-d : download iconset (default: true)
-l : enable log (default: false)
-c : clean up preparation files (default: false)
-h : usage info
```

## What is this?

* A **script to install XMJ Mahjong on MacOS**.
* The application is provided by its author for Linux and Windows, but no recent version has been available for MacOS.
  * This script creates it, hopefully with the latest version of the code.
* Note that Apple has claimed port 5000, so the default here has been set to 4000.
  * If playing with others on Linux/Windows OS, they need to adjust to this Port 5000 -> 4000 when starting/joining a new game
* There is no guarantee that this script will work for your machine, or even mess it up, use at your own risk.
* Please notify of issues (but there will not be any guaranteed response time). Fork if desired.

<!-- ## How to use it?

* Download the file *xmj-mahjong-macos-install.sh* eg in Download folder
* Start the MacOS terminal
* Go to the folder in which the file was downloaded
> cd Downloads
* Make sure the internet connection is still on
* Execute the file:
> sh ./xmj-mahjong-macos-install.sh
* Wait until returning to the terminal prompt
* Verify with Finder that the application is in the Applications folder and/or with Launchpad that the application is present
* In the terminal, you can remove the folder *XMJ-MacOS-Install*
> rm -Rf XMJ-MacOS-Install
* Go play -->

## What the script does

* Downloads XMJ Mahjong source code from its author's webpage
* Modifies some source files to enable working with Apple MacOS
  * change the default communication port from 5000 to 4000 due to Apple claiming 5000
  * ensure that local paths are represented referenced to the current path when calling files (WIP)
* Installs the package manager Homebrew
  * Then installs the packages gtk+ and pkg-config from Homebrew
* Compiles the source code
* Creates and populates the Apple App Bundle (Fancy name to say a folder that will be recognised by Launchpad)
  * NOTE: This script downloads the iconset from this website. The iconset is needed by the App Bundle.
  * You might perfer to prevent the script from doing this and create your own iconset.
  * Instruction are in the script file itself (a text file you can open with your favourite text editor - but not Word or Pages!)
* For portability: Import non-standard dylibs (such as gtk+) and patches the executables and dylibs to refer to the bundle
* Installs the App Bundle into the Applications Folder/Launchpad

## History

* 2025-08-09 - Version 0.8 - now adds the non-standard dylib to the bundle to be portable. Several bug fixes.
* 2025-08-04 - Version 0.7 - Added xmj-1.17 support, switched from manual editing patches to proper patching
* 2025-08-04 - Version 0.6 - Some refactoring for clarity
* 2024-09-06 - Version 0.5 - tested xmj-1.16 (-with-functions version) as working on Sonoma/Intel
* 2024-09-05 - Version 0.4 - structuring into function, untested, probably broken
* 2024-04-24 - Version 0.3 - first Beta
* 2024-04-24 - Version 0.2
* 2024-04-24 - Version 0.1

## TO DO

<!-- * Add confirmation request for each step -->
* Confirm this script on a variety of platforms
  * So far only 2018/9 Intel Macbook is tested
<!-- * Adjust more paths with reference to the local folder -->
* Identify what crashes in the app and report to original author
