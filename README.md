# Automatic Snapshots for Google (gcloud) Compute Engine

Powershell script for Automatic ECS Snapshots and Cleanup on Google Compute Service. 

**Requires no user input!**

This is a Powershell port of Jack Segal's bash script [google-compute-snapshot](https://github.com/jacksegal/google-compute-snapshot)


## Usage Options
```
NAME
    google-compute-snapshot-win\gcloud-snapshot.ps1

SYNOPSIS
    Take snapshots of Google Compute Engine disks

SYNTAX
    .\gcloud-snapshot.ps1 [[-retention] <Int32>] [-copylabels] [[-prefix] <String>]
    [[-account] <String>] [[-project] <String>] [[-storage] <String>] [[-labels] <String>] [-dryrun]
    [<CommonParameters>]

PARAMETERS
    -retention
        Number of days to keep snapshots. Snapshots older than this number deleted.
        Default if not set: 7 [OPTIONAL]
    -copylabels
        Copy disk labels to snapshot labels [OPTIONAL]
    -prefix
        Prefix to be used for naming snapshots.
        Max character length: 20
        Default if not set: 'gcs' [OPTIONAL]
    -account
        Service Account to use.
        Blank if not set [OPTIONAL]
    -project
        Project ID to use.
        Blank if not set [OPTIONAL]
    -storage
        Snapshot storage location.
        Uses default storage location if not set [OPTIONAL]
    -labels
        Additional labels to add to the created snapshots
        labels should be formatted as "label1=value1,label2=value2"
    -dryrun
        Dry run: causes script to print debug variables and doesn't execute any
        create / delete commands [OPTIONAL]

DESCRIPTION
    Automated creation of google compute disk snapshots and deletion of old ones
    Powershell port of google-compute-snapshot by jacksegal
```


## License

MIT License

Copyright (c) 2018 Jack Segal

Copyright (c) 2019 Fabien Loudet

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
