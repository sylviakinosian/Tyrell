###########################################################
# Regress Rt against environment for Imperial predictions #
###########################################################

source("src/packages.R")

# plotting theme
main_theme <- theme_bw() + 
  theme(axis.text.x = element_text(size = 14),
        axis.text.y = element_text(size = 14),
        axis.title.y = element_text(size = 16),
        axis.title.x = element_text(size = 16),
        plot.title = element_text(size=16, vjust=1),
        legend.text=element_text(size=16),
        legend.title = element_text(size = 16),
        strip.text.x = element_text(size = 14))
# colourblind friendly palette
cbPalette <- c("#CC0000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#999999", "#CC79A7")

# load in the data
full_climate_df_R0 <- read.csv("clean-data/climate_and_R0.csv")
full_climate_df_lockdown <- read.csv("clean-data/climate_and_lockdown_Rt.csv")

# should we transform pop density?
# ggplot(full_climate_df, aes(x = Pop_density)) + geom_histogram()
# ggplot(full_climate_df, aes(x = sqrt(Pop_density))) + geom_histogram()
# ggplot(full_climate_df, aes(x = log(Pop_density))) + geom_histogram()
# guess we'd better log it to make it more normally distributed

##############################
# --- USA vs environment --- #
##############################

USA_R0_data <- full_climate_df_R0[full_climate_df_R0$dataset == "USA",]
USA_Rt_data <- full_climate_df_lockdown[full_climate_df_lockdown$dataset == "USA",]

## -- Regressions -- ##

# 1. all variables

USA_regression_model_full <- lm(R0 ~ February_20_TC + February_20_AH + Feb_UV + log10(Pop_density), data = USA_R0_data)
summary(USA_regression_model_full)
# print(xtable(summary(USA_regression_model_full)))
# scaled coefficicents:
xtable(summary(lm(R0 ~ scale(February_20_TC) + scale(February_20_AH) + scale(Feb_UV) + scale(log10(Pop_density)), data = USA_R0_data)))

# 2. check corellation between climate variables

USA_clim_vars <- USA_R0_data[,c("February_20_TC", "February_20_AH", "Feb_UV")]

USA_clim_vars <- USA_clim_vars[!is.na(USA_clim_vars$February_20_TC) &
                         !is.na(USA_clim_vars$February_20_AH) &
                         !is.na(USA_clim_vars$Feb_UV),]

cor(USA_clim_vars)

vif(USA_regression_model_full)

# which is the best fitting when pop density is accounted for?
summary(lm(R0 ~ February_20_TC + log10(Pop_density), data = USA_R0_data))
summary(lm(R0 ~ February_20_AH + log10(Pop_density), data = USA_R0_data))
summary(lm(R0 ~ Feb_UV + log10(Pop_density), data = USA_R0_data))
# temperature model has the highest r2


# 3. temperature + pop density only

USA_regression_model <- lm(R0 ~ February_20_TC + log10(Pop_density), data = USA_R0_data)
summary(USA_regression_model)
# print(xtable(summary(USA_regression_model)))
# scaled coefficients?
xtable(summary(lm(R0 ~ scale(February_20_TC) + scale(log10(Pop_density)), data = USA_R0_data)))

# 4. check effects of lockdown
USA_regression_model_lockdown <- lm(Rt ~ May_20_TC + log10(Pop_density), data = USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,])
summary(USA_regression_model_lockdown)
summary(lm(Rt~ scale(May_20_TC) +  scale(log10(Pop_density)), data = USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,]))
# much lower correlations

# 5. t-test of R0 vs Rt to show importance of lockdown

USA_R0_data$Rt <- NA
locations <- as.character(unique(USA_R0_data$Location))
for(i in 1:length(locations)){
  
  R_t <- USA_Rt_data[USA_Rt_data$Location == locations[i],]$Rt
  if(length(R_t) > 0){
    USA_R0_data[USA_R0_data$Location == locations[i],]$Rt <- R_t 
  }
}

