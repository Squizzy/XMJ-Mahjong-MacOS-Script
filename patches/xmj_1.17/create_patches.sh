#!/bin/env zsh

VERSION="1.17"

# greedy_xmj_${VERSION}.c is the renamed copy of the original greedy.c for the ${VERSION} version.
diff -u xmj_${VERSION}/greedy_xmj_${VERSION}.c xmj_${VERSION}/greedy_xmj_${VERSION}_fixed_for_socket_port.c > greedy_xmj_${VERSION}_socket_port_fix.patch

# gui_xmj_${VERSION}.c is the renamed copy of the original gui.c for the ${VERSION} version.
diff -u xmj_${VERSION}/gui_xmj_${VERSION}.c xmj_${VERSION}/gui_xmj_${VERSION}_fixed_for_socket_port.c > gui_xmj_${VERSION}_socket_port_fix.patch
diff -u xmj_${VERSION}/gui_xmj_${VERSION}.c xmj_${VERSION}/gui_xmj_${VERSION}_fixed_for_executables_relative_path.c > gui_xmj_${VERSION}_executables_relative_path_fix.patch
diff -u xmj_${VERSION}/gui_xmj_${VERSION}.c xmj_${VERSION}/gui_xmj_${VERSION}_fixed_for_tiles_background.c > gui_xmj_${VERSION}_tiles_blackground_fix.patch