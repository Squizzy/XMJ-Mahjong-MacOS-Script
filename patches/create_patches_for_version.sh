#!/bin/env zsh

VERSION="1.17"

usage() {
    echo
    echo "Usage: $0 [-v version] [-h]"
    echo "This script creates patches for the XMJ Mahjong game."
    echo "Options:"
    echo "  -v version  Specify the version of XMJ Mahjong (default is 1.17 as the latest at the time)."
    echo "  -h          Show this help message."
    echo
}

# Check the arguments, provide help if needed
if [ $# -ne 0 ]; then
    while getopts ":v:h" flag; do
        case "${flag}" in
            v) 
                VERSION=${OPTARG}
                ;;
            h) 
                usage
                exit 0
                ;;
            *) 
                echo
                echo "Invalid option: -${OPTARG}"
                usage
                exit 1
                ;;
        esac
    done
fi

# Check if there is a folder with the file mods needed.
if [ ! -d xmj_${VERSION} ]; then
    echo "Directory xmj_${VERSION} does not exist. Please ensure you have the correct version of XMJ Mahjong."
    exit 1
fi

# execute the batch creator in that folder
echo "Creating patches for XMJ Mahjong version ${VERSION}..."
sh xmj_${VERSION}/create_patches.sh
echo "Done."