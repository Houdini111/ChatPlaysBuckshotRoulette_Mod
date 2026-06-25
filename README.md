
# What is this?

This is a mod for the game [Buckshot Roulette](https://store.steampowered.com/app/2835570/). It adds the capability for a Twitch chat to:

- Play endless mode by voting on which actions to take on each turn
- The mod intelligently only presents only valid options, including de-duping when multiple items are available
- Adds the ability for chat to vote on the name they want to use on the next run
- Allows chat to vote on whether to continue for another set during the double or nothing round
- Automatically navigates the menus before and after the game, starting from after loading into the bathroom
- This includes activating endless mode, leaving the bathroom, entering the backroom, picking up the waiver, entering the name, taking the items, and opening the briefcase at the end of a run

The bot also includes the ability to automatically generate OAuth tokens with twitch and refresh them when required.

![](https://raw.githubusercontent.com/Houdini111/ChatPlaysBuckshotRoulette_Mod/refs/heads/main/github-assets/ModInUse.png)

# How to install

## Installing the files

1. Download the addons.zip and Houdini111-ChatPlaysBuckshotRoulette.zip from this github
2. Extract unzip addons.zip and place in _**BOTH**_ the root of the project and beside the executable
	- Right click the game and click "Browse Local Files". This is the root. Put one copy of the addons folder here
	- Open the `Buckshot Roulette` folder. Paste the addons folder in here again
- This is probably called `Buckshot Roulette-windows` on Windows. It is called `Buckshot Roulette-Linux` on Linux. +
3. Create a `mods` folder beside the game's executable
4. Move `Houdini111-ChatPlaysBuckshotRoulette.zip` into the `mods` folder. Do NOT unzip

If you've set it up right then your folder structure should look like

```

── Buckshot Roulette
	├── addons
		├── mod_loader
		└── JSON_Schema_Validator
	└── Buckshot Roulette_windows or Buckshot Roulette_linux
		├── Buckshot Roulette.exe or Buckshot Roulette.x86_64
			├── addons
			├── mod_loader
			└── JSON_Schema_Validator
		└── mods
			└── Houdini111-ChatPlaysBuckshotRoulette.zip
			
```

## Updating Steam run options

- Right click the game in Steam
- Click Properties
- Ensure you are on the General page
- Copy/paste `--script addons/mod_loader/mod_loader_setup.gd` into Launch Options field

**NOTE**: You do **NOT** need a %command% in the Launch Options

# Running the mod

Simply click play inside steam.

## First run

On first boot the mod loader will notice and give you a prompt telling you a new mod was installed and that it needs to reboot. You can simply wait for it to do so by itself or you can click the button to confirm. Because Buckshot Roulette automatically hides the cursor it is probably easier to press the enter key.
Once the game boots again the mod should be successfully loaded. At this point you should have a new notification at the top of the screen notifying you that the bot needs to be authenticated. If you have no notifications at the top of the screen then the bot has probably not been installed correctly. 

![](https://raw.githubusercontent.com/Houdini111/ChatPlaysBuckshotRoulette_Mod/refs/heads/main/github-assets/MainMenu-ConnectionError.png)

## Configuring

The mod's options have been integrated into the game itself. You can change them by going to Option -> Chat Plays

![](https://raw.githubusercontent.com/Houdini111/ChatPlaysBuckshotRoulette_Mod/refs/heads/main/github-assets/OptionsMenu-ConnectionError.png)

The bot has the following options:

- Channel Name
	- This should be set to the username of the account you want the bot to read and chat in. You can check yours at https://www.twitch.tv/settings/profile. It should be Username, not Display Name.
- Bot Authorized 
	- The checkbox indicates if the bot is authenticated with Twitch. You will click on the Authorize button on the right to begin the process more in the Authorizing section below
- Default Name
	- The name that the bot will enter into the waiver if no name votes are entered. Limited to 6 alpha characters because that's the restrictions in game
	- Defaults to "CHAT"
- Action Vote Period
	- When it is the player's turn the chat gets time to vote. This setting determines how many seconds the bot will wait for votes.
- Instructions Cooldown
	- The bot includes the command !instructions. To prevent spam the bot will ignore requests while the cooldown is runing. This setting determines how many seconds must pass before the bot will respond again.

Set the settings as you like and then click Save at the bottom

![](https://raw.githubusercontent.com/Houdini111/ChatPlaysBuckshotRoulette_Mod/refs/heads/main/github-assets/ModSettingsPage.png)

## Authorizing

The mod needs chat read and write permissions to your Twitch account to read chat messages and respond in chat. You need to grant the bot access to an account and grant permission. You do this by clicking on the Authorize button in the Chat Plays Options setting. 
- Click the Authorize button to begin. This will open a browser tab with Twitch. 
- The game will have a popup with the a code. Verify it matches the code inside the new browser tab. If it does, click Activate on the tab. The page will reload.
- You should now be on the Authorize page where Twitch is telling you the bot would like to read chat messages and send messages as you. Verify the code in game matches the code in the tab again. Click Authorize to allow the bot to read and write messages as you. 

![](https://raw.githubusercontent.com/Houdini111/ChatPlaysBuckshotRoulette_Mod/refs/heads/main/github-assets/Twitch-Activate.png)

- The tab will now reload to the Twitch Connections tab. If you scroll to the bottom you can now verify that `ChatPlaysBuckshotRoulette` is listed in your Other Connections section. You may now close the tab

![](https://raw.githubusercontent.com/Houdini111/ChatPlaysBuckshotRoulette_Mod/refs/heads/main/github-assets/Twitch-Authorize.png)

- The game's verification code popup should have closed, you should have gotten a notification at the top saying the bot is authenticated and ready to go, and the bot should have posted as you in the channel specified by the settings saying that it is connected and ready.

***NOTE***: If you would like the bot to use a different account then you need to be signed into that account when before you begin this process. The bot may occasionally try to send messages back to back. If the Twitch account you gave is not your Streamer account, a Moderator, or a VIP then it it will be rate limited and these occasional rapid messages will be ignored by Twitch. So please ensure the account used is one of those for best results.

# Other notes for the curious

This mod is a re-implementation of https://github.com/Houdini111/ChatPlaysBuckshotRoulette, which was effectively blind. It worked surprisingly well but I was not satisfied. This mod is faster, more reliable, more reliable, easier to install, better looking for chat, and a better chat experience (particularly with how it handles the using of the adrenaline item)

The git history is incomplete because I developed this with the source decompiled using [GDRE](https://github.com/GDRETools/gdsdecomp). For it to work correctly with the game in the editor it requires modifying the source files. To make sure I didn't make unintended changes it was easiest to include it in my repo. But I will not share the game's assets so this repo is not what I developed in.

The mod_loader included in this mod is a fork of [GodotModLoader](https://github.com/GodotModding/godot-mod-loader) v7.0.1. I had to make a few tweaks to allow this mod to load properly.
As part of my slightly modified version of the mod loader I'm also using [GDRE](https://github.com/GDRETools/gdsdecomp) v2.5.0 
And for my decompilation I'm also making use of [GodotSteam](https://codeberg.org/godotsteam/godotsteam) [v4.4.1](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.4.1), which I believe to be the newest version that supports this version of Godot
