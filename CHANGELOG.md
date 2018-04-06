### v0.1
* Initial version supporting basic deployment of music collection, and basic inclusion and exclusion based on metadata pattern searching

### v0.2
* Rewrote deployment workflow to allow for smarter cleaning of unselected IMAGEIDs on TARGET
* Added "du" command to check projected disk usage of selected IMAGEIDs
* Added disk usage function on "deploy" function that checks if TARGET has enough space for what is to be deployed
* Fixed bug where everything in track title after a colon would disappear
* Fixed bug where sometimes two colliding trackids would cause mahem
* In the event that no title is set to track, album is used as name instead
* Added LAST_DEPLOY and LAST_UPDATE variable in database for keeping track of what commit was the last update and deployment done on.
* Metadata updates are now done on just the imageids that were updated since last deployment

