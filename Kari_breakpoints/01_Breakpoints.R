
# Knekkpunkt-analyse
# Har delvis brukt https://rpubs.com/MarkusLoew/12164 som guide

# 1-2 er å laste pakker og data
# 3-4 er testing med et eksempel
# 5-8 er den faktiske analysen for denne fila


#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 1. Libraries  ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

# install.packages("segmented")
library(segmented)
library(dplyr)
library(tidyr)
library(ggplot2)
library(purrr)

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 2. Data ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

dat <- read.delim("Input_data/LWTP.txt")

head(dat)

# Kjapp titt på datasett
library(skimr)
skim(dat)

#
# Omformater til "langt" datasett
#
dat2 <- dat %>%
  pivot_longer(X1992:X2018, names_to = "Year", values_to = "TotP") %>%
  mutate(Year = as.numeric(substr(Year,2,5))) %>%
  filter(!is.na(TotP))

ggplot(dat2, aes(Year, TotP, group = monitoringSiteIdentifier, color = seriesSpan)) +
  geom_line()

#
# Lagre 'identifiers'   
#
identifiers <- dat$monitoringSiteIdentifier

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 3. En relativt tilfeldig serie  ---- 
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

dat2_pick <- dat2 %>% filter(monitoringSiteIdentifier == identifiers[2])
dat2_pick <- dat2 %>% filter(monitoringSiteIdentifier == "DESM_DEBE_345")

ggplot(dat2_pick, aes(Year, TotP, group = monitoringSiteIdentifier, color = seriesSpan)) +
  geom_line() +
  geom_point()


#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 4a. Eksempel i https://rpubs.com/MarkusLoew/12164 ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

# create a linear model
my.lm <- lm(TotP ~ Year, data = dat2_pick)
# summary(my.lm)

# turn linear model into a segmented model
my.seg1 <- segmented(my.lm, 
                    seg.Z = ~ Year, 
                    psi = mean(range(dat2_pick$Year)))
summary(my.seg1)
my.seg1$psi
slope(my.seg1)
# class(my.seg1)

my.fitted <- fitted(my.seg1)
yrs <- seq(min(dat2_pick$Year), max(dat2_pick$Year))
my.fitted <- predict(my.seg1, 
                     newdata = data.frame(Year = yrs))
my.model <- data.frame(Year = yrs, TotP = my.fitted)

ggplot(dat2_pick, aes(Year, TotP)) +
  geom_point() +
  geom_line(data = my.model)

#
# Same, but with 2 breakpoints
#
starting_values <- seq(min(dat2_pick$Year), max(dat2_pick$Year), length = 4)
starting_values <- starting_values[2:3]
starting_values
my.seg2 <- segmented(my.lm, 
                     seg.Z = ~ Year, 
                     psi = starting_values)
summary(my.seg2)
my.seg2$psi
slope(my.seg2)
# class(my.seg2)

my.fitted <- fitted(my.seg2)

# points on x axis for plotting line
yrs <- c(min(dat2_pick$Year), 
         my.seg2[["psi"]][,2],
         max(dat2_pick$Year))

my.fitted <- predict(my.seg2, 
                     newdata = data.frame(Year = yrs))
my.model <- data.frame(Year = yrs, TotP = my.fitted)

ggplot(dat2_pick, aes(Year, TotP)) +
  geom_point() +
  geom_line(data = my.model)

#
# Test for zero, one or two breakpoints
#
test1 <- pscore.test(my.seg1) 
test2 <- pscore.test(my.seg1, more.break = TRUE) 
test1
str(test1)
test2 
str(test2)

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
# 
# 4b. selgmented -----
#    velger automatisk antall breakpoints
# 
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

my.selg <- selgmented(my.lm, Kmax = 2)
summary(my.selg)

my.selg <- selgmented(olm=my.lm, Kmax = 3, type = "davies")
my.selg <- selgmented(olm=my.lm, Kmax = 3, type = "bic")


#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 5. Kjør alle (<1 minutt) ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

# 
# Definere funksjon (bruker selgmented)
# 
get_model <- function(id, data){
  cat("-------------------------------------------------\n", id, "\n")   # prints to screen (or file)
  data_pick <<- data %>% filter(monitoringSiteIdentifier == id) # using "<<-" because selgmented relies on data_pick being global :-|
  # create a linear model
  my.lm <- lm(TotP ~ Year, data = data_pick)
  result <- selgmented(my.lm, seg.Z = ~ Year, Kmax = 2)
  cat("\n")
  list(result = result, id = id)
}
# Test 1
get_model(identifiers[6], dat2)

