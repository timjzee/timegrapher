Read Table from comma-separated file: "movements.csv"
num_movements = Get number of rows

beginPause: "Enter information"
    comment: "Welcome to timegrapher.praat"
    comment: "Options:"
    boolean: "Noise reduction", 1
    optionMenu: "Movement", 1
        option: "Other"
        for mvmnt from 1 to num_movements
            mvmnt_name$ = Get value: mvmnt, "movement"
            option: mvmnt_name$
        endfor
    comment: "Provide data if 'Movement' is set to 'Other'"
    real: "Lift angle", 52
    real: "Beats per hour", 21600
    comment: "Optional Information:"
    sentence: "Watch name", ""
    word: "Year of manufacture", ""
endPause: "Continue", 1

if movement$ != "Other"
    selectObject: "Table movements"
    movement_index = Search column: "movement", movement$
    beats_per_hour = Get value: movement_index, "bph"
    lift_angle = Get value: movement_index, "lift_angle"
endif

# Pulse identification

beginPause: "Watch recording"
    comment: "Now place the watch directly against the microphone in a position"
    comment: "that doesn't require you to hold it. Indicate the position of the"
    comment: "watch below:"
    choice: "Position", 3
        option: "Dial Up"
        option: "Dial Down"
        option: "Crown Up"
        option: "Crown Down"
        option: "Crown Left"
        option: "Crown Right"
    comment: "The recording will start when you press 'Continue'"
    real: "Recording duration", 20
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

selectObject: "Sound test3_part_band"
To Intensity: 5000, 0, "no"
Down to IntensityTier

procedure identifyPulses: identifyPulses.threshold_shift
    cooldown = 15

    selectObject: "Sound test3_part_band"
    new_dur = Get total duration
    Create TextGrid: 0, new_dur, "pulses", "pulses"
    selectObject: "Intensity test3_part_band"
    mean_intensity = Get mean: 0, 0, "energy"
    # threshold_shift = number(identifyPulses.threshold_shift$)
    intensity_threshold = mean_intensity + identifyPulses.threshold_shift
    selectObject: "IntensityTier test3_part_band"
    num_points = Get number of points
    continue_point = 16
    for point from continue_point to num_points
        if point >= continue_point
            selectObject: "IntensityTier test3_part_band"
            cur_intensity = Get value at index: point
            if cur_intensity > intensity_threshold
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
    prev_p3_time = 0
    for rp from 1 to raw_pulses
        if pulse_no == 4
            pulse_no = 1
        endif
        rp_time = Get time of point: 1, rp
        # part_start = rp_time - 0.04
        # part_end = rp_time - 0.001
        # Extract part: part_start, part_end, "no"
        # num_prev_rp = Get number of points: 1
        # Remove
        selectObject: "TextGrid pulses"
        if pulse_no == 3
            part_start = rp_time + 0.001
            part_end = rp_time + 0.05
            Extract part: part_start, part_end, "no"
            num_next_rp = Get number of points: 1
            Remove
            selectObject: "TextGrid pulses"
            if num_next_rp >= 1
                selectObject: "Intensity test3_part_band"
                rp_intensity = Get maximum: rp_time, rp_time + 0.002, "Parabolic"
                selectObject: "TextGrid pulses"
                label_pulse$ = "True"
                for nrp from (rp + 1) to (rp + num_next_rp)
                    nrp_time = Get time of point: 1, nrp
                    selectObject: "Intensity test3_part_band"
                    nrp_intensity = Get maximum: nrp_time, nrp_time + 0.002, "Parabolic"
                    selectObject: "TextGrid pulses"
                    # if one of the pulses is more than 5 dB louder than current pulse, the current pulse is not labelled
                    if (rp_intensity - nrp_intensity) < 5
                        label_pulse$ = "False"
                    endif
                endfor
                if label_pulse$ == "True"
                    Set point text: 1, rp, string$ (pulse_no)
                    prev_p3_time = Get time of point: 1, rp
                    pulse_no += 1
                endif
            else
                Set point text: 1, rp, string$ (pulse_no)
                prev_p3_time = Get time of point: 1, rp
                pulse_no += 1
            endif
        # ignore extra pulses between pulse two and three
        # if not (num_prev_rp >= 2 and num_next_rp >= 1)
        else
            part_start = rp_time + 0.001
            part_end = rp_time + 0.04
            Extract part: part_start, part_end, "no"
            num_next_rp = Get number of points: 1
            Remove
            selectObject: "TextGrid pulses"
            # ignore incomplete ticks at start and spurious pulses
            if pulse_no == 2
                Set point text: 1, rp, string$ (pulse_no)
                pulse_no += 1
            elsif pulse_no == 1 and num_next_rp >= 2
                # make sure that p1 can only be identified after 50% of the beat time since the last p3
                if rp == 1 or not ((rp_time - prev_p3_time) < 0.5  * (1/(beats_per_hour/3600)))
                    Set point text: 1, rp, string$ (pulse_no)
                    pulse_no += 1
                endif
            endif
        endif
    endfor
endproc

