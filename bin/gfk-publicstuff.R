library(rjson)

# Grab city view for Grand Forks
gfk <- fromJSON(file="https://www.publicstuff.com/api/2.0/city_view?space_id=15174")

## Make a data frame of request_type IDs and names
gfk_request_types <- as.data.frame(t(sapply(gfk$response$request_types$request_types, function(x) c(x$request_type$id, x$request_type$name))))
