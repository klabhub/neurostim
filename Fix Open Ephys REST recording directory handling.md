# Fix Open Ephys REST Recording Directory Handling

## Summary

This update makes Neurostim configure Open Ephys recording paths and session names reliably through the Open Ephys REST API.

It fixes cases where Open Ephys appeared to accept a new parent directory/name globally but still saved data to the wrong location, reused a stale GUI session name, or appended new recordings as `experiment2`, `experiment3`, etc. inside a previous session folder.

## Main Changes

- Force Open Ephys into `IDLE` before applying recording configuration.
- Use the REST API to set the next recording `base_text`.
- Convert Neurostim dotted session names to Open Ephys-safe underscore names because the Open Ephys REST API silently rejects `base_text` values containing `.`.
- Explicitly update each active Record Node's `parent_directory`, rather than relying on the global `/api/recording` parent directory.
- Remove reliance on a hard-coded Record Node ID.
- Assert that Open Ephys accepted the requested `base_text` before starting recording.

## Expected Behavior

Given a Neurostim file like:

```text
PATH_TEST.translatingImages.131853.mat
```

Open Ephys now creates a matching underscore-safe folder like:

```text
PATH_TEST_translatingImages_131853_2026-07-01_13-19-09
```

under:

```text
D:\data\YYYY\MM\DD\
```

## Operational Notes

- The date folder must already exist on the Open Ephys PC, for example:

  ```text
  D:\data\2026\07\02
  ```

- If the date folder does not exist, Open Ephys may silently keep using the previous valid folder.
- Downstream analysis should either handle underscore-safe Open Ephys folder names or rename folders after copying to the analysis location.

## Validation Performed

- Confirmed MATLAB can reach the Open Ephys HTTP API.
- Confirmed active Record Node parent directory updates only apply reliably when Open Ephys is `IDLE`.
- Confirmed dots in `base_text` are rejected while underscore-safe names are accepted.
- Confirmed new dummy recordings save as new top-level folders rather than new experiment folders inside the previous session.

