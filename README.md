# Gunbot

Gunbot is a Discord bot that use Gunbroker's REST API to allow users to search for items.

Running the `!help` command displays the following:
```
!daily - Create a daily recurring search - !daily {PRICE} {KEYWORDS}
!ffl - Search for nearby FFLs - !ffl {ZIP_CODE}
!help - Show all commands - !help
!remove - Remove a recurring search - !remove {DAILY_SEARCH_ID}
!search - Do a one-time search - !search {PRICE} {KEYWORDS}
!show - Show all recurring searches - !show
```

To run this locally, you'll need a Discord API Token, a Gunbroker API Dev Key, and an instance of Postgresql.

Configuration is done through environment variables. See `example.env` or `config/{config.exs|releases.exs}` for more info.

For daily searches, gunbot will send messages to the channel the daily search was created in. 