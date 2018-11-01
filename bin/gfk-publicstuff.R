##
# R script to get data from PublicStuff
# Note that the API version at https://www.publicstuff.com/developers#!/API is v2.0,
# but this only includes requests up to a certain date. Use v2.1 for recent requests.

library(jsonlite)
library(rjson)
library(dplyr)
library(twitteR)
library(ini)
library(mastodon)
library(RSQLite)

# TODO Generalize to remove gfk_ from these variable names

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
requests <- bind_rows(gfk_requests)
# Add URL column
requests$url <- paste0("https://iframe.publicstuff.com/#?client_id=1353&request_id=",requests$id)
# Add posted column
requests$posted <- NA
# Sort by date
#gfk_requests <- gfk_requests[order(gfk_requests$date_created),]

## Store requests in a database
# Create DB if it doesn't exist, otherwise connect
mydb <- dbConnect(RSQLite::SQLite(), "requests.sqlite")
# See if table exists, then get existing rows back
if(nrow(dbGetQuery(mydb, "SELECT name FROM sqlite_master WHERE type='table' AND name='requests'")) > 0){
    rows.exist <- dbGetQuery(mydb, 'SELECT id FROM requests')$id
} else rows.exist <- NA
# Only add rows that don't exist, by request ID
rows.add <- requests[!requests$id %in% rows.exist,]
# Add the rows
dbWriteTable(mydb, "requests", rows.add,append=T)

#### Tweeting
# You now need a developer account to set up an app, which takes some time.
# Do that here: https://developer.twitter.com/en/apply-for-access.html
# A workaround could be to set up a Mastodon account and then auto-tweet
# using the fantastic https://crossposter.masto.donte.com.br/.

# Read authentication values from ini file
# Don't commit real values to git!
auth <- read.ini("auth.ini")

# setup_twitter_oauth(consumer_key = auth$twitter$consumer_key,
#                     access_token = auth$twitter$access_token,
#                     consumer_secret = auth$twitter$consumer_secret,
#                     access_secret = auth$twitter$access_secret)

# https://rcrastinate.blogspot.com/2018/05/send-tweets-from-r-very-short.html




#### Tooting
# https://shkspr.mobi/blog/2018/08/easy-guide-to-building-mastodon-bots/
# Might be able to use this natively: https://github.com/ThomasChln/mastodon

auth <- read.ini("auth.ini")
mastodon_token <- login(auth$mastodon$server, auth$mastodon$email, auth$mastodon$password)

# Each time this script runs, take the oldest n requests, post them, and mark them in the db.
requests.new <- dbGetQuery(mydb, 'SELECT * FROM requests WHERE posted IS NULL ORDER BY date_created')

# Set number of posts allowed at once. Will need to adjust according to cron
# schedule and number of posts coming in daily so you don't get behind.
posts_at_once <- 3
for(i in 1:posts_at_once){
    request <- requests.new[i,]
    text_to_post <- paste0(request$title, " at ", request$address, " (",request$url,"): ", request$description)
    # Post one selected request
    if(nchar(request$image_thumbnail) > 1){
        download.file(gsub("small","large",request$image_thumbnail), 'temp.jpg', mode="wb")
        post_media(mastodon_token, text_to_post, file = "temp.jpg")
    } else {
        post_status(mastodon_token, text_to_post)
        }

    # After tweeting or tooting, mark what has been posted.
    # https://cran.r-project.org/web/packages/RSQLite/vignettes/RSQLite.html
    # https://stackoverflow.com/a/43978368/2152245

    # Update posted column as needed
    dbExecute(mydb, "UPDATE requests SET posted = :posted where id = :id",
                       params=data.frame(posted=TRUE,
                                            id=request$id))

}

# Get out of the database
dbDisconnect(mydb)
unlink("requests.sqlite")

