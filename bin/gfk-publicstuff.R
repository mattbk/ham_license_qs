##
# R script to get data from PublicStuff
# Note that the API version at https://www.publicstuff.com/developers#!/API is v2.0,
# but this only includes requests up to a certain date. Use v2.1 for recent requests.

library(jsonlite)
library(rjson)

# Grab city view for Grand Forks
gfk <- rjson::fromJSON(file="https://www.publicstuff.com/api/2.1/city_view?space_id=15174")
## Make a data frame of request_type IDs and names
gfk_request_types <- as.data.frame(t(sapply(gfk$response$request_types$request_types,
                                            function(x) c(x$request_type$id, x$request_type$name))))
# Add column names
names(gfk_request_types) <- c("request_type_id","request_type_name")
# Loop through request types and get n most recent in each category
# Unix timestamp from a week ago
today <- as.numeric(as.POSIXct(Sys.time()))
week_ago <- today-604800

gfk_requests <- lapply(gfk_request_types$request_type_id,
                       function(x) jsonlite::fromJSON(paste0("https://www.publicstuff.com/api/2.1/requests_list?request_type_id=",
                                                        x,"&after_timestamp=",week_ago,"&limit=10")))
#gfk_requests1[sapply(gfk_requests1 , is.null)] <- NULL

gfk_requests <- lapply(gfk_requests, function(x) x$response$requests$request)


## Need to clear out attachments in some way here

# Drop nulls
b<-Filter(Negate(is.null), gfk_requests)
gfk_requests <- dplyr::bind_rows(b)