# Test 2
test <- identifiers[5:6] %>% 
  purrr::map(get_model, data = dat2) %>% 
  set_names(identifiers[5:6])
str(test, 1)
str(test[[1]], 1)

#
# Kjører alle (< 1 minutt)
#
sink("01_Output_selgmented.txt")     # sender output (som ellers ville gått til skjerm) til denne fila
model_list <- purrr::map(identifiers, get_model, data = dat2)
model_list <- set_names(model_list, identifiers)
sink()                              # sender output til skjerm igjen

str(model_list[1:10],1)

model_list[[1]]$psi  # = NULL fordi det ikke e4r noen knekkpunkter
model_list[[6]]$psi  # en rad per knekkpunkt


#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 6. Antall knekkpunkt ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

get_number_of_breakpoints <- function(model){
  n <- ifelse(
    is.null(model$result$psi),
    0,                       # hvis
    nrow(model$result$psi)
  )
  tibble(
    monitoringSiteIdentifier = model$id,
    n_breaks = n
  )
}
# Test
# get_number_of_breakpoints(model_list[[1]])
# get_number_of_breakpoints(model_list[[6]])

# Samle alle 
df_number_of_breakpoints <- model_list %>% map_dfr(get_number_of_breakpoints)

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 7a. Verdi av knekkpunkt(er) ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

get_breakpoints <- function(model){
  result <- 
    tibble(monitoringSiteIdentifier = model$id,
           Brk1 = as.numeric(NA), 
           Brk1_SE = as.numeric(NA),
           Brk2 = as.numeric(NA), 
           Brk2_SE = as.numeric(NA))
  if (!is.null(model$result[["psi"]])){
    result$Brk1 <- model$result[["psi"]][1, "Est."]
    result$Brk1_SE <- model$result[["psi"]][1, "St.Err"]
    if (nrow(model$result[["psi"]]) == 2){
      result$Brk2 <- model$result[["psi"]][2, "Est."]
      result$Brk2_SE <- model$result[["psi"]][2, "St.Err"]
    }
  }
  result
}
# Test
get_breakpoints(model_list[[1]])
get_breakpoints(model_list[[6]])
get_breakpoints(model_list[["FISW_214"]])

# Samle alle 
df_breakpoints_value <- purrr::map_dfr(model_list, get_breakpoints)

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 7b. Verdi av stigningstall ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

get_slope <- function(model){
  result <- 
    data.frame(monitoringSiteIdentifier = model$id,
               Slope1 = as.numeric(NA), 
               Slope1_SE = as.numeric(NA),
               Slope2 = as.numeric(NA), 
               Slope2_SE = as.numeric(NA),
               Slope3 = as.numeric(NA), 
               Slope3_SE = as.numeric(NA),
               Slope_p = as.numeric(NA))
  result[1, "Slope_p"] <- summary(model$result)$coef[2,4]  
  if (is.null(model$result$psi)){
    result[1, c("Slope1","Slope1_SE")] <- summary(model$result)$coef[2,1:2]
  } else {
    slopes <- slope(model$result)
    result[1, c("Slope1","Slope1_SE")] <- slopes$Year[1,1:2]
    result[1, c("Slope2","Slope2_SE")] <- slopes$Year[2,1:2]
    if (nrow(slopes$Year) == 3){
      result[1, c("Slope3","Slope3_SE")] <- slopes$Year[3,1:2]
    }
  }
  result
}

# Test
get_slope(model_list[[1]])
get_slope(model_list[[6]])
get_slope(model_list[["FISW_214"]])

#
# Finn alle stigningstall
#
df_slopes <- purrr::map_dfr(model_list, get_slope)


#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 8. Sett sammen resultater fra 5,6,7 ----  
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

df_breakpoints <- dat %>%
  select(waterBodyCategory:seriesSpan) %>%
  left_join(df_number_of_breakpoints) %>%
  left_join(df_breakpoints_value) %>%
  left_join(df_slopes)
  

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 9a. Plott knekkpunkt ----
#
# Kun "long"
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

