library(rvest)

# Scrape the CRAN package list
cran_url <- "https://cran.r-project.org/web/packages/available_packages_by_name.html"
html_page <- read_html(cran_url)
pkg_names <- html_page %>% html_nodes("td a") %>% html_text()

# Select top 100 packages
top_100_pkgs <- head(pkg_names, 100)
print(top_100_pkgs)
