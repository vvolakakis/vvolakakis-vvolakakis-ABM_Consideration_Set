extensions [gis nw ls]

globals [
  agents
  transportation-options
  agent-list
  cities-dataset
  link-range
  beta-age
  beta-income
  beta-gender
  beta-household-size
  beta-shopping-propensity
  beta-cost
  beta-time
  beta-environmental
  clim-state
  poor-p
  rich-p
  jobs-n
  pop
  job-metric
  rich-metric
  poor-metric
  rich-unemp
  rich-emp
  poor-unemp
  poor-emp
  rich-employed-metric
  poor-employed-metric
  rich-unemployed-metric
  poor-unemployed-metric
  economy-profile
  cc-model
  ed-model
  env-profile
  tick-counter
  final-choice-percentages-f
  consideration-set-percentages-f
  consideration-set-proportional-percentages-f
  threshold-env
  threshold-econ
  old-final-choice
  pame
  ela
  mpaam
  final-choice-history
  consideration-set-size-history
  env-profile-history
  economy-profile-history
  switch-behavior-count
]

breed [ citizens citizen ]
breed [carriers carrier]
carriers-own[
  weight-cost-c
  weight-time-c
  weight-environmental-impact-c
]
citizens-own [ cntry_name
  weight-cost
  weight-time
  weight-environmental-impact
  final-choice
  utilities ;; List to store utilities for each option
  option-names ;; List to store names of options corresponding to utilities
  consideration-set-size ;; Number of options in the consideration set
  age
  income
  gender
  household-size
  shopping-propensity
  environment-elasticity
  price-elasticity
  delivery-time-elasticity
  education
  employment
  consideration-set
  mode-values
  follower? ;; Whether the agent is a follower (true) or not (false)
  influence-level ;; Level of influence the agent has
  my-linkss ;; List to store agent's links
  my-linkss-c
  shape-tick-counter
]

to setup
  clear-all
  set transportation-options [
    ["Traditional Delivery" 0.472 1.779 -1.7713] ;cost, delivery time, environmental friendliness
    ["Autonomous Vehicle" 1.931 0.9482 -0.407]
    ["Drone" 2.675 0.33 -0.301]
    ["Sidewalk Robot" 1.765 1.395 -0.257]
    ["Bipedal Robot" 1.220 1.243 -0.216]
  ]
  set beta-age 0.0647
  set beta-income 0.0384
  set beta-household-size 0.0149
  set beta-shopping-propensity 0.0045
  set beta-gender 0.0241
  set link-range 2 ;; Range within which agents can develop links
  setup-gis
  ;setup-agents
  create-network
  set final-choice-percentages-f []
  set consideration-set-percentages-f []
  set consideration-set-proportional-percentages-f []
  set threshold-env 0.3
  set threshold-econ 0.1
  set old-final-choice ""

  ; Initialize new global variables for recording statistics
  set final-choice-history []
  set consideration-set-size-history []
  set env-profile-history []
  set economy-profile-history []
  set switch-behavior-count 0

  draw-counties
  create-carriers-in-counties
  create-pop-in-counties
  if ls-models? [
    setup-parallel-models
  ]
  reset-ticks
end

to setup-parallel-models
  ls:reset
  set cc-model 0
  ; uncomment to hide parallel model interface
  ;(ls:create-models 1 "Climate Change.nlogo" [ [id] -> set cc-model id ])
  (ls:create-interactive-models 1 "Climate Change.nlogo" [ [id] -> set cc-model id ])
  set ed-model 0
  ;(ls:create-models 1 "Urban Suite - Economic Disparity.nlogo" [ [id] -> set ed-model id ])
  (ls:create-interactive-models 1 "Urban Suite - Economic Disparity.nlogo" [ [id] -> set ed-model id ])

  ls:ask ls:models [ setup ]
end

to run-parallel-models ;this function is destined to be for the back n forth between the parralel models running
  set clim-state [ temperature ] ls:of cc-model
  set env-profile [ environmental-index ] ls:of cc-model
  set poor-p [count poor] ls:of ed-model
  set rich-p [count rich] ls:of ed-model
  set jobs-n [count jobs] ls:of ed-model
  set poor-unemp [poor-unemployed] ls:of ed-model
  set rich-unemp [rich-unemployed] ls:of ed-model
  set poor-emp [poor-employed] ls:of ed-model
  set rich-emp [rich-employed] ls:of ed-model
  set economy-profile [economic-index] ls:of ed-model

  set pop poor-p + rich-p
  set job-metric (rich-emp + poor-emp) / pop
  set rich-metric rich-p / pop
  set poor-metric poor-p / pop
  set rich-employed-metric rich-emp / pop
  set poor-employed-metric poor-emp / pop
  set rich-unemployed-metric rich-unemp / pop
  set poor-unemployed-metric poor-unemp / pop
  ls:ask ls:models [ go ]
