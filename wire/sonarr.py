from hsapi import E
from arrwire import wire_arr
wire_arr('sonarr', 8989, 'SONARR_API_KEY', E['DATA_TV'] + '/library', 'tvCategory', 'tv')
