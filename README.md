# XMJ Mahjong on MacOS

A script to install Julian Bradfield's XMJ Mahjong on MacOS
* https://mahjong.julianbradfield.org/


## What is this?
* A **script to install XMJ Mahjong on MacOS**.
* The application is provided by its author for Linux and Windows, but no recent version has been available for MacOS.
  * This script creates it, hopefully with the latest version of the code.
* Note that Apple has claimed port 5000, so the default here has been set to 4000.
  * If playing with others on Linux/Windows OS, they need to adjust to this Port 5000 -> 4000 when starting/joining a new game
* There is no guarantee that this script will work for your machine, or even mess it up, use at your own risk.
* Please notify of issues (but there will not be any guaranteed response time). Fork if desired.

## How to use it?
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
* Go play

## What the script does: 
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
  * Insctruction are in the script file itself (a text file you can open with your favourite text editor - but not Word or Pages!)
* Installs the App Bundle into the Applications Folder/Launchpad

## History:
* v0.3 first beta release

## TO DO
* Add confirmation request for each step
* Confirm this script on a variety of platforms
  * So far only 2018/9 Intel Macbook is tested
* Adjust more paths with reference to the local folder
* Identify what crashes in the app and report to original author