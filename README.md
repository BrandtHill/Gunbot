# Gunbot

Gunbot is a Discord bot that use Gunbroker's REST API to allow users to search for items.

Running the `!help` command displays the following:
```
!daily - Create a daily recurring search - !daily {PRICE} {KEYWORDS}
!help - Show all commands - !help
!remove - Remove a recurring search - !remove {DAILY_SEARCH_ID}
!search - Do a one-time search - !search {PRICE} {KEYWORDS}
!show - Show all recurring searches - !show
```

To run this locally, you'll need a Discord API Token, a Gunbroker API Dev Key, and an instance of Postgresql.

Configuration is done through environment variables. See `example.env` or `config/{config.exs|releases.exs}` for more info.

Gunbot will respond in the same text channel the user issues the command in, but for a daily "tracked search", the bot will send messages to the configured `DISCORD_DEFAULT_CHANNEL_ID`, ideally a dedicated Gunbot text channel.

*This project is unrelated to the crypto trading bot*