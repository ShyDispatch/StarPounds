local module, args = table.unpack(params)
getmetatable ''.starPounds[module](table.unpack(args or jarray()))
