# Need a larger upload size?
Visit your owner panel on [SQLMatches.com](https://sqlmatches.com) under the community tab to increase the max upload size.


## Setup
- Visit [SQLMatches.com](https://sqlmatches.com) & create a community to get an API key.
- Upload the plugin onto your server & load it.
    - [How to download](#downloading-compiled-plugin)
- Install [extensions](/addons/sourcemod/extensions)
- Go to `/cfg/sourcemod/sqlmatches.cfg` & set your API key.
    - [More details of CVARs.](#cvars)

## Downloading compiled plugin
- ![step 1](https://tinyurl.com/y38tmonn)
    - Click the green tick.
    - Then click details.
- ![step 2](https://tinyurl.com/y3cdvmd6)
    - Click artifacts.
    - Then download 'Compiled plugins' & unzip it.

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

## Thanks to
- [The-Doggy](https://github.com/The-Doggy) - Contributor
- [WardPearce](https://github.com/WardPearce) - Contributor
- [ErikMinekus](https://github.com/ErikMinekus) - Contributor & created [REST in Pawn](https://github.com/ErikMinekus/sm-ripext)
- [SirLamer](https://forums.alliedmods.net/showthread.php?t=101764) - [Base64](https://forums.alliedmods.net/showthread.php?t=101764)
- [thraaawn](https://github.com/thraaawn) - [bzip2](https://github.com/thraaawn/SMbz2)
- [Bara](https://github.com/Bara) - [multicolors](https://github.com/Bara/Multi-Colors)
- [Deathknife](https://github.com/Deathknife) - [discord](https://github.com/Deathknife/sourcemod-discord)
- [SourceMod Include Library](https://github.com/JoinedSenses/SourceMod-IncludeLibrary) - Maintained includes
- [borzaka](https://github.com/borzaka) - Contributor
- [b3none](https://github.com/b3none) - Contributor
- To all the developers who helped to make these packages!