t.test(USA_R0_data$R0, USA_R0_data$Rt, paired = TRUE, alternative = "greater", na.rm = TRUE)

# 6. Combine temperature and population density into one 3d plot with trend surface
# plot_ly method?

# predict model over sensible grid of values
temps <- seq(-9.5, 20, by = 0.1)
pops <- 10^(seq(0.8, 3.5, by = 0.1))
grid <- with(USA_R0_data, expand.grid(temps, pops))
d <- setNames(data.frame(grid), c("February_20_TC", "Pop_density"))
vals <- predict(USA_regression_model, newdata = d)

# form matrix and give to plotly
R0 <- matrix(vals, nrow = length(unique(d$February_20_TC)), ncol = length(unique(d$Pop_density)))

R0_3d <- plot_ly() %>% 
  add_surface(x = ~log10(pops), y = ~temps, z = ~R0, opacity = 0.9, cmin = 0, cmax = 4.5) %>%
  add_trace(x = log10(USA_R0_data$Pop_density), 
            y = USA_R0_data$February_20_TC,
            z = USA_R0_data$R0, 
            type = "scatter3d", 
            mode = "markers",
            marker = list(color = "grey", size = 3,
                          line = list(color = "black",width = 1)),
            opacity = 1) %>% 
  layout(scene = list(xaxis = list(title = "", autorange = "reversed", tickfont = list(size = 15)),
                      yaxis = list(title = "", autotick = F, tickmode = "array", tickvals = c(-5, 0, 5, 10, 15, 20), 
                                   tickfont = list(size = 15)),
                      zaxis = list(title = "", range = c(0, 4.5), autotick = F, tickmode = "array", tickvals = c(1, 2, 3, 4, 5),
                                   tickfont = list(size = 15))))
R0_3d

# repeat for Rt data
# predict model over sensible grid of values (ld for lockdown)
temps_ld <- seq(7, 25, by = 0.1)
pops_ld <- 10^(seq(0.8, 3.5, by = 0.1))
grid_ld <- with(USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,], expand.grid(temps_ld, pops_ld))
d_ld <- setNames(data.frame(grid_ld), c("May_20_TC", "Pop_density"))
vals_ld <- predict(USA_regression_model_lockdown, newdata = d_ld)

Rt <- matrix(vals_ld, nrow = length(unique(d_ld$May_20_TC)), ncol = length(unique(d_ld$Pop_density)))

Rt_3d <- plot_ly() %>% 
  add_surface(x = ~log10(pops_ld), y = ~temps_ld, z = ~Rt, opacity = 0.9, cmin = 0, cmax = 4.5) %>%
  add_trace(x = log10(USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,]$Pop_density), 
            y = USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,]$May_20_TC,
            z = USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,]$Rt, 
            type = "scatter3d", 
            mode = "markers",
            marker = list(color = "grey", size = 3,
                          line = list(color = "black",width = 1)),
            opacity = 1) %>% 
  layout(scene = list(xaxis = list(title = "", autorange = "reversed", tickfont = list(size = 15)),
                      yaxis = list(title = "", tickfont = list(size = 15)),
                      zaxis = list(title = "", range = c(0, 4.5), autotick = F, tickmode = "array", tickvals = c(1, 2, 3, 4, 5),
                                   tickfont = list(size = 15))),
                                   showlegend = FALSE) %>%
  hide_colorbar() 
Rt_3d

# 7. plot residuals from pop density regression against temperature

d <- USA_R0_data[,c("February_20_TC", "February_20_AH", "Feb_UV", "Pop_density", "R0", "Location")]
names(d) <- c("Temperature", "Humidity", "UV", "Pop_density", "R0", "State")

d$pop_residuals <- residuals(lm(R0 ~ log10(Pop_density), data = d))

