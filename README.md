# r-map-plotting
Plotting layers of data on regional or country maps using R

I work in public health and often find myself looking for intuitive approaches to data visualization. A common approach to displaying data with a geographic component is of course coloured maps. An example of this is the annual publication of reports on rates of resistance to antibiotics in bacteria in [Europe](https://ecdc.europa.eu/en/about-us/partnerships-and-networks/disease-and-laboratory-networks/ears-net) and [north/central Asia](http://www.euro.who.int/en/health-topics/disease-prevention/antimicrobial-resistance/about-amr/central-asian-and-eastern-european-surveillance-of-antimicrobial-resistance-caesar). Unfortunately these, and many other maps like them, are a bit inaccessible; either because they are published as images in pdf documents or the web interface that generates them is quite limited. Since the data is freely available though, I decided to try and replicate the maps using R, both for work and for the fun of it! During the process, I found very valuable tips in various locations that I decided to compile here in a
step-wise manner, should anyone else be out there looking for them as desperately as I was. Also, if anyone spots something that could be solved in a cleverer or more aesthetically pleasing way, please do let me know!

First and foremost, we obviously need to get our hands on a map. There are several sources for up-to-date world and country maps. Here, I use [Natural Earth 1:50’000’000](https://www.naturalearthdata.com/). Plotting this gives:

```
library(rgdal) #Package for handling maps in the very useful shapefile format
library(tidyverse) #Package-world of its own with lots of handy stuff
shp.world <- readOGR(dsn = "world_borders", layer = "ne_50m_admin_0_countries")
plot(shp.world)
```

![plot 1](https://github.com/jonas-raposinha/r-map-plotting/blob/master/images/01)
