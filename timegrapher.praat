Read Table from comma-separated file: "movements.csv"
num_movements = Get number of rows

beginPause: "Enter information"
    comment: "Hallo Cheng-Kit, welkom in Praat :)"
    comment: "Options:"
    boolean: "Noise reduction", 1
    optionMenu: "Movement", 1
        option: "Other"
        for mvmnt from 1 to num_movements
            mvmnt_name$ = Get value: mvmnt, "movement"
            option: mvmnt_name$
        endfor
    comment: "Provide data if 'Movement' is set to 'Other'"
    real: "Lift angle", 51
    real: "Beats per hour", 21600
endPause: "Continue", 1

if movement$ != "other"
    selectObject: "Table movements"
    movement_index = Search column: "movement", movement$
    beats_per_hour = Get value: movement_index, "bph"
    lift_angle = Get value: movement_index, "lift_angle"
endif

# Pulse identification

beginPause: "Watch recording"
    comment: "Now place the watch directly against the microphone in a position"
    comment: "that doesn't require you to hold it."
    comment: "The recording will start when you press 'Continue'"
    real: "Recording duration", 20
    comment: "Change threshold when script fails to pick up pulses."
    comment: "If too many pulses, increase threshold; if too few, decrease."
    optionMenu: "Threshold shift", 5
        option: "20"
        option: "15"
        option: "10"
        option: "5"
        option: "0"
        option: "-5"
        option: "-10"
        option: "-15"
        option: "-20"
endPause: "Continue", 1

Record Sound (fixed time)... Microphone 1 0.5 44100 recording_duration
Rename: "test3"

selectObject: "Sound test3"
original_dur = Get total duration
Extract part: 0.2, original_dur - 0.2, "rectangular", 1, "no"
Filter (pass Hann band): 5000, 22000, 100
if noise_reduction
    selectObject: "Sound test3_part_band"
    Copy: "silence"
    To TextGrid (silences): 100, 0, -30, 0.001, 0.001, "silent", "sounding"
    num_ints = Get number of intervals: 1
    for int from 1 to num_ints
        selectObject: "TextGrid silence"
        int_name$ = Get label of interval: 1, int
        if int_name$ == "sounding"
            int_start = Get start time of interval: 1, int
            int_end = Get end time of interval: 1, int
            selectObject: "Sound silence"
            Set part to zero: int_start, int_end, "at nearest zero crossing"
        endif
    endfor

    selectObject: "Sound silence"
    To Spectrum: "no"

    Create Table with column names: "spectrum_bands", 17, "band energy filter"
    for band from 5 to 21
        band_start = band * 1000
        band_end = band_start + 1000
        selectObject: "Spectrum silence"
        band_energy = Get band energy: band_start, band_end
        selectObject: "Table spectrum_bands"
        Set numeric value: band - 4, "energy", band_energy
        Set numeric value: band - 4, "band", band_start
    endfor

    energy_median = Get quantile: "energy", 0.5
    energy_sd = Get standard deviation: "energy"

    for band from 5 to 21
        selectObject: "Table spectrum_bands"
        band_energy = Get value: band - 4, "energy"
        if band_energy > (energy_median + energy_sd)
            Set string value: band - 4, "filter", "yes"
            selectObject: "Sound test3_part_band"
            Filter (stop Hann band): band * 1000, band * 1000 + 1000, 100
            selectObject: "Sound test3_part_band"
            Remove
            selectObject: "Sound test3_part_band_band"
            Rename: "test3_part_band"
        else
            Set string value: band - 4, "filter", "no"
        endif
    endfor
endif

cooldown = 15

selectObject: "Sound test3_part_band"
new_dur = Get total duration
Create TextGrid: 0, new_dur, "pulses", "pulses"
selectObject: "Sound test3_part_band"
To Intensity: 5000, 0, "no"
mean_intensity = Get mean: 0, 0, "energy"
threshold_shift = number(threshold_shift$)
intensity_threshold = mean_intensity + threshold_shift
Down to IntensityTier
num_points = Get number of points
continue_point = 16
for point from continue_point to num_points
    if point >= continue_point
        selectObject: "IntensityTier test3_part_band"
        cur_intensity = Get value at index: point
        if cur_intensity > mean_intensity
            p_min_5_intensity = Get value at index: point - 5
            p_min_15_intensity = Get value at index: point - 15
            if ((cur_intensity / p_min_5_intensity) > 1.12) and (cur_intensity > p_min_15_intensity)
                pulse_time = Get time from index: point
                selectObject: "TextGrid pulses"
                Insert point: 1, pulse_time, ""
                continue_point = point + cooldown
            endif
        endif
    endif
endfor

selectObject: "TextGrid pulses"
raw_pulses = Get number of points: 1
pulse_no = 1
for rp from 1 to raw_pulses
    if pulse_no == 4
        pulse_no = 1
    endif
    rp_time = Get time of point: 1, rp
    part_start = rp_time - 0.03
    part_end = rp_time - 0.001
    Extract part: part_start, part_end, "no"
    num_prev_rp = Get number of points: 1
    Remove
    selectObject: "TextGrid pulses"
    part_start = rp_time + 0.001
    part_end = rp_time + 0.03
    Extract part: part_start, part_end, "no"
    num_next_rp = Get number of points: 1
    Remove
    selectObject: "TextGrid pulses"
    # ignore extra pulses between pulse two and three
    if not (num_prev_rp >= 2 and num_next_rp >= 1)
        # ignore incomplete ticks at start and spurious pulses
        if (not pulse_no == 1) or (pulse_no == 1 and num_next_rp >= 2)
            Set point text: 1, rp, string$ (pulse_no)
            pulse_no += 1
        endif
    endif