USA_residual_plot <- ggplot(d, aes(x = Temperature, y = pop_residuals)) + 
  geom_point(shape = 21, size = 3, alpha = 0.8, fill = "#56B4E9") +
  geom_smooth(method = lm, col = "black") +
  labs(x = expression(paste("Median February 2020 Temperature (", degree*C, ")")), 
       y = expression(paste("Corrected ", R[0]))) +
  geom_text(aes(label = State), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
  main_theme +
  theme(aspect.ratio = 1)
USA_residual_plot

ggsave("figures/USA_pop_residuals_vs_temperature.png", USA_residual_plot)

# 8. Plot heatmap of temp vs population density, with
# cells coloured by R0, with datapoints overlayed

predicted_R0 <- data.frame(grid, vals)
names(predicted_R0) <- c("Temperature", "Pop_density", "R0")

heatmap_plot <- ggplot(predicted_R0, aes(x = Temperature, y = log10(Pop_density))) + 
  geom_tile(aes(fill = R0)) +
  geom_point(data = USA_R0_data, aes(x = February_20_TC, y = log10(Pop_density), fill = R0), size = 4, shape = 21) +
  geom_text(data = USA_R0_data, aes(x = February_20_TC, y = log10(Pop_density), label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
  scale_fill_gradient(low = "blue", high = "yellow") +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(x = "Temperature (°C)",
       y = expression(paste(log[10], "(Population density)"))) +
  main_theme +
  theme(aspect.ratio = 1)
heatmap_plot

ggsave("figures/heatmap_R0.png", heatmap_plot)



################################
#### Supplementary material ####
################################

# ---- interactions ---- #

# combine R0 and Rt data and add lockdown as an interaction term

R0_df <- USA_R0_data[,c("Location", "R0", "February_20_TC", "February_20_AH", "Feb_UV", "Pop_density")]
names(R0_df) <- c("Location", "R0", "Temperature", "Absolute_humidity", "UV", "Pop_density")
R0_df$Lockdown <- "No"

Rt_df <- USA_R0_data[,c("Location", "Rt", "May_20_TC", "May_20_AH", "May_UV", "Pop_density")]
names(Rt_df) <- c("Location", "R0", "Temperature", "Absolute_humidity", "UV", "Pop_density")
Rt_df$Lockdown <- "Yes"

interaction_df <- rbind(R0_df, Rt_df)

interaction_lm <- lm(R0 ~ (scale(Temperature) + scale(log(Pop_density)))*Lockdown, data = interaction_df)
summary(interaction_lm)
addative_lm <- lm(R0 ~ scale(Temperature) + scale(log(Pop_density)) + Lockdown, data = interaction_df)
summary(addative_lm)

anova(addative_lm, interaction_lm)

# is this useful?


# ---- combined 3d plot ---- #

# 3D plot of Temperature, R0, population density for all 3 datasets to show partitioning
# plot3D solution
# x, y and z coordinates
x <- full_climate_df_R0$February_20_TC
y <- log(full_climate_df_R0$Pop_density)
z <- full_climate_df_R0$R0

png("figures/all_data_3d.png", width = 600, height = 600)
scatter3D(x, y, z, bty = "b2", pch = 19, 
          colvar = as.integer(full_climate_df_R0$dataset), 
          col = c("#CC0000", "#E69F00", "#56B4E9"),
          phi = 20, theta = 30, type = "h",
          pch = 18, cex = 1.5,
          colkey = list(at = c(1, 2, 3), side = 1, 
                        addlines = TRUE, length = 0.5, width = 0.5,
                        labels = c("Europe", "LMIC", "USA")),
          xlab = "Temperature",
          ylab ="log(Population density)", zlab = "R0")
dev.off()


# --- regression models for other datasets --- #


Europe_regression_model <- lm(R0 ~ scale(February_20_TC) +  scale(log(Pop_density)), data = full_climate_df_R0[full_climate_df_R0$dataset == "Europe",])
xtable(summary(Europe_regression_model))

LMIC_regression_model <- lm(R0 ~ scale(February_20_TC) + scale(log(Pop_density)), data = full_climate_df_R0[full_climate_df_R0$dataset == "LMIC",])
xtable(summary(LMIC_regression_model))


Europe_regression_model_lockdown <- lm(Rt ~ February_20_TC + log(Pop_density) + lockdown_strength, data = full_climate_df_lockdown[full_climate_df_lockdown$dataset == "Europe",])
summary(Europe_regression_model_lockdown)

LMIC_regression_model_lockdown <- lm(Rt ~ February_20_TC + log(Pop_density) + lockdown_strength, data = full_climate_df_lockdown[full_climate_df_lockdown$dataset == "LMIC",])
summary(LMIC_regression_model_lockdown)


# --- Do contact matrices matter? --- #

LMIC_contact_regression <- lm(R0 ~ scale(February_20_TC) + scale(log(Pop_density)) + n_contacts, data = full_climate_df_R0[full_climate_df_R0$dataset == "LMIC",])
summary(LMIC_contact_regression)

Europe_contact_regression <- lm(R0 ~ scale(February_20_TC) + scale(log(Pop_density)) + n_contacts, data = full_climate_df_R0[full_climate_df_R0$dataset == "Europe",])
summary(Europe_contact_regression)

# --- Does choice of month matter? --- #

# Jan
xtable(summary(lm(R0 ~ January_20_TC + log(Pop_density), data = USA_R0_data)))
# March
xtable(summary(lm(R0 ~ March_20_TC + log(Pop_density), data = USA_R0_data)))


# ---- Does the date when state-wide emergency decrees were implemented matter? ---- #

summary(lm(R0 ~ as.Date(emergency_decree), data = USA_R0_data))

emergdec_plot <- ggplot(USA_R0_data, aes(x = as.Date(emergency_decree), y = R0)) + 
  geom_point(size = 2) +
  geom_smooth(method = lm, col = "black") +
  geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.02)) +
  labs(x = "Date of Emergency Decree",
       y = expression(R[0])) +
  main_theme +
  theme(aspect.ratio = 1)
emergdec_plot

ggsave("figures/emergdec_plot.png", emergdec_plot)

emergdec_lm <- lm(R0 ~ as.Date(emergency_decree) + February_20_TC + log10(Pop_density), data = USA_R0_data)
summary(emergdec_lm)
vif(emergdec_lm)

# date of first 10 deaths?

summary(lm(R0 ~ as.Date(date_first_ten), data = USA_R0_data))

firstten_plot <- ggplot(USA_R0_data, aes(x = as.Date(date_first_ten), y = R0)) + 
  geom_point(size = 2) +
  geom_smooth(method = lm, col = "black") +
  geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.02)) +
  labs(x = "Date of First 10 Deaths",
       y = expression(R[0])) +
  main_theme +
  theme(aspect.ratio = 1)
