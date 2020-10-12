
#
# Based on examples from
#   https://frost.met.no/ex_userquest
# as well as
#   \\niva-of5\OSL-Userdata$\DHJ\Documents\Hjelp\ANS_klima_nyaalesund\ANS_klima_svea_frost.R
#


#
# Function for getting data for one day, one year, etc. 
# Note: doesn't include 'df_level' (height avove the ground) info
#

get_data_i <- function(i, listobject_data){
  df <- as.data.frame(listobject_data[i,]$observations)
  cn <- colnames(df)
  vars <- cn[!cn %in% "level"]
  df <- df[vars]
  data.frame(sourceId = listobject_data$sourceId[i], referenceTime = listobject_data$referenceTime[i], df, stringsAsFactors = FALSE)
}

#
# Gets url string for downloading data   
#
get_urlstring_download <- function(year1, year2, parameter, station){
  parameter <- sub(" ", "%20", parameter, fixed = TRUE)
  paste0("https://frost.met.no/observations/v0.jsonld?referencetime=", year1, "-01-01/", year2, "-12-31&elements=", parameter, "&sources=", station)
}

  
#
# Function for getting data for one or several years
#
get_data <- function(year1, year2, parameter, station, verbose = FALSE){
  urlstring <- get_urlstring_download(year1, year2, parameter, station)
  json <- getURL(urlstring, verbose = verbose, .opts = opts)
  listobject <- fromJSON(json)
  data_list <- 1:nrow(listobject$data) %>% map(~get_data_i(., listobject$data))
  data <- bind_rows(data_list)
  data$referenceTime <- ymd_hms(data$referenceTime)
  data %>%
    mutate(Parameter = parameter) %>%
    select(Parameter, everything())
}


#
# Perform Theil-Sen regression by year
# Input: data frame, where one variable is "Year"
# Returns one-line data frame
#
theil_sen_by_year <- function(df, variable){
  df <- as.data.frame(df)
  result <- rkt(df[,"Year"], df[,variable])
  data.frame(Parameter = variable, P = result$sl, Estimate = result$B, Change = result$B*(2015-1980))
}

#
# Gets data Perform Theil-Sen regression by year
# Returns a list of 
#   $statistics - a one-line data frame
#   $data - the data
#
get_theil_sen <- function(year1, year2, parameter, station){
  df <- get_data(year1, year2, parameter, station)
  df <- df %>% 
    mutate(Station = station,
           Year = lubridate::year(df$referenceTime)
           ) %>% 
    select(Station, Year, everything())
  statistics <- theil_sen_by_year(df, "value") %>%
    mutate(Parameter = parameter, Station = station, Year1 = min(df$Year), Year2 = max(df$Year)) %>%
    select(Parameter, Station, Year1, Year2, everything())
  list(statistics = statistics, data = df)
}

#
# Get available series given station code (stid)   
#
get_series_from_station <- function(stid, simplify = TRUE, verbose = FALSE){
  url_available <- "https://frost.met.no/observations/availableTimeSeries/v0.jsonld?sources=%s&referencetime=2016-01-01"
  urlstring <- sprintf(url_available, stid)
  json <- getURL(urlstring, verbose = verbose, .opts = opts)
  X <- fromJSON(json)
  result <- as.data.frame(X$data) %>%
    mutate(validFrom = ymd_hms(validFrom),
           validTo = ymd_hms(validTo))
  if (simplify){
    result <- result[,c("validFrom", "validTo", "timeResolution", "elementId", "unit")]
  }
  result
}


#
# Get stations with data on 'parameter' in years between start year (year 1) and end year (year 2)
#
get_station_from_parameter <- function(parameter, year1, year2, simplify = TRUE){
  url_available <- "https://frost.met.no/observations/availableTimeSeries/v0.jsonld?referencetime=%i-01-01/%i-01-01&elements=%s"
  parameter <- sub(" ", "%20", parameter, fixed = TRUE)
  urlstring <- sprintf(url_available, year1, year2, parameter)
  json <- getURL(urlstring, verbose = TRUE, .opts = opts)
  X <- fromJSON(json)
  result <- as.data.frame(X$data) %>%
    mutate(validFrom = ymd_hms(validFrom))
  if (simplify)
    result <- result[,c("sourceId", "validFrom", "performanceCategory")]
  result
}

station_flatten <- function(i, data){
  coord <- data[i,]$geometry$coordinates[[1]]
  data2 <- data[i,] %>% select(-geometry, -stationHolders, -externalIds)
  data.frame(data2, Long = coord[1], Lat = coord[2])
  }


#
# Get metadata for stations
# Returns id, name, m.a.s.l. and coordinates
#
# Works for several types of input (see script 01)
#

get_station_meta <- function(stid, simplify = TRUE, verbose = FALSE, querylength = 10){
  # Remove colon and everything after
  stid <- sub(":.+", "", stid)
  # Keep only those starting with SN
  stid <- stid[grepl("^SN", stid)]
  # The following partcuts the station list (stid) into parts of 10 stations each, to avoid that 
  #   the URL becomes too long
  # Inspired by niRvana::
  L <- length(stid)
  sq1 <-  seq(1, L, querylength)
  sq2 <-  c(seq(1, L, querylength)[-1] - 1, L)
  result_list <- vector("list", length(sq1))
  # For each chunnk of 10 stations
  for (i in seq_along(sq1)){
    stid_part <- stid[seq(sq1[i], sq2[i])]
    result_list[[i]] <- get_station_meta_worker(stid = stid_part, simplify = simplify, verbose = verbose)
  }    
  result <- bind_rows(result_list)
  result
}

# 
# Actually gets the data for get_station_meta()
# 
# get_station_meta cuts the station list into chunnks of 10 station, which then is sent to this function
#
get_station_meta_worker <- function(stid, simplify = TRUE, verbose = FALSE){
  url <- "https://frost.met.no/sources/v0.jsonld?ids=%s&types=SensorSystem"
  # If several objects, we collapse them
  if (length(stid) > 1){
    stid <- paste0(stid, collapse = ",")
  }
  urlstring <- sprintf(url, stid)
  json <- getURL(urlstring, verbose = verbose, .opts = opts)
  X <- fromJSON(json)
  df <- as.data.frame(X$data)
  result <- df %>% nrow() %>% seq_len() %>% map_df(station_flatten, data = df)
  result <- result %>%
    mutate(validFrom = ymd_hms(validFrom))
  if (simplify)
    result <- result[,c("id", "shortName", "county", "masl", "validFrom", "Long", "Lat")]
  result
}

#
# Show one station or one coordinate on Norgeskart
#
# Works for several types of input (see script 01)
#
show_norgeskart <- function(X, Y = NULL, zoom = 8){
  url_norgeskart <- "https://norgeskart.no/#!?project=norgeskart&layers=1002&zoom=8&markerLat=6574925.2973417565&markerLon=234672.63719512318&panel=searchOptionsPanel&sok=%.5f,%.5f"
  if (is.data.frame(X)){
    urlstring <- sprintf(url_norgeskart, X$Long[Y], X$Lat[Y])
  } else if (is.vector(X) & length(X) >= 2){
    urlstring <- sprintf(url_norgeskart, X[1], X[2])
  } else {
    urlstring <- sprintf(url_norgeskart, X, Y)
  }
  browseURL(urlstring)
}



