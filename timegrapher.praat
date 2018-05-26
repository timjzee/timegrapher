selectObject: "Sound test"
original_dur = Get total duration
Extract part: 0.2, original_dur - 0.2, "rectangular", 1, "no"
Filter (pass Hann band): 1000, 5000, 100
To Intensity: 100, 0.001, "no"
Down to IntensityTier
num_points = Get number of points
for point from 2 to num_points
endfor

