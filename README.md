# neurostim-ptb
Psychophysics Toolbox Variant of Neurostim

The goal of this Matlab project is to wrap code around the basic graphics functionality of the PTB to make 
experiments more reusable and reproducable. 

## Plugins


#### Defining properties as functions of other properties
Any property of a plugin may be defined as a function of any other property. This can be done using the following convention:
```MATLAB
plugin.property='@(plugin) plugin.property'
```
wherein the plugin to be evaluated must be referenced using the name it is assigned in the CIC. This functional definition also allows manipulation before assigning it to the original property, using standard MATLAB function syntax. Some examples of usage are below.
```MATLAB
f=stimuli.fixation('fix'); % creates a fixation stimulus named 'fix'
f.duration='@(fixate1) fixate1.done + 100' % assigns the duration to the end of a fixate behavior (named 'fixate1') + 100ms
f.color='@(cic,fix) [cic.screen.color.text(1) cic.screen.color.background(2) fix.size]'
```
The properties assigned this way are re-evaluated each time they are called.