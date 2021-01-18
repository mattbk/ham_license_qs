##
# R script to get data from PublicStuff
# Note that the API version at https://www.publicstuff.com/developers#!/API is v2.0,
# but this only includes requests up to a certain date. Use v2.1 for recent requests.

# Run from one machine, otherwise you'll get duplicate databases that have differing posted items.
# Run with `Rscript bin/gfk-publicstuff.R`

# Raspberry Pi: https://www.r-bloggers.com/how-to-install-the-latest-version-of-r-statistics-on-your-raspberry-pi/
# Can install in Jessie with sudo apt-get install... but it is 3.1.1 by default.

# Log the start time
#print(paste("311 script started at", Sys.time()))

library(jsonlite)
library(ini)
library(mastodon) #devtools::install_github('ThomasChln/mastodon')
library(RSQLite)
library(stringr)
library(emo) #devtools::install_github("hadley/emo")

### Config
# Authentication variables
auth <- read.ini("auth.ini")
# # Grab city view for Grand Forks
# space_id <- 15174
# client_id <- 1353 #needed later


# ### Get going
# city <- jsonlite::fromJSON(txt=paste0("https://www.publicstuff.com/api/2.1/city_view?space_id=",space_id))
# ## Make a data frame of request_type IDs and names
# city_request_types <- city$response$request_types$request_types$request_type[,c("id","name")]
#
# # Add column names
# names(city_request_types) <- c("request_type_id","request_type_name")
# # Loop through request types and get n most recent in each category
# # Unix timestamp from a week ago
# today <- as.numeric(as.POSIXct(Sys.time()))
# week_ago <- today-604800
# # For all request types, get requests from the last week from the PublicStuff API.
# recent_requests <- lapply(city_request_types$request_type_id,
#                        function(x) jsonlite::fromJSON(paste0("https://www.publicstuff.com/api/2.1/requests_list?request_type_id=",
#                                                         x,"&after_timestamp=",week_ago,"&limit=100")))
# # Pull out exactly the data we need
# recent_requests <- lapply(recent_requests, function(x) x$response$requests$request)
# # Drop null list items
# recent_requests <- Filter(Negate(is.null), recent_requests)
# # Image data is in a sub-dataframe, which we don't need
# drop_image <- function(x){
#     if(class(x$primary_attachment) == "data.frame") {
#         x$primary_attachment <- NULL
#         }
#     return(x)
# }
# recent_requests <- lapply(recent_requests, drop_image)
# # Put the requests together in a data frame
# recent_requests <- do.call("rbind",recent_requests)
# # Add URL
# recent_requests$url <- paste0("https://iframe.publicstuff.com/#?client_id=",client_id,"&request_id=",recent_requests$id)
# # Add posted column (to include in database table) and default to 0 (false)
# recent_requests$posted <- 0
# # Add request_type ID
# recent_requests <- merge(recent_requests,city_request_types, by.x = "title", by.y = "request_type_name", all.x=T)
#
# ## Store requests in a database
# # Create DB if it doesn't exist, otherwise connect
# mydb <- dbConnect(RSQLite::SQLite(), "requests.sqlite")
# # See if table exists, then get existing rows back
# if(nrow(dbGetQuery(mydb, "SELECT name FROM sqlite_master WHERE type='table' AND name='requests'")) > 0){
#     rows.exist <- dbGetQuery(mydb, 'SELECT id FROM requests')$id
#     col_names <- names(dbGetQuery(mydb, 'SELECT * FROM requests'))
# } else rows.exist <- NA
# # Only add rows that don't exist, by request ID
# rows.add <- recent_requests[!recent_requests$id %in% rows.exist,]
# # Add the rows (rarrange to be in right order)
# dbWriteTable(mydb, "requests", rows.add[,col_names],append=T)
# # Get out of the database
# dbDisconnect(mydb)

#### Tooting
# https://shkspr.mobi/blog/2018/08/easy-guide-to-building-mastodon-bots/
# https://github.com/ThomasChln/mastodon
mastodon_token <- login(auth$mastodon$server, auth$mastodon$email, auth$mastodon$password)


# Test vector of toots
# This is where a df of questions, answer options, and any figures will go
db <- data.frame(license = letters,
                question = LETTERS,
                ans1 = rev(letters),
                ans2 = letters,
                ans3 = rev(letters),
                ans4 = rev(LETTERS),
                ans_correct = letters,
                fig_path = rev(LETTERS))

# TODO pull all questions from https://github.com/russolsen/ham_radio_question_pool
# Arrange data frame accordingly.


# Choose a random row to toot
toot_row <- db[sample(1:nrow(db), 1), ]
# Scramble answers
ans_options <- rep(paste0("\n- ",
                               sample(as.character(toot_row[1,3:6])),
                                collapse = ""))

