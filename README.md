# vvolakakis-vvolakakis-ABM_Consideration_Set
An Agent – Based Simulation Framework to Observe Variations of Consideration Set and Mode Choice, Stemming from Interactions  within Social Settings

# Overview

This repository contains the code and simulation framework developed for studying consideration sets and their dynamics in choice modeling. The focus is on understanding how individual and social factors influence the alternatives considered before making a final choice, particularly in the context of transportation mode choice.

The framework is based on NetLogo and integrates agent-based modeling (ABM) with utility-based decision-making models, including a Multinomial Logit Model (MNL) estimated from survey data. The simulation captures the effects of individual-to-individual (I2I) and individual-to-environment (I2E) interactions on agents' consideration sets and choices.

# Key Features

## Agent-Based Model
Agents: Individuals with socioeconomic and demographic attributes sampled from survey data. Agents represent customers and carriers (last-mile delivery operators).
Attributes: Includes elasticities for travel time, cost, and environmental impact, as well as leader-follower dynamics, proximity effects, and shopping behavior.
Decision-making: Each agent’s choice is influenced by a utility function based on either:
Simple weights for cost, time, and environmental impact.
Coefficients from an MNL model estimated using R.
Social and Environmental Interactions
Social Influence: Links between agents represent proximity-based interactions, which influence their consideration sets and final choices.
Carrier Influence: Carrier agents modify customer preferences via strategies like rebates or reduced costs for environmentally friendly options.
## Integrated Models
Economic Model: Simulates economic cycles (boom/bust) and their effects on job creation, unemployment, and agents' decisions.
Environmental Model: Tracks greenhouse gas concentrations (CO2, CH4, N2O) and their effects on climate and agent behavior.
Simulation Details
Framework: Built entirely in NetLogo with extensions via LevelSpace.
Time Step: Day-level simulation, reflecting the typical frequency of package deliveries.
Utility Functions:
Baseline consideration sets generated from survey data.
Dynamic updates based on social and environmental interactions.
Scenarios: Includes variations in environmental quality, economic health, and agent behavior to analyze their impacts on decision-making.

# Requirements

NetLogo 6.3 or later
R (for MNL model estimation)

# Results

The simulation results highlight:
The impact of social and environmental factors on consideration sets and final choices.
Changes in agent behavior over time under varying economic and environmental conditions.
Effects of carrier strategies on consumer preferences for delivery modes.

# References

Wilensky, U. (1999). NetLogo. Center for Connected Learning and Computer-Based Modeling, Northwestern University. http://ccl.northwestern.edu/netlogo/
Hjorth, A., Wilensky, U., & Lombardi, M. (2015). LevelSpace: Extending NetLogo with Multi-Level Agent-Based Modeling.
R Core Team (2020). R: A language and environment for statistical computing. R Foundation for Statistical Computing, Vienna, Austria.

# Acknowledgments

This work builds on open-source contributions from the NetLogo community and incorporates data from stated preference surveys on last-mile delivery mode choice.
