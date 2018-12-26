### v0.1
* Initial version supporting basic deployment of music collection, and basic inclusion and exclusion based on metadata pattern searching

### v0.2
* Rewrote deployment workflow to allow for smarter cleaning of unselected IMAGEIDs on TARGET
* Added "du" command to check projected disk usage of selected IMAGEIDs
* Added disk usage function on "deploy" function that checks if TARGET has enough space for what is to be deployed
* Fixed bug where everything in track title after a colon would disappear
* Fixed bug where sometimes two colliding trackids would cause mahem
* In the event that no title is set to track, track number is used instead
* Added LAST_DEPLOY and LAST_UPDATE variable in database for keeping track of what commit was the last update and deployment done on.
* Metadata updates are now done on just the imageids that were updated since last deployment
* Added check functions to test integrity of database file
* Added dam --help command to facilitate use
* Saner function exit codes
* Command outputs are now prettier
* Fixed a bug where a "[" and "]" character would crash deploy_meta
* Added --git-dir option to defined git directory, in case working directory is now it

### v0.2.1
* Deploy now proper cleans up after itself in git directory
* Exit code for missing database file is now 3 instead of 1

### v0.2.2
* Further improvement to CLI UI
* Fixed critical bug with database update, where selection would be defined as "null"
* Fixed bug in include command

### v0.2.3
* Fixed bug where dam update would only add one track to the database per image

### v0.2.4
* DAM now downloads image from server if not present
* Now properly removes tracks that have been removed in the git directory
* A few UI changes
* Added options to "fsck" command to allow specific tests to be performed
* Fixed bug in nonexistent id test with changing the database
* Added --from options to deploy and update to define manually from what git commit hash to update from
* Added help menu for fsck, update and deploy commands
* Fixed bug in nonexistent id test where non-standard rows would be tests on
* Changed --git-dir option to not necessitate "=" sign when defining git directory

### v0.2.5
* Fixed bug with command parser not parsing options correctly
* Fixed bug where deploy would fail with errors that didn't exist

### v0.2.6
* Added "all" condition to apply exclude or include to all database
* Fixed bug where disk usage calculator would ungracefully exit when database had no selected tracks
* Added REPO_ID field to database to make sure that the provided GIT directory is the right git repo

### v0.3
* Added import function that allows importation of lone tracks and images from EAC and CUETOOLS
* Updated build.sh script to better debug functions
* Command "deploy" now "export"
* Fixed bug where on some version of shntool, the deploy process would fail
* Deprecated need for cuebreakpoints tool

### v0.3.1
* Rewrote import images function
* Fixed sanity check bug during fsck
* Fixed bug where non-english characters wouldn't compare well during include and exclude command
