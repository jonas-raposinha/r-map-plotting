# r-map-plotting
Plotting layers of data on regional or country maps using R

I work in public health and often find myself looking for intuitive approaches to data visualization. A common approach to displaying data with a geographic component is of course coloured maps. An example of this is the annual publication of reports on rates of resistance to antibiotics in bacteria in the [European Union](https://ecdc.europa.eu/en/about-us/partnerships-and-networks/disease-and-laboratory-networks/ears-net) and [north/central Asia and eastern Europe](http://www.euro.who.int/en/health-topics/disease-prevention/antimicrobial-resistance/about-amr/central-asian-and-eastern-european-surveillance-of-antimicrobial-resistance-caesar). Unfortunately these, and many other maps like them, are a bit inaccessible; either because they are published as images in pdf documents or because of limitations in the web interface that generates them. Since the data is freely available though, I decided to try and replicate the maps using R. During the process, I found very valuable tips in various locations that I would like to compile here in a step-wise manner, should anyone else be out there looking for them as desperately as I was. Also, if anyone spots something that could be solved in a cleverer or more aesthetically pleasing way, please let me know!

First and foremost, we obviously need to get our hands on a map. There are several sources for up-to-date world and country maps. Here, I use [Natural Earth](https://www.naturalearthdata.com/) 1:50’000’000. Plotting this gives:

```
library(rgdal) #Package for handling maps in the very useful shapefile format
library(tidyverse) #Package-world-of-its-own with lots of handy stuff
shp.world <- readOGR(dsn = "world_borders", layer = "ne_50m_admin_0_countries")
plot(shp.world)
```

![plot 1](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/01.png)

To check out Eurasia (and a bit of Africa too), we can alter the coordinates until we find an appropriate window, for example:

```
plot(shp.world, col = "grey", xlim = c(70, 150), ylim = c(35, 90))
```

![plot 2](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/02.png)
 
We then load the data file from the [European Health Information Gateway](https://gateway.euro.who.int/en/datasets/), containing levels of resistance against antibiotics (in this case percentage of invasive isolates of Klebsiella pneumoniae with combined resistance to fluoroquinolones, third-generation cephalosporins and aminoglycosides) from 2015 and 2016. For starters, we extract the data from 2016.

```
catresdata <- read.table("AMR_20_EN.csv", sep = ",", header = TRUE, stringsAsFactors = FALSE,
                         col.names = c("COUNTRY", "EVIDENCE_LEVEL_AMR",
                                       "PROPORTION_CATEGORICAL", "YEAR", "VALUE"))
head(catresdata)
   COUNTRY EVIDENCE_LEVEL_AMR PROPORTION_CATEGORICAL YEAR VALUE
 1     ALB            LEVEL_A         NO_DATA_LESS10 2015     1
 2     AND            LEVEL_A                    DNP 2015     1
 3     ARM            LEVEL_A         NO_DATA_LESS10 2015     1
 4     AUT            LEVEL_A                    1_5 2015     1
 5     AZE            LEVEL_A         NO_DATA_LESS10 2015     1
 6     BLR            LEVEL_B                    50+ 2015     1

data_select <-
  catresdata %>% 
  filter(YEAR == 2016)
```

It’s always good to check that the content is consistent with international standards, in this case the ISO 3166-1 alpha-3 codes, which are easy to use when cross referencing data sources and map areas. 

```
wrong.iso3 <- data_select$COUNTRY[is.na(match(data_select$COUNTRY,shp.world$ISO_A3))]
wrong.iso3
 [1] "FRA"    "NOR"    "RS-SRB" "RS-XKX"
```

As we can see, ISO-3 codes differ for France, Norway, Serbia and Kosovo, which we need to fix for them to be compatible.

```
levels(shp.world$ISO_A3) <- c(levels(shp.world$ISO_A3), wrong.iso3) #Changing codes for France, Norway, Serbia and Kosovo to fit the data file
shp.world$ISO_A3[match(c("France", "Norway", "Serbia", "Kosovo"), shp.world$NAME)] <- wrong.iso3
```

In this data file, the resistance level is given as a categorical variable, fitting our intention to colour countries according to binned values. Please note that the actual numerical values can be found in the yearly reports of EARS-NET and CAESAR (above links). To introduce colour data into the map file, we first translate resistance level to colour and then use the ISO-3 codes to match this to the map.

```
color_select_vect <- c("0_1", "1_5", "5_10", "10_25", "25_50", "50+", "DNP", "NO_DATA_LESS10") #Resistance level ($PROPORTION_CATEGORICAL) 
color_name_vect <- c("#006400", "#a6d96a", "#e5e500", "#fd9a61", "#e2001a", "#650d0e", "grey", "grey") #Colours for map
data_select$color <- color_name_vect[match(data_select$PROPORTION_CATEGORICAL, color_select_vect)]
shp.world$res <- data_select$color[match(shp.world$ISO_A3, data_select$COUNTRY)]
```

We are now ready to do the first plot.

```
plot(shp.world, col=shp.world$res, xlim = c(-25, 170), ylim = c(45, 80))
```

![plot 3](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/03.png)

Not too bad! Let’s clean it up a bit by removing countries not included in the data though.

```
map_select <- shp.world[-which(is.na(shp.world$res)),] #Removes all countries not in the data set
plot(map_select, col=map_select$res, xlim = c(-25, 170), ylim = c(45, 80))
```

![plot 4](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/04.png)

As you may have noticed, the dataset also includes information about the level of evidence (essentially, a measure of data quality). We would also like to include this in our plot in a way that does not mess with our colour scheme. Firstly, we isolate the countries with B level evidence.

```
mask_subset <- map_select[map_select$ISO_A3 %in% data_select$COUNTRY[grep("LEVEL_B", data_select$EVIDENCE_LEVEL_AMR)],]
```

We can then plot that on top of our colour layer as a pattern, say lines at 45 degrees.

```
plot(map_select, col=map_select$res, xlim = c(-25, 170), ylim = c(45, 80))
plot(mask_subset, density = c(25), angle = c(45), add = TRUE)
```

![plot 5](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/05.png)

Sweet! Next, we would like to highlight the border between Serbia and Kosovo since this is a matter of dispute. This might seem like an insignificant detail, but would be required in official documents (where we would refer to it in accordance with United Nations Security Council resolution 1244 of 1999). Also (and perhaps more importantly), this gives us an opportunity to explore the 'rgeos' package a bit.
First, we isolate the areas of Serbia and Kosovo and calculate the intersection between the polygons.

```
library(rgeos) #Package to interface with the Geometry Engine - Open Source, contains useful geometry operations
kos_set <- map_select[map_select$ISO_A3 %in% "RS-XKX",]
serb_set <- map_select[map_select$ISO_A3 %in% c("RS-SRB"),]
serb_kos_int <- gIntersection(serb_set, kos_set) #Calculates the intersection between the polygons
class(serb_kos_int)
 [1] "SpatialLines"
 attr(,"package")
 [1] "sp"
```

The class of the latter is “SpatialLines”, so we would like to make this into points to plot a dotted line. For this, we sample a number of points along the line. 

```
serb_kos_points <- spsample(serb_kos_int, 20, "regular")
class(serb_kos_points)
 [1] "SpatialPoints"
 attr(,"package")
 [1] "sp"
```

Finally, we plot it together with our map. 

```
plot(map_select, col=map_select$res, xlim = c(-25, 170), ylim = c(45, 80))
plot(mask_subset, density = c(25), angle = c(45), xlim = c(-25, 170), ylim = c(45, 80), add = TRUE)
points(serb_kos_points, col = "white", pch = 16, cex = 0.1)
```

![plot 6](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/06.png)
![plot 6 zoomed](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/06_02.png)

It looks reasonable, although the points are not actually evenly spread out along the line. I was unable to solve this and again, if anyone figures it out, please let me know.
Now, we need to add a plot title and legend. Let’s start easy and put the colours.

```
title(main = "Multidrug-resistant Klebsiella pneumoniae in 2016", cex.main = 1)
legend("topleft", legend = c("0 -< 1%", "1 -< 5%", "5 -< 10%", "10 -< 25", "25 -< 50", "> 50%", "NA"), fill = c(color_name_vect[1:7]), bty="n", cex = 1)
```

![plot 7](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/07.png)

The legend for the “shaded” areas can be added in the same way. In order to combine then, however, we will create a space for that extra box in the first legend and then overlay.

```
title(main = "Multidrug-resistant Klebsiella pneumoniae in 2016", cex.main = 1)
legend("topleft", legend = c("0 -< 1%", "1 -< 5%", "5 -< 10%", "10 -< 25", "25 -< 50", "> 50%", "", "NA"), fill = c(color_name_vect[1:6], "white", "grey"), bty="n", cex = 1)
legend("topleft", legend = c("", "", "", "", "", "", "Level B data",""), density=c(0, 0, 0, 0, 0, 0, 20, 0), angle = c(45), bty="n", cex = 1)
```

![plot 8](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/08.png)

Now we have a pretty nice plot already. However, since we are plotting a map of a large part of the Eurasian continent, we do have to consider the projection of our map (the operation of turning a spherical surface into a flat one). Without getting into much detail here (partly since I don’t remember my projective geometry as well as I probably should), the default projection (the one used above) is called “mercator” and has been around since the 16th century. As commonly used as it is, it does cause major distortions to the sizes of geographical objects, particularly when comparing those close to the equator to those closer to the poles. There are many alternative projections, and here I chose the “Albers Equal-Area” projection (that conserves area but distorts shape, you can’t have it all!) as an example of how to implement them using spTransform().

```
world_proj <- spTransform(map_select, CRS("+proj=aea")) #+proj=aea gives the Albers equal-area projection
plot(world_proj, col = world_proj$res)
```

![plot 9](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/09.png)

As we can see, the default parameters of CRS (Coordinate Reference System) do not centre the map quite where we want it. Finding the appropriate values can seem daunting, but we can often put our faith in the great reference collection at [Spatial Reference](http://spatialreference.org/). For example we can use the Albers Equal Area definition from the Space Research Institute in Moscow, Russia (SR-ORG: 8568) as a blueprint and then play around with the parameters until we are satisfied. 
Bonus tip: the recommended projection for European maps is the “Lambert Equal-Area”, try the reference EPSG:3035.

```
world_proj <- spTransform(map_select, CRS("+proj=aea +lat_1=50 +lat_2=70 +lat_0=56 +lon_0=100 +datum=WGS84 +units=m +no_defs"))
plot(world_proj, col = world_proj$res)
```

![plot 10](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/10.png)

The shapes look better, but the map is perhaps a bit to focused on Russia (not surprising, since that is what the reference was made for). Also, we would like a bit less curvature. This is easily remedied by changing the projection centre longitude (lon_0) and the first standard parallel (lat_1) respectively. You can read more about the parameters at the [Proj4 website](https://proj4.org/operations/projections/aea.html). To adjust limits, we recall the coordinate transformation and fiddle around until we find a good fit.

```
world_proj <- spTransform(map_select, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70+datum=WGS84 +units=m +no_defs"))
plot(world_proj, col = world_proj$res, xlim=c(-600000,300000), ylim=c(-2500000,4500000))
```

![plot 11](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/11.png)

Better still! To add the other 2 plot layers, these must be transformed as well. Note that the spsample() is placed after the transformation (you can place it before as well, but I find it comes out a bit better this way). 

```
world_proj <- spTransform(map_select, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70 +datum=WGS84 +units=m +no_defs")) 
mask_proj <- spTransform(mask_subset, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70 +datum=WGS84 +units=m +no_defs"))
serb_kos_proj <- spTransform(serb_kos_int, CRS("+proj=aea +lat_1=40 +lat_2=70 +lat_0=56 +lon_0=70 +datum=WGS84 +units=m +no_defs"))
serb_kos_points <- spsample(serb_kos_proj, 20, "regular")
```

And to finally print the plots, we add everything up together. Printing pdf is nice since it’s vector-based and can be opened on most machines. You can change it png for use in ppt or similar, although I usually prefer creating image files from pdf:s using Inkscape or similar. Also, pdf can be used to print several pages in the same document (just keep on adding new plot calls before you finish with dev.off()), which can be neat. For printing, the plot lines looked a bit too thick, so we add a lwd to the plot calls.

```
pdf("plot_name.pdf", w=15, h=10, pointsize = 1)
plot(world_proj, col = world_proj$res, xlim=c(-600000,300000), ylim=c(-2500000,4500000), lwd = 0.7)
plot(mask_proj, density = c(25), angle = c(45), lwd = 0.7, add = T)
points(serb_kos_points, col = "white", pch = 16, cex = 0.3)
title(main = "Multidrug-resistant Klebsiella pneumoniae in 2016", cex.main = 3.5)
legend("topleft", legend = c("0 -< 1%", "1 -< 5%", "5 -< 10%", "10 -< 25", "25 -< 50", "> 50%", "", "NA"), fill = c(color_name_vect[1:6], "white", "grey"), bty="n", cex = 3.5)
legend("topleft", legend = c("", "", "", "", "", "", "Level B data",""), density=c(0, 0, 0, 0, 0, 0, 20, 0), angle = c(45), bty="n", cex = 3.5)
dev.off()
```

![plot 12](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/12.png)
![plot 12 zoomed](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/12_2.png)

And there we have it! A nicely coloured map with two additional layers, all using base plot. I actually tried to replicate this using ggplot(), but ran into all kinds of issues with the second layer (lines), the legend and other things, so I just left it at that. If anyone could show me a way to do that, I would be most impressed. What is very convenient to do in ggplot() though, is a gradient map for a continuous variable, so let's try that.

For this, let's plot some regional data on antibiotic prescriptions in Sweden (also publicly available online). Just to mix it up a bit I'll be using a map of Sweden assembled by [ESRI Sweden](https://www.arcgis.com/home/item.html?id=912b806e3b864b5f83596575a2f7cb01).

```
shp.sweden <- readOGR(dsn = "Lan_SCB", layer = "Länsgränser_SCB_07") 
plot(shp.sweden)
```
![plot 13](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/13.png)

We specify the names of the regions so that they will be printes correctly. 

```
lan_map$lan <- c("Stockholm", "Uppsala", "Södermanland", "Östergötland", "Jönköping", "Kronoberg", "Kalmar", "Gotland", "Blekinge", "Skåne", "Halland", "Västra Götaland", "Värmland", "Örebro", "Västmanland", "Dalarna", "Gävleborg", "Västernorrland", "Jämtland", "Västerbotten", "Norrbotten")
lan_map <- data.frame(0:20) # Regional codes 1-20
```

Then we read the data (extracted from the Swedish Board of Health and Welfare database) and filter it on the year, region (whole country) and sex and age groups.

```
use_raw <- read.table("sos_antibiotikastat.csv", sep=";", header=T, stringsAsFactors = F, dec = ",", encoding="UTF-8") #check.names = F for real col names
colnames(use_raw)[1:5] <- c("year", "measure", "region", "sex", "age")
use_data <-
  use_raw %>%
  filter(year == 2017) %>%
  filter(sex == "Båda könen") %>%
  filter(region != "Riket") %>%
  filter(str_detect(age, "0.85+")) #%>% # stringr regex "." used to avoid issues with the "-" separator
```

We map the regional codes to facilitate matching the prescirption values.

```
use_data$code <- NA
for(k in 1:nrow(lan_map)){
  use_data$code[grep(lan_map$lan[k], use_data$region)] <- lan_map$X0.20[k]
}
```

All packages within the Tidyverse (including ggplot2) like data to be ["tidy"](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html), which shapefile data are not. Fortunately, they have made the conversion easy for us.

```
class(shp.sweden)
 [1] "SpatialPolygonsDataFrame"
 attr(,"package")
 [1] "sp"
shapefile_df <- broom::tidy(shp.sweden)
class(shapefile_df)
 [1] "tbl_df"     "tbl"        "data.frame"
```

We can now match the prescription numbers to the correct region (as done above).

```
shapefile_df$use <- use_data$Antibiotika[match(shapefile_df$id, use_data$code)] 
```

Time for the first plot. In ggplot(), the geom_polygon is useful for drawing regions connected by lines. The 'x' and 'y' are provided by longitudes and latitudes from the map file, 'fill' by our prescription data column and 'colour' refers to the borders.

```
gg <- ggplot() + geom_polygon(data=shapefile_df, aes(x=long, y=lat, group = group, fill=shapefile_df$use), size = 0.1, colour="black")
gg
```

![plot 14](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/14.png)

Ok, so it looks a bit squeezed. I find that easier to deal with when printing the plot, so let's just ignore it for now. We do need to fix the gradient though, since darker colours better represent higher numbers than vice versa. We specify this through scale_fill_gradient(), in which we can also add a title to the gradient legend. The neat thing about ggplot() is that we can just keep adding stuff to the plot object the we created.

```
gg <- gg + scale_fill_gradient(name = filter_text[2], low = "steelblue1", high = "midnightblue", guide = "colourbar")
gg
```

![plot 15](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/15.png)

That's better. Now we take care of the axis labels. I like to use str_wrap() to force new lines in plots texts. There are other ways but this one plays well with sprintf() that I often use for plot titles (not here though, since the meta data is in Swedish). We can also add a caption if we like.

```
gg <- gg + labs(title=str_wrap("J01 excl. metenamin prescriptions, all ages, both sexes for 2017", 45), y="", x="", caption="Source: Swedish Board of Health and Welfare")
gg
```

![plot 16](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/16.png)

I find the background distracting, so let's remove it one element at a time.

```
gg <- gg + theme(panel.grid.major = element_blank(), 
                 panel.grid.minor = element_blank(), 
                 panel.background = element_blank(),
                 axis.text.x = element_blank(),
                 axis.text.y = element_blank(),
                 axis.ticks = element_blank())
gg
```

![plot 17](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/17.png)

Finally, it's time to print the plot (with some adjustments to text sizes for readability).

```
gg <- gg + theme(plot.title=element_text(size=24, face="bold", lineheight=1.2),
                 plot.caption=element_text(size=20, hjust=1.8),
                 legend.title=element_text(size=20, face="bold"),
                 legend.text=element_text(size=20),
                 legend.key.size = unit(2, "cm"),)
pdf("swemap.pdf", w=10, h=15, pointsize = 1) #Sets an aspect ratio that fits the plot
gg
dev.off()
```

![plot 18](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/18.png)

As we can see, ggplot() has a somewhat more logical syntax than base plot, (at least once you get used to it), and setting up a gradient map like this one is quite straight forward. For more customized plots though, I prefer the versatility (sometimes rather idiosyncrasy) of base plot.