endfor

# Pulse analysis

correct_period = 1 / (beats_per_hour / 3600)

Create Table with column names: "measurements", 0, "beat p1 p2 p3 period y beat_error rate_deviation lift_time amplitude"

beat = 0
selectObject: "TextGrid pulses"
num_pulses = Get number of points: 1
for pulse from 1 to num_pulses
    selectObject: "TextGrid pulses"
    pulse_label$ = Get label of point: 1, pulse
    pulse_time = Get time of point: 1, pulse
    selectObject: "Table measurements"
    if pulse_label$ == "1"
        beat += 1
        Append row
        Set numeric value: beat, "beat", beat
        Set numeric value: beat, "p1", pulse_time
        # Measure period and y-coordinate for plot
        if beat == 1
            Set numeric value: beat, "y", 0
        else
            p1_min1 = Get value: beat - 1, "p1"
            current_period = pulse_time - p1_min1
            Set numeric value: beat, "period", current_period
            y_prev = Get value: beat - 1, "y"
            y = y_prev + (current_period - correct_period)
            Set numeric value: beat, "y", y
        endif
        # Measure beat error
        if beat >= 3
            prev_period = Get value: beat - 1, "period"
            beat_error = abs(prev_period - current_period) / 2
            Set numeric value: beat, "beat_error", beat_error
        endif
        # Measure rate deviation
        if beat >= 4
            p1_min2 = Get value: beat - 2, "p1"
            p1_min3 = Get value: beat - 3, "p1"
            rate_dev = ((((p1_min1 - p1_min3) - 2 * correct_period) + ((pulse_time - p1_min2) - 2 * correct_period)) / 2) * beats_per_hour
            Set numeric value: beat, "rate_deviation", rate_dev
        endif
    elif pulse_label$ == "2"
        Set numeric value: beat, "p2", pulse_time
    elif pulse_label$ == "3"
        Set numeric value: beat, "p3", pulse_time
        p1 = Get value: beat, "p1"
        lift_time = pulse_time - p1
        Set numeric value: beat, "lift_time", lift_time
        amplitude = lift_angle / sin(2 * pi * lift_time * beats_per_hour / 7200)
        Set numeric value: beat, "amplitude", amplitude
    endif
endfor

# Visualize results
width = 5
height = 1
x1 = 1
x2 = x1 + width
y1 = 0.5
y2 = y1 + height
margin = 0.5
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

median_y = Get quantile: "y", 0.5
Scatter plot (mark): "beat", 0, 0, "y", median_y - correct_period / 16, median_y + correct_period / 16, 1, "no", "+"
Draw inner box
Marks left: 2, "yes", "yes", "no"
Text top: "no", movement$ + " (" + date$() + ")"

y1 = y2 + 0.5
y2 = y1 + height
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

Extract rows where column (number): "beat", "greater than or equal to", 4
min_y = Get minimum: "rate_deviation"
max_y = Get maximum: "rate_deviation"
sd_y = Get standard deviation: "rate_deviation"
mean_y = Get mean: "rate_deviation"
Remove
selectObject: "Table measurements"
Scatter plot (mark): "beat", 0, 0, "rate_deviation", min_y - sd_y, max_y + sd_y, 1, "no", "+"
Draw inner box
Marks left: 2, "yes", "yes", "no"
Text left: "yes", "rate dev. (s)"
One mark right: mean_y, "yes", "yes", "yes", ""

y1 = y2 + 0.5
y2 = y1 + height
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

Extract rows where column (number): "beat", "greater than or equal to", 3
sd_y = Get standard deviation: "beat_error"
min_y = Get minimum: "beat_error"
max_y = Get maximum: "beat_error"
mean_y = Get mean: "beat_error"
Remove
selectObject: "Table measurements"
Scatter plot (mark): "beat", 0, 0, "beat_error", min_y - sd_y, max_y + sd_y, 1, "no", "+"
Draw inner box
Marks left: 2, "yes", "yes", "no"
Text left: "yes", "beat err. (s)"
One mark right: mean_y, "yes", "yes", "yes", ""

y1 = y2 + 0.5
y2 = y1 + height
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

min_y = Get minimum: "amplitude"
max_y = Get maximum: "amplitude"
sd_y = Get standard deviation: "amplitude"
Scatter plot (mark): "beat", 0, 0, "amplitude", min_y - sd_y, max_y + sd_y, 1, "yes", "+"
mean_y = Get mean: "amplitude"
One mark right: mean_y, "yes", "yes", "yes", ""

y1 = 0.5
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2
Save as PDF file: "./measurements/" + movement$ + ".pdf"
Save as comma-separated file: "./measurements/" + movement$ + ".csv"
