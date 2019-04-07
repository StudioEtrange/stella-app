#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="calibre-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# TODO WIP - NOT FINISHED

# TODO
# objective : 
#             1/have Calibre content server 
#             2/AND Calibre-web (https://github.com/janeczku/calibre-web/) interface to manage and get ebook 
#             3/AND lazy librarian to get metadata
#             
# NOTE : we dont need calibre gui access

# To get calibre content server (1) AND lazylibrarian (3) WORK on https://github.com/StudioEtrange/docker-lazylibrarian-calibre and get specific version of calibre (https://github.com/kovidgoyal/calibre/tags)
#       alternative For calibre content server (1) : use https://github.com/aptalca/docker-rdp-calibre (but we do not need rdp over calibre gui)

# To get calibre web (2) WORK on  https://github.com/Technosoft2000/docker-calibre-web OR https://github.com/linuxserver/docker-calibre-web
#      original calibre web (2) : https://github.com/janeczku/calibre-web/

# optional : unlock ebook tools : https://github.com/apprenticeharper/DeDRM_tools
