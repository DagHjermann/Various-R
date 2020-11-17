
# Calculate percentage detected (i.e., not less-thans) per parameter/group  

library(dplyr)
library(tidyr)
library(ggplot2)

# dir()
dat <- readxl::read_excel("Data til dag for deteksjonsfrekvens_2018.xlsx", col_types = "text")
colnames(dat)[1] <- "Sample_type"
# colnames(dat)

#
# Get the correct sequence of parameters and Sample_type
# (used in factor() later, to get ordering correct in plots and in 'table_detect')
#
# Parameters
param_levels <- colnames(dat)[-1]
# Sample types
type_levels <- dat$Sample_type
sel <- !(type_levels == lag(type_levels))
sel[1] <- TRUE
type_levels <- type_levels[sel]

#
# Reshape data (narrow/tall)
#
dat2 <- gather(dat, key = "Param", value = "Value" , -Sample_type)

#
# Calculate detection %
#
df_detect <- dat2 %>%
  mutate(Sample_type = factor(Sample_type, levels = type_levels), 
         Param = factor(Param, levels = param_levels)) %>%
  group_by(Sample_type, Param) %>%
  summarize(N = sum(!is.na(Value)), Nondetect_n = sum(grepl("<", Value)), Detect = 100 - 100*Nondetect_n/N )

# Test plot
ggplot(df_detect %>% mutate(Param = factor(Param, levels = rev(param_levels))), # set reverse order, in order to get first values on top
       aes(Sample_type, Param, fill = Detect)) +
  geom_raster() +
  theme(axis.text.x = element_text(hjust = 0, angle = -60)) +
  theme(axis.text.y = element_text(size = 6))

#
# Grouping
#

# With 0-9 %
group_breaks <- c(0, 10, 30, 50, 70, 90, 100)
groups <- c("0-9%", "10-29%", "30-49%", "50-69%", "70-89%", "90-100%")

# With 0% plus 1-9 %
group_breaks <- c(0, 1, 10, 30, 50, 70, 90, 100)
groups <- c("0%", "1-9%", "10-29%", "30-49%", "50-69%", "70-89%", "90-100%")

df_detect <- df_detect %>%
  mutate(Detect_group = cut(Detect, breaks = group_breaks, include.lowest = TRUE, labels = groups))

xtabs(~Detect_group, df_detect)

ggplot(df_detect %>% mutate(Param = factor(Param, levels = rev(param_levels))), # set reverse order, in order to get first values on top
       aes(Sample_type, Param, fill = Detect_group)) +
  geom_raster() +
  scale_fill_brewer("Detection", palette = "Oranges", na.value = "grey65") +
  theme(axis.text.x = element_text(hjust = 0, angle = -60)) +
  theme(axis.text.y = element_text(size = 6)) +
  labs(x = "Sample type", y = "Parameter")

ggsave("01 Detection percentage 2018.png", width = 9, height = 12, dpi = 500)

#
# Make table
#
table_detect <- df_detect %>%
  select(Param, Sample_type, Detect_group) %>%
  spread(key = Sample_type, value = Detect_group)

# Save
openxlsx::write.xlsx(table_detect, "01 Deteksjonsfrekvens 2018.xlsx")
