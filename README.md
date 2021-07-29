# Gunbot

Gunbot is a Discord bot that uses Gunbroker's REST API to allow users to search for items.

Running the `!help` command displays the following:
```
`!daily` - Create a daily recurring search - `!daily [{CATEGORY}] {PRICE} {KEYWORDS}`
`!ffl` - Search for nearby FFLs - `!ffl {ZIP_CODE}`
`!help` - Show all commands - `!help`
`!remove` - Remove a recurring search - `!remove {DAILY_SEARCH_ID}`
`!search` - Do a one-time search - `!search [{CATEGORY}] {PRICE} {KEYWORDS}`
`!show` - Show all recurring searches - `!show`

  The search and daily commands accept an optional category flag
    `-g`    Guns & Firearms (default)
        `-p`    Pistols
        `-r`    Rifles
        `-s`    Shotguns
    `-a`    Ammo
    `-o`    Optics

  Examples
    `!daily 350 mosin nagant`
    `!search -p 625 glizzy 19`
```

To run this locally, you'll need a Discord API Token, a Gunbroker API Dev Key, and an instance of Postgresql.

Configuration is done through environment variables. See `example.env` or `config/{config.exs|releases.exs}` for more info.

For daily searches, gunbot will send messages to the channel the daily search was created in. 
