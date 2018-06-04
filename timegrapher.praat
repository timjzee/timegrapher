cooldown = 15

selectObject: "Sound test3"
original_dur = Get total duration
Extract part: 0.2, original_dur - 0.2, "rectangular", 1, "no"
Filter (pass Hann band): 5000, 22000, 100
Filter (stop Hann band): 15000, 18000, 100
new_dur = Get total duration
Create TextGrid: 0, new_dur, "pulses", "pulses"
selectObject: "Sound test3_part_band_band"
To Intensity: 5000, 0, "no"
mean_intensity = Get mean: 0, 0, "energy"
Down to IntensityTier
num_points = Get number of points
continue_point = 16
for point from continue_point to num_points
    if point >= continue_point
        selectObject: "IntensityTier test3_part_band_band"
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
