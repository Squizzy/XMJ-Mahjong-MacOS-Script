#!/bin/sh

# Script to install Julian Bradfield XMJ Mahjong to MacOS
# Version 0.1

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

# then
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

# and also:
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
make