pulses_identified = 0
threshold_shift = 0
while not pulses_identified
    @identifyPulses: threshold_shift
    selectObject: "Sound test3_part_band"
    plusObject: "TextGrid pulses"
    View & Edit
    beginPause: "Check pulse identification"
        comment: "Use 'in' and 'out' buttons to zoom in and out in the pop-up window."
        comment: "Does every tic/toc have a '1', '2', and '3' pulse?"
        boolean: "Pulses identified", 0
    endPause: "Continue", 1
    if not pulses_identified
        beginPause: "Adjust pulse threshold"
            comment: "If too many pulses, increase threshold; if too few, decrease."
            comment: "The useful range of the threshold shift is between -10 and 10."
            real: "Threshold shift", 0
        endPause: "Continue", 1
        selectObject: "TextGrid pulses"
        Remove
    endif
endwhile

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
            rate_dev = (((p1_min1 - p1_min3) - 2 * correct_period) * (beats_per_hour / 2) + ((pulse_time - p1_min2) - 2 * correct_period) * (beats_per_hour / 2)) * 24
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
margin = 0.5

## General Parameters
height = 0.75
x1 = 0.25
x2 = x1 + width + 1.5
y1 = 0.5
y2 = y1 + height
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2
Line width: 0.5
Draw inner box
Font size: 11
Text: 0.025, "Left", 0.8, "Half", "Movement: " + movement$
Text: 0.025, "Left", 0.5, "Half", "Watch: " + watch_name$
Text: 0.025, "Left", 0.2, "Half", "Year of Manufacture: " + year_of_manufacture$
Text: 0.355, "Left", 0.8, "Half", "Time: " + date$()
Text: 0.355, "Left", 0.5, "Half", "Duration (seconds): " + string$(recording_duration)
Text: 0.355, "Left", 0.2, "Half", "Watch Position: " + position$
Text: 0.725, "Left", 0.8, "Half", "Beat Rate (BPH): " + string$(beats_per_hour)
Text: 0.725, "Left", 0.5, "Half", "Lift Angle (degrees): " + string$(lift_angle)
Font size: 12

## Timegraph
height = 1
x1 = 1
x2 = x1 + width
y1 = y2 + margin
y2 = y1 + height
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

median_y = Get quantile: "y", 0.5
Scatter plot (mark): "beat", 0, 0, "y", median_y - correct_period / 16, median_y + correct_period / 16, 1, "no", "+"
Line width: 1
Draw inner box
Marks left: 2, "yes", "yes", "no"
#Text top: "no", movement$ + " (" + date$() + ")"

## Rate Deviation
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

## Beat Error
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

## Amplitude
y1 = y2 + 0.5
y2 = y1 + height
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

min_y = Get minimum: "amplitude"
max_y = Get maximum: "amplitude"
sd_y = Get standard deviation: "amplitude"
Scatter plot (mark): "beat", 0, 0, "amplitude", min_y - sd_y, max_y + sd_y, 1, "no", "+"
Draw inner box
Marks left: 2, "yes", "yes", "no"
Marks bottom: 2, "yes", "yes", "no"
Text left: "yes", "amplitude"
mean_y = Get mean: "amplitude"
One mark right: mean_y, "yes", "yes", "yes", ""

## draw tic
y1 = y2 + 0.5
y2 = y1 + height
x2 = x1 + 0.5 * width
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2
tic_p1 = Get value: 3, "p1"
tic_p2 = Get value: 3, "p2"
tic_p3 = Get value: 3, "p3"
tic_start = tic_p1 - 0.015
tic_end = tic_p3 + 0.025
selectObject: "Sound test3_part_band"
Draw: tic_start, tic_end, 0, 0, "no", "Curve"
Draw inner box
One mark bottom: tic_p1, "no", "yes", "yes", ""
One mark bottom: tic_p2, "no", "yes", "yes", ""
One mark bottom: tic_p3, "no", "yes", "yes", ""
Text top: "no", "Tic"

## draw toc
x1 = x2
x2 = x1 + 0.5 * width
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2
selectObject: "Table measurements"
toc_p1 = Get value: 4, "p1"
toc_p2 = Get value: 4, "p2"
toc_p3 = Get value: 4, "p3"
toc_start = toc_p1 - 0.015
toc_end = toc_p3 + 0.025
selectObject: "Sound test3_part_band"
Draw: toc_start, toc_end, 0, 0, "no", "Curve"
Draw inner box
One mark bottom: toc_p1, "no", "yes", "yes", ""
One mark bottom: toc_p2, "no", "yes", "yes", ""
One mark bottom: toc_p3, "no", "yes", "yes", ""
Text top: "no", "Toc"

x1 = 0.5
x2 = x1 + width + 1
y1 = 0.5
Select outer viewport: x1 - margin, x2 + margin, y1 - margin, y2 + margin
Select inner viewport: x1, x2, y1, y2

system$ = Report system properties
newline_index = index_regex(system$, "\n")
os$ = mid$(system$, newline_index + 2, 3)
if os$ == "mac"
    Save as PDF file: "./measurements/" + movement$ + " - " + position$ + ".pdf"
else
    Save as 300-dpi PNG file: "./measurements/" + movement$ + " - " + position$ + ".png"
endif

selectObject: "Table measurements"
Save as comma-separated file: "./measurements/" + movement$ + " - " + position$ + ".csv"