end

to create-network
  ask citizens [
    create-links-with n-of max-links other citizens  ; `max-links` is the maximum number of connections
  ]
   ask citizens [
    let potential-carriers carriers in-radius link-range with [not link-neighbor? myself]
    if any? potential-carriers [
      create-link-with one-of potential-carriers
    ]
  ]
  nw:set-context turtles links  ; Set the network context
end

to go
  if ticks >= 500 [ stop ]  ;; Stop the simulation after 500 ticks
  ask citizens [
    ;move
    if ticks mod 3 = 0 [
      check-links
      let leader-links filter [follower? = false] my-linkss
      if not empty? leader-links[
        if follower? and any? leader-links [
          update-weights
        ]
      ]
    ]
  ]
  if ls-models? [
    run-parallel-models
  ]
  if ticks mod 10 = 0 [
    update-agent-weights-based-on-profile
  ]

  if tick-counter mod 15 = 0 [ ;every 15 ticks we check and present the current delivery mode status of each agent
    set-shape-based-on-choice
    set tick-counter 0
  ]
  ask citizens [
    ;; Reset shape to human after 10 ticks
    ;if shape-tick-counter > 0 [
    if shape-tick-counter > 0 [
      set shape-tick-counter shape-tick-counter - 1
      if shape-tick-counter = 0 [
        set shape "person"
        set size 1  ;; Reset size to default
      ]
    ]
  ]
  set tick-counter tick-counter + 1
  update-network-context
  evaluate-and-choose-options
  plot-distributions

  ; Record statistics at each time step
  record-statistics

  tick
end

to update-weights
  let leader-link one-of my-linkss with [follower? = false] ;; Get a link to a leader
  if leader-link != nobody [
    let leader-agent [end2] of leader-link
    ;; Update weights based on leader's weights
    set weight-cost [weight-cost] of leader-agent
    set weight-time [weight-time] of leader-agent
    set weight-environmental-impact [weight-environmental-impact] of leader-agent
  ]
end

to recalculate-utilities
  ask citizens [
    evaluate-options
  ]
end

to move
  rt random 50
  lt random 50
  fd 1
end

to check-links
  ;; For each agent, check if they are within link-range of another agent
  ;; and if they don't already have a link with that agent
  ;; If both conditions are met, develop a new link
  let potential-links other citizens in-radius link-range with [not link-neighbor? myself]
  let potential-link-count count potential-links
  if potential-link-count > 0 [
    let target one-of potential-links
    if not link-neighbor? target [
      create-link-with target
      set my-linkss sort my-linkss
    ]
  ]
end

to update-network-context
  nw:set-context citizens links
end

;; Finding utility for the case when MNL model is used, when the utility of cost, time, env should be subracted from the total utility and then find the highest utility, wanting the max utility, so having a decending order type of list sorting
;;to evaluate-options
;;  let min-utility 999999999  ;; Set an initial high value
;;  let best-option ""
;;  let agent-utilities [] ;; List to store utilities for each option for current agent
;;  let agent-option-names [] ;; List to store names of options corresponding to utilities for current agent
;;  foreach transportation-options [
;;    option ->
;;    let utility calculate-utility option
;;    ;; Save the utility and corresponding option name for each option
;;    set agent-utilities lput utility agent-utilities
;;    set agent-option-names lput (item 0 option) agent-option-names
;;    if utility < min-utility [  ;; Check if utility is lower than the current minimum
;;      set min-utility utility
;;      set best-option item 0 option
;;    ]
;;  ]
;;  ;; Sort the utilities and corresponding option names in ascending order
;;  let sorted-utilities sort agent-utilities
;;  let sorted-option-names []
;;  foreach sorted-utilities [
;;    u ->
;;    let index position u agent-utilities
;;    set sorted-option-names lput (item index agent-option-names) sorted-option-names
;;  ]
;;  ;; Truncate the lists based on the consideration set size
;;  set sorted-utilities sublist sorted-utilities 0 (consideration-set-size)
;;  set sorted-option-names sublist sorted-option-names 0 (consideration-set-size)
;;  set utilities sorted-utilities ;; Save the sorted utilities list for the agent
;;  set option-names sorted-option-names ;; Save the sorted option names list for the agent
;;  set final-choice best-option
;;end

;same as above but error with filtering properly using consideration-set list fixed here
;to evaluate-options
;  let min-utility 999999999  ;; Set an initial high value
;  let best-option ""
;  let agent-utilities [] ;; List to store utilities for each option for current agent
;  let agent-option-names [] ;; List to store names of options corresponding to utilities for current agent

  ;; Filter transportation-options based on the agent's consideration-set
;  let filtered-options filter [opt -> member? (item 0 opt) consideration-set] transportation-options

  ;; Iterate over filtered options
;  foreach filtered-options [
;    option ->
;    let utility calculate-utility option
;    ;; Save the utility and corresponding option name for each option
;    set agent-utilities lput utility agent-utilities
;    set agent-option-names lput (item 0 option) agent-option-names
;    if utility < min-utility [  ;; Check if utility is lower than the current minimum
;      set min-utility utility
;      set best-option item 0 option
;    ]
;  ]

;  ;; Sort the utilities and corresponding option names in ascending order
;  let sorted-utilities sort agent-utilities
;  let sorted-option-names []
;  foreach sorted-utilities [
;    u ->
;    let index position u agent-utilities
;    set sorted-option-names lput (item index agent-option-names) sorted-option-names
;  ]

  ;; Truncate the lists based on the consideration set size
;  set sorted-utilities sublist sorted-utilities 0 (consideration-set-size)
;  set sorted-option-names sublist sorted-option-names 0 (consideration-set-size)
;  set utilities sorted-utilities ;; Save the sorted utilities list for the agent
;  set option-names sorted-option-names ;; Save the sorted option names list for the agent
;  set final-choice best-option
;end


;; Evaluation of options when utility is found from only cost, time and env utility function, in which case we only want the lowest utility, not the maximum, so ascending order sorting
to evaluate-options
  let max-utility 0
  let best-option ""
  let agent-utilities [] ;; List to store utilities for each option for current agent
  let agent-option-names [] ;; List to store names of options corresponding to utilities for current agent

  ;; Filter transportation-options based on the agent's consideration-set
  let filtered-options filter [opt -> member? (item 0 opt) consideration-set] transportation-options

  ;; Iterate over filtered options
  foreach filtered-options [
    option ->
    let utility calculate-utility option
    ;; Save the utility and corresponding option name for each option
    set agent-utilities lput utility agent-utilities
    set agent-option-names lput (item 0 option) agent-option-names
    if utility > max-utility [
      set max-utility utility
      set best-option item 0 option
    ]
  ]

  ;; Sort the utilities and corresponding option names in ascending order
  let sorted-utilities sort agent-utilities
  let sorted-option-names []
  foreach sorted-utilities [
    u ->
    let index position u agent-utilities
    set sorted-option-names lput (item index agent-option-names) sorted-option-names
  ]

  set utilities sorted-utilities ;; Save the sorted utilities list for the agent
  set option-names sorted-option-names ;; Save the sorted option names list for the agent
  set final-choice best-option
end



;; Utility function that is used for the case of incorporating MNL model in utility function calc
;;to-report calculate-utility [option]
;;  ;; Retrieve socio-demographic characteristics of the agent
;;  let age_ [age] of self
;;  let income_ [income] of self
;;  let gender_ [gender] of self
;;  let shopping-propensity_ [shopping-propensity] of self
;;  let household-size_ [household-size] of self
;;  ;; Multiply each characteristic by its corresponding beta coefficient
;;  let utility_socio_demographic beta-age * age_ + beta-income * income_ + beta-gender * gender_ + beta-shopping-propensity * shopping-propensity_ + beta-household-size * household-size_
;;  ;; Calculate utility using exponential utility function for travel attributes
;;  let u_cost   exp (beta-cost * item 1 option)
;;  let u_time   exp (beta-time * item 2 option)
;;  let u_env    exp (beta-environmental * item 3 option)
;;  ;; Calculate total utility as sum of socio-demographic and travel utility
;;  let total-utility utility_socio_demographic + u_cost + u_time + u_env
;;  report total-utility
;;end

to-report calculate-utility [option]
  let u_cost   exp (weight-cost * item 1 option)
  let u_time   exp (weight-time * item 2 option)
  let u_env    exp (weight-environmental-impact * item 3 option)
  let total-utility u_cost + u_time + u_env
  let utility (u_cost * item 1 option) + (u_time * item 2 option) + (u_env * item 3 option)
  report utility / total-utility
end

to evaluate-and-choose-options
  ask citizens [
    evaluate-options
    ;show consideration-set
    ;show final-choice
  ]
end

to setup-gis
  ;gis:load-coordinate-system (word "data/geo_export_7db3d517-9e0a-4781-9f65-010fce1786db.prj")
  set cities-dataset gis:load-dataset "data/geo_export_7db3d517-9e0a-4781-9f65-010fce1786db.shp"

  gis:set-world-envelope (gis:envelope-of cities-dataset)
end

to draw-counties
  gis:set-drawing-color red
  gis:draw cities-dataset 1
end
;------------------

to create-pop-in-counties
  foreach gis:feature-list-of cities-dataset [ this-country ->
    gis:create-turtles-inside-polygon this-country citizens num-agents [
      set shape "person"
      set age random 6 + 1  ;; Random age from 1 to 6
      set income random 6 + 1  ;; Random income from 1 to 6
      set gender random 3  ;; Random sex: 0 for male, 1 for female, 2 for other
      set household-size random 5 + 1  ;; Random household size from 1 to 5
      set shopping-propensity random 5 + 1  ;; Random shopping propensity from 1 to 5
      set environment-elasticity random-float 1  ;; Random environment elasticity from 0 to 1
      set price-elasticity random-float 1  ;; Random price elasticity from 0 to 1
      set delivery-time-elasticity random-float 1  ;; Random delivery time elasticity from 0 to 1
      set education random 6 + 1  ;; Random education level from 1 to 6
      set employment random 6 + 1  ;; Random employment status from 1 to 6
      set shape-tick-counter 0 ;; Initialize shape tick counter
      set follower? one-of [true false] ;; Randomly assign follower or leader attribute
      ifelse follower? [ ;; Set influence level based on whether the agent is a follower or leader
        set influence-level random 3 + 1  ;; Follower's influence level: random from 1 to 3
      ] [
        set influence-level random 5 + 1  ;; Leader's influence level: random from 1 to 5
      ]
      ;;setxy random-xcor random-ycor
      set my-linkss [] ;; Initialize the list of links
      create-links-with n-of max-links other citizens ;; Create initial links
                                                     ;; Assign random weights to each agent (summing up to 1)
      set my-linkss-c [] ;; Initialize the list of links
      create-links-with n-of 1 other carriers ;; Create initial links
                                                     ;; Assign random weights to each agent (summing up to 1)
      let w1 random-float 1 ;cost/time
      let w2 random-float (1 - w1) ;environment
      set weight-cost w1 / 2
      set weight-time w1 / 2
      set weight-environmental-impact w2
      set consideration-set random-subset delivery-modes (1 + random length delivery-modes)
      evaluate-options
      ;show utilities
      ;show consideration-set
      ;show final-choice
    ]
    set agent-list citizens
    reset-ticks
  ]
end

to create-carriers-in-counties
  foreach gis:feature-list-of cities-dataset [ this-country ->
    gis:create-turtles-inside-polygon this-country carriers num-carriers [
      set shape "car"
      let w1-c random-float 1
      let w2-c random-float (1 - w1-c)
      let w3-c 1 - (w1-c + w2-c)
      set weight-cost-c w1-c
      set weight-time-c w2-c
      set weight-environmental-impact-c w3-c
    ]
  ]
end

to-report random-subset [item-list n]
  let shuffled-list shuffle item-list
  report sublist shuffled-list 0 n
end

to-report delivery-modes
  report ["Traditional Delivery" "Autonomous Vehicle" "Drone" "Sidewalk Robot" "Bipedal Robot"]
end

to set-shape-based-on-choice
  ask citizens [
    if shape-tick-counter <= 0 [
      if final-choice = "Traditional Delivery" [
        set shape "truck"
        set size 2
      ]
      if final-choice = "Autonomous Vehicle" [
        set shape "car"
        set size 2
      ]
      if final-choice = "Drone" [
        set shape "airplane"
        set size 2
      ]
      if final-choice = "Sidewalk Robot" [
        set shape "bowling pin"
        set size 2
      ]
      if final-choice = "Bipedal Robot" [
        set shape "chess bishop"
        set size 2
      ]
      set shape-tick-counter 10
    ]
  ]
end

to update-consideration-sets
  ask citizens [
    ; With a small probability, remove a random mode from the consideration set
    if random-float 1 < 0.1 [
      if length consideration-set > 1 [
        let mode-to-remove one-of consideration-set
        set consideration-set remove mode-to-remove consideration-set
      ]
    ]
    if random-float 1 < 0.1 [
      let mode-to-add one-of delivery-modes
      if not member? mode-to-add consideration-set [
        set consideration-set lput mode-to-add consideration-set
      ]
    ]
  ]
end

to validate-final-choices
  ; Ensure all citizens have a valid final-choice
  let valid-choices map [x -> item 0 x] transportation-options  ; Corrected map usage
  ; Alternatively, use: let valid-choices map [first ?] transportation-options

  ask citizens [
    if not member? final-choice valid-choices [
      ; If final-choice is invalid, reassign a valid one
      set final-choice one-of valid-choices
    ]
  ]
end



to plot-distributions
  ; Update consideration sets with random variation
  update-consideration-sets

  ; Validate that all citizens have a valid final choice
  validate-final-choices

  ; Plot distribution of final choices
  let final-choice-counts []
  foreach transportation-options [
    option ->
    let choice-count count citizens with [final-choice = item 0 option]
    set final-choice-counts lput choice-count final-choice-counts
  ]
  let total-agents count citizens
  let final-choice-percentages map [choice-count -> choice-count / total-agents * 100] final-choice-counts

  let sum-final-choice-percentages sum final-choice-percentages
  if sum-final-choice-percentages != 100 [
    ;print (word "Warning: Final choice percentages do not sum to 100%! Sum: " sum-final-choice-percentages)

    ; Normalize percentages to sum to 100%
    set final-choice-percentages map [percent -> (percent / sum-final-choice-percentages) * 100] final-choice-percentages

    ;print (word "Normalized final choice percentages: " final-choice-percentages)
  ]

  ; Plot distribution of consideration sets (allowing for overlap)
  let consideration-set-counts []
  foreach delivery-modes [
    mode ->
    let set-count count citizens with [member? mode consideration-set]
    set consideration-set-counts lput set-count consideration-set-counts
  ]
  let consideration-set-percentages map [set-count -> set-count / total-agents * 100] consideration-set-counts

  ; Plot distribution of consideration sets (ensuring sum to 100%)
  let total-consideration-count sum [length consideration-set] of citizens
  let consideration-set-proportional-percentages map [set-count -> set-count / total-consideration-count * 100] consideration-set-counts

  ; The following is just to enable the histograms to be created - idea from stack overflow
  let final-choice-numbered []
  foreach n-values (length delivery-modes) [i -> i + 1] [
    i ->
    let percentage item (i - 1) final-choice-percentages
    set final-choice-numbered lput (list i percentage) final-choice-numbered
    set final-choice-percentages-f final-choice-numbered
  ]

  let consideration-set-numbered []
  foreach n-values (length delivery-modes) [i -> i + 1] [
    i ->
    let percentage item (i - 1) consideration-set-percentages
    set consideration-set-numbered lput (list i percentage) consideration-set-numbered
    set consideration-set-percentages-f consideration-set-numbered
  ]

  let consideration-set-proportional-numbered []
  foreach n-values (length delivery-modes) [i -> i + 1] [
    i ->
    let percentage item (i - 1) consideration-set-proportional-percentages
    set consideration-set-proportional-numbered lput (list i percentage) consideration-set-proportional-numbered
    set consideration-set-proportional-percentages-f consideration-set-proportional-numbered
  ]

  ;print (word "Updated final choice percentages: " final-choice-percentages-f)
  ;print (word "Updated consideration set percentages: " consideration-set-percentages-f)
  ;print (word "Updated consideration set proportional percentages: " consideration-set-proportional-percentages-f)

end


to update-agent-weights-based-on-profile
  let proportion 0.6 ; Set the proportion of agents to update
  let random-agents n-of (proportion * count citizens) citizens ; Select random agents based on proportion
  ask random-agents [
    if env-profile > threshold-env [
      ; Increase environmental weight and decrease cost/time weight
      let delta random-float 0.4
      set weight-environmental-impact weight-environmental-impact + delta
      set weight-cost weight-cost - (delta / 2)
      set weight-time weight-time - (delta / 2)
    ]
    if economy-profile > threshold-econ [
      ; Increase cost/time weight and decrease environmental weight
      let delta random-float 0.4
      set weight-environmental-impact weight-environmental-impact + delta
      set weight-cost weight-cost - (delta / 2)
      set weight-time weight-time - (delta / 2)
    ]
    let total weight-cost + weight-time + weight-environmental-impact
    set weight-cost weight-cost / total
    set weight-time weight-time / total
    set weight-environmental-impact weight-environmental-impact / total
  ]
end


;;------------------------------------------------------------- results
to record-statistics
  ; Record final choice distribution
  let final-choice-counts []
  foreach transportation-options [
    option ->
    let choice-count count citizens with [final-choice = item 0 option]
    set final-choice-counts lput choice-count final-choice-counts
  ]
  let total-agents count citizens
  let final-choice-percentages map [choice-count -> choice-count / total-agents * 100] final-choice-counts
  set final-choice-history lput final-choice-percentages final-choice-history

  ; Record average consideration set size
  let avg-consideration-set-size mean [length consideration-set] of citizens
  set consideration-set-size-history lput avg-consideration-set-size consideration-set-size-history

  ; Record environmental and economic profiles
  set env-profile-history lput env-profile env-profile-history
  set economy-profile-history lput economy-profile economy-profile-history

  ; Record switching behavior
  let switching-count count citizens with [final-choice != old-final-choice]
  if switching-count > 0 [
    set switch-behavior-count switch-behavior-count + switching-count
    ask citizens with [final-choice != old-final-choice] [
      set old-final-choice final-choice
    ]
  ]

  ; Print statistics every 30 ticks
  if ticks mod 30 = 0 [
    ; Print the statistics
    print (word "Tick: " ticks)
    print (word "Final choice percentages: " final-choice-percentages)
    print (word "Average consideration set size: " avg-consideration-set-size)
    print (word "Environmental profile: " env-profile)
    print (word "Economic profile: " economy-profile)
    print (word "Switching behavior count: " switching-count)
  ]
end









; --- References
;; https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Community-Areas-current-/cauq-8yn6
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
5
220
68
253
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
70
220
133
253
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
76
172
109
num-agents
num-agents
2
5000
66.0
1
1
NIL
HORIZONTAL

SLIDER
0
43
172
76
max-links
max-links
0
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
0
110
172
143
num-carriers
num-carriers
1
4
2.0
1
1
NIL
HORIZONTAL

SWITCH
1
155
126
188
ls-models?
ls-models?
0
1
-1000

PLOT
5
320
200
450
Available job opportunities
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"clear-plot" ""
PENS
"default" 1.0 0 -16777216 true "" "plot job-metric"

PLOT
650
10
955
160
Economic Disparity
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"clear-plot" ""
PENS
"% jobs" 1.0 0 -16777216 true "" "plot job-metric"
"% rich-employed" 1.0 0 -7500403 true "" "plot rich-employed-metric"
"% poor-employed" 1.0 0 -2674135 true "" "plot poor-employed-metric"
"% rich-unemployed" 1.0 0 -955883 true "" "plot rich-unemployed-metric"
"% poor-unemployed" 1.0 0 -6459832 true "" "plot poor-unemployed-metric"

PLOT
955
10
1265
160
Economic profile
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"clear-plot" ""
PENS
"Economy profile" 1.0 0 -1184463 true "" "plot economy-profile"
"Environmental profile" 1.0 0 -10899396 true "" "plot env-profile"

PLOT
650
160
1275
310
Final choices dist ("Traditional Delivery" "Sidewalk Robot" "Bipedal Robot" "Autonomous Vehicle" "Drone")
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" "clear-plot"
PENS
"default" 1.0 1 -16777216 true "\n" "foreach ( final-choice-percentages-f ) [x ->\nplotxy first x last x\n]"

PLOT
650
310
1330
470
Consideration set dist ("Traditional Delivery" "Sidewalk Robot" "Bipedal Robot" "Autonomous Vehicle" "Drone")
NIL
NIL
0.0
1.0
0.0
1.0
true
false
"" "clear-plot"
PENS
"default" 1.0 1 -16777216 true "" "foreach ( consideration-set-percentages-f ) [x ->\nplotxy first x last x\n]"

PLOT
650
470
1400
625
Consideration set (proportional) dist ("Traditional Delivery" "Sidewalk Robot" "Bipedal Robot" "Autonomous Vehicle" "Drone")
NIL
NIL
0.0
1.0
0.0
1.0
true
false
"" "clear-plot"
PENS
"pen-0" 1.0 1 -7500403 true "" "foreach ( consideration-set-proportional-percentages-f ) [x ->\nplotxy first x last x\n]"

@#$#@#$#@
## WHAT IS IT?

This model simulates the decision-making process of agents choosing among various transportation options. Each agent evaluates the options based on cost, time, and environmental impact. The agents' preferences are influenced by their socio-demographic characteristics, such as age, income, and gender. The model also incorporates a network of social influence, where agents can be leaders or followers. Leaders influence the preferences and decisions of their follower agents, and the model demonstrates how these social interactions can affect the overall decision-making process.

## HOW IT WORKS

Agent Initialization

Socio-Demographic Characteristics: Each agent is assigned characteristics such as age, income, gender, household size, shopping propensity, environment elasticity, price elasticity, delivery time elasticity, education, and employment.
Weights: Each agent is assigned random weights for cost, time, and environmental impact, which sum to 1.

Consideration Set Size: Each agent determines a random number of options to consider, ensuring at least one option is considered.
Leader/Follower Status: Agents are randomly assigned to be leaders or followers. Leaders have a higher influence level.

Decision-Making

Utility Calculation: Agents calculate the utility of each transportation option using their weights and the characteristics of the options. This calculation incorporates the estimated beta coefficients for socio-demographic characteristics.
Consideration Set: Agents sort the transportation options based on their utilities and select the top options as their consideration set.

Final Choice: Agents choose the option with the highest utility from their consideration set.

Social Influence

Network Creation: Agents form a network where each agent has a specified number of links to other agents, created randomly at setup.
Influence Update: Every three ticks, follower agents check their links to see if they are connected to a leader. If so, they adopt the weights of the leader, recalculate their utilities, and possibly change their final choice.

## HOW TO USE IT

Interface Tab
Sliders:
num-agents: Sets the number of agents in the simulation.
num-links: Sets the number of links each agent initially has.
Buttons:
Setup: Initializes the simulation, creating agents and setting up their initial conditions and network.
Go: Runs the simulation, with agents making decisions and updating their choices every tick.

## THINGS TO NOTICE

Initial Choices: Observe the initial transportation choices of the agents based on their random weights and socio-demographic characteristics.

Social Influence: Pay attention to how the choices of follower agents change over time due to the influence of leader agents. This can be seen more clearly if you monitor the weights and choices of a few specific agents.

Network Dynamics: Watch how the network of links between agents evolves, especially how new links are formed when agents spend time near each other.

Utility Changes: Notice how the recalculated utilities influence the agents' choices and consideration sets after they adopt the weights of leader agents

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bowling pin
false
0
Polygon -7500403 true true 132 285 117 256 105 210 105 165 121 135 136 90 136 75 126 32 125 14 134 5 151 0 168 4 177 12 176 32 166 75 166 90 181 135 195 165 195 210 184 256 170 285
Polygon -2674135 true false 134 68 132 59 170 59 168 68
Polygon -2674135 true false 136 84 135 94 167 94 166 84

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

chess bishop
false
0
Circle -7500403 true true 135 35 30
Circle -16777216 false false 135 35 30
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 165 180 165 195 255
Polygon -16777216 false false 105 255 120 165 180 165 195 255
Rectangle -7500403 true true 105 165 195 150
Rectangle -16777216 false false 105 150 195 165
Line -16777216 false 137 59 162 59
Polygon -7500403 true true 135 60 120 75 120 105 120 120 105 120 105 90 90 105 90 120 90 135 105 150 195 150 210 135 210 120 210 105 195 90 165 60
Polygon -16777216 false false 135 60 120 75 120 120 105 120 105 90 90 105 90 135 105 150 195 150 210 135 210 105 165 60

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="num-carriers">
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-links">
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ls-models?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-agents">
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="300"/>
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
