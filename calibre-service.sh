#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="calibre-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include




# TODO
# objective : have Calibre content server AND Calibre-web (https://github.com/janeczku/calibre-web/) interface to manage and get ebook AND lazy librarian to get metadata
#             we dont need calibre gui access

# To get calibre content server AND lazylibrarian WORK on https://github.com/StudioEtrange/docker-lazylibrarian-calibre and get specific version of calibre (https://github.com/kovidgoyal/calibre/tags) 
#       alternative For calibre content server : use https://github.com/aptalca/docker-rdp-calibre (but we do not need rdp over calibre gui)
# To get calibre web WORK on  https://github.com/Technosoft2000/docker-calibre-web OR https://github.com/linuxserver/docker-calibre-web
#       alternative for calibre web https://github.com/janeczku/calibre-web/  

# optional : unlock ebook tools : https://github.com/apprenticeharper/DeDRM_tools