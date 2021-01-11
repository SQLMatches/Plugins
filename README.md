## Setup
- Visit [SQLMatches.com](https://sqlmatches.com) & create a community to get an API key.
- Upload the plugin onto your server & load it.
- Go to `/cfg/sourcemod/sqlmatches.cfg` & set your API key.


## CVARs
#### Set all of these under sqlmatches.cfg
- sm_sqlmatches_announce
    - Get version announcements, used to alert you to new plugin versions.
- sm_sqlmatches_autoconfig
    - Automatically sets up server CVARs for demo recording.
- sm_sqlmatches_key
    - SQLMatches.com API key.
- sm_sqlmatches_start_round_upload
    - 0, Upload demo at match end.
    - 1, Upload demo at start of next match.
- sm_sqlmatches_delete_after_upload
    - Delete demo file after successfully upload.