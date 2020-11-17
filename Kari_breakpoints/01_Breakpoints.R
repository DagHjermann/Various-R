
# Knekkpunkt-analyse
# Har fulgt
#   https://rpubs.com/MarkusLoew/12164

# 1. Libraries  

# install.packages("segmented")
library(segmented)
library(dplyr)
library(tidyr)
library(ggplot2)
library(purrr)

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

#
# En relativt tilfeldig serie   
#
dat2_pick <- dat2 %>% filter(monitoringSiteIdentifier == identifiers[6])

ggplot(dat2_pick, aes(Year, TotP, group = monitoringSiteIdentifier, color = seriesSpan)) +
  geom_line() +
  geom_point()


#
# Eksempel i https://rpubs.com/MarkusLoew/12164
#

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
yrs <- seq(min(dat2_pick$Year), max(dat2_pick$Year))
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
# 
# selgmented - velger automatisk antall breakpoints
# 
my.selg <- selgmented(my.lm, Kmax = 2)
summary(my.selg)

my.selg <- selgmented(olm=my.lm, Kmax = 3, type = "davies")
my.selg <- selgmented(olm=my.lm, Kmax = 3, type = "bic")


# 
# selgmented i funksjon
# 
get_model <- function(id, data){
  cat("-------------------------------------------------\n", id, "\n")   # prints to screen (or file)
  data_pick <<- data %>% filter(monitoringSiteIdentifier == id) # using "<<-" because selgmented relies on data_pick being global :-|
  # create a linear model
  my.lm <- lm(TotP ~ Year, data = data_pick)
  result <- selgmented(my.lm, seg.Z = ~ Year, Kmax = 2)
  cat("\n")
  result
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
# Kjør alle (<1 minutt) 
#
sink("01_Output_selgmented.txt")     # sender output (som ellers ville gått til skjerm) til denne fila
model_list <- purrr::map(identifiers, get_model, data = dat2)
model_list <- set_names(model_list, identifiers)
sink()                              # sender output til skjerm igjen


str(model_list[1:10],1)

model_list[[1]]$psi  # = NULL fordi det ikke e4r noen knekkpunkter
model_list[[6]]$psi  # en rad per knekkpunkt

#
# Antall knekkpunkt
#
get_number_of_breakpoints <- function(model){
  ifelse(
    is.null(model$psi),
    0,                       # hvis
    nrow(model$psi)
  )
}
# Test
# get_number_of_breakpoints(model_list[[1]])
# get_number_of_breakpoints(model_list[[6]])

number_of_breakpoints <- model_list %>% map_dbl(get_number_of_breakpoints)

df_number_of_breakpoints <- tibble(
  monitoringSiteIdentifier = names(number_of_breakpoints),
  n_breaks = number_of_breakpoints
)

#
# Verdi av knekkpunkt(er)
#
get_breakpoints <- function(model){
  result <- 
    tibble(Brk1 = as.numeric(NA), 
           Brk1_SE = as.numeric(NA),
           Brk2 = as.numeric(NA), 
           Brk2_SE = as.numeric(NA))
  if (!is.null(model[["psi"]])){
    result$Brk1 <- model[["psi"]][1, "Est."]
    result$Brk1_SE <- model[["psi"]][1, "St.Err"]
    if (nrow(model[["psi"]]) == 2){
      result$Brk2 <- model[["psi"]][2, "Est."]
      result$Brk2_SE <- model[["psi"]][2, "St.Err"]
    }
  }
  result
}
# Test
get_breakpoints(model_list[[1]])
get_breakpoints(model_list[[6]])
get_breakpoints(model_list[["FISW_214"]])

#
# Finn alle knekkpunkt(er)
#
df_breakpoints_value <- purrr::map_dfr(model_list, get_breakpoints)
df_breakpoints_value$monitoringSiteIdentifier <- names(model_list)

head(df_breakpoints_value)

#
# Sett sammen
#

df_breakpoints <- dat %>%
  select(waterBodyCategory:seriesSpan) %>%
  left_join(df_number_of_breakpoints) %>%
  left_join(df_breakpoints_value)

#
# PLott knekkpunkt
#
ggplot(df_breakpoints, aes(monitoringSiteIdentifier, color = countryCode)) +
  geom_pointrange(aes(y = Brk1, ymin = Brk1 - Brk1_SE, ymax = Brk1 + Brk1_SE)) +
  geom_pointrange(aes(y = Brk2, ymin = Brk2 - Brk2_SE, ymax = Brk2 + Brk1_SE)) +
  theme(axis.text.y = element_text(size = 6)) +
  coord_flip()

# Lagre
writexl::write_xlsx(df_breakpoints, "01_df_breakpoints.xlsx")


 # get_number_of_breakpoints(model_list[[6]])