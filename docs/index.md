# Neurostim 

## What is Neurostim? 

Neurostim is software to create experiments in (visual) neuroscience. It allows users to design and/or implement visual stimuli, feedback conditions, eye tracking systems and more.  The software harnesses the functions available in Psychtoolbox and packages them into reusable, modular classes. In this way, new experiments can be quickly assembled by instantiating pre-existing classes from the Neurostim library. 

## Why should I use Neurostim? 

Rather than create independent scripts for every new experiment – a time consuming process – Neurostim enables users to build their experiments from pre-existing, re-usable and tested components. This accelerates the software development phase and allows users to focus on what matters most, the actual experimentation.  

## Prerequisites
Neurostim requires 

* Matlab R2016 
* Psychophysics Toolbox 3 

## Installation 

1. Install Psychtoolbox
The Psychtoolbox-3 library must be installed prior to the use of Neurostim. For 
comprehensive instructions on how to install Psychtoolbox, please visit 
[http://psychtoolbox.org/download](http://psychtoolbox.org/download).

2. Clone Neurostim
Cloning the repository (https://github.com/klabhub/neurostim) to your machine
has the advantage that you can update easily, and that you can contribute bug fixes. It does, however, require familiarity with git. Alternatively, you can download the latest version in ZIP format.

3. Add the folder in which you cloned/unpacked neurostim to
MATLAB's search path. Only the top folder needs to be added to the path. 
4. Make a copy of myRig.m, and adapt it to your  needs.

## Getting Started

The demos are the best place to start. Each demo is documented extensively and shows how to setup an  experiment, add stimuli, add behavioral control, and include plugins to interact with external devices. 

Here is a suggested path through the demos:

* Basic setup 
`behaviorDemo`

* Eye movement control
`behaviorDemo`  (fixation)
`fixateThenChooseDemo`  (Fixate, then give an "answer" by looking at one of two dots)

* Adaptive parameters
`adaptiveDemo`  (Quest, Staircase, Psi)

* Retrieving and Analyzing Neurostim output
`taeDemo` 

* Calibrated luminance and color
`lumDemo` 
`xyLDemo`
`xylTextureDemo`

* Complex visual stimuli
`fastFilteredImageDemo`
`noiseGridDemo`

* Interaction with external devices 
`rippleDemo`
`starstimDemo`
`egiDemo`
`stgDemo`
`daqDemo`

* High resolution graphics
` lumM16Demo`  (VPIXX)
`responsePixxDemo` (VPIXX)

## GUI
Neurostim has a graphical user interface [nsGui](nsGui.html) that is intended for someone _runnning_ the experiment who may not be familiar with Matlab code. 

