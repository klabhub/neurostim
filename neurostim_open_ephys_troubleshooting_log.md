# Neurostim/Open Ephys Troubleshooting Log

## Goal

Ensure Neurostim stimulus sessions and Open Ephys Neuropixels recordings create matching, predictable outputs for `freeviewing.runTranslatingImages`, including dummy path/naming tests before real recordings.

## Starting Symptoms

- Neurostim saved locally on the stimulus PC, e.g.
  `/home/stimadmin/data/2026/07/01/PATH_TEST.translatingImages.HHMMSS.mat`.
- Open Ephys initially saved to unexpected folders such as `D:\CJ269_...`, `D:\2026-...`, or into an old session folder as `experiment2`, `experiment3`, etc.
- Open Ephys GUI settings could appear correct globally while the active Record Node still saved elsewhere.

## Productive Findings

### 1. MATLAB Path Setup Was Required

After MATLAB restart, the required paths must be available:

```matlab
addpath(genpath('/home/stimadmin/Documents/neurostim'));
addpath(genpath('/home/stimadmin/Documents/MATLAB/marmolab/marmolab-common'));
addpath(genpath('/home/stimadmin/Documents/MATLAB/marmolab/marmolab-stimuli'));
addpath(genpath('/home/stimadmin/Documents/MATLAB/marmolab/marmodata'));
addpath('/home/stimadmin/Documents/MATLAB-git');
addpath(genpath('/home/stimadmin/Documents/Psychtoolbox-3/Psychtoolbox'));
addpath(genpath('/home/stimadmin/Documents/open-ephys-matlab-tools'));
addpath(genpath('/home/stimadmin/Documents/V1_1_urlread2'));
```

Useful checks:

```matlab
which freeviewing.runTranslatingImages -all
which neurostim.plugins.oephys -all
which marmolab.MU00011699 -all
```

### 2. Open Ephys Has Global And Record Node Recording Paths

The Open Ephys REST API showed:

```matlab
r = webread('http://130.194.192.3:37497/api/recording');
r.parent_directory
r.record_nodes.node_id
r.record_nodes.parent_directory
```

Important finding:

- `/api/recording` can show the desired global parent directory.
- Existing Record Nodes may still have their own `parent_directory`.
- The Record Node value is what Open Ephys actually uses when saving.

The active Record Node was `101`, while old code targeted hard-coded node `106`.

### 3. Open Ephys Must Be IDLE For Path Changes

Record Node directory updates did not apply while Open Ephys was in `ACQUIRE`.

Working sequence:

```matlab
webwrite('http://130.194.192.3:37497/api/status', ...
    struct('mode','IDLE'), ...
    weboptions('RequestMethod','put','MediaType','application/json'));
```

Then update `/api/recording` and `/api/recording/<node_id>`.

### 4. Open Ephys REST API Rejects Dots In `base_text`

This failed silently:

```matlab
base_text = 'PATH_TEST.translatingImages.131853_2026-07-01_13-19-09'
```

This worked:

```matlab
base_text = 'PATH_TEST_translatingImages_131853_2026-07-01_13-19-09'
```

Conclusion: Open Ephys-safe session folder names must replace `.` with `_`.

## Final Working Solution

### `MU00011699.m`

Use Neurostim to generate the intended full Open Ephys session name:

```matlab
c.oephys.prependText = '@strjoin({cic.file,datestr(now,''yyyy-mm-dd_HH-MM-SS'')},''_'')';
```

Although the property is called `prependText`, it is used by the modified `oephys.m` as the desired Open Ephys `base_text`.

### `oephys.m`

Use REST API `webwrite`, force Open Ephys to `IDLE`, convert dots to underscores, set `base_text`, and explicitly update each active Record Node parent directory:

```matlab
opts = weboptions('RequestMethod','put','MediaType','application/json');

webwrite([o.hostAddr '/api/status'], struct('mode','IDLE'), opts);

safeBaseText = strrep(o.prependText,'.','_');

config = struct( ...
  'parent_directory',o.recordDir, ...
  'base_text',safeBaseText, ...
  'prepend_text','', ...
  'append_text','');

webwrite([o.hostAddr '/api/recording'], config, opts);

check = webread([o.hostAddr '/api/recording']);
assert(strcmp(check.base_text,safeBaseText), ...
  'Open Ephys did not accept base_text update.');

for nodeId = [check.record_nodes.node_id]
  webwrite([o.hostAddr '/api/recording/' num2str(nodeId)], ...
    struct('parent_directory',o.recordDir), opts);
end
```

Then continue to start recording:

```matlab
[~,status] = o.put('status',struct('mode','RECORD'));
```

## Expected Outputs

Neurostim file on stimulus PC:

```text
/home/stimadmin/data/YYYY/MM/DD/PATH_TEST.translatingImages.HHMMSS.mat
```

Open Ephys folder on Open Ephys PC:

```text
D:\data\YYYY\MM\DD\PATH_TEST_translatingImages_HHMMSS_YYYY-MM-DD_HH-MM-SS\
```

Example:

```text
Neurostim:
/home/stimadmin/data/2026/07/01/PATH_TEST.translatingImages.131853.mat

Open Ephys:
D:\data\2026\07\01\PATH_TEST_translatingImages_131853_2026-07-01_13-19-09\
```

## Remaining Analysis Implication

Current downstream matching code may expect dotted Neurostim-style folder prefixes:

```text
PATH_TEST.translatingImages.HHMMSS_*
```

The fixed Open Ephys folder uses underscores:

```text
PATH_TEST_translatingImages_HHMMSS_*
```

Later analysis/copy code should either:

- rename Open Ephys folders after copying to a shared analysis location, or
- update the loader to search for both dotted and underscore-safe folder names.

## Preflight Checklist

Before real recording:

1. Confirm Open Ephys GUI is open and HTTP server is reachable:

   ```matlab
   webread('http://130.194.192.3:37497/api/status')
   ```

2. Confirm target date folder exists on Open Ephys PC:

   ```text
   D:\data\YYYY\MM\DD
   ```

3. Run a tiny dummy stimulus with `subject = PATH_TEST`.

4. Confirm Open Ephys creates a new top-level folder under the correct date directory.

5. Confirm it does not append `experiment2`, `experiment3`, etc. inside a previous session folder.

6. Confirm Neurostim saves locally under:

   ```text
   /home/stimadmin/data/YYYY/MM/DD
   ```

7. For dummy-only PTB sync bypass:

   ```matlab
   Screen('Preference','SkipSyncTests',1)
   ```

   Do not use this for real timing-sensitive recordings unless the display sync issue has been intentionally accepted.
