### ASU Creation and Mapping Script
### Nevada Research & Analysis Bureau + Ohio Bureau of Labor Market Information
### June 2023

# Install Necessary Packages ------------------
install.packages(c("tigris", "readxl", "openxlsx", "sf", 
                   "mapview", "tidyverse", "leaflet", "leafpop"))

# Load Necessary Packages ------------------
library(tigris)
library(readxl)
library(openxlsx)
library(sf)
library(mapview)
library(tidyverse)
library(leaflet)
library(leafpop)

# Set Working Directory ------------------
setwd("R:/private/OWD/LMI/LMIStaging/LaborForceStats/LAUS/ASU/NV R Experiment")

# Set Variables ------------------
State_FIPS <- 39
Census_File <- "OH_asu23.xlsx"
UR_ASU_Threshold <- 6.45

# Download TIGER/Line shapefile from US Census Bureau ------------------
State_Tracts <- tracts(State_FIPS)

# Import Data from "ST_asuYY.xlsx" File ------------------
Census_Import <- read_excel(Census_File, sheet = "data")

# Shorten "geoid" Field and Select Only Relevant Fields ------------------
Census_Import$geoid_trimmed <- str_remove(Census_Import$geoid, "14000US")

Census_Data <- Census_Import %>%
  select(geoid_trimmed,
         st_fips,
         cnty_fips,
         tract_fips,
         name,
         tract_pop2023,
         tract_ASU_clf,
         tract_ASU_emp,
         tract_ASU_unemp,
         tract_ASU_urate) %>%
  rename(geoid = geoid_trimmed)

# Join BLS Data with US Census shapefile ------------------
Census_Map <- left_join(State_Tracts, Census_Data, by = c("GEOID" = "geoid"))
Census_Map <- Census_Map %>% arrange(desc(tract_ASU_urate), desc(tract_ASU_unemp))

# Set Variables for the ASU Creation Loop ------------------
high_tract <- head(Census_Map, 1)
ASU_assigned <- high_tract[0, ]

filteredCensus_Map <- Census_Map

rate <- 100
asunum <- 1

# ASU Creation Loop ------------------

while (filteredCensus_Map$tract_ASU_urate[1] > UR_ASU_Threshold) {

  orderid <- 1
  high_tract <- head(filteredCensus_Map, 1)
  high_tract$orderid = orderid
  combined_area <- bind_rows(high_tract)
  combined_tracts <- combined_area$name
  
  while(rate > UR_ASU_Threshold){
    
    continuous_tracts <- filteredCensus_Map %>% 
      filter(!name %in% combined_tracts) %>% 
      st_filter(combined_area, .predicate = st_intersects)
    
    if(nrow(continuous_tracts) == 0){
      add_tract <- FALSE
      break
    } else if(min(continuous_tracts$tract_ASU_clf) < 1){
      new_tract <- continuous_tracts %>% 
        filter(tract_ASU_clf < 1)
    } else {
      new_tract <- continuous_tracts %>% 
        arrange(desc(tract_ASU_urate),
                desc(tract_ASU_unemp)) %>% 
        head(1)
    }
    
    orderid <- orderid + 1
    new_tract$orderid = orderid
    
    combined_area <- bind_rows(combined_area, new_tract)
    
    rate <- sum(combined_area$tract_ASU_unemp) / sum(combined_area$tract_ASU_clf) * 100
    
    combined_tracts <- combined_area$name
    
  }  

  if(rate < UR_ASU_Threshold){combined_area <- head(combined_area, -1)}
  preASU_assign <- cbind(combined_area, asunum)
  ASU_assigned <- bind_rows(ASU_assigned, preASU_assign)
  ASU_assigned_names <- ASU_assigned$name
  asunum <- asunum + 1
  filteredCensus_Map <- Census_Map %>% filter(!name %in% ASU_assigned_names)
  filteredCensus_Map <- filteredCensus_Map %>% arrange(desc(tract_ASU_urate))
  rate <- 100
  
}

print("Finished!")

# Create Excel Spreadsheet with Initial ASU Assignment ------------------
Excel_File <- left_join(st_drop_geometry(Census_Map),
                        st_drop_geometry(ASU_assigned))

Excel_File <- Excel_File %>%
  select(-c(STATEFP, TRACTCE, NAME, NAMELSAD, MTFCC, FUNCSTAT, ALAND, AWATER,
            INTPTLAT, INTPTLON, st_fips, cnty_fips, tract_fips)) %>%
  mutate(asunum = coalesce(asunum, 0))

ASU_Map_Assignment <- createWorkbook()
addWorksheet(ASU_Map_Assignment,"data")
writeData(ASU_Map_Assignment,"data",Excel_File)
saveWorkbook(ASU_Map_Assignment,"ASU Map Assignment.xlsx", overwrite = TRUE)

# Load ASU Map Assignment Excel File ------------------
State_FIPS <- 39
State_Tracts <- tracts(State_FIPS)

new_data <- read_excel("ASU Map Assignment.xlsx")
new_data <- left_join(State_Tracts, new_data)

# Map ASU Assignments ------------------
new_included <- new_data %>%
  filter(asunum != 0)

new_not_included <- new_data %>%
  filter(asunum == 0)

mapview(new_included, zcol = "asunum", label = "name",
        popup = popupTable(new_included, zcol = c("GEOID", "name", "tract_pop2023", "tract_ASU_clf", "tract_ASU_emp", "tract_ASU_unemp", "tract_ASU_urate","asunum"))) +
  mapview(new_not_included, label = "name", col.regions = "white",
        popup = popupTable(new_not_included, zcol = c("GEOID", "name", "tract_pop2023", "tract_ASU_clf", "tract_ASU_emp", "tract_ASU_unemp", "tract_ASU_urate")))

# Create Table to Check Population and Rate ------------------
criteria_check <- st_drop_geometry(new_data) %>% 
  group_by(asunum) %>% 
  summarise(population = sum(tract_pop2023),
            rate = 100 * sum(tract_ASU_unemp)/sum(tract_ASU_clf))

# View Criteria Check Table ------------------
view(criteria_check)

# Create a Batch File for LSS ------------------
batch_file <- read_excel("ASU Map Assignment.xlsx") %>% 
  select(GEOID, asunum) %>% 
  filter(asunum != 0) %>% 
  mutate(GEOID = paste0("14000US", GEOID)) %>% 
  mutate(asunum = paste("SU", State_FIPS, sprintf("%04d", asunum), sep = "")) %>% 
  mutate(GEOID = paste(asunum, GEOID, sep = " + ")) %>% 
  select(-asunum)

write.table(batch_file,
            file = "MyBatchFile.txt", 
            row.names = FALSE, 
            col.names = FALSE, 
            quote = FALSE)
