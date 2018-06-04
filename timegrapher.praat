Read Table from comma-separated file: "lift_angles.csv"
num_movements = Get number of rows

beginPause: "Enter information"
    comment: "Hallo Cheng-Kit, welkom in Praat :)"
    comment: "Options:"
    boolean: "Noise_reduction", 1
    optionMenu: "Movement", 1
        option: "Other"
        for mvmnt from 1 to num_movements
            mvmnt_name$ = Get value: mvmnt, "movement"
            option: mvmnt_name$
        endfor
    comment: "Provide lift angle if 'Movement' is set to 'Other'"
    real: "Lift_angle", 51
endPause: "Continue", 1

if noise_reduction
    goto NOISE_REDUCTION
else
    goto ANALYSIS
endif

# identify background noise
label NOISE_REDUCTION

beginPause: "Noise reduction"
    comment: "Once you click 'Continue' a 5 second recording will be made that"
    comment: "will be used for noise reduction."
    comment: "Please be quiet during these 5 seconds and keep the watch AWAY"
    comment: "from the microphone."
endPause: "Continue", 1

Record Sound (fixed time)... Microphone 1 0.5 44100 5
Rename: "silence"

selectObject: "Sound silence"
Filter (pass Hann band): 5000, 22000, 100
To Spectrum: "no"

Create Table with column names: "spectrum_bands", 17, "band energy filter"
for band from 5 to 21
    band_start = band * 1000
    band_end = band_start + 1000
    selectObject: "Spectrum silence_band"
    band_energy = Get band energy: band_start, band_end
    selectObject: "Table spectrum_bands"
    Set numeric value: band - 4, "energy", band_energy
    Set numeric value: band - 4, "band", band_start
endfor

energy_median = Get quantile: "energy", 0.5
energy_sd = Get standard deviation: "energy"

for band from 5 to 21
    band_energy = Get value: band - 4, "energy"
    if band_energy > (energy_median + energy_sd)
        Set string value: band - 4, "filter", "yes"
    else
        Set string value: band - 4, "filter", "no"
    endif
endfor

# Pulse analysis
label ANALYSIS

beginPause: "Watch recording"
    comment: "Now place the watch directly against the microphone in a position"
    comment: "that doesn't require you to hold it."
    comment: "The recording will start when you press 'Continue'"
    real: "Recording duration", 30
endPause: "Continue", 1

Record Sound (fixed time)... Microphone 1 0.5 44100 recording_duration
Rename: "test3"

cooldown = 15

selectObject: "Sound test3"
original_dur = Get total duration
Extract part: 0.2, original_dur - 0.2, "rectangular", 1, "no"
Filter (pass Hann band): 5000, 22000, 100
if noise_reduction
    for band from 5 to 21
        selectObject: "Table spectrum_bands"
        filter_band$ = Get value: band - 4, "filter"
        if filter_band$ == "yes"
            selectObject: "Sound test3_part_band"
            Filter (stop Hann band): band * 1000, band * 1000 + 1000, 100
            selectObject: "Sound test3_part_band"
            Remove
            selectObject: "Sound test3_part_band_band"
            Rename: "test3_part_band"
        endif
    endfor
endif
new_dur = Get total duration
Create TextGrid: 0, new_dur, "pulses", "pulses"
selectObject: "Sound test3_part_band"
To Intensity: 5000, 0, "no"
mean_intensity = Get mean: 0, 0, "energy"
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
    part_start = rp_time - 0.015
    part_end = rp_time - 0.001
    Extract part: part_start, part_end, "no"
    num_prev_rp = Get number of points: 1
    Remove
    selectObject: "TextGrid pulses"
    part_start = rp_time + 0.001
    part_end = rp_time + 0.015
    Extract part: part_start, part_end, "no"
    num_next_rp = Get number of points: 1
    Remove
    selectObject: "TextGrid pulses"
    if not (num_prev_rp == 2 and num_next_rp == 1)
        Set point text: 1, rp, string$ (pulse_no)
        pulse_no += 1
    endif
endfor
