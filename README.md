# GEESpatioTemporalSampling
Functions to assist with aligning samples collected at specific dates with views from above from as close to the same date as possible.

Largely taken from [this implementation](https://smithsonian.github.io/SpatiotemporalMatchingOfAnimalPositionsWithRemotelySensedDataUsingGoogleEarthEngineAndR/), with some aspects of the codebase cleaned up a bit and wrapped into a nice little function.

See:

Crego, R.D.; Masolele, M.M.; Connette, G.; Stabach, J.A. Enhancing Animal Movement Analyses: Spatiotemporal Matching of Animal Positions with Remotely Sensed Data Using Google Earth Engine and R. Remote Sens. 2021, 13, 4154. https://doi.org/10.3390/rs13204154

For the original idea, explanation, and examples.

Use `devtools::install_github("ethanshafron/GEESpatioTemporalSampling")` to install.

Right now this only works on point data - to sample Gpp from modis for an sf object with a column called date, we would do:

`library(rgee)`

`ee$Initialize()`

`sampledData <- temporalSample(df = data, datecol = "Date", tempwin = 8, collection = "MODIS/006/MOD17A2H", band = "Gpp")`