firstten_plot

# new metric of "preparedness" of state 
# - how early did they put out emergency decree
# compared to their number of deaths

USA_R0_data$preparedness <- as.Date(USA_R0_data$date_first_ten) - as.Date(USA_R0_data$emergency_decree)

summary(lm(R0 ~ preparedness, data = USA_R0_data))

preparedness_plot <- ggplot(USA_R0_data, aes(x =preparedness, y = R0)) + 
  geom_point(size = 2) +
  geom_smooth(method = lm, col = "black") +
  geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.02)) +
  labs(x = "Preparedness",
       y = expression(R[0])) +
  main_theme +
  theme(aspect.ratio = 1)
preparedness_plot

preparedness_lm <- lm(R0 ~ preparedness + February_20_TC + log10(Pop_density), data = USA_R0_data)
summary(preparedness_lm)
vif(preparedness_lm)

#
#
#
#

# -- Old stuff -- #


# 
# # can we plot the USA model residuals onto the US states map?
# # i.e. which states have higher R0 than our model predicts, which have lower?
# 
# library("usmap")
# 
# # list of all US states
# us_state_list <- data.frame(unique(usmap::us_map()$abbr))
# names(us_state_list) <- c("state")
# 
# # get residuals from the temp + pop density US model
# 
# d$all_residuals <- residuals(lm(R0 ~ Temperature + log(Pop_density), data = d))
# # d$all_residuals <- residuals(lm(R0 ~ log(Pop_density), data = d))
# # d$all_residuals <- residuals(lm(R0 ~ Temperature, data = d))
# 
# 
# us_residuals_data <- d[,c("State", "all_residuals")]
# names(us_residuals_data) <- c("state", "value")
# us_state_data <- merge(x = us_state_list, y = us_residuals_data, by.x = "state", by.y = "state", all.x = TRUE)
# 
# png("~/Documents/COVID/figures/USA_residuals_map.png", width = 800, height = 600)
# plot_usmap(data = us_state_data, values = "value") + 
#   scale_fill_gradient2(low = "blue", mid = "white", high = "red", name = "Model Residuals") +
#   theme(legend.text = element_text(size = 12),
#         legend.title = element_text(size = 14),
#         legend.position = c(0, 0.15))
# dev.off()

