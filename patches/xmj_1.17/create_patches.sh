#!/bin/env zsh

VERSION="1.17"

# greedy_xmj_${VERSION}.c is the renamed copy of the original greedy.c for the ${VERSION} version.
diff -u xmj_${VERSION}/greedy_xmj_${VERSION}.c xmj_${VERSION}/greedy_xmj_${VERSION}_fixed_for_socket_port.c > greedy_xmj_${VERSION}_socket_port_fix.patch

# controller_xmj_${VERSION}.c is the renamed copy of the original controller.c for the ${VERSION} version.
diff -u xmj_${VERSION}/controller_xmj_${VERSION}.c xmj_${VERSION}/controller_xmj_${VERSION}_fixed_for_socket_port.c > controller_xmj_${VERSION}_socket_port_fix.patch

# gui_xmj_${VERSION}.c is the renamed copy of the original gui.c for the ${VERSION} version.
diff -u xmj_${VERSION}/gui_xmj_${VERSION}.c xmj_${VERSION}/gui_xmj_${VERSION}_fixed_for_socket_port.c > gui_xmj_${VERSION}_socket_port_fix.patch
diff -u xmj_${VERSION}/gui_xmj_${VERSION}.c xmj_${VERSION}/gui_xmj_${VERSION}_fixed_for_tiles_display.c > gui_xmj_${VERSION}_tiles_display_fix.patch

# Now obsolete
# diff -u xmj_${VERSION}/gui_xmj_${VERSION}.c xmj_${VERSION}/gui_xmj_${VERSION}_fixed_for_executables_relative_path.c > gui_xmj_${VERSION}_executables_relative_path_fix.patch