# timegrapher
Praat script for wristwatch timing

## To Do
- automatic pre-processing
  - determine noisy frequencies
    - make recording of background noise
    - analyse spectrum
    - determine stop Hann band frequency range
- analyse timing
  - identify pulses
    - ~~raw pulse concretization~~
    - clean up spurious pulses
      - remove wrongly identified pulses
      - remove pulses at start and end of recording
    - ~~label pulses~~
  - automatically identify rate (vibrations/hour)
    - seiko 7s26: 21600
    - other common rates: 14400, 18000, 28800, 36600
  - calculate rate deviation (seconds/day)
  - calculate Amplitude: amplitude = liftAngle / sin(2 * pi * liftTime * beatsPerHour / 7200)
- visualize measurements
