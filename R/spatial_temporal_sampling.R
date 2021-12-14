library(tidyverse)
library(stringr)
library(sf)
library(rgee)
library(remotes)
library(reticulate)

add_date<-function(feature) {
  date <- ee$Date(ee$String(feature$get("Date")))$millis()
  feature$set(list(date_millis=date))
}

#Set temporal window in days for filter. This will depend on the remote sensing data used.
temporal_filter <- function(tempwin){
  #Set the filter
  maxDiffFilter<-ee$Filter$maxDifference(
    difference=tempwin*24*60*60*1000, #days * hr * min * sec * milliseconds
    leftField= "date_millis", #Timestamp of the telemetry data
    rightField="system:time_start" #Image date
  )
  return(maxDiffFilter)
}


#Function to add property with raster pixel value from the matched image
add_value<-function(feature){
  #Get the image selected by the join
  img1<-ee$Image(feature$get("bestImage"))$select(band)
  #Extract geometry from the feature
  point<-feature$geometry()
  #Get pixel value for each point at the desired spatial resolution (argument scale)
  pixel_value<-img1$sample(region=point, scale=scalef, tileScale = tileScale, dropNulls = dropNulls)
  #Return the data containing pixel value and image date.
  feature$setMulti(list(PixelVal = pixel_value$first()$get(band), DateTimeImage = img1$get('system:index')))
}

# Function to remove image property from features
removeProperty<- function(feature) {
  #Get the properties of the data
  properties = feature$propertyNames()
  #Select all items except images
  selectProperties = properties$filter(ee$Filter$neq("item", "bestImage"))
  #Return selected features
  feature$select(selectProperties)
}

bandSelection <- function(img, band){
  out <- img$select(band)
  return(out)
}


temporalSample <- function(df, datecol="", tempwin=1, collection = "", band = "", start="2000-01-01", end="2020-01-01", 
                           scalef=50, tileScale=1, dropNulls=F){
  # Define globals to be used in featurecollection$map(func) calls. I'm sure there is a cleaner way to do this
  # but it is probably fine for now.
  band <<- band
  scalef <<- scalef
  tileScale <<- tileScale
  dropNulls <<- dropNulls
  
  # Define the join. We implement the saveBest function for the join, which finds the image 
  # that best matches the filter (i.e., the image closest in time to the particular GPS fix location). 
  maxDiffFilter <- temporal_filter(tempwin)
  
  saveBestJoin<-ee$Join$saveBest(
    matchKey="bestImage",
    measureKey="timeDiff"
  )
  
  ### Put in wgs84
  df <- st_transform(df, 4326)
  
  ### for now this just assumes your date is ymd
  df[[datecol]] <- lubridate::ymd(df[[datecol]]) #Modify as necessary
  df[[datecol]] <- as.factor(df[[datecol]])
  df[[datecol]] <- sub(" ", "T", df[[datecol]]) #Put in a format that can be read by javascript
  df$ID <- seq(1:nrow(df))
  # Send sf to GEE
  data <- sf_as_ee(df)
  
  # Transform day into milliseconds
  data <- data$map(add_date)
  
  imagecoll <- bandSelection(ee$ImageCollection(collection)$filterDate(start,end), band)

  # Apply the join
  Data_match<-saveBestJoin$apply(data, imagecoll, maxDiffFilter)
  
  # Add pixel value to the data
  DataFinal<-Data_match$map(add_value)

  # Remove image property from the data
  DataFinal<-DataFinal$map(removeProperty)

  # Move GEE object into R
  output <- ee_as_sf(DataFinal, via = 'getInfo')
  names(output)[names(output) == 'PixelVal'] <- band
  return(output)
}


