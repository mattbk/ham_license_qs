##
# R script to get data from PublicStuff
# Note that the API version at https://www.publicstuff.com/developers#!/API is v2.0,
# but this only includes requests up to a certain date. Use v2.1 for recent requests.

library(jsonlite)
library(rjson)
library(dplyr)
library(twitteR)

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
# For all request types, get (at most) 10 requests from the last week from the PublicStuff API.
gfk_requests <- lapply(gfk_request_types$request_type_id,
                       function(x) jsonlite::fromJSON(paste0("https://www.publicstuff.com/api/2.1/requests_list?request_type_id=",
                                                        x,"&after_timestamp=",week_ago,"&limit=10")))
# Pull out exactly the data we need
gfk_requests <- lapply(gfk_requests, function(x) x$response$requests$request)
# Drop null list items
gfk_requests <- Filter(Negate(is.null), gfk_requests)
# Drop images (in fact, there is image_thumbnail in the data we want,
# and we can just replace small_ with large_ to get a bigger image later!)
drop_image <- function(x){
    if(class(x$primary_attachment) == "data.frame") {
        x$primary_attachment <- NULL
        }
    return(x)
}
gfk_requests <- lapply(gfk_requests, drop_image)
# Put the requests together in a data frame
gfk_requests <- bind_rows(gfk_requests)


#### Tweeting
# https://rcrastinate.blogspot.com/2018/05/send-tweets-from-r-very-short.html

# Need to create an external file with keys so they don't end up on GitHub
setup_twitter_oauth(consumer_key = "<your Consumer Key>",
                    access_token = "<your Acces Token>",
                    consumer_secret = "<your Consumer Secret>",
                    access_secret = "<your Access Token Secret>")

# After tweeting, write a small text file that has the last timestamp that was tweeted. Use that for grabbing future requests.








