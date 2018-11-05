##
# R script to get data from PublicStuff
# Note that the API version at https://www.publicstuff.com/developers#!/API is v2.0,
# but this only includes requests up to a certain date. Use v2.1 for recent requests.

# Run from one machine, otherwise you'll get duplicate databases that have differing posted items.
# Run with `Rscript bin/gfk-publicstuff.R`

# Raspberry Pi: https://www.r-bloggers.com/how-to-install-the-latest-version-of-r-statistics-on-your-raspberry-pi/
# Can install in Jessie with sudo apt-get install... but it is 3.1.1 by default.

library(jsonlite)
library(rjson)
library(ini)
library(mastodon) #devtools::install_github('ThomasChln/mastodon')
library(RSQLite)
library(stringr)

### Config
# Authentication variables
auth <- read.ini("auth.ini")
# Grab city view for Grand Forks
space_id <- 15174
client_id <- 1353 #needed later


### Get going
city <- rjson::fromJSON(file=paste0("https://www.publicstuff.com/api/2.1/city_view?space_id=",space_id))
## Make a data frame of request_type IDs and names
city_request_types <- as.data.frame(t(sapply(city$response$request_types$request_types,
                                            function(x) c(x$request_type$id, x$request_type$name))))
# Add column names
names(city_request_types) <- c("request_type_id","request_type_name")
# Loop through request types and get n most recent in each category
# Unix timestamp from a week ago
today <- as.numeric(as.POSIXct(Sys.time()))
week_ago <- today-604800
# For all request types, get requests from the last week from the PublicStuff API.
recent_requests <- lapply(city_request_types$request_type_id,
                       function(x) jsonlite::fromJSON(paste0("https://www.publicstuff.com/api/2.1/requests_list?request_type_id=",
                                                        x,"&after_timestamp=",week_ago,"&limit=100")))
# Pull out exactly the data we need
recent_requests <- lapply(recent_requests, function(x) x$response$requests$request)
# Drop null list items
recent_requests <- Filter(Negate(is.null), recent_requests)
# Image data is in a sub-dataframe, which we don't need
drop_image <- function(x){
    if(class(x$primary_attachment) == "data.frame") {
        x$primary_attachment <- NULL
        }
    return(x)
}
recent_requests <- lapply(recent_requests, drop_image)
# Put the requests together in a data frame
#recent_requests <- bind_rows(recent_requests)
recent_requests <- do.call("rbind",recent_requests)
# Add URL
recent_requests$url <- paste0("https://iframe.publicstuff.com/#?client_id=",client_id,"&request_id=",recent_requests$id)
# Add posted column (to include in database table) and default to 0 (false)
recent_requests$posted <- 0

## Store requests in a database
# Create DB if it doesn't exist, otherwise connect
mydb <- dbConnect(RSQLite::SQLite(), "requests.sqlite")
# See if table exists, then get existing rows back
if(nrow(dbGetQuery(mydb, "SELECT name FROM sqlite_master WHERE type='table' AND name='requests'")) > 0){
    rows.exist <- dbGetQuery(mydb, 'SELECT id FROM requests')$id
} else rows.exist <- NA
# Only add rows that don't exist, by request ID
rows.add <- recent_requests[!recent_requests$id %in% rows.exist,]
# Add the rows
dbWriteTable(mydb, "requests", rows.add,append=T)
# Get out of the database
dbDisconnect(mydb)

#### Tooting
# https://shkspr.mobi/blog/2018/08/easy-guide-to-building-mastodon-bots/
# https://github.com/ThomasChln/mastodon
mastodon_token <- login(auth$mastodon$server, auth$mastodon$email, auth$mastodon$password)

# Each time this script runs, take the oldest n requests, post them, and mark them in the db.
mydb <- dbConnect(RSQLite::SQLite(), "requests.sqlite")
#all_requests <- dbGetQuery(mydb, 'SELECT * FROM requests')
new_requests <- dbGetQuery(mydb, 'SELECT * FROM requests WHERE posted <> 1 ORDER BY date_created')


# Only post if there are new requests
if(nrow(new_requests) > 0){
    # Set number of posts allowed at once. Will need to adjust according to cron
    # schedule and number of posts coming in daily so you don't get behind.
    posts_at_once <- min(3, nrow(new_requests))
    # One post per request, up to limit
    for(i in 1:posts_at_once){
        request <- new_requests[i,]
        # Post one selected request
        post_text <- paste0(request$title, " at ", str_squish(request$address), " (",request$url,"): ", request$description)
        if(nchar(request$image_thumbnail) > 1){
            download.file(gsub("small","large",request$image_thumbnail), 'temp.jpg', mode="wb")
            post_media(mastodon_token, post_text, file = "temp.jpg")
        } else {
            post_status(mastodon_token, post_text)
            }

        # After tooting, mark what has been posted.
        # https://cran.r-project.org/web/packages/RSQLite/vignettes/RSQLite.html
        # https://stackoverflow.com/a/43978368/2152245

        # Update posted column as needed
        dbExecute(mydb, "UPDATE requests SET posted = :posted where id = :id",
                           params=data.frame(posted=TRUE,
                                                id=request$id))
    }
    # Get out of the database
    dbDisconnect(mydb)

    # Message to console (if running from script)
    print("Successful toots.")
} else {
    # Message to console (if running from script)
    print("No requests to toot.")
}

