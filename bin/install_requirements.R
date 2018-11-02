lib <- "~/R/library"
repos='http://cran.us.r-project.org/'
install.packages("jsonlite",lib=lib, repos=repos)
install.packages("rjson",lib=lib, repos=repos)
install.packages("dplyr",lib=lib, repos=repos)
install.packages("twitteR",lib=lib, repos=repos)
install.packages("ini",lib=lib, repos=repos)
install.packages("RSQLite",lib=lib, repos=repos)
install.packages("devtools",lib=lib, repos=repos)
devtools::install_github('ThomasChln/mastodon',lib=lib)