# # --- combined dataset plots --- #

# temperature
# all_plot_temperature <- ggplot(full_climate_df_R0, aes(x = February_20_TC, y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.6) +
#   geom_smooth(method = lm, aes(col = dataset), se = FALSE, size = 2) +
#   geom_smooth(method = lm, col = "black", size = 2) +
#   labs(x = expression(paste("February Temperature (", degree*C, ")")), y = expression(R[0])) +
#   scale_fill_manual(values=cbPalette) +
#   scale_colour_manual(values=cbPalette) +
#   main_theme +
#   #annotate("text", x = -18, y = 5.5, label = "A", size = 10) +
#   theme(legend.title = element_blank(),
#         legend.position = c(0.2, 0.8))
# # all_plot_temperature
# 
# # relative humidity
# all_plot_humidity_rel <- ggplot(full_climate_df_R0, aes(x = February_20_RH, y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("February Relative Humidity (", '%', ")")), y = expression(R[0])) +
#   scale_fill_manual(values=cbPalette) +
#   annotate("text", x = 15, y = 5.5, label = "B", size = 10) +
#   main_theme +
#   theme(legend.position = "none")
# # all_plot_humidity_rel
# 
# # absolute humidity
# all_plot_humidity_abs <- ggplot(full_climate_df_R0, aes(x = February_20_AH, y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, aes(col = dataset), se = FALSE, size = 2) +
#   geom_smooth(method = lm, col = "black", size = 2) +
#   labs(x = expression(paste("February Absolute Humidity (g", m^-3, ")")) , y = expression(R[0])) +
#   scale_fill_manual(values=cbPalette) +
#   scale_colour_manual(values=cbPalette) +
#   #annotate("text", x = 0.7, y = 5.5, label = "B", size = 10) +
#   main_theme +
#   theme(legend.position = "none")
# # all_plot_humidity_abs
# 
# # UV-B
# all_plot_uv <- ggplot(full_climate_df_R0, aes(x = Feb_UV, y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, aes(col = dataset), se = FALSE, size = 2) +
#   geom_smooth(method = lm, col = "black", size = 2) +
#   labs(x = expression(paste("February UV-B (", J, m^-2, d^-1, ")")), y = expression(R[0])) +
#   scale_fill_manual(values=cbPalette) +
#   scale_colour_manual(values=cbPalette) +
#   #annotate("text", x = 0, y = 5.5, label = "C", size = 10) +
#   main_theme +
#   theme(legend.position = "none")
# # all_plot_uv
# 
# # population density
# all_plot_popdensity <- ggplot(full_climate_df_R0, aes(x = log(Pop_density), y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, aes(col = dataset), se = FALSE, size = 2) +
#   geom_smooth(method = lm, col = "black", size = 2) +
#   labs(x = expression(paste("log (People ", km^-2, ")")), y = expression(R[0])) +
#   scale_fill_manual(values=cbPalette) +
#   scale_colour_manual(values=cbPalette) +
#   #annotate("text", x = 1, y = 5.5, label = "D", size = 10) +
#   main_theme +
#   theme(legend.position = "none")
# # all_plot_popdensity
# 
# ggsave("figures/temperature_plot.png", all_plot_temperature)
# ggsave("figures/absolute_humidity_plot.png", all_plot_humidity_abs)
# ggsave("figures/uv_plot.png", all_plot_uv)
# ggsave("figures/pop_density_plot.png", all_plot_popdensity)
# 
# # --- compare to post-lockdown Rt vs May climate --- #
# 
# # temperature
# lockdown_plot_temperature <- ggplot(full_climate_df_lockdown, aes(x = May_20_TC, y = Rt)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.6) +
#   geom_smooth(method = lm, aes(col = dataset), se = FALSE, size = 2) +
#   geom_smooth(method = lm, col = "black", size = 2) +
#   labs(x = expression(paste("May Temperature (", degree*C, ")")), y = expression(paste("May ", R[t]))) +
#   scale_fill_manual(values=cbPalette) +
#   scale_colour_manual(values=cbPalette) +
#   main_theme +
#   #annotate("text", x = 3, y = 5.5, label = "D", size = 10) +
#   theme(legend.position = "none")
# lockdown_plot_temperature
# 
# ggsave("figures/temperature_plot_lockdown.png", lockdown_plot_temperature)
# 
# # population density
# 
# lockdown_plot_popdensity <- ggplot(full_climate_df_lockdown, aes(x = log(Pop_density), y = Rt)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.6) +
#   geom_smooth(method = lm, aes(col = dataset), se = FALSE, size = 2) +
#   geom_smooth(method = lm, col = "black", size = 2) +
#   labs(x = expression(paste("log (People ", km^-2, ")")), y = expression(paste("May ", R[t]))) +
#   scale_fill_manual(values=cbPalette) +
#   scale_colour_manual(values=cbPalette) +
#   main_theme +
#   theme(legend.position = "none")
# lockdown_plot_popdensity
# 
# ggsave("figures/popdensity_plot_lockdown.png", lockdown_plot_popdensity)

