# SQLMatches 0.0.13 is no longer maintained
Dear SQLMatches users, SQLMatches.com will be offline after the 20th of August 2021.
We'll be returning whenever `1.0.0` is completed.

## Setup
- Visit [SQLMatches.com](https://sqlmatches.com) & create a community to get an API key.
- Upload the plugins onto your server & load them.
    - [How to download](#downloading-compiled-plugin)
- Install [extensions](/addons/sourcemod/extensions)
- Install [configs](/addons/sourcemod/configs)
- Make sure to set these CVARs.
    - `tv_enable 1`
    - `tv_autorecord 0`
    - `sv_hibernate_when_empty 0`
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
- sm_sqlmatches_community_name
    - Name of community from SQLMatches, needed for Discord webhooks.
- sm_sqlmatches_start_round_upload
    - 0, Upload demo at match end.
    - 1, Upload demo at start of next match.
- sm_sqlmatches_delete_after_upload
    - Delete demo file after successfully upload.
- sm_sqlmatches_discord_match_end
    - Discord webhook to push at match end, leave blank to disable.
- sm_sqlmatches_discord_match_start
    - Discord webhook to push at match start, leave blank to disable.
- sm_sqlmatches_discord_round_end
    - Discord webhook to push at round end, leave blank to disable.
- sm_sqlmatches_discord_embed_decimal
    - Decimal color code for embed messages, [Hex to decimal converter](https://www.binaryhexconverter.com/hex-to-decimal-converter).
- sm_sqlmatches_discord_name
    - Set discord name, please leave as SQLMatches.com if using hosted version.
- sm_sqlmatches_discord_avatar
    - URL to avatar.
- sm_sqlmatches_end_of_round_message
    - Disable SQLMatches' end of round message.

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
