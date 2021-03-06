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
#       other version of calibre content server (1) : use https://github.com/aptalca/docker-rdp-calibre (but we do not need rdp over calibre gui)

# To get calibre web (2) WORK on  https://github.com/Technosoft2000/docker-calibre-web OR https://github.com/linuxserver/docker-calibre-web
#       original calibre web (2) : https://github.com/janeczku/calibre-web/
#       technosoft2000/calibre-web : If you want the option to convert/download ebooks in multiple formats, use this image as it includes Calibre's ebook-convert binary. The "path to convertertool" should be set to /opt/calibre/ebook-convert.
#       linuxserver/calibre-web : Cannot convert between ebook formats.

# Alternative to Calibre content server (1) + Calibre Web (2) : ubooquity (which is also compatible with Calibre server (1) http://vaemendis.net/ubooquity/

# optional : 
#         unlock ebook tools : https://github.com/apprenticeharper/DeDRM_tools
#         shells scripts to organize collection : https://github.com/na--/ebook-tools
