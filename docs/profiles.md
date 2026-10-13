# Profiles: rebuild a specific server without the menus

A profile is a folder that describes one machine completely:

```
myserver/
  profile.env            BUNDLES + the same settings the menus write (see config.env.example), plus:
                           SECRETS_ENV=/path/secrets.env   values that overrides reference as ${VAR}
                           EXCLUDE="welcome ..."           catalogue services this machine does not run
                           SKIP_STEPS="layout wiring dashboard summary"   installer steps to leave out
                           CAPTURE_IGNORE="..."            containers `capture` should not touch
  overrides/<name>.args  changes to one catalogue container (see below)
  extras/<name>.sh       containers that are not in the catalogue (same format as services/*.sh)
```

```
sudo ./install.sh --profile myserver            # install / recreate everything, no questions
./install.sh --render --profile myserver        # print the exact docker run commands, change nothing
tools/profile.py diff --profile myserver        # rendered commands vs the running containers
tools/profile.py capture --profile myserver     # write overrides/extras so the profile matches what is running
./install.sh --profile myserver --only radarr   # recreate just one container (Docker access, no sudo needed)
```

## Override files

One directive per line; `#` starts a comment; `${VAR}` comes from the environment (`SECRETS_ENV`, profile.env);
`$$` is a literal `$`.

```
-e KEY=value            set an env var (replaces the catalogue's value for KEY)
-v /src:/dst:ro         set the mount at /dst
-p 127.0.0.1:8094:80    set the binding of container port 80
--label k=v  --network host  --user 1000:1000  ...   any docker run flag; same key = replaced
unset -e TZ             remove a catalogue flag (unset -p 80, unset --privileged, ...)
image repo/name:tag     use a different image
cmd arg arg ...         replace the command (cmd - = none)
```

Commands are compared by meaning, not text: env by name, mounts by container path, ports by container port, and so
on, so flag order and spelling never show up as differences.

## Capture

`capture` turns the running containers into the profile: catalogue containers become override files with the minimum
set of changes; unknown containers become `extras/<name>.sh` (marked unreviewed); catalogue services that are not
running are added to `EXCLUDE`; extras whose container is gone are removed. Values that equal a value in `SECRETS_ENV`
are written as `${THATVAR}`; secret-looking values not there yet are appended to it. It refuses to write anything if
a secret value would end up in the profile. Running it from cron keeps a profile in step with a server you also change
by hand; `--dry-run` shows what it would write.
