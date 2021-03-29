# Autoupload Utility

This directory contains files that can help developers automate:

- recompiling your plugins when saving
- copying your build outputs to a local / remote server

## Requirements

- [`modd`][], a single-binary utility that runs a simple command whenever files change.  This is
used to invoke `ninja` and keep our daemon script running.
- [`watchdog`][], a Python library to monitor filesystem changes.  This is used in the daemon to
detect changed built outputs.
  - At some point I may switch to implementing `modd`'s functionality within the daemon itself,
  but for now this is fine for getting things up and running.

[`modd`]: https://github.com/cortesi/modd/
[`watchdog`]: https://pypi.org/project/watchdog/

## Configuration

1.  Copy `modd.conf` to your project root.  This shouldn't need modification, unless you've
changed the location of the build directory or the uploader script.
2.  Copy `uploader.example.ini` to your project root and rename to `uploader.ini`.  Read through
the configuration file and modify the settings as you see fit.
3.  Run `modd`.  The application will launch the upload monitoring daemon, and then start
watching for changes to source files.  The monitoring daemon will watch for changes within the
build directory (as specified in the configuration file).

The modified files are excluded from the root directory by default to prevent any personal
credentials from leaking, since this is a developer-specific workflow.