# # --- USA only plots --- #
# 

# plot temperature and population density pre- and post- lockdown regressions
# 
# USA_plot_temperature <-  ggplot(USA_R0_data, aes(x = February_20_TC, y = R0)) +
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("Median February 2020 Temperature (", degree*C, ")")), y = expression(R[0])) +
#   geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   scale_fill_manual(values=c("#56B4E9")) +
#   main_theme +
#   theme(legend.position = "none")
# USA_plot_temperature
# 
# USA_plot_popdensity <-  ggplot(USA_R0_data, aes(x = log(Pop_density), y = R0)) +
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("log (People ", km^-2, ")")), y = expression(R[0])) +
#   geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   scale_fill_manual(values=c("#56B4E9")) +
#   main_theme +
#   theme(legend.position = "none")
# USA_plot_popdensity
# 
# ggsave("figures/USA_temperature_plot.png", USA_plot_temperature)
# ggsave("figures/USA_pop_density_plot.png", USA_plot_popdensity)
# 
# USA_plot_temperature_lockdown <-  ggplot(USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,], aes(x = May_20_TC, y = Rt)) +
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("Median May 2020 Temperature (", degree*C, ")")), y = expression(R[t])) +
#   geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.01)) +
#   scale_fill_manual(values=c("#56B4E9")) +
#   main_theme +
#   theme(legend.position = "none")
# USA_plot_temperature_lockdown
# 
# USA_plot_popdensity_lockdown <-  ggplot(USA_Rt_data[USA_Rt_data$Location %in% USA_R0_data$Location,], aes(x = log(Pop_density), y = Rt)) +
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("log (People ", km^-2, ")")), y = expression(R[t])) +
#   geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.01)) +
#   scale_fill_manual(values=c("#56B4E9")) +
#   main_theme +
#   theme(legend.position = "none")
# USA_plot_popdensity_lockdown
# 
# ggsave("figures/USA_temperature_plot_lockdown.png", USA_plot_temperature_lockdown)
# ggsave("figures/USA_pop_density_plot_lockdown.png", USA_plot_popdensity_lockdown)

