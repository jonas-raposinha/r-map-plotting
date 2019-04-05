# Plots map of Eurasia and colours countries according to EARS-NET/CAESAR resistance proportions (csv) and level of evidence

rm(list=ls())
library(rgdal)
library(rgeos)

##Reads the world map shapefile (Natural Earth, Admin 0 - Countries)
shp.world <- readOGR(dsn = "world_borders", 
                      layer = "ne_50m_admin_0_countries")

##Reads and filters the data on year
catresdata <- read.table("AMR_20_EN.csv", sep=",",
                         header = T, stringsAsFactors = F,
                         col.names = c("COUNTRY", "EVIDENCE_LEVEL_AMR", "PROPORTION_CATEGORICAL", "YEAR", "VALUE")) #Categorical data from European Health Information Gateway
data_select <-
  catresdata[catresdata$YEAR == 2016,]

##Detects entries in ne_50m_admin_0_countries that lack ISO 3166-1 alpha-3 codes
wrong.iso3 <- data_select$COUNTRY[
                                  is.na(
                                    match(
                                      data_select$COUNTRY,shp.world$ISO_A3))]
levels(shp.world$ISO_A3) <- c(levels(shp.world$ISO_A3), wrong.iso3) #Adding Norway and France and changing codes for Serbia and Kosovo to fit the data file
shp.world$ISO_A3[match(c("France", "Norway", "Serbia", "Kosovo"), shp.world$NAME)] <- wrong.iso3

##Adds a column for colouring countries according to resistance level
color_select_vect <- c("0_1", "1_5", "5_10", "10_25", "25_50", "50+", "DNP", "NO_DATA_LESS10") #Resistance levels ($PROPORTION_CATEGORICAL) 
color_name_vect <- c("#006400", "#a6d96a", "#e5e500", "#fd9a61", "#e2001a", "#650d0e", "grey", "grey") #Colours for map
data_select$color <- color_name_vect[
                                     match(data_select$PROPORTION_CATEGORICAL, color_select_vect)]
shp.world$res <- data_select$color[match(shp.world$ISO_A3, data_select$COUNTRY)]
map_select <- shp.world[
                        -which(
                               is.na(shp.world$res)),] #Removes all countries not in the data set

##Prepares a second layer for showing level B evidence data
mask_subset <- map_select[map_select$ISO_A3 %in% #All rows in map.select corresponding to the country codes that have LEVEL_B evidence level
                           data_select$COUNTRY[
                             grep("LEVEL_B", data_select$EVIDENCE_LEVEL_AMR)],]

##Prepares a third layer for indicating disputed border of Kosovo (in accordance with United Nations Security Council resolution 1244 (1999))
kos_set <- map_select[map_select$ISO_A3 %in% "RS-XKX",]
serb_set <- map_select[map_select$ISO_A3 %in% c("RS-SRB"),]
serb_kos_int <- gIntersection(serb_set, kos_set) #Calculates the intersection between the polygons

##Applies Albers equal-area projection to the Eurasian map (Europe -> EPSG:3035 (Lambert) Russia -> SR-ORG:8568)
world_proj <- spTransform(map_select, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70 +datum=WGS84 +units=m +no_defs")) 
mask_proj <- spTransform(mask_subset, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70 +datum=WGS84 +units=m +no_defs"))
serb_kos_proj <- spTransform(serb_kos_int, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70 +datum=WGS84 +units=m +no_defs"))
serb_kos_points <- spsample(serb_kos_proj, 20, "regular")

##Plots and prints the map
pdf("resmap_test2.pdf", w=15, h=10, pointsize = 1)
#plot(map_select, col = map_select$res, xlim = c(-15, 150), ylim = c(30, 80)) #Plots Mercator proj
plot(world_proj, col = world_proj$res, xlim=c(-600000,300000), ylim=c(-2500000,4500000), lwd = 0.7)
plot(mask_proj, density = c(25), angle = c(45), lwd = 0.7, add = T)
points(serb_kos_points, col = "white", pch = 16, cex = 0.3)
title(main = "Multidrug-resistant Klebsiella pneumoniae in 2016", cex.main = 3.5)
legend("topleft", legend = c("0 -< 1%", "1 -< 5%", "5 -< 10%", "10 -< 25", "25 -< 50", "> 50%", "", "NA"),
       fill = c(color_name_vect[1:6], "white", "grey"), bty="n", cex = 3.5)
legend("topleft", legend = c("", "", "", "", "", "", "Level B data",""), density=c(0, 0, 0, 0, 0, 0, 20, 0), angle = c(45), bty="n", cex = 3.5)
dev.off()