df_breakpoints %>%
  filter(seriesSpan == "long") %>%
  ggplot(aes(monitoringSiteIdentifier, color = countryCode)) +
  geom_pointrange(aes(y = Brk1, ymin = Brk1 - Brk1_SE, ymax = Brk1 + Brk1_SE)) +
  geom_pointrange(aes(y = Brk2, ymin = Brk2 - Brk2_SE, ymax = Brk2 + Brk1_SE)) +
  theme(axis.text.y = element_text(size = 6)) +
  coord_flip()

ggsave("01_df_breakpoints.png", width = 6, height = 12, dpi = 400)

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 9b. Histogram for år for knekkpunkt ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

# Histogram for hevrt land
df_breakpoints %>%
  select(waterBodyCategory:seriesSpan, Brk1, Brk2) %>%
  pivot_longer(Brk1:Brk2, names_to = "Break_no", values_to = "Year") %>% 
  filter(seriesSpan == "long") %>%
  ggplot(aes(Year)) +
  geom_histogram(binwidth = 1) + 
  facet_wrap(vars(countryCode))

# Histogram med farger for land
df_breakpoints %>%
  select(waterBodyCategory:seriesSpan, Brk1, Brk2) %>%
  pivot_longer(Brk1:Brk2, names_to = "Break_no", values_to = "Year") %>% 
  filter(seriesSpan == "long") %>%
  ggplot(aes(Year, fill = countryCode)) +
  geom_histogram(binwidth = 1)

# Histogram med mellomrom
df_breakpoints %>%
  select(waterBodyCategory:seriesSpan, Brk1, Brk2) %>%
  pivot_longer(Brk1:Brk2, names_to = "Break_no", values_to = "Year") %>% 
  filter(seriesSpan == "long" & !is.na(Year)) %>%
  mutate(Year2 = round(Year, 0)) %>% # View()
  # Oppsummere data:
  count(countryCode, Year2) %>% #View()
  ggplot(aes(Year2, y = n)) +
  geom_col(aes(fill = countryCode)) +
  labs(x = "", y = "Count")

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 9c. Stigningstall før/etter brekkpunkt 1 ----
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

gg <- df_breakpoints %>%
  filter(seriesSpan == "long" & Brk1 >= 1996 & Brk1 <= 1999) %>%
  ggplot(aes(Slope1, Slope2, color = countryCode)) +
  geom_point()

gg

gg + 
  xlim(-0.003, 0.003) + ylim(-0.003, 0.003) +
  geom_hline(yintercept = 0) +
  geom_vline(xintercept = 0)

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 10. Plotting trend/data vs time ----  
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

# Function 
get_plotdata_vs_time <- function(model){
  # points on x axis for plotting line
  yrs <- c(model$result$rangeZ[1], 
           model$result[["psi"]][,2],
           model$result$rangeZ[2])
  my.fitted <- predict(model$result, 
                       newdata = data.frame(Year = yrs))
  my.model <- data.frame(
    monitoringSiteIdentifier = model$id,
    Year = yrs, 
    TotP = my.fitted)
  my.model
  }

# Test
get_plotdata_vs_time(model_list[[6]])

# Velge stasjoner med brekkpunkt 1996-1999 
stations <- df_breakpoints %>%
  filter(seriesSpan == "long" & Brk1 >= 1996 & Brk1 <= 1999) %>%
  pull(monitoringSiteIdentifier)

df_timeplot <- model_list[stations] %>% 
  map_dfr(get_plotdata_vs_time)

ggplot(df_timeplot, aes(Year, TotP, group = monitoringSiteIdentifier)) +
  geom_line()

# Kun stasjoner med 
stations <- df_breakpoints %>%
  filter(seriesSpan == "long" & Brk1 >= 1996 & Brk1 <= 1999 &
           Slope1 >  -0.004) %>%
  pull(monitoringSiteIdentifier)

df_timeplot <- model_list[stations] %>% 
  map_dfr(get_plotdata_vs_time) %>%
  left_join(dat %>%
              select(waterBodyCategory:seriesSpan))

ggplot(df_timeplot, aes(Year, TotP, 
                        group = monitoringSiteIdentifier,
                        color = countryCode)) +
  geom_line()

#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o
#
# 11. Lagre ----  
#
#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o#o

writexl::write_xlsx(df_breakpoints, "01_df_breakpoints.xlsx")