# Build question
post_text <- paste0(toot_row[['license']],
                    ": ",
                    toot_row[['question']],
                    ans_options)

# Toot the thing!
post_status(mastodon_token,
            post_text)

# Check for image
if(!is.na(toot_row[['fig_path']])){
    # Post
    post_media(mastodon_token, post_text, file = toot_row[['fig_path']])
} else {
    # Post without image
    post_status(mastodon_token, post_text)
}


#
#
#
#
#
#
# # Each time this script runs, take the oldest n requests, post them, and mark them in the db.
# mydb <- dbConnect(RSQLite::SQLite(), "requests.sqlite")
# #all_requests <- dbGetQuery(mydb, 'SELECT * FROM requests')
# new_requests <- dbGetQuery(mydb, 'SELECT * FROM requests WHERE posted <> 1 ORDER BY date_created')
#
# # Only post if there are new requests
# if(nrow(new_requests) > 0){
#     # Set number of posts allowed at once. Will need to adjust according to cron
#     # schedule and number of posts coming in daily so you don't get behind.
#     posts_at_once <- min(3, nrow(new_requests))
#     # One post per request, up to limit
#     for(i in 1:posts_at_once){
#         # Select request
#         request <- new_requests[i,]
#         # Determine emoji from request_type_id
#         emoji <- emo::ji("interrobang") # default
#         if(request$request_type_id==28157){
#             emoji <- emo::ji("biohazard")
#         } else if(request$request_type_id==28158){
#             emoji <- emo::ji("poop")
#         } else if(request$request_type_id==28400){
#             emoji <- emo::ji("bicycle")
#         } else if(request$request_type_id==28171){
#             emoji <- emo::ji("recycle")
#         } else if(request$request_type_id==32004){
#             emoji <- emo::ji("snowflake")
#         } else if(request$request_type_id==28155){
#             emoji <- emo::ji("car")
#         } else if(request$request_type_id==28086){
#             emoji <- emo::ji("leaves")
#         } else if(request$request_type_id==28060){
#             emoji <- emo::ji("bulb")
#         } else if(request$request_type_id==27903){
#             emoji <- emo::ji("seedling")
#         } else if(request$request_type_id==27902){
#             emoji <- emo::ji("tractor")
#         } else if(request$request_type_id==27901){
#             emoji <- emo::ji("alarm")
#         } else if(request$request_type_id==26104){
#             emoji <- emo::ji("pick")
#         } else if(request$request_type_id==26096){
#             emoji <- emo::ji("biohazard")
#         } else emoji <- emo::ji("interrobang") #27904, general concern
#
#         # Add emoji from request description
#         if(grepl("dog|dogs", request$description)) {
#             emoji <- paste0(emoji, emo::ji("dog"))
#         }
#         if(grepl("parking", request$description)) {
#             emoji <- paste0(emoji, emo::ji("parking"))
#         }
#         if(grepl("leaf|leaves", request$description)) {
#             emoji <- paste0(emoji, emo::ji("fallen_leaf"))
#         }
#         if(grepl("flood|floods", request$description)) {
#             emoji <- paste0(emoji, emo::ji("ocean"))
#         }
#         if(grepl("speeding", request$description)) {
#             emoji <- paste0(emoji, emo::ji("rocket"))
#         }
#         if(grepl("pedestrian|pedestrians|walkers", request$description)) {
#             emoji <- paste0(emoji, emo::ji("walking"))
#         }
#
#         # Post one selected request
#         post_text <- str_trunc(paste0(emoji, " ", request$title, " at ", str_squish(request$address), " (",request$url,"): ", request$description),500)
#         # Check for image
#         if(nchar(request$image_thumbnail, keepNA = F) > 2 ){
#             # Get the image
#             download.file(gsub("small","large",request$image_thumbnail), 'temp.jpg', mode="wb")
#             # Post
#             post_media(mastodon_token, post_text, file = "temp.jpg")
#         } else {
#             # Post without image
#             post_status(mastodon_token, post_text)
#             }
#
#         # After tooting, mark what has been posted.
#         # https://cran.r-project.org/web/packages/RSQLite/vignettes/RSQLite.html
#         # https://stackoverflow.com/a/43978368/2152245
#
#         # Update posted column as needed
#         dbExecute(mydb, "UPDATE requests SET posted = :posted where id = :id",
#                            params=data.frame(posted=TRUE,
#                                                 id=request$id))
#     }
#     # Get out of the database
#     dbDisconnect(mydb)
#
#     # Message to console (if running from script)
#     print("Successful toots.")
# } else {
#     # Message to console (if running from script)
#     print("No requests to toot.")
# }