# 
# USA_plot_humidity <-  ggplot(full_climate_df_R0[full_climate_df_R0$dataset == "USA",], aes(x = February_20_AH, y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("February Absolute Humidity (g", m^-3, ")")), y = expression(R[0])) +
#   geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   scale_fill_manual(values=c("#56B4E9")) +
#   main_theme +
#   theme(legend.position = "none")
# USA_plot_humidity
# 
# USA_plot_uv <-  ggplot(full_climate_df_R0[full_climate_df_R0$dataset == "USA",], aes(x = Feb_UV, y = R0)) + 
#   geom_point(aes(fill = dataset), shape = 21, size = 3, alpha = 0.8) +
#   geom_smooth(method = lm, col = "black") +
#   labs(x = expression(paste("February UV-B (", J, m^-2, d^-1, ")")), y = expression(R[0])) +
#   geom_text(aes(label = Location), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   scale_fill_manual(values=c("#56B4E9")) +
#   main_theme +
#   theme(legend.position = "none")
# USA_plot_uv


# plot the residuals from the USA model
# just do lm(R0 ~ pop density)
# then plot the residuals from that for the climate variables


# # Fit the model
# # fit <- lm(R0 ~ Temperature + Humidity + UV + log(Pop_density), data = d)
# 
# fit <- lm(R0 ~ log(Pop_density), data = d)
# summary(fit)
# 
# # Obtain predicted and residual values
# d$predicted <- predict(fit)
# d$residuals <- residuals(fit)
# head(d)
# 
# residual_plot_temp <- ggplot(d, aes(x = Temperature, y = R0)) +
#   geom_segment(aes(xend = Temperature, yend = predicted), alpha = 0.3) +  # Lines to connect points
#   geom_point(aes(color = residuals, size = abs(residuals))) +
#   geom_point(aes(y = predicted), shape = 1) +  # Points of predicted values
#   scale_color_gradient2(low = "blue", mid = "white", high = "red") +
#   guides(color = FALSE) +
#   geom_text(aes(label = State), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   #annotate("text", x = -10, y = 3.5, label = "A", size = 10) +
#   labs(x = expression(paste("February Temperature (", degree*C, ")")), y = expression(R[0])) +
#   main_theme +
#   theme(legend.position = "none")
# residual_plot_temp
# 
# residual_plot_humidity <- ggplot(d, aes(x = Humidity, y = R0)) +
#   geom_segment(aes(xend = Humidity, yend = predicted), alpha = 0.3) +  # Lines to connect points
#   geom_point(aes(color = residuals, size = abs(residuals))) +
#   geom_point(aes(y = predicted), shape = 1) +  # Points of predicted values
#   scale_color_gradient2(low = "blue", mid = "white", high = "red") +
#   guides(color = FALSE) +
#   geom_text(aes(label = State), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   #annotate("text", x = 2, y = 3.5, label = "B", size = 10) +
#   main_theme +
#   theme(legend.position = "none")
# residual_plot_humidity
# # guess we shouldn't really do humidity if its not significant anyway
# 
# residual_plot_pop <- ggplot(d, aes(x = log(Pop_density), y = R0)) +
#   geom_segment(aes(xend = log(Pop_density), yend = predicted), alpha = 0.3) +  # Lines to connect points
#   geom_point(aes(color = residuals, size = abs(residuals))) +
#   geom_point(aes(y = predicted), shape = 1) +  # Points of predicted values
#   scale_color_gradient2(low = "blue", mid = "white", high = "red") +
#   guides(color = FALSE) +
#   geom_text(aes(label = State), hjust = 0, vjust = 0, position = position_nudge(y = 0.05)) +
#   #annotate("text", x = 2, y = 3.5, label = "B", size = 10) +
#   labs(x = expression(paste("log (People ", km^-2, ")")), y = expression(R[0])) +
#   main_theme +
#   theme(legend.position = "none")
# residual_plot_pop
# 
# png("figures/USA_residual_plots.png", width = 800, height = 400)
# grid.arrange(residual_plot_temp, residual_plot_pop, nrow = 1)
# dev.off()

