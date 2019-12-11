# Author: Joshua Anderson - Fall 2019
# This script grabs data from the NYTimes API for the use of aggregating the record count to the Stanford_MSA_Databse

stanford_msa <- read.csv("Stanford_MSA_Database.csv")
# aggregate similar factors
stanford_msa %<>% 
  mutate(Shooter.Race = fct_recode(Shooter.Race,
                                   "Asian American" = "Asian American/Some other race",
                                   "Black American or African American" = "Black American or African American/Unknown",
                                   "White American or European American" = "White American or European American/Some other Race",
                                   "Some other race" = "Some Other Race",
                                   "Some other race" = "Unknown"),
         Fate.of.Shooter.at.the.scene = fct_recode(Fate.of.Shooter.at.the.scene,
                                                   "Custody" = "Arrested",
                                                   "Deceased" = "Killed"),
         Fate.of.Shooter = fct_recode(Fate.of.Shooter,
                                      "Custody/Escaped" = "Custody / Escaped",
                                      "Custody/Escaped" = "FALSE"),
         Type.of.Gun...General = fct_recode(Type.of.Gun...General,
                                            "Multiple Guns" = "\nMultiple guns",
                                            "Multiple Guns" = "Multiple guns",
                                            "Multiple Guns" = "Multiple guns\n",
                                            "Handgun" = "handgun",
                                            "Handgun" = "9-mm"),
         Shooter.s.Cause.of.Death = fct_recode(Shooter.s.Cause.of.Death,
                                               "Suicide" = "Killed/Suicide",
                                               "Not Applicable" = "Not applicable",
                                               "Not Applicable" = "Not Apllicable"),
         Place.Type = fct_recode(Place.Type, "Park/Wilderness" = "Park/Wildness"),
         Targeted.Victim.s...General = fct_recode(Targeted.Victim.s...General,"General public" = "Social/General public"),
         Possible.Motive...General = fct_recode(Possible.Motive...General, "Unknown" = "")) 

# correct column types
stanford_msa %<>% mutate(
  Title = as.character(Title),
  Location = as.character(Location),
  City = as.character(City),
  Shooter.Name = as.character(Shooter.Name),
  Shooter.Age.s. = toString(Shooter.Age.s.),
  Number.of.shooters = as.numeric(as.character(Number.of.shooters)),
  Average.Shooter.Age = as.numeric(as.character(Average.Shooter.Age)),
  Number.of.Shotguns = as.numeric(as.character(Number.of.Shotguns)),
  Number.of.Rifles = as.numeric(as.character(Number.of.Rifles)),
  Number.of.Handguns = as.numeric(as.character(Number.of.Handguns)),
  Number.of.Automatic.Guns = as.numeric(as.character(Number.of.Automatic.Guns)),
  Number.of.Semi.Automatic.Guns = as.numeric(as.character(Number.of.Semi.Automatic.Guns)),
  Total.Number.of.Guns = as.numeric(as.character(Total.Number.of.Guns)),
  Date = as.Date(Date, format="%m/%d/%Y")
)

# remove description columns
stanford_msa %<>% select(-c(CaseID, Description, Possible.Motive...Detailed, 
                            History.of.Mental.Illness...Detailed, Date...Detailed,
                            Targeted.Victim.s...Detailed, Type.of.Gun...Detailed, Notes,
                            Data.Source.1, Data.Source.2, Data.Source.3, Data.Source.4, 
                            Data.Source.5, Data.Source.6, Data.Source.7))

# filter cases with a high confidence depreciation value
stanford_msa %<>% filter(Depreciation == "1") # 1' indicates the case clearly fits the criteria for inclusion in the database

# replace NAs for numeric values with mean
is.numeric.NA <- function(x) return (is.numeric(x) & any(is.na(x)))
replace.NA.mean <- function(x) {
  avg <- round(mean(x, na.rm = T), 0)
  return (ifelse(is.na(x), avg, x))
}

stanford_msa %<>% mutate_if(is.numeric.NA, replace.NA.mean)


# grab articles from every month in the dataset
NYTIMES_KEY <- "qrAO1eS330SaT2t3Dxxxxxxxxxxxxxxx"

dates <- levels(as.factor(stanford_msa$Date))
months <- unique(format(as.Date(dates, format="%Y-%m-%d"), "%Y-%m"))
years <- unique(format(as.Date(dates, format="%Y-%m-%d"), "%Y"))

library(tidyverse)
library(magrittr)
library(jsonlite)
length(months)
articles <- list()
count <- 1 # currently at 11 at last run

for(i in count:length(months)) {
  print(paste("Count: ", count))
  year <- substring(months[[i]], 1, 4)
  month <- substring(months[[i]], 6)
  if (substr(month, 1,1) == '0') {
    month <- substr(month, 2,2)
  }
  
  url <- paste("https://api.nytimes.com/svc/archive/v1/", year, "/", month, ".json?api-key=", NYTIMES_KEY, sep="")
  result <- fromJSON(url, flatten = T) %>% data.frame()
  if (typeof(result$response.docs.word_count) == "character") {
    result %<>% mutate(response.docs.word_count = as.integer(response.docs.word_count))
  }
  articles %<>% bind_rows(result)
  count <- count + 1
  
  print("Finished")
  wait <- ceiling(runif(1, 30, 100))
  Sys.sleep(wait)
}
articles_copy <- articles
articles <- articles_copy
nrow(articles)
View(head(articles))

write.csv(articles, "./NYTimes")

# remove unrelated data
articles %<>% select(-c(copyright, response.hits, response.docs.source, 
                        response.docs.news_desk,response.docs.section_name,
                        response.docs.subsection_name, response.docs.slideshow_credits,
                        response.docs.byline.organization, response.docs.byline.person,
                        response.docs.byline.original, response.docs.print_page, 
                        response.docs.byline, response.docs.score))
names(articles)
# rename columns
colnames(articles) <- c("Web.URL", "Snippet", "Lead.Paragraph", "Abstract", "Blog",
                        "Multimedia", "Keywords", "Publish.Date", "Doc.Type",
                        "Material.Type", "id", "Word.Count", "Headline.Main", 
                        "Headline.Kicker", "URI", "Content.Kicker", "Print.Headline",
                        "Headline.Name", "SEO", "Headline.Sub", "Headline")

articles_shootings <- articles %>%
  filter(grepl("mass shooting", paste(Snippet, Lead.Paragraph, Abstract, Headline.Main, 
                                      Headline.Kicker, Content.Kicker, Print.Headline,
                                      Headline.Name, SEO, Headline.Sub)))

articles_output <- articles_shootings %>%
  select(-c(Blog, Multimedia, Headline, Keywords))
nrow(articles_output)
write.csv(articles_output, file="~/Downloads/NYTimes_msa.csv")
