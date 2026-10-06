from hsapi import E
from arrwire import wire_arr
wire_arr('radarr', 7878, 'RADARR_API_KEY', E['DATA_MOVIES'] + '/library', 'movieCategory', 'movies')
