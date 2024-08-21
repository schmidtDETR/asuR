This package is designed to improve the process by which states create Areas of Substantial Unemployment.

Use of this file requires a file supplied by the Bureau of Labor statistics, of the form ST_asYY.xlsx, where ST is the state abbreviation
and YY is the year for which the ASU will apply. These files are not provided currently, but a process to calculate these measures may be provided in the future.

There are two primary files provided.  The Flexdashboard RMD file provides a GUI interface for working with the files. This is the most current
process for creating the ASU skeletons, as it uses an improved geographic search technique to gain significant performance improvements over the
original iteration of this program.

The original script and documentation from 2023 are also included, which were developed in a collaborative effort between analysts in Nevada and Ohio.
This repository is being provided to allow for further development, and to provide a centralized platform for sharing these resources across the states.

Due to the changes to local areas in New England (counties vs. NECTAs), there is a version of this code modified to work for Connecticut as well, which
forces the census tract data to pull from 2021, as 2022 and 2023 data does not match correctly.  This is not yet accounted for in the RMD Flexdashboard.