# 3d plot with shadows:

# lattice method
# df <- USA_R0_data[,c("February_20_TC", "Pop_density", "R0")]
# df$Pop_density <- log(df$Pop_density)
# names(df) <- c("temperature", "log_pop_density", "r0")
# 
# plot_range_x <- c(min(df$temperature)*1.1, max(df$temperature)*1.1)
# plot_range_y <- c(min(df$log_pop_density)*0.9, max(df$log_pop_density)*1.1)
# plot_range_z <- c(0, 3.8)
# 
# shadow_x <- df
# shadow_y <- df
# shadow_z <- df
# shadow_x$temperature <- rep(max(plot_range_x),length(shadow_y$log_pop_density))
# shadow_y$log_pop_density <- rep(max(plot_range_y),length(shadow_y$log_pop_density))
# shadow_z$r0 <- rep(min(plot_range_z),length(shadow_y$log_pop_density))
# df_shadows <- rbind(df, shadow_x, shadow_y, shadow_z)
# png("figures/USA_3d_R0.png")
# cloud(df_shadows$r0 ~ 
#         df_shadows$temperature*df_shadows$log_pop_density,
#       screen=list(z = 50, x = -70, y = 0),
#       scales=list(arrows=FALSE, cex=0.6, col="black", font=3,
#                   tck=0.6, distance=1),
#       pch=c(rep(19, 43), rep(19, 129)), 
#       col=c(rep("blue", 43), rep("gray", 129)),
#       cex = 1.5,
#       xlim=plot_range_x, ylim=plot_range_y, zlim=plot_range_z,
#       xlab = "Temperature", ylab = "log(Pop density)", zlab = expression(R[0]))
# dev.off()
# 
# 
# # repeat for post-lockdown
# df_2 <- USA_R0_data[,c("May_20_TC", "Pop_density", "Rt")]
# df_2$Pop_density <- log(df_2$Pop_density)
# names(df_2) <- c("temperature", "log_pop_density", "rt")
# 
# plot_range_x <- c(min(df_2$temperature)*1.1, max(df_2$temperature)*1.1)
# plot_range_y <- c(min(df_2$log_pop_density)*0.9, max(df_2$log_pop_density)*1.1)
# plot_range_z <- c(0, 3.8)
# 
# shadow_x <- df_2
# shadow_y <- df_2
# shadow_z <- df_2
# shadow_x$temperature <- rep(max(plot_range_x),length(shadow_y$log_pop_density))
# shadow_y$log_pop_density <- rep(max(plot_range_y),length(shadow_y$log_pop_density))
# shadow_z$rt <- rep(min(plot_range_z),length(shadow_y$log_pop_density))
# df_2_shadows <- rbind(df_2, shadow_x, shadow_y, shadow_z)
# png("figures/USA_3d_Rt.png")
# cloud(df_2_shadows$rt ~ 
#         df_2_shadows$temperature*df_2_shadows$log_pop_density,
#       screen=list(z = 50, x = -70, y = 0),
#       scales=list(arrows=FALSE, cex=0.6, col="black", font=3,
#                   tck=0.6, distance=1),
#       pch=c(rep(19, 43), rep(19, 129)), 
#       col=c(rep("blue", 43), rep("gray", 129)),
#       cex = 1.5,
#       xlim=plot_range_x, ylim=plot_range_y, zlim=plot_range_z,
#       xlab = "Temperature", ylab = "log(Pop density)", zlab = expression(R[t]))
# dev.off()

