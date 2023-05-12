# Documentation

## CLI Commands for Contestants

There are various CLI commands that are available to the contestants. Read about them [here](./cli.md).

## Scheduled Commands for Contests

There are various commands that are executed around contest time. They are automated via scheduling, but some can be manually executed, too. Read about them [here](./contest.md).

## When VPN/Firewall Goes Wrong

During the contest, when something unexpected happens, we might want to disable VPN and/or disable the firewall. See how [here](./totp.md).

## Logging

All IOI-related commands will create logs to `local0` facility. These logs will also be stored in `/opt/ioi/store/log/local.log` in the contestant VM.
