# r-map-plotting
Plotting layers of data on regional or country maps using R

I work in public health and often find myself looking for intuitive approaches to data visualization. A common approach to displaying data with a geographic component is of course coloured maps. An example of this is the annual publication of reports on rates of resistance to antibiotics in bacteria in [Europe](https://ecdc.europa.eu/en/about-us/partnerships-and-networks/disease-and-laboratory-networks/ears-net) and [north/central Asia](http://www.euro.who.int/en/health-topics/disease-prevention/antimicrobial-resistance/about-amr/central-asian-and-eastern-european-surveillance-of-antimicrobial-resistance-caesar). Unfortunately these, and many other maps like them, are a bit inaccessible; either because they are published as images in pdf documents or the web interface that generates them is quite limited. Since the data is freely available though, I decided to try and replicate the maps using R, both for work and for the fun of it! During the process, I found very valuable tips in various locations that I decided to compile here in a step-wise manner, should anyone else be out there looking for them as desperately as I was. Also, if anyone spots something that could be solved in a cleverer or more aesthetically pleasing way, please do let me know!

First and foremost, we obviously need to get our hands on a map. There are several sources for up-to-date world and country maps. Here, I use [Natural Earth](https://www.naturalearthdata.com/) 1:50’000’000. Plotting this gives:

```
library(rgdal) #Package for handling maps in the very useful shapefile format
library(tidyverse) #Package-world of its own with lots of handy stuff
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

It’s always good to check that the content is consistent with international standards, in this case the ISO 3166-1 alpha-3 codes, which are easy to use when cross referencing data sources and maps. 

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
mask_subset <- map_select[map_select$ISO_A3 %in% #All rows in map.select corresponding to the country codes that have LEVEL_B evidence level                         
data_select$COUNTRY[ grep("LEVEL_B", data_select$EVIDENCE_LEVEL_AMR)],]
```

We can then plot that on top of our colour layer as a pattern, say lines at 45 degrees.

```
plot(map_select, col=map_select$res, xlim = c(-25, 170), ylim = c(45, 80))
plot(mask_subset, density = c(25), angle = c(45), add = TRUE)
```

![plot 5](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/05.png)
